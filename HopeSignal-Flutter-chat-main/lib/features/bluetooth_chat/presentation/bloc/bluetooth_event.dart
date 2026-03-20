import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

abstract class BluetoothEvent {}

class StartScanEvent extends BluetoothEvent {}

class ConnectToDeviceEvent extends BluetoothEvent {
  final BluetoothDevice device;
  ConnectToDeviceEvent(this.device);
}

class ToggleBluetoothEvent extends BluetoothEvent {
  final bool enable;
  ToggleBluetoothEvent(this.enable);
}

class StopScanEvent extends BluetoothEvent {}
