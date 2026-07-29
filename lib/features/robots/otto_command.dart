import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/network/bt_classic_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import 'robot_widgets.dart';

/// Sends Otto DIY Bluetooth commands directly via [BtClassicManager], matching
/// the firmware in `examples/Otto_APP` of the official OttoDIYLib
/// (HC-05 / HC-06, 9600 baud).
///
/// Protocol (verified against OttoDIYLib `SerialCommand.cpp`):
///   * The parser tokenizes arguments on a single SPACE (`delim = " "`) and
///     treats a **carriage return `\r`** as the end-of-command terminator
///     (`term = '\r'`).
///   * `readSerial()` only buffers printable chars (`if (isprint(inChar))`),
///     so a lone `\n` is IGNORED and would never trigger a command — the
///     terminator MUST be `\r`. We append `\r\n`; the trailing `\n` is
///     harmlessly dropped by the firmware.
///
/// Command set (letter → firmware handler):
///   * `M <moveId> <T> <moveSize>` → receiveMovement()  (T = speed/time in ms)
///   * `H <gestureId>`             → receiveGesture()   (emotion/gesture)
///   * `K <singId>`                → receiveSing()      (sound)
///   * `S`                         → receiveStop()      (stop + home)
///   * `L <bitmap>`                → receiveLED()       (8x8 mouth matrix)
///
/// Bypasses `CommandService` — that layer targets the FABRI Robotic Arm
/// protocol (multi-char frames needing a ~10ms silence gap). Otto commands are
/// short, discrete, `\r`-terminated lines with no inter-command gap needed.
class OttoCommands {
  OttoCommands._();

  static DateTime? _lastSend;
  static const _minInterval = Duration(milliseconds: 50);

  /// Movement command: `M <moveId> <speed> <moveSize>`.
  ///
  /// [moveId] selects the move (1 = walk fwd, 2 = walk back, 3 = turn left,
  /// 4 = turn right, 8 = swing/dance, 11 = jump, … see firmware `move()`).
  /// [speed] maps to the firmware `T` (ms per step; higher = slower).
  /// [moveSize] is the amplitude used by moves that accept it.
  ///
  /// The move repeats every firmware loop until [sendStop] is called.
  static void sendMove(int moveId, {int speed = 1000, int moveSize = 15}) {
    _send('M $moveId $speed $moveSize');
  }

  /// Gesture/emotion command: `H <gestureId>`
  /// (1 = Happy, 2 = SuperHappy, 3 = Sad, 4 = Sleeping, 5 = Fart,
  /// 6 = Confused, 7 = Love, 8 = Angry, …).
  static void sendGesture(int gestureId) => _send('H $gestureId');

  /// Sound command: `K <singId>` (1 = connection, 8 = happy, 11 = sad, …).
  static void sendSing(int singId) => _send('K $singId');

  /// LED mouth-matrix command: `L <bitmap>` where [bitmap] is the firmware's
  /// unsigned-long bit pattern encoded as a base-2 string (`strtoul(arg, _, 2)`).
  static void sendLed(String bitmap) => _send('L $bitmap');

  /// Stop + home command: `S`. Sent immediately, bypassing the throttle —
  /// a stop must never be dropped.
  static void sendStop() => _dispatch('S');

  /// Throttled to at most one send every 50ms so repeated taps can't flood the
  /// HC-05 link. Drops (does not queue) sends inside the window.
  static void _send(String command) {
    final now = DateTime.now();
    if (_lastSend != null && now.difference(_lastSend!) < _minInterval) {
      debugPrint('[Otto] THROTTLED, dropped: "$command"');
      return;
    }
    _lastSend = now;
    _dispatch(command);
  }

