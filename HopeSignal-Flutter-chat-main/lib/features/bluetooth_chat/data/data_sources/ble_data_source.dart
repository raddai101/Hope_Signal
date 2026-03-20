import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothClassicDataSource {
  BluetoothConnection? _connection;

  final _messageStreamController = StreamController<Uint8List>.broadcast();

  Future<void> connect(String address) async {
    try {
      _connection = await BluetoothConnection.toAddress(address);

      _connection!.input!
          .listen((Uint8List data) {
            _messageStreamController.add(data);
          })
          .onDone(() {
            _connection = null;
          });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> write(List<int> data) async {
    if (_connection != null && _connection!.isConnected) {
      _connection!.output.add(Uint8List.fromList(data));
      await _connection!.output.allSent;
    }
  }

  Stream<Uint8List> get incomingMessages => _messageStreamController.stream;

  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
  }
}
