import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/doodle_background.dart';
import '../../core/providers/arm_pose_provider.dart';
import '../../core/models/arm_pose.dart';
import '../../core/models/sequence_macro.dart';
import '../../core/network/command_service.dart';

class SequenceScreen extends ConsumerStatefulWidget {
  const SequenceScreen({super.key});
  @override
  ConsumerState<SequenceScreen> createState() => _SequenceScreenState();
}

class _SequenceScreenState extends ConsumerState<SequenceScreen> {
  int _playingMacro = -1; // index of macro currently playing, -1 = none
  int _playIndex = 0;
  bool _loop = false;
  Timer? _timer;

  bool get _isPlaying => _playingMacro != -1;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _play(int macroIndex, SequenceMacro macro) {
    _timer?.cancel();
    if (macro.poses.isEmpty) return;
    setState(() { _playingMacro = macroIndex; _playIndex = 0; });
    _applyFrame(macro.poses.first);
    _timer = Timer.periodic(macro.stepDuration, (t) {
      final next = _playIndex + 1;
      if (next >= macro.poses.length) {
        if (_loop) {
          setState(() => _playIndex = 0);
          _applyFrame(macro.poses.first);
        } else {
          _stop();
        }
        return;
      }
      setState(() => _playIndex = next);
      _applyFrame(macro.poses[next]);
    });
  }

  void _applyFrame(ArmPose pose) {
    ref.read(armPoseProvider.notifier).loadPose(pose); // drives visualizer
    CommandService().sendArmPose(pose); // drives hardware
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() { _playingMacro = -1; _playIndex = 0; });
  }

  @override
  Widget build(BuildContext context) {
    final sequences = ref.watch(sequenceProvider);
    final isRecording = ref.watch(isRecordingProvider);
    final buffer = ref.watch(recordingBufferProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.navy), onPressed: () => Navigator.of(context).maybePop()),
        title: Text('Sequences', style: AppTypography.headline2()),
        actions: [
          Row(children: [
            Text('Loop', style: AppTypography.label()),
            Switch(value: _loop, activeThumbColor: AppColors.orange, onChanged: (v) => setState(() => _loop = v)),
          ]),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: AppColors.divider))),
      body: DoodleBackground(child: Padding(padding: const EdgeInsets.all(20),
        child: Column(children: [
          if (buffer.isNotEmpty) _TimelineBar(poses: buffer, playIndex: -1),
          AppButton(
            backgroundColor: isRecording ? AppColors.stopRed : AppColors.cardWhite,
            onTap: () {
              if (!isRecording) {
                ref.read(isRecordingProvider.notifier).state = true;
                ref.read(recordingBufferProvider.notifier).state = [ref.read(armPoseProvider)];
              } else {
                ref.read(isRecordingProvider.notifier).state = false;
                final poses = ref.read(recordingBufferProvider);
                if (poses.length > 1) {
                  ref.read(sequenceProvider.notifier).addSequence(
                    SequenceMacro(name: 'Sequence ${sequences.length + 1}', poses: poses));
                }
                ref.read(recordingBufferProvider.notifier).state = [];
              }
            },
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedContainer(duration: 500.ms, width: 12, height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, color: isRecording ? Colors.white : AppColors.stopRed)),
              const SizedBox(width: 10),
              Text(isRecording ? 'Stop Recording' : 'Start Recording',
                style: AppTypography.buttonText().copyWith(color: isRecording ? Colors.white : AppColors.navy)),
            ])),
          if (isRecording) Padding(padding: const EdgeInsets.only(top: 8),
            child: Text('Go to the arm and move the sliders — each change is captured.',
              textAlign: TextAlign.center, style: AppTypography.statusText())),
          const SizedBox(height: 20),
          Expanded(child: sequences.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.motion_photos_off_outlined, size: 48, color: AppColors.lightGray),
                const SizedBox(height: 12),
                Text('No sequences yet.\nRecord one!', textAlign: TextAlign.center, style: AppTypography.body()),
              ]))
            : ListView.separated(itemCount: sequences.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) => _SequenceCard(
                  macro: sequences[i],
                  isPlaying: _playingMacro == i,
                  onPlay: () => _isPlaying ? _stop() : _play(i, sequences[i]),
                  onDelete: () {
                    if (_playingMacro == i) _stop();
                    ref.read(sequenceProvider.notifier).deleteSequence(i);
                  },
                ).animate().fadeIn(delay: (i * 60).ms).slideX(begin: 0.1, end: 0))),
        ]))),
    );
  }
}

class _TimelineBar extends StatelessWidget {
  final List<ArmPose> poses; final int playIndex;
  const _TimelineBar({required this.poses, required this.playIndex});
  @override
  Widget build(BuildContext context) => Container(height: 60, margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border, width: 1),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), offset: const Offset(0, 2), blurRadius: 8)]),
    child: Row(children: [
      Text('${poses.length} frames', style: AppTypography.label()),
      const SizedBox(width: 14),
      Expanded(child: Row(children: poses.asMap().entries.map((e) => Expanded(child: Container(height: 16,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: e.key == playIndex ? AppColors.orange : AppColors.orange.withValues(alpha: 0.35)),
      ))).toList())),
    ]));
}

class _SequenceCard extends StatelessWidget {
  final SequenceMacro macro; final bool isPlaying; final VoidCallback onPlay, onDelete;
  const _SequenceCard({required this.macro, required this.isPlaying, required this.onPlay, required this.onDelete});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: isPlaying ? AppColors.orange : AppColors.border, width: isPlaying ? 2 : 1),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), offset: const Offset(0, 2), blurRadius: 8)]),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(macro.name, style: AppTypography.headline3().copyWith(fontSize: 15)),
        Text('${macro.poses.length} poses • ${macro.stepDurationMs}ms/step', style: AppTypography.statusText()),
      ])),
      AppButton(backgroundColor: isPlaying ? AppColors.stopRed : AppColors.orange, onTap: onPlay,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Icon(isPlaying ? Icons.stop : Icons.play_arrow, color: Colors.white, size: 20)),
      const SizedBox(width: 8),
      AppButton(backgroundColor: AppColors.stopRed, onTap: onDelete,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 20)),
    ]));
}
