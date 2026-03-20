import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

abstract class BluetoothBlocState {}

class BluetoothInitial extends BluetoothBlocState {}

class ScanningState extends BluetoothBlocState {
  final List<BluetoothDevice> results; // Liste des appareils appairés/détectés
  ScanningState(this.results);
}

class ConnectingState extends BluetoothBlocState {
  final BluetoothDevice device;
  ConnectingState(this.device);
}

class ConnectedState extends BluetoothBlocState {
  final BluetoothDevice device;
  ConnectedState(this.device);
}

class BluetoothErrorState extends BluetoothBlocState {
  final String message;
  BluetoothErrorState(this.message);
}
