import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/doodle_background.dart';
import '../../core/providers/controller_mode_provider.dart';
import '../../core/providers/sensor_stream_provider.dart';
import '../../core/network/smart_car_commands.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/orientation.dart';

class GyroScreen extends ConsumerStatefulWidget {
  const GyroScreen({super.key});
  @override
  ConsumerState<GyroScreen> createState() => _GyroScreenState();
}

class _GyroScreenState extends ConsumerState<GyroScreen> {
  double _rawSmoothedX = 0, _smoothedX = 0, _smoothedY = 0;
  double _pitch = 0, _roll = 0;
  CarDirection _activeDirection = CarDirection.stop;

  @override
  void initState() {
    super.initState();
    lockLandscape();
  }

  @override
  void dispose() {
    // NOTE: deliberately NOT restoring the portrait lock here. Gyro is only
    // ever reached by pushing on top of the D-Pad screen (still mounted,
    // still landscape-locked, underneath). Forcing portrait in this
    // dispose() used to race the pop transition — the device would briefly
    // rotate to portrait while D-Pad's landscape layout was still on
    // screen, throwing a "RIGHT OVERFLOWED" error. D-Pad's own dispose()
    // (and its didPopNext backstop) owns restoring portrait when the user
    // actually leaves the Smart Car section.
    super.dispose();
  }

  /// forward/backward lean (pitch, sx) beats left/right lean (roll, sy)
  /// whenever its deviation from neutral is larger. No diagonals.
  CarDirection _resolveDirection(double sx, double sy, double tiltThreshold) {
    final absX = sx.abs();
    final absY = sy.abs();
    if (absX < tiltThreshold && absY < tiltThreshold) return CarDirection.stop;
    if (absX >= absY) {
      if (sx < -tiltThreshold) return CarDirection.forward;
      if (sx > tiltThreshold) return CarDirection.backward;
    } else {
      if (sy < -tiltThreshold) return CarDirection.left;
      if (sy > tiltThreshold) return CarDirection.right;
    }
    return CarDirection.stop;
  }

  @override
  Widget build(BuildContext context) {
    final calibOffset = ref.watch(calibrationProvider);
    final sensitivity = ref.watch(gyroSensitivityProvider);
    final deadzone = ref.watch(gyroDeadzoneProvider);
    final sensorAsync = ref.watch(sensorStreamProvider);

    final dynamicTiltThreshold = deadzone * 9.81;

    sensorAsync.whenData((event) {
      const alpha = 0.15;
      
      // Track the raw phone angle first, multiplied by user sensitivity
      _rawSmoothedX = alpha * (event.x * sensitivity) + (1 - alpha) * _rawSmoothedX;
      
      // Apply calibration offset for driving logic
      _smoothedX = _rawSmoothedX - calibOffset;
      _smoothedY = alpha * (event.y * sensitivity) + (1 - alpha) * _smoothedY;
      
      // Pitch from X-axis accel: tilt forward (top of phone away) = positive pitch
      _pitch = (_smoothedX / 9.81).clamp(-1.0, 1.0) * 90;
      // Roll from Y-axis accel: tilt right = positive roll
      _roll = (_smoothedY / 9.81).clamp(-1.0, 1.0) * 90;

      final resolved = _resolveDirection(_smoothedX, _smoothedY, dynamicTiltThreshold);
      if (resolved != _activeDirection) {
        _activeDirection = resolved;
        ref.hapticFeedback(HapticStrength.selection);
        if (resolved == CarDirection.stop) {
          SmartCarCommands.stop();
        } else {
          SmartCarCommands.send(resolved);
        }
      } else if (resolved != CarDirection.stop) {
        // Keep re-sending while held over so the throttle inside
        // SmartCarCommands can refresh the link at its own 50ms cadence.
        SmartCarCommands.send(resolved);
      }
    });

    // Fix axis mapping:
    // indY: tilt forward (positive pitch) → indicator moves UP (negative Y on canvas)
    final indY = (_pitch / 90).clamp(-1.0, 1.0);
    // indX: tilt right (positive roll) → indicator moves RIGHT (positive X on canvas)
    final indX = (_roll / 90).clamp(-1.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DoodleBackground(
        child: SafeArea(
          child: Column(children: [
            _TopBar(onBack: () => Navigator.of(context).maybePop()),
            Expanded(child: _buildLandscape(indX, indY)),
          ]),
        ),
      ),
    );
  }