  static void _dispatch(String command) {
    // `\r` is the required terminator; the trailing `\n` is ignored by the
    // firmware's isprint() filter. sendRaw guards on isConnected internally.
    final connected = BtClassicManager().isConnected;
    if (connected) {
      debugPrint('[Otto] SEND: "$command\\r\\n"');
    } else {
      debugPrint('[Otto] NOT CONNECTED, not sent: "$command\\r\\n"');
    }
    BtClassicManager().sendRaw('$command\r\n');
  }
}

// ── Movement direction for animation ────────────────────────────────────────
enum _OttoMove { idle, forward, backward, left, right }

/// Otto Biped Robot Controller
/// Directional buttons for Forward, Backward, Left, Right movement.
/// Quick Move chips for special actions (dance, jump, gestures).
class OttoScreen extends ConsumerStatefulWidget {
  const OttoScreen({super.key});
  @override
  ConsumerState<OttoScreen> createState() => _OttoScreenState();
}

class _OttoScreenState extends ConsumerState<OttoScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  _OttoMove _currentMove = _OttoMove.idle;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..addStatusListener((status) {
        // Loop the animation while a move is active.
        if (status == AnimationStatus.completed && _currentMove != _OttoMove.idle) {
          _animCtrl.forward(from: 0);
        }
      });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _startMove(_OttoMove move, int moveId) {
    setState(() => _currentMove = move);
    _animCtrl.forward(from: 0);
    OttoCommands.sendMove(moveId);
  }

  void _stopMove() {
    OttoCommands.sendStop();
    setState(() => _currentMove = _OttoMove.idle);
    _animCtrl.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.navy), onPressed: () => Navigator.of(context).maybePop()),
        title: Text('Otto Robot', style: AppTypography.headline2()),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: AppColors.divider))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Animated Visualizer
          Container(height: 220, width: double.infinity,
            decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), offset: const Offset(0, 2), blurRadius: 8)]),
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (_, __) => CustomPaint(
                painter: _OttoAnimatedPainter(
                  move: _currentMove,
                  phase: _animCtrl.value,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 20),

          // Directional Controls
          Text('CONTROLS', style: AppTypography.label().copyWith(color: AppColors.orange, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          _buildDirectionalPad(),
          const SizedBox(height: 24),

          // Quick actions — wired to the Otto DIY BT movement/gesture protocol.
          Text('QUICK MOVES', style: AppTypography.label().copyWith(color: AppColors.orange, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            MoveChip(label: 'Dance', onTap: () => OttoCommands.sendMove(8)),
            MoveChip(label: 'Jump', onTap: () => OttoCommands.sendMove(11)),
            MoveChip(label: 'Happy', onTap: () => OttoCommands.sendGesture(1)),
            MoveChip(label: 'Sad', onTap: () => OttoCommands.sendGesture(3)),
          ]).animate().fadeIn(),
          const SizedBox(height: 24),

          // STOP
          SizedBox(width: double.infinity, child: AppButton(
            backgroundColor: AppColors.stopRed,
            onTap: _stopMove,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('STOP', style: AppTypography.headline3().copyWith(color: Colors.white))))),
        ])),
    );
  }

  Widget _buildDirectionalPad() {
    return Center(
      child: SizedBox(
        width: 220,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Forward — top center
            Positioned(
              top: 0,
              left: 0, right: 0,
              child: Center(child: _DpadButton(
                icon: Icons.arrow_upward_rounded,
                label: 'FWD',
                isActive: _currentMove == _OttoMove.forward,
                onTapDown: () => _startMove(_OttoMove.forward, 1),
                onTapUp: _stopMove,
              )),
            ),
            // Backward — bottom center
            Positioned(
              bottom: 0,
              left: 0, right: 0,
              child: Center(child: _DpadButton(
                icon: Icons.arrow_downward_rounded,
                label: 'BACK',
                isActive: _currentMove == _OttoMove.backward,
                onTapDown: () => _startMove(_OttoMove.backward, 2),
                onTapUp: _stopMove,
              )),
            ),
            // Left — middle left
            Positioned(
              left: 0,
              top: 0, bottom: 0,
              child: Center(child: _DpadButton(
                icon: Icons.arrow_back_rounded,
                label: 'LEFT',
                isActive: _currentMove == _OttoMove.left,
                onTapDown: () => _startMove(_OttoMove.left, 3),
                onTapUp: _stopMove,
              )),
            ),
            // Right — middle right
            Positioned(
              right: 0,
              top: 0, bottom: 0,
              child: Center(child: _DpadButton(
                icon: Icons.arrow_forward_rounded,
                label: 'RIGHT',
                isActive: _currentMove == _OttoMove.right,
                onTapDown: () => _startMove(_OttoMove.right, 4),
                onTapUp: _stopMove,
              )),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }
}

// ── D-Pad Button ────────────────────────────────────────────────────────────
class _DpadButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;

  const _DpadButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTapDown,
    required this.onTapUp,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: onTapUp,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: isActive ? AppColors.orange : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isActive ? AppColors.orange : AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isActive ? 0.12 : 0.05),
              offset: Offset(0, isActive ? 1 : 3),
              blurRadius: isActive ? 4 : 8,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: isActive ? Colors.white : AppColors.navy),
            Text(label, style: AppTypography.mono(size: 9, color: isActive ? Colors.white : AppColors.navy)),
          ],
        ),
      ),
    );
  }
}

