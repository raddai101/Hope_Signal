import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() async => await _recorder.hasPermission();

  Future<String?> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final String filePath =
            '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        const config = RecordConfig(); 

        await _recorder.start(config, path: filePath);
        return filePath;
      }
    } catch (e) {
      print("Erreur démarrage enregistrement: $e");
    }
    return null;
  }

  Future<String?> stopRecording() async {
    try {
      return await _recorder.stop();
    } catch (e) {
      print("Erreur arrêt enregistrement: $e");
      return null;
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}
