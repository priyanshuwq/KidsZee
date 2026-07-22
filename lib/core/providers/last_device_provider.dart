import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The last successfully connected device, persisted so it can be shown as the
/// "Saved Device" and used for auto-reconnect.
class LastDevice {
  final String address;
  final String name;
  const LastDevice({required this.address, required this.name});

  bool get isEmpty => address.isEmpty;
  static const empty = LastDevice(address: '', name: '');
}

class LastDeviceNotifier extends StateNotifier<LastDevice> {
  LastDeviceNotifier() : super(LastDevice.empty) {
    _load();
  }

  static const _kAddr = 'last_device_mac';
  static const _kName = 'last_device_name';

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final addr = p.getString(_kAddr) ?? '';
      final name = p.getString(_kName) ?? '';
      if (addr.isNotEmpty) state = LastDevice(address: addr, name: name);
    } catch (_) {
      // fail-safe: no saved device
    }
  }

  Future<void> save(String address, String name) async {
    state = LastDevice(address: address, name: name);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kAddr, address);
      await p.setString(_kName, name);
    } catch (_) {}
  }

  Future<void> forget() async {
    state = LastDevice.empty;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kAddr);
      await p.remove(_kName);
    } catch (_) {}
  }
}

final lastDeviceProvider =
    StateNotifierProvider<LastDeviceNotifier, LastDevice>(
  (ref) => LastDeviceNotifier(),
);
