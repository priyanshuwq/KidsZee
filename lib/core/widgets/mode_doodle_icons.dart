import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../providers/controller_mode_provider.dart';
import '../theme/app_colors.dart';

/// Hand-drawn "kids painting canvas" doodle illustrations for each control
/// mode. Styled to match the navy-outline / flat-fill sketch language already
/// established by `_ArmPainter` in the Robo Arm controller screen — thick
/// rounded strokes, flat single-color fills, no gradients or glossy shading.
class ModeDoodleIcon extends StatelessWidget {
  final ControlMode mode;
  final Color accentColor;
  final double size;

  const ModeDoodleIcon({super.key, required this.mode, required this.accentColor, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final CustomPainter painter = switch (mode) {
      ControlMode.rcCar => _RcCarPainter(accentColor),
      ControlMode.robotArm => _RoboArmPainter(accentColor),
      ControlMode.ottoRobot => _OttoPainter(accentColor),
      ControlMode.spiderRobot => _SpiderPainter(accentColor),
    };
    return SizedBox(width: size, height: size, child: CustomPaint(painter: painter));
  }
}

/// Shared "ink" paints so every doodle uses the same outline weight/color.
Paint _outline({double width = 3.2}) => Paint()
  ..color = AppColors.navy
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint _fill(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.fill;

/// Scales the 96×96 design grid to whatever size the widget is given.
void _withGrid(Canvas canvas, Size size, void Function(Canvas c) draw) {
  canvas.save();
  canvas.scale(size.width / 96, size.height / 96);
  draw(canvas);
  canvas.restore();
}

// ── RC Car ───────────────────────────────────────────────────────────────
class _RcCarPainter extends CustomPainter {
  final Color accent;
  _RcCarPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) => _withGrid(canvas, size, (c) {
        // Speed lines (behind everything, motion doodle)
        final speed = _outline(width: 2.2)..color = accent.withValues(alpha: 0.5);
        c.drawLine(const Offset(3, 48), const Offset(12, 45), speed);
        c.drawLine(const Offset(1, 57), const Offset(11, 55), speed);
        c.drawLine(const Offset(3, 66), const Offset(11, 64), speed);

        // Chunky monster-truck body
        final body = Path()
          ..moveTo(18, 60)
          ..cubicTo(15, 51, 19, 43, 29, 43)
          ..lineTo(63, 43)
          ..cubicTo(75, 43, 81, 46, 83, 54)
          ..cubicTo(85, 60, 82, 65, 77, 65)
          ..lineTo(20, 65)
          ..cubicTo(15, 64, 16, 62, 18, 60)
          ..close();
        c.drawPath(body, _fill(accent));
        c.drawPath(body, _outline());

        // Cabin bump
        final cabin = Path()
          ..moveTo(35, 43)
          ..lineTo(37, 27)
          ..cubicTo(38, 24, 41, 23, 45, 23)
          ..lineTo(55, 23)
          ..cubicTo(59, 23, 61, 25, 62, 28)
          ..lineTo(64, 43)
          ..close();
        c.drawPath(cabin, _fill(AppColors.cardWhite));
        c.drawPath(cabin, _outline());
        c.drawLine(const Offset(43, 32), const Offset(56, 32), _outline(width: 2.2));

        // Antenna
        final antenna = Path()..moveTo(59, 23)..cubicTo(65, 16, 68, 12, 73, 8);
        c.drawPath(antenna, _outline(width: 2.4));
        c.drawCircle(const Offset(74, 7), 3, _fill(accent));
        c.drawCircle(const Offset(74, 7), 3, _outline(width: 1.8));

        // Wheels
        for (final cx in [31.0, 68.0]) {
          final center = Offset(cx, 76);
          c.drawCircle(center, 15, _fill(AppColors.navy));
          c.drawCircle(center, 15, _outline());
          c.drawCircle(center, 6, _fill(AppColors.cardWhite));
          final spoke = _outline(width: 2.0)..color = AppColors.cardWhite;
          for (int i = 0; i < 4; i++) {
            final a = (i * math.pi / 2) + 0.4;
            c.drawLine(center, center + Offset(math.cos(a), math.sin(a)) * 12.5, spoke);
          }
        }
      });

  @override
  bool shouldRepaint(covariant _RcCarPainter old) => old.accent != accent;
}

// ── Robo Arm ─────────────────────────────────────────────────────────────
class _RoboArmPainter extends CustomPainter {
  final Color accent;
  _RoboArmPainter(this.accent);

