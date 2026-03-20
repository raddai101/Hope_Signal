import '../entities/ble_message.dart';

abstract class BleRepository {
  Stream<List<BleMessage>> get messagesStream;
  Future<void> connect(String address);
  Future<void> disconnect();
  Future<void> sendMessage(String text);
  Future<void> sendAudioFile(String filepath);
}
