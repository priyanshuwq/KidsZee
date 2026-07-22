import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_slider.dart';
import '../../core/widgets/doodle_background.dart';
import '../../core/providers/arm_pose_provider.dart';
import '../../core/providers/preset_provider.dart';
import '../../core/models/arm_pose.dart';
import '../../core/network/command_service.dart';
import '../../core/network/bt_classic_manager.dart';

class ArmControllerScreen extends ConsumerStatefulWidget {
  const ArmControllerScreen({super.key});
  @override
  ConsumerState<ArmControllerScreen> createState() => _ArmControllerScreenState();
}

class _ArmControllerScreenState extends ConsumerState<ArmControllerScreen> {
  bool _hasMoved = false;

  /// Update a joint in the provider AND push it to hardware (single-servo,
  /// throttled + coalesced inside CommandService).
  void _onJoint(int servoId, double value, void Function(double) update) {
    update(value);
    CommandService().sendSingleServo(servoId, value.round());
    if (!_hasMoved) setState(() => _hasMoved = true);
  }

  @override
  Widget build(BuildContext context) {
    final pose = ref.watch(armPoseProvider);
    final notifier = ref.read(armPoseProvider.notifier);
    // While recording a sequence, capture every pose change into the buffer.
    ref.listen<ArmPose>(armPoseProvider, (prev, next) {
      if (ref.read(isRecordingProvider)) {
        ref.read(recordingBufferProvider.notifier).update((b) => [...b, next]);
      }
    });
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.navy), onPressed: () => Navigator.of(context).maybePop()),
        title: Text('Robotic Arm', style: AppTypography.headline2()),
        actions: [
          const _ConnectionDot(),
          IconButton(icon: const Icon(Icons.bookmark_border, color: AppColors.navy), tooltip: 'Presets', onPressed: () => _showPresets(context, ref)),
          IconButton(icon: const Icon(Icons.list_alt, color: AppColors.navy), onPressed: () => context.push('/sequences')),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: AppColors.divider))),
      body: DoodleBackground(child: SingleChildScrollView(padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(height: 260, width: double.infinity,
            decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), offset: const Offset(0, 2), blurRadius: 8)]),
            child: Column(children: [
              Expanded(child: Padding(padding: const EdgeInsets.only(top: 20),
                child: CustomPaint(painter: _ArmPainter(pose: pose, showLabels: !_hasMoved), child: const SizedBox.expand()))),
              Padding(padding: const EdgeInsets.only(bottom: 16),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.swipe, color: AppColors.navy, size: 20),
                  const SizedBox(width: 8),
                  Text('Drag sliders to move the arm', style: AppTypography.label().copyWith(color: AppColors.navy)),
                ])),
            ])).animate().fadeIn(),
          const SizedBox(height: 20),
          _ServoSlider(label: 'Base', value: pose.base, servoId: ServoId.base, onChanged: (v) => _onJoint(ServoId.base, v, notifier.updateBase)),
          const SizedBox(height: 12),
          _ServoSlider(label: 'Shoulder', value: pose.shoulder, servoId: ServoId.shoulder, onChanged: (v) => _onJoint(ServoId.shoulder, v, notifier.updateShoulder)),
          const SizedBox(height: 12),
          _ServoSlider(label: 'Elbow', value: pose.elbow, servoId: ServoId.elbow, onChanged: (v) => _onJoint(ServoId.elbow, v, notifier.updateElbow)),
          const SizedBox(height: 12),
          _ServoSlider(label: 'Wrist Pitch', value: pose.wristPitch, servoId: ServoId.wristPitch, onChanged: (v) => _onJoint(ServoId.wristPitch, v, notifier.updateWristPitch)),
          const SizedBox(height: 12),
          _ServoSlider(label: 'Wrist Roll', value: pose.wristRoll, servoId: ServoId.wristRoll, onChanged: (v) => _onJoint(ServoId.wristRoll, v, notifier.updateWristRoll)),
          const SizedBox(height: 12),
          _ServoSlider(label: 'Gripper', value: pose.gripper, servoId: ServoId.gripper, onChanged: (v) => _onJoint(ServoId.gripper, v, notifier.updateGripper)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: AppButton(backgroundColor: AppColors.cardWhite,
              onTap: () {
                notifier.resetHome();
                CommandService().sendHome();
                setState(() => _hasMoved = false);
              },
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.restart_alt, color: AppColors.navy, size: 18),
                const SizedBox(width: 8), Text('Reset', style: AppTypography.buttonText()),
              ]))),
            const SizedBox(width: 12),
            Expanded(child: AppButton(backgroundColor: AppColors.orange,
              onTap: () => _savePose(context, ref),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.save_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8), Text('Save Pose', style: AppTypography.buttonText().copyWith(color: Colors.white)),
              ]))),
          ]),
        ]))),
    );
  }

  Future<void> _savePose(BuildContext context, WidgetRef ref) async {
    final pose = ref.read(armPoseProvider);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Save Pose', style: AppTypography.headline3()),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name (optional)'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (name == null) return; // cancelled / dismissed
    if (!context.mounted) return;
    // Empty string → auto-name "Pose N" (Q2).
    await ref.read(presetProvider.notifier).savePreset(pose, name.isEmpty ? null : name);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pose saved!'), duration: Duration(seconds: 1)));
    }
  }

  void _showPresets(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Consumer(builder: (ctx, r, _) {
        final presets = r.watch(presetProvider);
        return Padding(padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Saved Poses', style: AppTypography.headline3()),
            const SizedBox(height: 12),
            if (presets.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No saved poses yet.', style: AppTypography.body())))
            else
              ConstrainedBox(constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(shrinkWrap: true, itemCount: presets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (c, i) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 1)),
                    child: Row(children: [
                      Expanded(child: Text(presets[i].label ?? 'Pose ${i + 1}', style: AppTypography.body())),
                      IconButton(icon: const Icon(Icons.play_arrow, color: AppColors.orange),
                        onPressed: () {
                          r.read(armPoseProvider.notifier).loadPose(presets[i]);
                          CommandService().sendArmPose(presets[i]);
                          Navigator.of(ctx).pop();
                        }),
                      IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.stopRed),
                        onPressed: () => r.read(presetProvider.notifier).deletePreset(i)),
                    ]),
                  ))),
          ]));
      }),
    );
  }
}

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot();
  @override
  Widget build(BuildContext context) => StreamBuilder<BtState>(
    stream: CommandService().connectionStateStream,
    builder: (ctx, snap) {
      final connected = snap.data == BtState.connected;
      return Padding(padding: const EdgeInsets.only(right: 4),
        child: Center(child: Container(width: 12, height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: connected ? AppColors.successGreen : AppColors.stopRed,
            border: Border.all(color: AppColors.navy, width: 1.5)))));
    });
}

