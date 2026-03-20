import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../../domain/repositories/ble_repository.dart'; 
import 'bluetooth_event.dart';
import 'bluetooth_state.dart';

class BluetoothBloc extends Bloc<BluetoothEvent, BluetoothBlocState> {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  final BleRepository
  repository; 

  BluetoothBloc({required this.repository}) : super(BluetoothInitial()) {
    on<StartScanEvent>((event, emit) async {
      emit(ScanningState(const []));
      try {
        bool? isEnabled = await _bluetooth.isEnabled;
        if (isEnabled != true) {
          emit(BluetoothErrorState("Veuillez activer le Bluetooth"));
          return;
        }

        
        List<BluetoothDevice> bondedDevices = await _bluetooth
            .getBondedDevices();

        emit(ScanningState(bondedDevices));
      } catch (e) {
        emit(
          BluetoothErrorState(
            "Erreur lors de la récupération des appareils: $e",
          ),
        );
      }
    });

    on<ConnectToDeviceEvent>((event, emit) async {
      emit(ConnectingState(event.device));
      try {
        await repository.connect(event.device.address);

        emit(ConnectedState(event.device));
      } catch (e) {
        emit(
          BluetoothErrorState(
            "Échec de connexion à ${event.device.name}. Vérifiez qu'il est bien appairé.",
          ),
        );
      }
    });

    on<ToggleBluetoothEvent>((event, emit) async {
      try {
        if (event.enable) {
          await _bluetooth.requestEnable();
        } else {
          await _bluetooth.requestDisable();
        }
        add(StartScanEvent());
      } catch (e) {
        emit(BluetoothErrorState("Impossible de changer l'état Bluetooth"));
      }
    });

    on<StopScanEvent>((event, emit) async {
      await repository.disconnect();
      emit(BluetoothInitial());
    });
  }
}