  Widget _buildLandscape(double indX, double indY) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Live doodle car compass — the hero visual.
        _GyroCarCompass(indX: indX, indY: indY, active: _activeDirection, size: 220),
        const SizedBox(width: 28),
        // D-Pad state indicators + actions
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _TiltIndicatorPad(active: _activeDirection),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
              width: 140,
              child: AppButton(backgroundColor: AppColors.cardWhite, padding: const EdgeInsets.symmetric(vertical: 12), onTap: _calibrate,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.gps_fixed, color: AppColors.navy, size: 18), const SizedBox(width: 8),
                  Text('Calibrate', style: AppTypography.buttonText().copyWith(fontSize: 14)),
                ])),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 140,
              child: AppButton(backgroundColor: AppColors.stopRed, padding: const EdgeInsets.symmetric(vertical: 12),
                onTap: () { SmartCarCommands.stop(); ref.hapticFeedback(HapticStrength.heavy); },
                child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.stop_circle_outlined, color: Colors.white, size: 18), const SizedBox(width: 8),
                  Text('STOP', style: AppTypography.headline3().copyWith(color: Colors.white, fontSize: 16, letterSpacing: 1.5)),
                ]))),
            ),
          ]),
        ]),
      ],
    );
  }

  void _calibrate() {
    ref.read(calibrationProvider.notifier).state = _rawSmoothedX;
    ref.hapticFeedback(HapticStrength.medium);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gyro Calibrated!'), duration: Duration(seconds: 1)));
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(children: [
      GestureDetector(onTap: onBack, child: Container(width: 44, height: 44,
        decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 3),
            blurRadius: 8,
          )
        ]),
        child: const Icon(Icons.arrow_back_ios_new, color: AppColors.navy, size: 20))),
      const SizedBox(width: 16),
      Text('GYRO CONTROL', style: AppTypography.headline3().copyWith(fontSize: 18, letterSpacing: 2.0)),
    ]));
}

/// Small compact 4-direction indicator pad — mirrors the D-Pad screen's
/// AppIconButton styling, but here the buttons are tilt-state readouts
/// (highlighted orange when that direction is currently active) rather
/// than separately tappable controls.
class _TiltIndicatorPad extends StatelessWidget {
  final CarDirection active;
  const _TiltIndicatorPad({required this.active});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _AnimatedDirButton(icon: Icons.keyboard_arrow_up, isActive: active == CarDirection.forward),
      const SizedBox(height: 8),
      Row(mainAxisSize: MainAxisSize.min, children: [
        _AnimatedDirButton(icon: Icons.keyboard_arrow_left, isActive: active == CarDirection.left),
        const SizedBox(width: 8),
        _AnimatedDirButton(icon: Icons.keyboard_arrow_down, isActive: active == CarDirection.backward),
        const SizedBox(width: 8),
        _AnimatedDirButton(icon: Icons.keyboard_arrow_right, isActive: active == CarDirection.right),
      ]),
    ]);
  }
}

/// Direction button that animates to orange with a scale-down + glow
/// when the gyro tilt activates its direction — a clear "pressed" effect.
class _AnimatedDirButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  const _AnimatedDirButton({required this.icon, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 48,
      height: 48,
      transform: Matrix4.diagonal3Values(
        isActive ? 0.92 : 1.0, isActive ? 0.92 : 1.0, 1.0),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? AppColors.orange : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isActive
          ? [
              BoxShadow(color: AppColors.orange.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: 2),
              BoxShadow(color: AppColors.orange.withValues(alpha: 0.25), blurRadius: 6),
            ]
          : [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), offset: const Offset(0, 3), blurRadius: 8),
            ],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Icon(icon,
            key: ValueKey(isActive),
            color: isActive ? Colors.white : AppColors.navy,
            size: 26),
        ),
      ),
    );
  }
}

class _GyroCarCompass extends StatelessWidget {
  final double indX, indY; final CarDirection active; final double size;
  const _GyroCarCompass({required this.indX, required this.indY, required this.active, this.size = 220});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size,
    child: CustomPaint(painter: _GyroCarPainter(indX: indX, indY: indY, active: active)));
}

