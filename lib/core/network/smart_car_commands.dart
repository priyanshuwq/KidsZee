import 'bt_classic_manager.dart';

/// Directions the Smart Car understands, mapped to the exact single-char
/// Bluetooth protocol expected by `smart_car.ino` (HC-05, no terminator —
/// each command is one raw char, no inter-command gap needed).
///
/// NOTE: the Arduino firmware now uses standard letter mapping where the
/// chars match their direction names or layout:
///   U → forward()   D → backward()   L → leftTurn()   R → rightTurn()   S → stopCar()
enum CarDirection { forward, backward, left, right, stop }

extension CarDirectionChar on CarDirection {
  String get char => switch (this) {
        CarDirection.forward => 'U',
        CarDirection.backward => 'D',
        CarDirection.left => 'L',
        CarDirection.right => 'R',
        CarDirection.stop => 'S',
      };

  String get label => switch (this) {
        CarDirection.forward => 'FWD',
        CarDirection.backward => 'BACK',
        CarDirection.left => 'LEFT',
        CarDirection.right => 'RIGHT',
        CarDirection.stop => 'STOP',
      };
}

/// Thin helper that sends single-char Smart Car BT commands directly via
/// [BtClassicManager]. Bypasses `CommandService` — that layer is built for
/// the FABRI Robotic Arm protocol (multi-char frames needing a ~10ms silence
/// gap between commands). The Smart Car protocol is a single raw char with
/// no gap required, so wiring through CommandService would add complexity
/// (and an incorrect protocol assumption) for no benefit.
class SmartCarCommands {
  SmartCarCommands._();

  static DateTime? _lastSend;
  static const _minInterval = Duration(milliseconds: 50);

  /// Sends [direction]'s char over BT Classic. Throttled to at most one send
  /// every 50ms so callers (D-Pad press-repeat timers, per-frame gyro tilt
  /// checks) can call this freely without flooding the HC-05 link.
  static void send(CarDirection direction) {
    final now = DateTime.now();
    if (_lastSend != null && now.difference(_lastSend!) < _minInterval) return;
    _lastSend = now;
    _dispatch(direction);
  }

  /// Sends STOP immediately, bypassing the throttle — a stop must never be
  /// dropped (press-release, tilt-back-to-neutral, voice "stop").
  static void stop() => _dispatch(CarDirection.stop);

  static void _dispatch(CarDirection direction) {
    BtClassicManager().sendRaw(direction.char);
  }
}
