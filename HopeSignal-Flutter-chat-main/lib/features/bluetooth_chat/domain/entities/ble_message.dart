
enum MessageType { text, audio }
class BleMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isFromMe;
  final MessageType type; 
  final Duration? duration; 

  BleMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isFromMe,
    this.type = MessageType.text, 
    this.duration,
  });
}