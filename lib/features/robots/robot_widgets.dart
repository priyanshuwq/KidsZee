import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/providers/controller_mode_provider.dart';

// ── Shared robot-controller widgets ─────────────────────────────────────────
// Used by both the Otto (otto_command.dart) and Spider (spider_screen.dart)
// controller screens.

/// A tappable quick-action chip (e.g. "🚶 Walk Fwd").
class MoveChip extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const MoveChip({super.key, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => AppButton(
    backgroundColor: AppColors.cardWhite, onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Text(label, style: AppTypography.chipText()));
}

/// A single servo row with an angle slider, rename tap and optional remove.
class ServoTile extends StatelessWidget {
  final int index; final ServoConfig config;
  final ValueChanged<double> onAngleChanged;
  final VoidCallback? onRemove;
  final ValueChanged<String> onRename;
  const ServoTile({super.key, required this.index, required this.config, required this.onAngleChanged, this.onRemove, required this.onRename});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
    decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), offset: const Offset(0, 2), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 28, height: 28,
          decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text('${index + 1}', style: AppTypography.mono(size: 12, color: AppColors.orange)))),
        const SizedBox(width: 10),
        Expanded(child: GestureDetector(
          onTap: () => _showRenameDialog(context, config.label, onRename),
          child: Text(config.label, style: AppTypography.body().copyWith(fontWeight: FontWeight.w700)))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(8)),
          child: Text('${config.angle.round()}°', style: AppTypography.mono(size: 12, color: Colors.white))),
        if (onRemove != null)
          IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.stopRed), onPressed: onRemove, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32)),
      ]),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: AppColors.orange, inactiveTrackColor: AppColors.lightGray,
          thumbColor: AppColors.cardWhite, overlayColor: AppColors.orange.withValues(alpha: 0.15),
          trackHeight: 5, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10)),
        child: Slider(value: config.angle, min: 0, max: 180, divisions: 180, onChanged: onAngleChanged)),
    ]),
  );
}

/// Shows the "Add Servo" dialog for the given [provider].
void showAddServoDialog(BuildContext context, WidgetRef ref, StateNotifierProvider<ServoListNotifier, List<ServoConfig>> provider) {
  final controller = TextEditingController(text: 'Servo ${ref.read(provider).length + 1}');
  showDialog(context: context, builder: (ctx) => AlertDialog(
    title: Text('Add Servo', style: AppTypography.headline3()),
    content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Servo Name', border: OutlineInputBorder())),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      TextButton(onPressed: () { ref.read(provider.notifier).addServo(controller.text); Navigator.pop(ctx); },
        child: Text('Add', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700))),
    ],
  ));
}

void _showRenameDialog(BuildContext context, String current, ValueChanged<String> onRename) {
  final controller = TextEditingController(text: current);
  showDialog(context: context, builder: (ctx) => AlertDialog(
    title: Text('Rename Servo', style: AppTypography.headline3()),
    content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      TextButton(onPressed: () { onRename(controller.text); Navigator.pop(ctx); },
        child: Text('Save', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700))),
    ],
  ));
}

/// Draws a dotted leader line from [start] to [end] with a [text] label at the
/// end — shared by the Otto and Spider visualiser painters.
void drawLabel(Canvas canvas, String text, Offset start, Offset end) {
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
