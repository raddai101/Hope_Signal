import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothClassicDataSource {
  BluetoothConnection? _connection;

  final StreamController<Uint8List> _incomingStreamController =
      StreamController<Uint8List>.broadcast();

  Future<void> connect(String address) async {
    try {
      _connection = await BluetoothConnection.toAddress(address);

      _connection!.input!
          .listen((Uint8List data) {
            _incomingStreamController.add(data);
          })
          .onDone(() {
            _connection = null;
          });
    } catch (e) {
      throw Exception("Erreur de connexion Socket: $e");
    }
  }

  Future<void> write(List<int> data) async {
    if (_connection != null && _connection!.isConnected) {
      _connection!.output.add(Uint8List.fromList(data));
      await _connection!.output.allSent;
    } else {
      throw Exception("Non connecté à l'appareil");
    }
  }

  Stream<Uint8List> get incomingMessages => _incomingStreamController.stream;

  bool get isConnected => _connection?.isConnected ?? false;

  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
  }
}
