import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/arm_pose.dart';

/// Saved arm presets, persisted in the Hive box `arm_presets`.
/// Each preset is an [ArmPose] whose [ArmPose.label] is the display name.
const _presetBox = 'arm_presets';

class PresetNotifier extends StateNotifier<List<ArmPose>> {
  PresetNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final box = await Hive.openBox<ArmPose>(_presetBox);
    state = box.values.toList();
  }

  /// Saves [pose] as a new preset. Auto-names "Pose N" when [name] is null (Q2).
  Future<void> savePreset(ArmPose pose, [String? name]) async {
    final box = await Hive.openBox<ArmPose>(_presetBox);
    final n = (name == null || name.trim().isEmpty)
        ? 'Pose ${state.length + 1}'
        : name.trim();
    final preset = pose.copyWith(label: n);
    await box.add(preset);
    state = [...state, preset];
  }

  Future<void> deletePreset(int index) async {
    final box = await Hive.openBox<ArmPose>(_presetBox);
    await box.deleteAt(index);
    final updated = [...state]..removeAt(index);
    state = updated;
  }

  Future<void> renamePreset(int index, String newName) async {
    final box = await Hive.openBox<ArmPose>(_presetBox);
    final renamed = state[index].copyWith(label: newName.trim());
    await box.putAt(index, renamed);
    final updated = [...state];
    updated[index] = renamed;
    state = updated;
  }

  Future<void> clearAll() async {
    final box = await Hive.openBox<ArmPose>(_presetBox);
    await box.clear();
    state = [];
  }
}

final presetProvider =
    StateNotifierProvider<PresetNotifier, List<ArmPose>>(
  (ref) => PresetNotifier(),
);