class _ServoSlider extends StatelessWidget {
  final String label; final double value; final int servoId; final ValueChanged<double> onChanged;
  const _ServoSlider({required this.label, required this.value, required this.servoId, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final (lo, hi) = kJointLimits[servoId];
    return AppSlider(label: label, value: value.clamp(lo.toDouble(), hi.toDouble()),
      min: lo.toDouble(), max: hi.toDouble(), divisions: hi - lo, unit: '°', onChanged: onChanged);
  }
}

class _ArmPainter extends CustomPainter {
  final ArmPose pose;
  final bool showLabels;
  _ArmPainter({required this.pose, this.showLabels = true});

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()..color = AppColors.navy..strokeWidth = 24..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final fillPaint = Paint()..color = AppColors.cardWhite..strokeWidth = 18..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final clawBorderPaint = Paint()..color = AppColors.navy..strokeWidth = 12..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
    final clawFillPaint = Paint()..color = AppColors.cardWhite..strokeWidth = 6..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
    final jointPaint = Paint()..color = AppColors.orange;
    final jointBorder = Paint()..color = AppColors.navy..style = PaintingStyle.stroke..strokeWidth = 2.5;

    final base = Offset(size.width / 2, size.height - 45);
    final baseAngle = (pose.base - 90) * math.pi / 180;
    final shoulderAng = (pose.shoulder - 90) * math.pi / 180;
    final elbowAng = (pose.elbow - 90) * math.pi / 180;
    final wristPitchAng = (pose.wristPitch - 90) * math.pi / 180;
    const seg1 = 50.0, seg2 = 50.0, seg3 = 32.0, seg4 = 24.0;

    final shoulder = base + Offset(math.sin(baseAngle) * seg1, -math.cos(baseAngle) * seg1);
    final elbow = shoulder + Offset(math.sin(baseAngle + shoulderAng) * seg2, -math.cos(baseAngle + shoulderAng) * seg2);
    final wristAngle = baseAngle + shoulderAng + elbowAng;
    final wrist = elbow + Offset(math.sin(wristAngle) * seg3, -math.cos(wristAngle) * seg3);
    final gripperAngle = wristAngle + wristPitchAng;
    final gripper = wrist + Offset(math.sin(gripperAngle) * seg4, -math.cos(gripperAngle) * seg4);
    final clawAngle = (pose.gripper - 90) * 0.4 * math.pi / 180;

    final leftClawP1 = gripper + Offset(math.sin(gripperAngle - 0.4 - clawAngle) * 18, -math.cos(gripperAngle - 0.4 - clawAngle) * 18);
    final leftClawP2 = leftClawP1 + Offset(math.sin(gripperAngle) * 14, -math.cos(gripperAngle) * 14);
    final rightClawP1 = gripper + Offset(math.sin(gripperAngle + 0.4 + clawAngle) * 18, -math.cos(gripperAngle + 0.4 + clawAngle) * 18);
    final rightClawP2 = rightClawP1 + Offset(math.sin(gripperAngle) * 14, -math.cos(gripperAngle) * 14);

