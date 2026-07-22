import 'package:hive_flutter/hive_flutter.dart';

part 'arm_pose.g.dart';

/// Servo IDs as wired on the Arduino (must match firmware `servoPins` order).
/// 0:Gripper 1:WristRoll 2:WristPitch 3:Elbow 4:Shoulder 5:Base
class ServoId {
  static const int gripper = 0;
  static const int wristRoll = 1;
  static const int wristPitch = 2;
  static const int elbow = 3;
  static const int shoulder = 4;
  static const int base = 5;
}

/// Per-joint safe min/max angle (degrees), indexed by [ServoId].
/// These mirror the PROVEN slider limits from the FABRI Creator app (.aia),
/// which were tuned for this exact physical arm — do not widen without testing.
const List<(int min, int max)> kJointLimits = [
  (20, 140), // gripper   (FABRI Servo_06)
  (0, 180), //  wristRoll  (FABRI Servo_04 — full rotation)
  (0, 180), //  wristPitch (FABRI Servo_05)
  (0, 130), //  elbow      (FABRI Servo_03)
  (0, 170), //  shoulder   (FABRI Servo_02)
  (0, 180), //  base       (FABRI Servo_01)
];

double clampJoint(int servoId, double value) {
  final (lo, hi) = kJointLimits[servoId];
  return value.clamp(lo.toDouble(), hi.toDouble());
}

@HiveType(typeId: 0)
class ArmPose extends HiveObject {
  @HiveField(0)
  final double base;

  @HiveField(1)
  final double shoulder;

  @HiveField(2)
  final double elbow;

  @HiveField(3)
  final double gripper;

  @HiveField(4)
  final String? label;

  @HiveField(5)
  final double wristRoll;

  @HiveField(6)
  final double wristPitch;

  ArmPose({
    required this.base,
    required this.shoulder,
    required this.elbow,
    required this.gripper,
    this.wristRoll = 90,
    this.wristPitch = 90,
    this.label,
  });

  ArmPose copyWith({
    double? base,
    double? shoulder,
    double? elbow,
    double? gripper,
    double? wristRoll,
    double? wristPitch,
    String? label,
  }) {
    return ArmPose(
      base: base ?? this.base,
      shoulder: shoulder ?? this.shoulder,
      elbow: elbow ?? this.elbow,
      gripper: gripper ?? this.gripper,
      wristRoll: wristRoll ?? this.wristRoll,
      wristPitch: wristPitch ?? this.wristPitch,
      label: label ?? this.label,
    );
  }

  /// Read a joint angle by its [ServoId].
  double byServoId(int id) {
    switch (id) {
      case ServoId.gripper:
        return gripper;
      case ServoId.wristRoll:
        return wristRoll;
      case ServoId.wristPitch:
        return wristPitch;
      case ServoId.elbow:
        return elbow;
      case ServoId.shoulder:
        return shoulder;
      case ServoId.base:
        return base;
      default:
        return 90;
    }
  }

  /// Home position — matches the Arduino's power-on `pos[]` (all servos at 90),
  /// so the app and the physical arm are in sync the moment you connect.
  static ArmPose get home => ArmPose(
        base: 90,
        shoulder: 90,
        elbow: 90,
        wristPitch: 90,
        wristRoll: 90,
        gripper: 90,
        label: 'Home',
      );
}
