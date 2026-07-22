import 'package:hive_flutter/hive_flutter.dart';
import 'arm_pose.dart';

part 'sequence_macro.g.dart';

@HiveType(typeId: 1)
class SequenceMacro extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final List<ArmPose> poses;

  @HiveField(2)
  final int stepDurationMs;

  SequenceMacro({
    required this.name,
    required this.poses,
    this.stepDurationMs = 500,
  });

  SequenceMacro copyWith({
    String? name,
    List<ArmPose>? poses,
    int? stepDurationMs,
  }) {
    return SequenceMacro(
      name: name ?? this.name,
      poses: poses ?? this.poses,
      stepDurationMs: stepDurationMs ?? this.stepDurationMs,
    );
  }

  Duration get stepDuration => Duration(milliseconds: stepDurationMs);
}
