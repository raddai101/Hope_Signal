import '../entities/voice_message.dart';

abstract class VoiceRepository {
  Stream<VoiceMessage> get incomingVoiceMessages;
  Future<void> sendText(String text);
  Future<void> sendAudioFile(String filepath);
}