  void _boneSegment(Canvas c, Offset a, Offset b, {double outerWidth = 11, double innerWidth = 5.5}) {
    c.drawLine(a, b, _outline(width: outerWidth));
    c.drawLine(a, b, _outline(width: innerWidth)..color = accent);
  }

  @override
  void paint(Canvas canvas, Size size) => _withGrid(canvas, size, (c) {
        // Base
        final base = Path()
          ..moveTo(24, 86)
          ..lineTo(72, 86)
          ..lineTo(64, 73)
          ..lineTo(32, 73)
          ..close();
        c.drawPath(base, _fill(accent));
        c.drawPath(base, _outline());

        // Post
        final post = RRect.fromRectAndRadius(const Rect.fromLTWH(41, 58, 14, 16), const Radius.circular(3));
        c.drawRRect(post, _fill(AppColors.cardWhite));
        c.drawRRect(post, _outline(width: 2.6));

        const shoulder = Offset(48, 58);
        const elbow = Offset(69, 37);
        const wrist = Offset(82, 48);

        _boneSegment(c, shoulder, elbow);
        _boneSegment(c, elbow, wrist);

        c.drawCircle(shoulder, 7, _fill(accent));
        c.drawCircle(shoulder, 7, _outline(width: 2.4));
        c.drawCircle(elbow, 6, _fill(accent));
        c.drawCircle(elbow, 6, _outline(width: 2.4));

        // Gripper — two clear V-shaped pincer jaws
        // Upper jaw
        final jaw1 = Path()
          ..moveTo(wrist.dx, wrist.dy - 3)
          ..lineTo(wrist.dx + 12, wrist.dy - 10)
          ..lineTo(wrist.dx + 15, wrist.dy - 5);
        c.drawPath(jaw1, _outline(width: 3.0));
        // Lower jaw
        final jaw2 = Path()
          ..moveTo(wrist.dx, wrist.dy + 3)
          ..lineTo(wrist.dx + 12, wrist.dy + 10)
          ..lineTo(wrist.dx + 15, wrist.dy + 5);
        c.drawPath(jaw2, _outline(width: 3.0));

        // Wrist joint
        c.drawCircle(wrist, 5, _fill(accent));
        c.drawCircle(wrist, 5, _outline(width: 2.2));

        // Little held sparkle between jaws
        c.drawCircle(Offset(wrist.dx + 15, wrist.dy), 2.4, _fill(AppColors.warningYellow));
      });

  @override
  bool shouldRepaint(covariant _RoboArmPainter old) => old.accent != accent;
}

// ── Otto Robot ───────────────────────────────────────────────────────────
// Modelled on the real Otto DIY biped: a big boxy head (that houses the
// ultrasonic-sensor "eyes"), a slimmer body block below it, two side servo
// arms, and two stubby legs on flat feet. Boxy + mechanical, not a round baby
// face — matches the navy-outline / flat-fill sketch language of the family.
class _OttoPainter extends CustomPainter {
  final Color accent;
  _OttoPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) => _withGrid(canvas, size, (c) {
        final steel = HSLColor.fromColor(accent).withLightness(0.92).toColor();

        // ── Feet ──────────────────────────────────────────────────────────
        for (final cx in [39.0, 57.0]) {
          final foot = RRect.fromRectAndCorners(
            Rect.fromCenter(center: Offset(cx, 90), width: 17, height: 8),
            topLeft: const Radius.circular(2), topRight: const Radius.circular(2),
            bottomLeft: const Radius.circular(4), bottomRight: const Radius.circular(4));
          c.drawRRect(foot, _fill(AppColors.navy));
        }
        // ── Legs (short servo blocks) ───────────────────────────────────────
        for (final cx in [39.0, 57.0]) {
          final leg = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, 81), width: 11, height: 12), const Radius.circular(3));
          c.drawRRect(leg, _fill(steel));
          c.drawRRect(leg, _outline(width: 2.6));
        }

        // ── Side arms (servo horns) ─────────────────────────────────────────
        for (final side in [-1.0, 1.0]) {
          final sx = 48 + side * 20;
          final arm = Path()
            ..moveTo(48 + side * 15, 58)
            ..lineTo(sx, 58)
            ..lineTo(sx, 70);
          c.drawPath(arm, _outline(width: 3.4));
          c.drawCircle(Offset(sx, 72), 3.2, _fill(accent));
          c.drawCircle(Offset(sx, 72), 3.2, _outline(width: 1.8));
        }

        // ── Body block ──────────────────────────────────────────────────────
        final body = RRect.fromRectAndRadius(
          const Rect.fromLTWH(37, 54, 22, 20), const Radius.circular(5));
        c.drawRRect(body, _fill(accent));
        c.drawRRect(body, _outline());
        // little control button + slot detail
        c.drawCircle(const Offset(48, 60), 2.4, _fill(AppColors.cardWhite));
        c.drawCircle(const Offset(48, 60), 2.4, _outline(width: 1.6));
        c.drawLine(const Offset(43, 68), const Offset(53, 68), _outline(width: 2.0)..color = AppColors.navy.withValues(alpha: 0.55));

        // ── Head (the signature big Otto box) ───────────────────────────────
        final head = RRect.fromRectAndRadius(
          const Rect.fromLTWH(28, 18, 40, 34), const Radius.circular(9));
        c.drawRRect(head, _fill(AppColors.cardWhite));
        c.drawRRect(head, _outline());

        // Two big round ultrasonic-sensor eyes
        for (final ex in [40.0, 56.0]) {
          final eye = Offset(ex, 34);
          c.drawCircle(eye, 7.5, _fill(accent));
          c.drawCircle(eye, 7.5, _outline(width: 2.6));
          c.drawCircle(eye, 3.2, _fill(AppColors.navy));
          c.drawCircle(eye + const Offset(-1.4, -1.4), 1.3, _fill(AppColors.cardWhite));
        }
        // Friendly little mouth line
        final mouth = Path()..moveTo(43, 46)..quadraticBezierTo(48, 49, 53, 46);
        c.drawPath(mouth, _outline(width: 2.4));

        // ── Twin antennae ───────────────────────────────────────────────────
        for (final side in [-1.0, 1.0]) {
          final bx = 48 + side * 9;
          c.drawLine(Offset(bx, 18), Offset(bx + side * 3, 9), _outline(width: 2.4));
          c.drawCircle(Offset(bx + side * 3, 7), 2.8, _fill(accent));
          c.drawCircle(Offset(bx + side * 3, 7), 2.8, _outline(width: 1.6));
        }
      });

  @override
  bool shouldRepaint(covariant _OttoPainter old) => old.accent != accent;
}

