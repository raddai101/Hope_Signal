enum MessageType { text, audio }

class ChatMessage {
  final String text; 
  final bool isFromMe;
  final MessageType type;
  final Duration? duration;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isFromMe,
    this.type = MessageType.text,
    this.duration,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