    // Base stand
    canvas.drawRect(Rect.fromLTWH(base.dx - 65, base.dy + 35, 130, 6), Paint()..color = AppColors.cardWhite);
    canvas.drawRect(Rect.fromLTWH(base.dx - 65, base.dy + 35, 130, 6), Paint()..color = AppColors.navy..style = PaintingStyle.stroke..strokeWidth = 2.5);
    canvas.drawRect(Rect.fromLTWH(base.dx - 50, base.dy + 25, 100, 10), Paint()..color = AppColors.cardWhite);
    canvas.drawRect(Rect.fromLTWH(base.dx - 50, base.dy + 25, 100, 10), Paint()..color = AppColors.navy..style = PaintingStyle.stroke..strokeWidth = 2.5);
    final standPath = Path()..moveTo(base.dx - 22, base.dy)..lineTo(base.dx + 22, base.dy)..lineTo(base.dx + 40, base.dy + 25)..lineTo(base.dx - 40, base.dy + 25)..close();
    canvas.drawPath(standPath, Paint()..color = AppColors.cardWhite);
    canvas.drawPath(standPath, Paint()..color = AppColors.navy..style = PaintingStyle.stroke..strokeWidth = 2.5);

    // Claws border + arm border
    canvas.drawPath(Path()..moveTo(gripper.dx, gripper.dy)..lineTo(leftClawP1.dx, leftClawP1.dy)..lineTo(leftClawP2.dx, leftClawP2.dy), clawBorderPaint);
    canvas.drawPath(Path()..moveTo(gripper.dx, gripper.dy)..lineTo(rightClawP1.dx, rightClawP1.dy)..lineTo(rightClawP2.dx, rightClawP2.dy), clawBorderPaint);
    canvas.drawLine(base, shoulder, borderPaint);
    canvas.drawLine(shoulder, elbow, borderPaint);
    canvas.drawLine(elbow, wrist, borderPaint);
    canvas.drawLine(wrist, gripper, borderPaint);

    // Claws fill + arm fill
    canvas.drawPath(Path()..moveTo(gripper.dx, gripper.dy)..lineTo(leftClawP1.dx, leftClawP1.dy)..lineTo(leftClawP2.dx, leftClawP2.dy), clawFillPaint);
    canvas.drawPath(Path()..moveTo(gripper.dx, gripper.dy)..lineTo(rightClawP1.dx, rightClawP1.dy)..lineTo(rightClawP2.dx, rightClawP2.dy), clawFillPaint);
    canvas.drawLine(base, shoulder, fillPaint);
    canvas.drawLine(shoulder, elbow, fillPaint);
    canvas.drawLine(elbow, wrist, fillPaint);
    canvas.drawLine(wrist, gripper, fillPaint);

    // Joints
    for (final pt in [base, shoulder, elbow, wrist, gripper]) {
      canvas.drawCircle(pt, 8.5, jointPaint);
      canvas.drawCircle(pt, 8.5, jointBorder);
    }

    // Only show labels & roll indicator when the user hasn't started moving yet.
    if (showLabels) {
      // Wrist-roll indicator (cannot be drawn as a 2D segment — show as a value).
      final rollTp = TextPainter(
        text: TextSpan(text: 'roll ${pose.wristRoll.round()}°', style: AppTypography.label().copyWith(fontSize: 10, color: AppColors.navy)),
        textDirection: TextDirection.ltr)..layout();
      rollTp.paint(canvas, wrist + const Offset(10, -6));

      // Labels
      _drawLabel(canvas, 'Base', base, base + const Offset(-60, -10));
      _drawLabel(canvas, 'Shoulder', shoulder, shoulder + const Offset(-60, -20));
      _drawLabel(canvas, 'Elbow', elbow, elbow + const Offset(60, -20));
      _drawLabel(canvas, 'Grip', gripper, gripper + const Offset(50, -20));
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset start, Offset end) {
    final dist = (end - start).distance;
    final dir = (end - start) / dist;
    double current = 14.0;
    final dotPaint = Paint()..color = AppColors.orange..strokeWidth = 2..strokeCap = StrokeCap.round;
    while (current < dist) {
      canvas.drawLine(start + dir * current, start + dir * math.min(current + 4, dist), dotPaint);
      current += 8;
    }
    final tp = TextPainter(text: TextSpan(text: text, style: AppTypography.label().copyWith(fontSize: 11, color: AppColors.navy)), textDirection: TextDirection.ltr);
    tp.layout();
    if (end.dx < start.dx) { tp.paint(canvas, end - Offset(tp.width + 6, tp.height / 2)); }
    else { tp.paint(canvas, end + Offset(6, -tp.height / 2)); }
  }

  @override
  bool shouldRepaint(_ArmPainter o) =>
      o.pose.base != pose.base || o.pose.shoulder != pose.shoulder ||
      o.pose.elbow != pose.elbow || o.pose.gripper != pose.gripper ||
      o.pose.wristRoll != pose.wristRoll || o.pose.wristPitch != pose.wristPitch ||
      o.showLabels != showLabels;
}
