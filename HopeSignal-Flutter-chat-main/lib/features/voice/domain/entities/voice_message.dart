enum VoicePacketType { text, audio }

class VoiceMessage {
  final String id;
  final List<int> data;
  final VoicePacketType type;
  final DateTime timestamp;
  final bool isFromMe;
  final String? localFilePath;

  VoiceMessage({
    required this.id,
    required this.data,
    required this.type,
    required this.timestamp,
    required this.isFromMe,
    this.localFilePath,
  });
}
