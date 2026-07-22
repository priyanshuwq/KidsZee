import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

/// Low-level connection state for the BT Classic transport.
enum BtState { disconnected, connecting, connected, error }

/// A discovered/bonded device, kept transport-agnostic for the UI.
class BtDevice {
  final String address;
  final String name;
  final int? rssi;
  const BtDevice({required this.address, required this.name, this.rssi});
}

/// Wraps `flutter_blue_classic` for HC-05 (SPP). Android-only.
///
/// Responsibilities: list bonded devices, connect by MAC, send newline-terminated
/// string commands, and emit complete incoming lines (buffered + split on '\n').
///
/// This is intentionally behind [CommandService] so a future swap to BLE (HM-10)
/// only touches one layer.
class BtClassicManager {
  BtClassicManager._internal();
  static final BtClassicManager _instance = BtClassicManager._internal();
  factory BtClassicManager() => _instance;

  static const String _sppUuid = '00001101-0000-1000-8000-00805f9b34fb';

  /// HC-05 / Bluetooth Classic is Android-only. On any other platform the plugin
  /// is unimplemented; we never call it (prevents red error screens off-Android).
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final FlutterBlueClassic _bt = FlutterBlueClassic();

  BluetoothConnection? _conn;
  StreamSubscription<Uint8List>? _inputSub;
  String _rxBuffer = '';

  final _stateController = StreamController<BtState>.broadcast();
  final _linesController = StreamController<String>.broadcast();

  BtState _state = BtState.disconnected;
  String? _deviceName;
  String? _deviceAddress;

  Stream<BtState> get stateStream => _stateController.stream;
  Stream<String> get incomingLines => _linesController.stream;
  BtState get state => _state;
  bool get isConnected => _state == BtState.connected;
  String? get connectedDeviceName => _deviceName;
  String? get connectedDeviceAddress => _deviceAddress;

  void _setState(BtState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  /// True if Bluetooth is supported and on. Fails safe to false.
  Future<bool> isBluetoothOn() async {
    if (!isSupported) return false;
    try {
      return await _bt.isEnabled;
    } catch (_) {
      return false;
    }
  }

  Future<void> turnOn() async {
    if (!isSupported) return;
    try {
      await _bt.turnOn();
    } catch (e) {
      debugPrint('[BT] turnOn failed: $e');
    }
  }

  /// Lists already-paired (bonded) devices. HC-05 must be paired in the
  /// Android system Bluetooth settings first.
  Future<List<BtDevice>> getBondedDevices() async {
    if (!isSupported) return const [];
    try {
      final devices = await _bt.bondedDevices ?? const [];
      return devices
          .map((d) => BtDevice(
                address: d.address,
                name: d.alias ?? d.name ?? d.address,
                rssi: d.rssi,
              ))
          .toList();
    } catch (e) {
      debugPrint('[BT] getBondedDevices failed: $e');
      return const [];
    }
  }

  /// Connects to [address]. Returns true on success.
  Future<bool> connect(String address, {String? name}) async {
    if (!isSupported) return false;
    if (_state == BtState.connecting) return false;
    await disconnect(); // ensure clean slate
    _setState(BtState.connecting);
    _deviceAddress = address;
    _deviceName = name;
    try {
      final conn = await _bt.connect(address, uuid: _sppUuid);
      if (conn == null || conn.input == null) {
        _setState(BtState.error);
        return false;
      }
      _conn = conn;
      _rxBuffer = '';
      _inputSub = conn.input!.listen(
        _onBytes,
        onError: (e) {
          debugPrint('[BT] input error: $e');
          _handleDrop();
        },
        onDone: _handleDrop,
        cancelOnError: true,
      );
      _setState(BtState.connected);
      return true;
    } catch (e) {
      debugPrint('[BT] connect failed: $e');
      _conn = null;
      _setState(BtState.error);
      return false;
    }
  }

  void _onBytes(Uint8List data) {
    // SPP delivers arbitrary chunks; reassemble into '\n'-terminated lines.
    _rxBuffer += ascii.decode(data, allowInvalid: true);
    int idx;
    while ((idx = _rxBuffer.indexOf('\n')) != -1) {
      final line = _rxBuffer.substring(0, idx).trim();
      _rxBuffer = _rxBuffer.substring(idx + 1);
      if (line.isNotEmpty && !_linesController.isClosed) {
        _linesController.add(line);
      }
    }
    // Guard against an unbounded buffer if no newline ever arrives.
    if (_rxBuffer.length > 256) _rxBuffer = '';
  }

  void _handleDrop() {
    if (_state == BtState.disconnected) return;
    _inputSub?.cancel();
    _inputSub = null;
    _conn = null;
    _setState(BtState.disconnected);
  }

  /// Sends a raw command with NO terminator. The FABRI Arduino detects
  /// end-of-command by a ~10ms silence gap, so callers must space commands out
  /// (see CommandService's pump). Never throws.
  void sendRaw(String command) {
    final conn = _conn;
    if (conn == null || !isConnected) return;
    try {
      conn.writeString(command);
    } catch (e) {
      debugPrint('[BT] write failed: $e');
      _handleDrop();
    }
  }

  /// Sends one command with a trailing '\n' (kept for any newline-based firmware).
  void sendLine(String command) {
    final conn = _conn;
    if (conn == null || !isConnected) return;
    try {
      conn.writeString('$command\n');
    } catch (e) {
      debugPrint('[BT] write failed: $e');
      _handleDrop();
    }
  }

  Future<void> disconnect() async {
    await _inputSub?.cancel();
    _inputSub = null;
    try {
      await _conn?.close();
    } catch (_) {}
    _conn = null;
    _rxBuffer = '';
    if (_state != BtState.disconnected) _setState(BtState.disconnected);
  }
}
