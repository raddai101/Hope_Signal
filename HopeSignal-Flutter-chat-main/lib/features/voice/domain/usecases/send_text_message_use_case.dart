import '../repositories/voice_repository.dart';

class SendTextMessageUseCase {
  final VoiceRepository repository;

  SendTextMessageUseCase(this.repository);

  Future<void> call(String text) async {
    if (text.trim().isEmpty) {
      throw Exception('Texte vide');
    }
    await repository.sendText(text);
  }
}
