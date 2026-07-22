import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/doodle_background.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/providers/connection_provider.dart';
import '../../core/providers/last_device_provider.dart';
import '../../core/network/bt_classic_manager.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});
  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final _bt = BtClassicManager();
  List<BtDevice> _bonded = [];
  bool _loading = false;
  bool _btOff = false;
  String? _connectingAddr;
  StreamSubscription<BtState>? _stateSub;

  @override
  void initState() {
    super.initState();
    // Listen for BT state changes — wrap provider mutations in
    // Future.microtask so they never fire during a widget build frame.
    _stateSub = _bt.stateStream.listen((s) {
      if (!mounted) return;
      Future.microtask(() {
        if (!mounted) return;
        final notifier = ref.read(connectionProvider.notifier);
        if (s == BtState.disconnected) notifier.onDisconnected();
        if (s == BtState.connected) notifier.onConnected();
        if (mounted) setState(() {});
      });
    });
    // Everything that touches providers MUST run after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(connectionProvider.notifier).setProtocol(Protocol.btClassic);
      _init();
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    // Bluetooth Classic only exists on Android — never touch the plugin elsewhere.
    if (!BtClassicManager.isSupported) {
      if (mounted) setState(() => _btOff = true);
      return;
    }
    try {
      await _requestPermissions();
      final on = await _bt.isBluetoothOn();
      if (!on) {
        await _bt.turnOn();
      }
      final stillOff = !(await _bt.isBluetoothOn());
      if (mounted) setState(() => _btOff = stillOff);
      await _loadBonded();
    } catch (e, st) {
      // Never let a plugin/permission error crash the screen — fail safe.
      debugPrint('[Connection] init failed: $e\n$st');
      if (mounted) setState(() { _btOff = true; _loading = false; });
    }
  }

  Future<void> _requestPermissions() async {
    // Android 12+ : scan + connect. Older : location.
    try {
      await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.locationWhenInUse,
      ].request();
    } catch (e) {
      debugPrint('[Connection] permission request failed: $e');
    }
  }

  Future<void> _loadBonded() async {
    setState(() => _loading = true);
    final devices = await _bt.getBondedDevices();
    if (!mounted) return;
    setState(() { _bonded = devices; _loading = false; });
  }

  Future<void> _connect(String address, String name) async {
    setState(() => _connectingAddr = address);
    ref.read(connectionProvider.notifier).connect(address, name);
    final ok = await _bt.connect(address, name: name);
    if (!mounted) return;
    setState(() => _connectingAddr = null);
    if (ok) {
      await ref.read(lastDeviceProvider.notifier).save(address, name);
      ref.read(connectionProvider.notifier).onConnected();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to $name'), duration: const Duration(seconds: 1)));
      }
    } else {
      ref.read(connectionProvider.notifier).setError('Could not connect to $name');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to $name'), backgroundColor: AppColors.stopRed));
      }
    }
  }

  Future<void> _disconnect() async {
    await _bt.disconnect();
    ref.read(connectionProvider.notifier).onDisconnected();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(lastDeviceProvider);
    final connected = _bt.isConnected;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DoodleBackground(child: SafeArea(
        child: Column(children: [
          // Header with title and refresh
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(children: [
              Expanded(child: Text('Connect Device', style: AppTypography.headline2())),
              IconButton(
                icon: Icon(_loading ? Icons.hourglass_top : Icons.refresh, color: AppColors.navy, size: 24),
                tooltip: 'Refresh Devices',
                onPressed: _loading ? null : _loadBonded,
              ),
            ]),
          ),
          // Scrollable content
          Expanded(child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _HeaderChip(),
              const SizedBox(height: 12),
              if (_btOff) _InfoBanner(
                color: AppColors.stopRed,
                icon: Icons.bluetooth_disabled,
                text: 'Bluetooth is off. Turn it on to connect.'),
              _InfoBanner(
                color: AppColors.navy,
                icon: Icons.info_outline,
                text: 'Pair your HC-05 in the phone\'s Bluetooth settings first, then it appears below.'),
              const SizedBox(height: 12),

              if (!connected && !saved.isEmpty) ...[
                Text('Saved Device', style: AppTypography.headline3()),
                const SizedBox(height: 8),
                _DeviceCard(name: saved.name.isEmpty ? saved.address : saved.name, id: saved.address,
                  isConnected: false, isSaved: true,
                  busy: _connectingAddr == saved.address,
                  onAction: () => _connect(saved.address, saved.name)),
                const SizedBox(height: 20),
              ],

              if (connected) ...[
                Text('Currently Connected', style: AppTypography.headline3()),
                const SizedBox(height: 8),
                _DeviceCard(name: _bt.connectedDeviceName ?? 'Connected', id: _bt.connectedDeviceAddress ?? '',
                  isConnected: true, isSaved: false, busy: false, onAction: _disconnect),
                const SizedBox(height: 20),
              ],

              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Paired Devices', style: AppTypography.headline3()),
                Text('${_bonded.length}', style: AppTypography.statusText()),
              ]),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 3)))
              else if (_bonded.isEmpty)
                Padding(padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No paired devices.\nPair your HC-05 in system settings.',
                    textAlign: TextAlign.center, style: AppTypography.body())))
              else
                ...List.generate(_bonded.length, (i) {
                  final d = _bonded[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DeviceCard(name: d.name, id: d.address,
                      isConnected: false, isSaved: false,
                      busy: _connectingAddr == d.address,
                      onAction: () => _connect(d.address, d.name)),
                  );
                }),
            ]),
          )),
          // Bottom nav
          const AppBottomNav(activeTab: NavTab.devices),
        ]),
      )),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      const Icon(Icons.bluetooth, color: AppColors.orange, size: 20),
      const SizedBox(width: 8),
      Text('Bluetooth Classic (HC-05)', style: AppTypography.buttonText().copyWith(color: AppColors.navy)),
    ]));
}

class _InfoBanner extends StatelessWidget {
  final Color color; final IconData icon; final String text;
  const _InfoBanner({required this.color, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: AppTypography.statusText().copyWith(color: color))),
    ]));
}

class _DeviceCard extends StatelessWidget {
  final String name, id; final bool isConnected, isSaved, busy; final VoidCallback onAction;
  const _DeviceCard({required this.name, required this.id, required this.isConnected, required this.isSaved, required this.busy, required this.onAction});
  @override
  Widget build(BuildContext context) {
    final iconColor = isConnected ? AppColors.successGreen : (isSaved ? AppColors.navy : AppColors.orange);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isConnected ? AppColors.successGreen.withValues(alpha: 0.3) : AppColors.border, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), offset: const Offset(0, 2), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle, color: iconColor.withValues(alpha: 0.08)),
          child: Icon(isSaved ? Icons.bookmark : Icons.bluetooth, color: iconColor, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: AppTypography.headline3().copyWith(fontSize: 15)),
          Text(isConnected ? '✓ Connected' : id, style: AppTypography.statusText().copyWith(color: isConnected ? AppColors.successGreen : AppColors.textMuted)),
        ])),
        busy
          ? const Padding(padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange)))
          : AppButton(onTap: onAction,
              backgroundColor: isConnected ? AppColors.lightGray : (isSaved ? const Color(0xFF2B2B2B) : AppColors.orange),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(isConnected ? 'Disconnect' : 'Connect', style: AppTypography.buttonText().copyWith(fontSize: 13, color: isConnected ? AppColors.navy : Colors.white))),
      ]),
    );
  }
}
