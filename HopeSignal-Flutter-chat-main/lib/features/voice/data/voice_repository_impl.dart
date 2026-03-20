import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../../bluetooth_chat/data/data_sources/bluetooth_classic_data_source.dart';
import '../../bluetooth_chat/domain/entities/ble_message.dart';
import '../../bluetooth_chat/domain/repositories/ble_repository.dart';
import '../domain/entities/voice_message.dart';
import '../domain/repositories/voice_repository.dart';
import 'voice_manager.dart';

class VoiceRepositoryImpl implements VoiceRepository, BleRepository {
  final BluetoothClassicDataSource dataSource;
  final StreamController<VoiceMessage> _incomingVoiceController =
      StreamController<VoiceMessage>.broadcast();

  StreamSubscription<Uint8List>? _dataSub;
  Completer<bool>? _ackCompleter;

  bool _audioReceiving = false;
  int _audioExpectedSeq = 0;
  final List<Uint8List> _audioChunks = [];

  VoiceRepositoryImpl(this.dataSource) {
    _dataSub = dataSource.incomingMessages.listen((data) async {
      await _handleIncoming(data);
    });
  }

  @override
  Stream<VoiceMessage> get incomingVoiceMessages =>
      _incomingVoiceController.stream;

  @override
  Future<void> connect(String address) => dataSource.connect(address);

  @override
  Future<void> disconnect() => dataSource.disconnect();

  @override
  Future<void> sendMessage(String text) => sendText(text);

  @override
  Future<void> sendText(String text) async {
    final payload = utf8.encode(text);
    final chunks = VoiceManager.chunkPayload(Uint8List.fromList(payload));
    int seq = 0;

    for (final chunk in chunks) {
      await _sendWithAck(
        VoiceManager.buildPacket(VoiceManager.flagText, seq, chunk),
        seq,
      );
      seq = (seq + 1) & 0xFF;
    }
  }

  @override
  Future<void> sendAudioFile(String filepath) async {
    final file = File(filepath);
    if (!await file.exists()) {
      throw Exception('Fichier audio introuvable: $filepath');
    }

    final raw = await file.readAsBytes();
    final compressed = VoiceManager.compressAudio(raw);
    final chunks = VoiceManager.chunkPayload(compressed);
    int seq = 0;

    for (int i = 0; i < chunks.length; i++) {
      final isLast = (i == chunks.length - 1);
      final packet = VoiceManager.buildPacket(
        VoiceManager.flagAudio,
        seq,
        chunks[i],
        isLastChunk: isLast,
      );
      await _sendWithAck(packet, seq);
      seq = (seq + 1) & 0xFF;
    }
  }

  Future<void> _sendWithAck(Uint8List packet, int seq) async {
    const int maxRetries = 3;
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;
      _ackCompleter = Completer<bool>();

      await dataSource.write(packet);

      try {
        final ok = await _ackCompleter!.future.timeout(
          const Duration(seconds: 3),
        );
        if (ok) return;
      } catch (_) {
        // timeout ou NAK
      }
    }

    throw Exception('ACK non reçu après $maxRetries tentatives (seq $seq)');
  }

  Future<String> _saveAudioFile(Uint8List decodedBytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final filename = 'audio_recu_${DateTime.now().millisecondsSinceEpoch}.pcm';
    final path = '${dir.path}/$filename';
    await File(path).writeAsBytes(decodedBytes);
    return path;
  }

  Future<void> _handleIncoming(Uint8List data) async {
    if (data.length == 2) {
      final code = data[0];
      if (code == VoiceManager.ack || code == VoiceManager.nak) {
        final isOk = code == VoiceManager.ack;
        if (_ackCompleter != null && !_ackCompleter!.isCompleted) {
          _ackCompleter!.complete(isOk);
          return;
        }
      }
    }

    if (data.length >= 3) {
      try {
        if (!VoiceManager.verifyPacket(data)) return;

        if (VoiceManager.isTextPacket(data)) {
          final parsed = VoiceManager.parseIncomingPacket(data);
          _incomingVoiceController.add(parsed);
          return;
        }

        if (VoiceManager.isAudioPacket(data)) {
          final seq = data[1];
          final isLast = VoiceManager.isLastAudioChunk(data);
          final chunk = data.sublist(3, data.length - 1);

          if (!_audioReceiving || seq == 0) {
            _audioReceiving = true;
            _audioExpectedSeq = 0;
            _audioChunks.clear();
          }

          if (seq != _audioExpectedSeq) {
            // perte/ordre, on redémarre sur le nouveau seq
            _audioChunks.clear();
            _audioExpectedSeq = seq;
          }

          _audioChunks.add(chunk);
          _audioExpectedSeq = (seq + 1) & 0xFF;

          if (isLast) {
            _audioReceiving = false;
            final all = <int>[];
            for (final c in _audioChunks) {
              all.addAll(c);
            }

            final combinedCompressed = Uint8List.fromList(all);
            final decoded = VoiceManager.decompressAudio(combinedCompressed);
            final localPath = await _saveAudioFile(decoded);

            _incomingVoiceController.add(
              VoiceMessage(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                data: decoded,
                type: VoicePacketType.audio,
                timestamp: DateTime.now(),
                isFromMe: false,
                localFilePath: localPath,
              ),
            );

            _audioChunks.clear();
            _audioExpectedSeq = 0;
          }
        }
      } catch (_) {
        // CRC fail ou parse fail
      }
    }
  }

  @override
  Stream<List<BleMessage>> get messagesStream {
    return _incomingVoiceController.stream.map((voiceMessage) {
      if (voiceMessage.type == VoicePacketType.text) {
        final text = utf8.decode(Uint8List.fromList(voiceMessage.data));
        return [
          BleMessage(
            id: voiceMessage.id,
            text: text,
            timestamp: voiceMessage.timestamp,
            isFromMe: false,
            type: MessageType.text,
          ),
        ];
      }

      // Si audio
      final audioPath = voiceMessage.localFilePath ?? 'AUDIO_RECEIVED';
      return [
        BleMessage(
          id: voiceMessage.id,
          text: audioPath,
          timestamp: voiceMessage.timestamp,
          isFromMe: false,
          type: MessageType.audio,
          duration: const Duration(seconds: 0),
        ),
      ];
    });
  }

  @override
  Future<void> dispose() async {
    await _dataSub?.cancel();
    await _incomingVoiceController.close();
  }
}
