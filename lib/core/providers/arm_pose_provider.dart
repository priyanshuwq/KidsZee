import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/arm_pose.dart';
import '../models/sequence_macro.dart';

// ── ArmPose Provider ─────────────────────────────────────────────────────────

class ArmPoseNotifier extends StateNotifier<ArmPose> {
  ArmPoseNotifier() : super(ArmPose.home);

  void updateBase(double v) =>
      state = state.copyWith(base: clampJoint(ServoId.base, v));
  void updateShoulder(double v) =>
      state = state.copyWith(shoulder: clampJoint(ServoId.shoulder, v));
  void updateElbow(double v) =>
      state = state.copyWith(elbow: clampJoint(ServoId.elbow, v));
  void updateGripper(double v) =>
      state = state.copyWith(gripper: clampJoint(ServoId.gripper, v));
  void updateWristRoll(double v) =>
      state = state.copyWith(wristRoll: clampJoint(ServoId.wristRoll, v));
  void updateWristPitch(double v) =>
      state = state.copyWith(wristPitch: clampJoint(ServoId.wristPitch, v));

  void resetHome() => state = ArmPose.home;

  void loadPose(ArmPose pose) => state = pose;
}

final armPoseProvider =
    StateNotifierProvider<ArmPoseNotifier, ArmPose>(
  (ref) => ArmPoseNotifier(),
);

// ── Sequence Provider ─────────────────────────────────────────────────────────

const _boxName = 'sequences';

class SequenceNotifier extends StateNotifier<List<SequenceMacro>> {
  SequenceNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final box = await Hive.openBox<SequenceMacro>(_boxName);
    state = box.values.toList();
  }

  Future<void> addSequence(SequenceMacro macro) async {
    final box = await Hive.openBox<SequenceMacro>(_boxName);
    await box.add(macro);
    state = [...state, macro];
  }

  Future<void> deleteSequence(int index) async {
    final box = await Hive.openBox<SequenceMacro>(_boxName);
    await box.deleteAt(index);
    final updated = [...state];
    updated.removeAt(index);
    state = updated;
  }
}

final sequenceProvider =
    StateNotifierProvider<SequenceNotifier, List<SequenceMacro>>(
  (ref) => SequenceNotifier(),
);

// ── Recording state ──────────────────────────────────────────────────────────
final isRecordingProvider = StateProvider<bool>((ref) => false);
final recordingBufferProvider =
    StateProvider<List<ArmPose>>((ref) => []);