// ── Spider Robot ─────────────────────────────────────────────────────────
class _SpiderPainter extends CustomPainter {
  final Color accent;
  _SpiderPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) => _withGrid(canvas, size, (c) {
        const center = Offset(48, 52);
        const bodyR = 19.0;

        // Legs — drawn first so the body overlaps their roots
        final legPaint = _outline(width: 3.0);
        final rightAngles = [-58.0, -20.0, 20.0, 58.0];
        for (int side = 0; side < 2; side++) {
          final sign = side == 0 ? 1.0 : -1.0;
          for (int i = 0; i < rightAngles.length; i++) {
            final a = rightAngles[i] * math.pi / 180;
            final wobble = (i.isEven ? 1 : -1) * 0.06;
            final root = center + Offset(sign * bodyR * math.cos(a) * 0.9, bodyR * math.sin(a) * 0.9);
            final knee = center +
                Offset(sign * (bodyR + 16 + (i.isOdd ? 2 : 0)) * math.cos(a + sign * 0.1),
                    (bodyR + 12) * math.sin(a) + 6);
            final foot = center +
                Offset(sign * (bodyR + 30 + (i.isEven ? 2 : -1)) * math.cos(a + sign * wobble),
                    (bodyR + 24) * math.sin(a) + 14);
            final leg = Path()
              ..moveTo(root.dx, root.dy)
              ..quadraticBezierTo(knee.dx, knee.dy, foot.dx, foot.dy);
            c.drawPath(leg, legPaint);
          }
        }

        // Little antenna topper (family motif, kept subtle)
        c.drawLine(const Offset(48, 33), const Offset(48, 25), _outline(width: 2.2));
        c.drawCircle(const Offset(48, 23), 2.6, _fill(AppColors.warningYellow));

        // Body
        c.drawCircle(center, bodyR, _fill(accent));
        c.drawCircle(center, bodyR, _outline());

        // Big friendly eyes
        for (final ex in [40.0, 56.0]) {
          final eyeCenter = Offset(ex, 48);
          c.drawCircle(eyeCenter, 6.5, _fill(AppColors.cardWhite));
          c.drawCircle(eyeCenter, 6.5, _outline(width: 2.2));
          c.drawCircle(eyeCenter + const Offset(0.5, 1), 2.8, _fill(AppColors.navy));
          c.drawCircle(eyeCenter + const Offset(-1.2, -1.2), 1.0, _fill(AppColors.cardWhite));
        }
      });

  @override
  bool shouldRepaint(covariant _SpiderPainter old) => old.accent != accent;
}
