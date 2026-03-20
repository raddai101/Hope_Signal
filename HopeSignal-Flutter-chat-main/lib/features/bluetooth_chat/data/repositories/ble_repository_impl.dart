import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../../domain/entities/ble_message.dart';
import '../../domain/repositories/ble_repository.dart';
import '../data_sources/bluetooth_classic_data_source.dart';
import '../../../voice/data/voice_manager.dart';

class BleRepositoryImpl implements BleRepository {
  final BluetoothClassicDataSource dataSource;
  final StreamController<List<BleMessage>> _incomingController =
      StreamController<List<BleMessage>>.broadcast();

  StreamSubscription<Uint8List>? _dataSub;
  Completer<bool>? _ackCompleter;

  BleRepositoryImpl(this.dataSource) {
    _dataSub = dataSource.incomingMessages.listen(_handleIncoming);
  }

  @override
  Future<void> connect(String address) async {
    try {
      await dataSource.connect(address);
    } catch (e) {
      throw Exception("Erreur de connexion dans le Repository: $e");
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await dataSource.disconnect();
      await _dataSub?.cancel();
      await _incomingController.close();
    } catch (e) {
      throw Exception("Erreur lors de la déconnexion: $e");
    }
  }

  @override
  Future<void> sendMessage(String text) async {
    final payload = utf8.encode(text);
    final chunks = VoiceManager.chunkPayload(Uint8List.fromList(payload));
    int seq = 0;

    for (final chunk in chunks) {
      final packet = VoiceManager.buildPacket(
        VoiceManager.flagText,
        seq,
        chunk,
      );
      print(
        "📤 TEXTE envoyé via BT: seq=$seq, size=${chunk.length}, packet=${packet.length} bytes",
      );
      await _sendWithAck(packet, seq);
      seq = (seq + 1) & 0xFF;
    }
  }

  @override
  Future<void> sendAudioFile(String filepath) async {
    final file = File(filepath);
    if (!await file.exists()) {
      throw Exception('Fichier audio introuvable: $filepath');
    }

    final fileRaw = await file.readAsBytes();
    print("🎵 AUDIO brut lu: ${fileRaw.length} bytes");

    final compressed = VoiceManager.compressAudio(Uint8List.fromList(fileRaw));
    print(
      "🗜️ AUDIO compressé: ${compressed.length} bytes (ratio: ${(compressed.length / fileRaw.length * 100).toStringAsFixed(1)}%)",
    );

    final chunks = VoiceManager.chunkPayload(compressed);
    print(
      "📦 AUDIO divisé en ${chunks.length} chunks de max ${VoiceManager.maxChunkSize} bytes",
    );

    int seq = 0;

    for (int i = 0; i < chunks.length; i++) {
      final isLast = (i == chunks.length - 1);
      final packet = VoiceManager.buildPacket(
        VoiceManager.flagAudio,
        seq,
        chunks[i],
        isLastChunk: isLast,
      );
      print(
        "📤 Envoi chunk audio $i/${chunks.length - 1} (seq:$seq, last:$isLast, size:${chunks[i].length})",
      );
      await _sendWithAck(packet, seq);
      seq = (seq + 1) & 0xFF;
    }

    print("✅ AUDIO envoyé complètement");
  }

  Future<void> _sendWithAck(Uint8List packet, int seq) async {
    const maxRetries = 3;
    int tries = 0;

    while (tries < maxRetries) {
      tries += 1;
      _ackCompleter = Completer<bool>();
      await dataSource.write(packet);

      try {
        final ok = await _ackCompleter!.future.timeout(
          const Duration(seconds: 3),
        );
        if (ok) return;
      } catch (_) {
        // Timeout or NAK, on repart
      }
    }

    throw Exception('ACK non reçu après $maxRetries tentatives (seq $seq)');
  }

  void _handleIncoming(Uint8List bytes) {
    // ACK/NAK reçus de l'ESP32
    if (bytes.length == 2) {
      final control = bytes[0];
      if (control == VoiceManager.ack || control == VoiceManager.nak) {
        if (_ackCompleter != null && !_ackCompleter!.isCompleted) {
          _ackCompleter!.complete(control == VoiceManager.ack);
          return;
        }
      }
    }

    // Traiter comme paquet binaire (ESP32 trans.ino envoie des paquets [flag, seq, payload..., crc])
    if (bytes.length >= 3 && VoiceManager.verifyPacket(bytes)) {
      final flag = bytes[0];
      final payload = bytes.sublist(2, bytes.length - 1);
      final type = flag == VoiceManager.flagAudio
          ? MessageType.audio
          : MessageType.text;

      String text = '';
      if (type == MessageType.text) {
        text = utf8.decode(payload, allowMalformed: true);
        print("📥 TEXTE reçu via BT: '$text'");
      } else {
        try {
          final decompressed = VoiceManager.decompressAudio(
            Uint8List.fromList(payload),
          );
          text = 'AUDIO_CHUNK_${decompressed.length}';
          print(
            "📥 AUDIO chunk reçu: ${payload.length} bytes compressés -> ${decompressed.length} bytes décompressés",
          );
        } catch (_) {
          text = 'AUDIO_CHUNK_NON_DECOMPRESSIBLE';
          print("❌ Erreur décompression audio chunk");
        }
      }

      final message = BleMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        timestamp: DateTime.now(),
        isFromMe: false,
        type: type,
      );

      _incomingController.add([message]);
    } else {
      print(
        "⚠️ Données reçues non reconnues: ${bytes.length} bytes, premier byte: ${bytes.isNotEmpty ? bytes[0] : 'N/A'}",
      );
    }
  }

  @override
  Stream<List<BleMessage>> get messagesStream => _incomingController.stream;
}
