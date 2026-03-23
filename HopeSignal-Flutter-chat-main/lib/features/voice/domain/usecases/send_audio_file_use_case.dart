import 'dart:io';
import '../repositories/voice_repository.dart';

class SendAudioFileUseCase {
  final VoiceRepository repository;

  SendAudioFileUseCase(this.repository);

  Future<void> call(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Fichier audio non trouvé: $filePath');
    }

    final stat = await file.stat();
    if (stat.size == 0) {
      throw Exception('Fichier audio vide');
    }

    await repository.sendAudioFile(filePath);
  }
}
