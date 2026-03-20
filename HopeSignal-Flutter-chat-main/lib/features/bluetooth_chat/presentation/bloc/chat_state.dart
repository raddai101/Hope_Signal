import '../../domain/entities/ble_message.dart';
import '../../data/models/chat_message.dart';

class ChatState {
  final List<BleMessage> messages;
  final bool isReady; 
  final String? error;

  ChatState({this.messages = const [], this.isReady = false, this.error});

  ChatState copyWith({
    List<BleMessage>? messages,
    bool? isReady,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isReady: isReady ?? this.isReady,
      error: error ?? this.error,
    );
  }
}


