import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ControlMode { rcCar, robotArm, ottoRobot, spiderRobot }

final controllerModeProvider = StateProvider<ControlMode>(
  (ref) => ControlMode.rcCar,
);

// Gyro calibration offset
final calibrationProvider = StateProvider<double>((ref) => 0.0);

// Gyro sensitivity (0.5 – 2.0)
final gyroSensitivityProvider = StateProvider<double>((ref) => 1.0);

// Gyro deadzone (0.05 – 0.4)
final gyroDeadzoneProvider = StateProvider<double>((ref) => 0.15);

// Speed (0–100)
final speedProvider = StateProvider<int>((ref) => 60);

// Tactile & Connection Settings
final buttonSizeProvider = StateProvider<String>((ref) => 'Medium');
final autoReconnectProvider = StateProvider<bool>((ref) => true);
final hapticFeedbackProvider = StateProvider<bool>((ref) => true);
final defaultProtocolProvider = StateProvider<String>((ref) => 'BT Classic');

// Customizable D-Pad Keyboard Keybinds
final keybindForwardProvider = StateProvider<String>((ref) => 'W');
final keybindBackwardProvider = StateProvider<String>((ref) => 'S');
final keybindLeftProvider = StateProvider<String>((ref) => 'A');
final keybindRightProvider = StateProvider<String>((ref) => 'D');

// ── Otto Robot (4 servos default) ───────────────────────────────────────────
/// Each servo: [label, angle 0-180]
class ServoConfig {
  final String label;
  final double angle;
  const ServoConfig({required this.label, this.angle = 90});
  ServoConfig copyWith({String? label, double? angle}) =>
      ServoConfig(label: label ?? this.label, angle: angle ?? this.angle);
}

final ottoServosProvider = StateNotifierProvider<ServoListNotifier, List<ServoConfig>>(
  (ref) => ServoListNotifier([
    const ServoConfig(label: 'Left Leg'),
    const ServoConfig(label: 'Right Leg'),
    const ServoConfig(label: 'Left Foot'),
    const ServoConfig(label: 'Right Foot'),
    const ServoConfig(label: 'Left Hand'),
    const ServoConfig(label: 'Right Hand'),
  ]),
);

final spiderServosProvider = StateNotifierProvider<ServoListNotifier, List<ServoConfig>>(
  (ref) => ServoListNotifier([
    const ServoConfig(label: 'FL Hip'),
    const ServoConfig(label: 'FL Knee'),
    const ServoConfig(label: 'FR Hip'),
    const ServoConfig(label: 'FR Knee'),
    const ServoConfig(label: 'BL Hip'),
    const ServoConfig(label: 'BL Knee'),
    const ServoConfig(label: 'BR Hip'),
    const ServoConfig(label: 'BR Knee'),
  ]),
);

class ServoListNotifier extends StateNotifier<List<ServoConfig>> {
  ServoListNotifier(super.initial);

  void updateAngle(int index, double angle) {
    state = [
      for (int i = 0; i < state.length; i++)
        i == index ? state[i].copyWith(angle: angle) : state[i],
    ];
  }

  void addServo(String label) {
    state = [...state, ServoConfig(label: label)];
  }

  void removeServo(int index) {
    state = [...state]..removeAt(index);
  }

  void renameServo(int index, String label) {
    state = [
      for (int i = 0; i < state.length; i++)
        i == index ? state[i].copyWith(label: label) : state[i],
    ];
  }

  void resetAll() {
    state = [for (final s in state) s.copyWith(angle: 90)];
  }
}
