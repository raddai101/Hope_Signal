import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<void> requestBluetoothPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.microphone, 
      Permission.location, 
    ].request();

    if (statuses[Permission.bluetoothConnect]!.isDenied) {
      print("Permission Bluetooth Connect refusée");
    }
  }
}
