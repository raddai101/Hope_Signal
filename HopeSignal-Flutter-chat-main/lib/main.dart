import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/services/permission_service.dart';
import 'features/bluetooth_chat/data/data_sources/bluetooth_classic_data_source.dart';
import 'features/bluetooth_chat/data/repositories/ble_repository_impl.dart';
import 'features/bluetooth_chat/presentation/bloc/bluetooth_bloc.dart';
import 'features/bluetooth_chat/presentation/bloc/bluetooth_event.dart';
import 'features/bluetooth_chat/presentation/bloc/chat_bloc.dart';
import 'features/bluetooth_chat/presentation/pages/connection_page.dart';
import 'features/bluetooth_chat/presentation/pages/chat_page.dart';
import 'features/bluetooth_chat/presentation/pages/splash_page.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On demande TOUTES les permissions (BT + Micro) au démarrage
  await PermissionService.requestBluetoothPermissions();

  final dataSource = BluetoothClassicDataSource();
  final repository = BleRepositoryImpl(dataSource);

  runApp(HopeSignalApp(repository: repository));
}

class HopeSignalApp extends StatelessWidget {
  final BleRepositoryImpl repository;
  const HopeSignalApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<BleRepositoryImpl>.value(value: repository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<BluetoothBloc>(
            create: (context) =>
                BluetoothBloc(repository: repository)..add(StartScanEvent()),
          ),
          BlocProvider<ChatBloc>(create: (context) => ChatBloc(repository)),
        ],
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentMode, child) {
            return MaterialApp(
              title: 'Hope Signal',
              debugShowCheckedModeBanner: false,
              themeMode: currentMode,
              theme: ThemeData(
                brightness: Brightness.light,
                primaryColor: const Color(0xFF007AFF),
                scaffoldBackgroundColor: const Color(0xFFF2F2F7),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  centerTitle: true,
                ),
                textTheme: GoogleFonts.plusJakartaSansTextTheme(),
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                primaryColor: const Color(0xFF007AFF),
                scaffoldBackgroundColor: Colors.black,
                cardColor: const Color(0xFF1C1C1E),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF1C1C1E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  centerTitle: true,
                ),
                textTheme: GoogleFonts.plusJakartaSansTextTheme(
                  ThemeData.dark().textTheme,
                ),
              ),
              initialRoute: '/splash',
              routes: {
                '/splash': (context) => const SplashPage(),
                '/': (context) => const BluetoothConnectionPage(),
                '/chat': (context) => const ChatPage(),
              },
            );
          },
        ),
      ),
    );
  }
}