// ── Animated Visualizer ─────────────────────────────────────────────────────
class _OttoAnimatedPainter extends CustomPainter {
  final _OttoMove move;
  final double phase; // 0.0 → 1.0

  _OttoAnimatedPainter({required this.move, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    // Compute limb offsets based on current move and animation phase.
    // Phase goes 0→1 per cycle; we use sin(phase * 2π) for smooth oscillation.
    final cycle = math.sin(phase * 2 * math.pi);

    double leftLegSwing = 0;
    double rightLegSwing = 0;
    double leftFootSwing = 0;
    double rightFootSwing = 0;
    double bodyOffsetX = 0;
    double bodyOffsetY = 0;

    switch (move) {
      case _OttoMove.forward:
        // Walking gait: legs alternate, feet follow.
        leftLegSwing = cycle * 18;
        rightLegSwing = -cycle * 18;
        leftFootSwing = cycle * 8;
        rightFootSwing = -cycle * 8;
        bodyOffsetY = -cycle.abs() * 3; // slight bounce
        break;
      case _OttoMove.backward:
        // Reverse gait.
        leftLegSwing = -cycle * 18;
        rightLegSwing = cycle * 18;
        leftFootSwing = -cycle * 8;
        rightFootSwing = cycle * 8;
        bodyOffsetY = -cycle.abs() * 3;
        break;
      case _OttoMove.left:
        // Lean and shift left.
        leftLegSwing = cycle * 12;
        rightLegSwing = cycle * 12;
        leftFootSwing = cycle * 15;
        rightFootSwing = -cycle * 5;
        bodyOffsetX = cycle * 6;
        break;
      case _OttoMove.right:
        // Lean and shift right.
        leftLegSwing = -cycle * 12;
        rightLegSwing = -cycle * 12;
        leftFootSwing = cycle * 5;
        rightFootSwing = -cycle * 15;
        bodyOffsetX = -cycle * 6;
        break;
      case _OttoMove.idle:
        // Gentle breathing/idle sway.
        bodyOffsetY = math.sin(phase * 2 * math.pi) * 1.5;
        break;
    }

    final borderPaint = Paint()..color = AppColors.navy..strokeWidth = 24..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final fillPaint = Paint()..color = AppColors.cardWhite..strokeWidth = 16..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final jointPaint = Paint()..color = AppColors.orange;
    final jointBorder = Paint()..color = AppColors.navy..style = PaintingStyle.stroke..strokeWidth = 2.5;

    final center = Offset(size.width / 2 + bodyOffsetX, size.height / 2 - 30 + bodyOffsetY);

    // Left Leg
    final leftHip = center + const Offset(-28, 37);
    final leftKnee = leftHip + Offset(
      math.sin(leftLegSwing * math.pi / 180) * 45,
      math.cos(leftLegSwing * math.pi / 180) * 45,
    );

    // Left Foot
    final lfAngle = (leftLegSwing + leftFootSwing) * math.pi / 180;
    final leftToe = leftKnee + Offset(math.cos(lfAngle) * 22, -math.sin(lfAngle) * 22);
    final leftHeel = leftKnee - Offset(math.cos(lfAngle) * 12, -math.sin(lfAngle) * 12);

    // Right Leg
    final rightHip = center + const Offset(28, 37);
    final rightKnee = rightHip + Offset(
      math.sin(rightLegSwing * math.pi / 180) * 45,
      math.cos(rightLegSwing * math.pi / 180) * 45,
    );

    // Right Foot
    final rfAngle = (rightLegSwing + rightFootSwing) * math.pi / 180;
    final rightToe = rightKnee + Offset(math.cos(rfAngle) * 22, -math.sin(rfAngle) * 22);
    final rightHeel = rightKnee - Offset(math.cos(rfAngle) * 12, -math.sin(rfAngle) * 12);

    // Hands (idle sway only)
    final leftShoulder = center + const Offset(-40, 5);
    final leftHand = leftShoulder + Offset(
      -math.sin((cycle * 8) * math.pi / 180) * 35,
      math.cos((cycle * 8) * math.pi / 180) * 35,
    );

    final rightShoulder = center + const Offset(40, 5);
    final rightHand = rightShoulder + Offset(
      math.sin((-cycle * 8) * math.pi / 180) * 35,
      math.cos((-cycle * 8) * math.pi / 180) * 35,
    );

    // Draw borders (hands, feet, legs)
    canvas.drawLine(leftShoulder, leftHand, borderPaint);
    canvas.drawLine(rightShoulder, rightHand, borderPaint);
    canvas.drawLine(leftHeel, leftToe, borderPaint);
    canvas.drawLine(rightHeel, rightToe, borderPaint);
    canvas.drawLine(leftHip, leftKnee, borderPaint);
    canvas.drawLine(rightHip, rightKnee, borderPaint);

    // Draw fills
    canvas.drawLine(leftShoulder, leftHand, fillPaint);
    canvas.drawLine(rightShoulder, rightHand, fillPaint);
    canvas.drawLine(leftHeel, leftToe, fillPaint);
    canvas.drawLine(rightHeel, rightToe, fillPaint);
    canvas.drawLine(leftHip, leftKnee, fillPaint);
    canvas.drawLine(rightHip, rightKnee, fillPaint);

    // Draw body
    final bodyRect = Rect.fromCenter(center: center, width: 80, height: 75);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(16)), Paint()..color = AppColors.cardWhite);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(16)), Paint()..color = AppColors.navy..style = PaintingStyle.stroke..strokeWidth = 3);

    // Eyes
    canvas.drawCircle(center + const Offset(-20, -10), 12, Paint()..color = AppColors.navy);
    canvas.drawCircle(center + const Offset(20, -10), 12, Paint()..color = AppColors.navy);
    canvas.drawCircle(center + const Offset(-20, -10), 5, Paint()..color = AppColors.orange);
    canvas.drawCircle(center + const Offset(20, -10), 5, Paint()..color = AppColors.orange);

    // Joints
    final joints = [leftHip, leftKnee, rightHip, rightKnee, leftShoulder, rightShoulder];
    for (final pt in joints) {
      canvas.drawCircle(pt, 8.5, jointPaint);
      canvas.drawCircle(pt, 8.5, jointBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _OttoAnimatedPainter oldDelegate) =>
      oldDelegate.move != move || oldDelegate.phase != phase;
}
