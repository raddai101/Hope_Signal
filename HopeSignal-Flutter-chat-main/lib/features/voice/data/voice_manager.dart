import 'dart:typed_data';
import '../domain/entities/voice_message.dart';
import 'voice_codec.dart';

class VoiceManager {
  static const int maxChunkSize = 50;
  static const int flagText = 0x01;
  static const int flagAudio = 0x02;
  static const int ack = 0x06;
  static const int nak = 0x15;

  /// CRC8 poly 0x07 init 0
  static int crc8(Uint8List data) {
    int crc = 0;
    for (final b in data) {
      crc ^= b;
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x80) != 0) {
          crc = ((crc << 1) ^ 0x07) & 0xFF;
        } else {
          crc = (crc << 1) & 0xFF;
        }
      }
    }
    return crc;
  }

  static Uint8List buildPacket(
    int flag,
    int seq,
    Uint8List payload, {
    bool isLastChunk = true,
  }) {
    final packet = BytesBuilder();
    packet.add([flag]);
    packet.add([seq & 0xFF]);

    if (flag == flagAudio) {
      // pour le mode audio, on encode un indicateur last chunk
      packet.add([isLastChunk ? 1 : 0]);
      packet.add(payload);
      final crc = crc8(Uint8List.fromList([isLastChunk ? 1 : 0, ...payload]));
      packet.add([crc]);
      return packet.toBytes();
    }

    // texte : ancien format (pas de champ lastChunk)
    packet.add(payload);
    final crc = crc8(payload);
    packet.add([crc]);
    return packet.toBytes();
  }

  static List<Uint8List> chunkPayload(Uint8List payload) {
    final chunks = <Uint8List>[];
    int offset = 0;
    while (offset < payload.length) {
      int end = (offset + maxChunkSize).clamp(0, payload.length);
      chunks.add(payload.sublist(offset, end));
      offset = end;
    }
    return chunks;
  }

  static bool verifyPacket(Uint8List packet) {
    if (packet.length < 3) return false;
    final flag = packet[0];
    final payloadSegment = packet.sublist(2, packet.length - 1);
    final crcReceived = packet.last;

    // Pour audio on inclut le flag lastChunk dans le CRC
    return crc8(payloadSegment) == crcReceived;
  }

  static bool isTextPacket(Uint8List packet) =>
      packet.isNotEmpty && packet[0] == flagText;
  static bool isAudioPacket(Uint8List packet) =>
      packet.isNotEmpty && packet[0] == flagAudio;
  static bool isLastAudioChunk(Uint8List packet) =>
      packet.length > 2 && packet[2] == 1;

  static VoiceMessage parseIncomingPacket(Uint8List packet) {
    if (!verifyPacket(packet)) {
      throw Exception('CRC invalide');
    }

    final flag = packet[0];

    if (flag == flagText) {
      final payload = packet.sublist(2, packet.length - 1);
      return VoiceMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        data: payload,
        type: VoicePacketType.text,
        timestamp: DateTime.now(),
        isFromMe: false,
      );
    }

    // audio : [flag, seq, isLast, payload..., crc]
    final isLast = isLastAudioChunk(packet);
    final payload = packet.sublist(3, packet.length - 1);

    return VoiceMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      data: payload,
      type: VoicePacketType.audio,
      timestamp: DateTime.now(),
      isFromMe: false,
    );
  }

  static Uint8List compressAudio(Uint8List raw) {
    try {
      return VoiceCodec.compress(raw);
    } catch (_) {
      return VoiceCodec.compressDart(raw);
    }
  }

  static Uint8List decompressAudio(Uint8List compressed) {
    try {
      return VoiceCodec.decompress(compressed);
    } catch (_) {
      return VoiceCodec.decompressDart(compressed);
    }
  }
}
