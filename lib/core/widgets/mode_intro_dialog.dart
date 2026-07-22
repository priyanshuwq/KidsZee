import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/mode_doodle_icons.dart';
import '../providers/controller_mode_provider.dart';

/// Data for each mode's first-time introduction popup.
class ModeIntroData {
  final ControlMode mode;
  final Color color;
  final String title;
  final String description;
  final List<String> features;
  final String prefKey;

  const ModeIntroData({
    required this.mode,
    required this.color,
    required this.title,
    required this.description,
    required this.features,
    required this.prefKey,
  });
}

const _modeIntros = [
  ModeIntroData(
    mode: ControlMode.rcCar,
    color: AppColors.orange,
    title: 'Smart Car Control',
    description: 'Drive your car with 3 different control styles. Switch between them anytime from the top bar.',
    features: ['D-Pad — Tap directional buttons', 'Gyro — Tilt your phone to steer', 'Voice — Say commands out loud'],
    prefKey: 'seen_intro_rcCar',
  ),
  ModeIntroData(
    mode: ControlMode.robotArm,
    color: AppColors.terracotta,
    title: 'Robotic Arm',
    description: 'Control a 6-axis robotic arm with precision. Perfect for picking up and placing objects.',
    features: ['Drag each joint slider to move', 'Save poses and replay sequences', 'Reset all joints to center instantly'],
    prefKey: 'seen_intro_robotArm',
  ),
  ModeIntroData(
    mode: ControlMode.ottoRobot,
    color: AppColors.brandBlue,
    title: 'Otto Robot',
    description: 'Meet Otto — your biped walking buddy. Uses 6 servos for walking and grooving.',
    features: ['Walk forward, backward and turn', 'Play built-in dance moves', 'Fine-tune each of 6 servos'],
    prefKey: 'seen_intro_ottoRobot',
  ),
  ModeIntroData(
    mode: ControlMode.spiderRobot,
    color: AppColors.spiderGreen,
    title: 'Spider Robot',
    description: 'Wake the 4-legged crawler. Great for learning multi-legged locomotion.',
    features: ['Walk in any direction', 'Control 8 servos — 4 hips + 4 knees', 'Calibrate leg positions'],
    prefKey: 'seen_intro_spiderRobot',
  ),
];

/// Returns the [ModeIntroData] for the given [ControlMode].
ModeIntroData getModeIntro(ControlMode mode) {
  return _modeIntros.firstWhere((m) => m.mode == mode);
}

/// Shows a first-time introduction dialog for the given mode.
/// Returns `true` if the dialog was shown (first time), `false` if skipped.
Future<bool> showModeIntroIfNeeded(BuildContext context, ControlMode mode) async {
  final intro = getModeIntro(mode);
  final prefs = await SharedPreferences.getInstance();

  if (prefs.getBool(intro.prefKey) == true) {
    return false;
  }

  await prefs.setBool(intro.prefKey, true);

  if (!context.mounted) return false;

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Mode Intro',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 350),
    transitionBuilder: (ctx, anim, secondAnim, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
    pageBuilder: (ctx, anim, secondAnim) {
      return _ModeIntroDialog(intro: intro);
    },
  );

  return true;
}

class _ModeIntroDialog extends StatelessWidget {
  final ModeIntroData intro;
  const _ModeIntroDialog({required this.intro});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mode icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: intro.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: intro.color.withValues(alpha: 0.25), width: 1.5),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: ModeDoodleIcon(mode: intro.mode, accentColor: intro.color, size: 56),
                ).animate().scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.easeOutBack,
                ),
                const SizedBox(height: 18),
                // Title
                Text(
                  intro.title,
                  textAlign: TextAlign.center,
                  style: AppTypography.headline1().copyWith(fontSize: 22),
                ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
                const SizedBox(height: 10),
                // Description
                Text(
                  intro.description,
                  textAlign: TextAlign.center,
                  style: AppTypography.body().copyWith(
                    height: 1.5,
                    fontSize: 13.5,
                    color: AppColors.textMuted,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
                const SizedBox(height: 18),
                // Feature list
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: intro.color.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: intro.color.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < intro.features.length; i++) ...[
                        _FeatureRow(text: intro.features[i], color: intro.color),
                        if (i < intro.features.length - 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1, color: intro.color.withValues(alpha: 0.1)),
                          ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 280.ms, duration: 300.ms),
                const SizedBox(height: 22),
                // Got it button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: intro.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Got it!',
                      style: AppTypography.headline3().copyWith(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ).animate().fadeIn(delay: 350.ms, duration: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  final Color color;
  const _FeatureRow({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTypography.body().copyWith(
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.darkGray,
            ),
          ),
        ),
      ],
    );
  }
}
