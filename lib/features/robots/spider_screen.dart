import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/providers/controller_mode_provider.dart';
import 'robot_widgets.dart';

/// Quadruped Spider: 8 servos default (2 per leg: Hip + Knee)
/// Optional 12 servos (3 per leg: Hip + Knee + Shoulder)
/// Supports adding custom servos up to 16 (PCA9685 limit).
class SpiderScreen extends ConsumerWidget {
  const SpiderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servos = ref.watch(spiderServosProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.navy), onPressed: () => Navigator.of(context).maybePop()),
        title: Text('Spider Robot', style: AppTypography.headline2()),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.orange),
            tooltip: 'Add Servo',
            onPressed: () {
              if (servos.length >= 16) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max 16 servos (PCA9685 limit)'), duration: Duration(seconds: 2)));
                return;
              }
              showAddServoDialog(context, ref, spiderServosProvider);
            }),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: AppColors.divider))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Visualizer
          Container(height: 260, width: double.infinity,
            decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), offset: const Offset(0, 2), blurRadius: 8)]),
            child: CustomPaint(painter: _SpiderPainter(servos: servos), child: const SizedBox.expand()),
          ).animate().fadeIn(),
          const SizedBox(height: 20),

          // Quick gaits
          Text('GAITS & MOVES', style: AppTypography.label().copyWith(color: AppColors.orange, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            MoveChip(label: '🕷️ Crawl Fwd', onTap: () {}),
            MoveChip(label: '🔙 Crawl Back', onTap: () {}),
            MoveChip(label: '↩️ Turn Left', onTap: () {}),
            MoveChip(label: '↪️ Turn Right', onTap: () {}),
            MoveChip(label: '🧍 Stand', onTap: () {}),
            MoveChip(label: '🪑 Sit', onTap: () {}),
            MoveChip(label: '👋 Wave', onTap: () {}),
            MoveChip(label: '🏃 Trot', onTap: () {}),
          ]).animate().fadeIn(),
          const SizedBox(height: 24),
          // Servo controls
          Row(children: [
            Text('SERVOS (${servos.length}/16)', style: AppTypography.label().copyWith(color: AppColors.orange, letterSpacing: 1.2)),
            const Spacer(),
            AppButton(backgroundColor: AppColors.cardWhite, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              onTap: () => ref.read(spiderServosProvider.notifier).resetAll(),
              child: Text('Reset All', style: AppTypography.statusText().copyWith(color: AppColors.orange))),
          ]),
          const SizedBox(height: 10),
          ...servos.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ServoTile(
              index: e.key, config: e.value,
              onAngleChanged: (v) => ref.read(spiderServosProvider.notifier).updateAngle(e.key, v),
              onRemove: e.key >= 8 ? () => ref.read(spiderServosProvider.notifier).removeServo(e.key) : null,
              onRename: (name) => ref.read(spiderServosProvider.notifier).renameServo(e.key, name),
            ).animate().fadeIn(delay: (e.key * 40).ms).slideX(begin: 0.05, end: 0),
          )),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: AppButton(
            backgroundColor: AppColors.stopRed, onTap: () => ref.read(spiderServosProvider.notifier).resetAll(),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('STOP & RESET', style: AppTypography.headline3().copyWith(color: Colors.white))))),
        ])),
    );
  }
}

// ── Visualizer ──────────────────────────────────────────────────────────────
class _SpiderPainter extends CustomPainter {
  final List<ServoConfig> servos;
  _SpiderPainter({required this.servos});

  void drawLeg(Canvas canvas, Offset center, double baseAngle, double hipAng, double kneeAng, Paint borderP, Paint fillP, List<Offset> joints) {
    final hip = center + Offset(math.cos(baseAngle) * 35, math.sin(baseAngle) * 35);
    final knee = hip + Offset(math.cos(baseAngle + hipAng) * 45, math.sin(baseAngle + hipAng) * 45);
    final foot = knee + Offset(math.cos(baseAngle + hipAng + kneeAng) * 45, math.sin(baseAngle + hipAng + kneeAng) * 45);

    canvas.drawLine(hip, knee, borderP);
    canvas.drawLine(knee, foot, borderP);
    canvas.drawLine(hip, knee, fillP);
    canvas.drawLine(knee, foot, fillP);

    joints.addAll([hip, knee, foot]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()..color = AppColors.navy..strokeWidth = 14..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final fillPaint = Paint()..color = AppColors.cardWhite..strokeWidth = 8..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final jointPaint = Paint()..color = AppColors.orange;
    final jointBorder = Paint()..color = AppColors.navy..style = PaintingStyle.stroke..strokeWidth = 2.5;

    final center = Offset(size.width / 2, size.height / 2);

    double getA(int idx) => (servos.length > idx ? servos[idx].angle : 90) - 90;

    List<Offset> joints = [];

    // FL: 0, 1 (base -135 deg)
    drawLeg(canvas, center, -3 * math.pi / 4, getA(0) * math.pi / 180, getA(1) * math.pi / 180, borderPaint, fillPaint, joints);
    // FR: 2, 3 (base -45 deg)
    drawLeg(canvas, center, -math.pi / 4, getA(2) * math.pi / 180, getA(3) * math.pi / 180, borderPaint, fillPaint, joints);
    // BL: 4, 5 (base 135 deg)
    drawLeg(canvas, center, 3 * math.pi / 4, getA(4) * math.pi / 180, getA(5) * math.pi / 180, borderPaint, fillPaint, joints);
    // BR: 6, 7 (base 45 deg)
    drawLeg(canvas, center, math.pi / 4, getA(6) * math.pi / 180, getA(7) * math.pi / 180, borderPaint, fillPaint, joints);

    // Draw body
    canvas.drawOval(Rect.fromCenter(center: center, width: 70, height: 100), Paint()..color = AppColors.cardWhite);
    canvas.drawOval(Rect.fromCenter(center: center, width: 70, height: 100), Paint()..color = AppColors.navy..strokeWidth = 3..style = PaintingStyle.stroke);

    // Eyes
    canvas.drawCircle(center + const Offset(-15, -35), 6, Paint()..color = AppColors.navy);
    canvas.drawCircle(center + const Offset(15, -35), 6, Paint()..color = AppColors.navy);

    // Draw joints
    for (int i = 0; i < joints.length; i++) {
      if (i % 3 == 2) {
        canvas.drawCircle(joints[i], 5, Paint()..color = AppColors.stopRed);
        canvas.drawCircle(joints[i], 5, jointBorder);
      } else {
        canvas.drawCircle(joints[i], 8.5, jointPaint);
        canvas.drawCircle(joints[i], 8.5, jointBorder);
      }
    }

    // Add labels for FL (Front Left)
    if (joints.length >= 3) {
      drawLabel(canvas, 'FL Hip', joints[0], joints[0] + const Offset(-50, -20));
      drawLabel(canvas, 'FL Knee', joints[1], joints[1] + const Offset(-50, -20));
    }
  }

  @override
  bool shouldRepaint(covariant _SpiderPainter oldDelegate) => true;
}
