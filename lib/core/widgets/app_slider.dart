import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/haptics.dart';

/// Clean slider with soft styling — matching kidszee.toys design
class AppSlider extends ConsumerWidget {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final String? unit;
  final ValueChanged<double> onChanged;
  final Color activeColor;

  const AppSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    this.divisions = 100,
    this.unit,
    this.activeColor = AppColors.orange,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTypography.label()),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${value.round()}${unit ?? ''}',
                  style: AppTypography.mono(size: 13, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              inactiveTrackColor: AppColors.lightGray,
              thumbColor: AppColors.cardWhite,
              overlayColor: activeColor.withValues(alpha: 0.15),
              trackHeight: 6,
              thumbShape: _CleanSliderThumb(),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: (v) {
                ref.hapticFeedback(HapticStrength.selection);
                onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CleanSliderThumb extends SliderComponentShape {
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(24, 24);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    // Soft shadow
    canvas.drawCircle(
      center + const Offset(0, 1),
      13,
      Paint()..color = Colors.black.withValues(alpha: 0.1),
    );
    // White circle fill
    canvas.drawCircle(center, 12, Paint()..color = Colors.white);
    // Subtle border
    canvas.drawCircle(
      center,
      12,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Orange inner dot
    canvas.drawCircle(
      center,
      5,
      Paint()..color = AppColors.orange,
    );
  }
}