/// Live-interactive top-down doodle car — drawn with the same conventions
/// as the robot painters (`_OttoPainter` in otto_command.dart, `_SpiderPainter`
/// in spider_screen.dart,
/// `_ArmPainter` in arm_controller_screen.dart): thick navy outline strokes,
/// flat single-color fills, orange joint circles with navy borders, and
/// dotted lines pointing out to direction labels.
class _GyroCarPainter extends CustomPainter {
  final double indX, indY;
  final CarDirection active;
  _GyroCarPainter({required this.indX, required this.indY, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = size.width / 2 - 8;

    // Soft ground shadow, same treatment as the old compass.
    canvas.drawCircle(center + const Offset(0, 6), ringRadius,
      Paint()..color = Colors.black.withValues(alpha: 0.08)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

    // Outer ring (play-mat)
    canvas.drawCircle(center, ringRadius, Paint()..color = AppColors.cardWhite);
    canvas.drawCircle(center, ringRadius, Paint()..color = AppColors.border..style = PaintingStyle.stroke..strokeWidth = 3.0);



    // The car itself — tilts with live gyro data. Lean is decorative (kid
    // friendly), not physically accurate: roll rotates it, pitch nudges it
    // forward/back along its own long axis.
    canvas.save();
    canvas.translate(center.dx + indX * 14, center.dy + indY * 10);
    canvas.rotate(indX * 0.35);
    _drawCar(canvas);
    canvas.restore();
  }

  void _drawCar(Canvas canvas) {
    final outline = Paint()..color = AppColors.navy..style = PaintingStyle.stroke..strokeWidth = 3.6..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final thinOutline = Paint()..color = AppColors.navy..style = PaintingStyle.stroke..strokeWidth = 2.0..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;

    // ── Wheels — drawn first so they peek out from under the chassis like
    // real wheel wells, instead of the old plain corner "joint" dots.
    // Pulse (bigger + glow) when their side matches the active direction.
    final wheelSpecs = <Offset, bool>{
      const Offset(-28, -32): active == CarDirection.forward || active == CarDirection.left,
      const Offset(28, -32): active == CarDirection.forward || active == CarDirection.right,
      const Offset(-28, 32): active == CarDirection.backward || active == CarDirection.left,
      const Offset(28, 32): active == CarDirection.backward || active == CarDirection.right,
    };
    for (final entry in wheelSpecs.entries) {
      final o = entry.key;
      final on = entry.value;
      final w = on ? 13.0 : 11.0;
      final h = on ? 24.0 : 20.0;
      if (on) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: w + 10, height: h + 10), const Radius.circular(10)),
          Paint()..color = AppColors.orange.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      }
      final tire = RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: w, height: h), const Radius.circular(4));
      canvas.drawRRect(tire, Paint()..color = AppColors.navy);
      canvas.drawRRect(tire, thinOutline);
      // Hubcap
      canvas.drawCircle(o, on ? 3.4 : 2.6, Paint()..color = on ? AppColors.orange : AppColors.cardWhite);
    }

    // ── Chassis ──
    final chassis = RRect.fromRectAndRadius(const Rect.fromLTWH(-24, -46, 48, 92), const Radius.circular(22));
    canvas.drawRRect(chassis, Paint()..color = AppColors.orange.withValues(alpha: 0.22));
    canvas.drawRRect(chassis, outline);

    // Front bumper band + headlights (front = -y, matches the FWD arrow)
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-20, -46, 40, 7), const Radius.circular(5)), Paint()..color = AppColors.navy);
    canvas.drawCircle(const Offset(-13, -42.5), 2.6, Paint()..color = const Color(0xFFFFE29A));
    canvas.drawCircle(const Offset(13, -42.5), 2.6, Paint()..color = const Color(0xFFFFE29A));

    // Windshield
    final windshield = RRect.fromRectAndRadius(const Rect.fromLTWH(-13, -33, 26, 21), const Radius.circular(8));
    canvas.drawRRect(windshield, Paint()..color = AppColors.cardWhite);
    canvas.drawRRect(windshield, Paint()..color = AppColors.navy..style = PaintingStyle.stroke..strokeWidth = 2.2);

    // Side mirrors — a small doodle touch that reads instantly as "car"
    canvas.drawOval(Rect.fromCenter(center: const Offset(-25, -18), width: 7, height: 4), Paint()..color = AppColors.navy);
    canvas.drawOval(Rect.fromCenter(center: const Offset(25, -18), width: 7, height: 4), Paint()..color = AppColors.navy);

    // Cabin seam lines (roof outline between the windows)
    canvas.drawLine(const Offset(-24, -8), const Offset(24, -8), thinOutline);
    canvas.drawLine(const Offset(-24, 10), const Offset(24, 10), thinOutline);

    // Rear window
    final rearWindow = RRect.fromRectAndRadius(const Rect.fromLTWH(-12, 16, 24, 17), const Radius.circular(8));
    canvas.drawRRect(rearWindow, Paint()..color = AppColors.cardWhite);
    canvas.drawRRect(rearWindow, Paint()..color = AppColors.navy..style = PaintingStyle.stroke..strokeWidth = 2.0);

    // Rear bumper band + tail-lights
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-20, 39, 40, 7), const Radius.circular(5)), Paint()..color = AppColors.navy);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(-13, 42.5), width: 6, height: 3.6), const Radius.circular(2)), Paint()..color = AppColors.stopRed);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(13, 42.5), width: 6, height: 3.6), const Radius.circular(2)), Paint()..color = AppColors.stopRed);
  }



  @override
  bool shouldRepaint(covariant _GyroCarPainter old) => old.indX != indX || old.indY != indY || old.active != active;
}
