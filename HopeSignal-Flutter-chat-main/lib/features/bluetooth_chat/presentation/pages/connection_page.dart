import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'; // On reste sur Serial pour ton ESP32
import 'package:lottie/lottie.dart';
import './../../../../main.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_state.dart';
import '../bloc/bluetooth_event.dart';

class BluetoothConnectionPage extends StatefulWidget {
  const BluetoothConnectionPage({super.key});

  @override
  State<BluetoothConnectionPage> createState() =>
      _BluetoothConnectionPageState();
}

class _BluetoothConnectionPageState extends State<BluetoothConnectionPage> {
  bool _isManualScanning = false;

  // Fonction pour simuler le scan avec l'animation
  void _handleManualScan() async {
    setState(() => _isManualScanning = true);

    // On attend 2 secondes pour laisser l'animation Lottie s'exprimer
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      context.read<BluetoothBloc>().add(StartScanEvent());
      setState(() => _isManualScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Bluetooth"),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: primaryColor,
            ),
            onPressed: () =>
                themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark,
          ),
        ],
      ),
      body: BlocConsumer<BluetoothBloc, BluetoothBlocState>(
        listener: (context, state) {
          if (state is ConnectedState)
            Navigator.pushReplacementNamed(context, '/chat');
          if (state is BluetoothErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: _buildStatusCard(theme, primaryColor, isDark),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "APPAREILS DÉTECTÉS",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: secondaryTextColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (state is ScanningState || _isManualScanning)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _buildDeviceList(state, theme, primaryColor),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildAnimatedScanButton(primaryColor),
    );
  }

  Widget _buildDeviceList(
    BluetoothBlocState state,
    ThemeData theme,
    Color primary,
  ) {
    // Si on est en train de "simuler" le scan ou si le Bloc scanne et que la liste est vide
    if (_isManualScanning ||
        (state is ScanningState && state.results.isEmpty)) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/Bluetooth.json', // Ton fichier Lottie
                width: 200,
                repeat: true,
              ),
              const SizedBox(height: 16),
              const Text(
                "Recherche de modules Hope...",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final devices = (state is ScanningState)
        ? state.results
        : <BluetoothDevice>[];

    if (devices.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            "Aucun appareil trouvé",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final device = devices[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListTile(
              leading: Icon(Icons.bluetooth, color: primary),
              title: Text(
                device.name ?? "Inconnu",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(device.address),
              onTap: () => context.read<BluetoothBloc>().add(
                ConnectToDeviceEvent(device),
              ),
            ),
          );
        }, childCount: devices.length),
      ),
    );
  }

  Widget _buildAnimatedScanButton(Color primary) {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isManualScanning ? null : _handleManualScan,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isManualScanning
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.radar_rounded),
                  SizedBox(width: 12),
                  Text(
                    "Lancer le scan",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme, Color primary, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primary.withOpacity(0.1),
            child: Icon(Icons.bluetooth_audio_rounded, color: primary),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Signal Radio",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                "Modules Hope ESP32",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
