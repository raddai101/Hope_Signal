import '../entities/voice_message.dart';

abstract class VoiceRepository {
  /// Stream de messages reçus (texte ou audio)
  Stream<VoiceMessage> get incomingVoiceMessages;

  /// Envoyer un message texte avec ACK/NAK/CRC
  Future<void> sendText(String text);

  /// Envoyer un fichier audio compressé en chunks avec ACK/NAK/CRC
  Future<void> sendAudioFile(String filepath);
}
