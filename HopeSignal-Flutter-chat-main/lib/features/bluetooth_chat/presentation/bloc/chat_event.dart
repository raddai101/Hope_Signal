import '../../domain/entities/ble_message.dart';

abstract class ChatEvent {}

class InitChatEvent extends ChatEvent {}

class SendTextMessageEvent extends ChatEvent {
  final String text;
  SendTextMessageEvent(this.text);
}

class OnMessageReceivedEvent extends ChatEvent {
  final BleMessage message;
  OnMessageReceivedEvent(this.message);
}

class SendAudioMessageEvent extends ChatEvent {
  final String path;
  SendAudioMessageEvent(this.path);
}
