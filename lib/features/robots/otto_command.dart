import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/network/bt_classic_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/providers/controller_mode_provider.dart';
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

  /// Logs a servo slider change for debugging. NOTE: the sliders only update
  /// the local visualiser state — they do NOT transmit to the robot (only the
  /// Quick Move chips send BT commands). This log confirms the slider fires.
  static void logServo(int index, String label, double angle) {
    debugPrint('[Otto] SERVO ${index + 1} "$label" angle=${angle.round()} (local only, not sent)');
  }

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

/// Otto Biped Robot Controller
/// Standard Otto: 4 SG90 micro servos (Left Leg, Right Leg, Left Foot, Right Foot)
/// Supports adding custom servos for extended builds.
class OttoScreen extends ConsumerWidget {
  const OttoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servos = ref.watch(ottoServosProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.navy), onPressed: () => Navigator.of(context).maybePop()),
        title: Text('Otto Robot', style: AppTypography.headline2()),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.orange),
            tooltip: 'Add Servo',
            onPressed: () => showAddServoDialog(context, ref, ottoServosProvider)),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: AppColors.divider))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Visualizer
          Container(height: 220, width: double.infinity,
            decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), offset: const Offset(0, 2), blurRadius: 8)]),
            child: CustomPaint(painter: _OttoPainter(servos: servos), child: const SizedBox.expand()),
          ).animate().fadeIn(),
          const SizedBox(height: 20),

          // Quick actions — wired to the Otto DIY BT movement/gesture protocol.
          Text('QUICK MOVES', style: AppTypography.label().copyWith(color: AppColors.orange, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            MoveChip(label: '🚶 Walk Fwd', onTap: () => OttoCommands.sendMove(1)),
            MoveChip(label: '🔙 Walk Back', onTap: () => OttoCommands.sendMove(2)),
            MoveChip(label: '↩️ Turn Left', onTap: () => OttoCommands.sendMove(3)),
            MoveChip(label: '↪️ Turn Right', onTap: () => OttoCommands.sendMove(4)),
            MoveChip(label: '💃 Dance', onTap: () => OttoCommands.sendMove(8)),
            MoveChip(label: '🦘 Jump', onTap: () => OttoCommands.sendMove(11)),
            MoveChip(label: '😊 Happy', onTap: () => OttoCommands.sendGesture(1)),
            MoveChip(label: '😢 Sad', onTap: () => OttoCommands.sendGesture(3)),
          ]).animate().fadeIn(),
          const SizedBox(height: 24),
          // Servo controls
          Row(children: [
            Text('SERVO MOTORS (${servos.length})', style: AppTypography.label().copyWith(color: AppColors.orange, letterSpacing: 1.2)),
            const Spacer(),
            AppButton(backgroundColor: AppColors.cardWhite, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              onTap: () => ref.read(ottoServosProvider.notifier).resetAll(),
              child: Text('Reset All', style: AppTypography.statusText().copyWith(color: AppColors.orange))),
          ]),
          const SizedBox(height: 10),
          ...servos.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ServoTile(
              index: e.key, config: e.value,
              onAngleChanged: (v) {
                OttoCommands.logServo(e.key, e.value.label, v);
                ref.read(ottoServosProvider.notifier).updateAngle(e.key, v);
              },
              onRemove: e.key >= 4 ? () => ref.read(ottoServosProvider.notifier).removeServo(e.key) : null,
              onRename: (name) => ref.read(ottoServosProvider.notifier).renameServo(e.key, name),
            ).animate().fadeIn(delay: (e.key * 60).ms).slideX(begin: 0.05, end: 0),
          )),
          const SizedBox(height: 16),
          // STOP — send the Otto `S` (stop + home) command, then reset local sliders.
          SizedBox(width: double.infinity, child: AppButton(
            backgroundColor: AppColors.stopRed,
            onTap: () {
              OttoCommands.sendStop();
              ref.read(ottoServosProvider.notifier).resetAll();
            },
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('STOP & RESET', style: AppTypography.headline3().copyWith(color: Colors.white))))),
        ])),
    );
  }
}

// ── Visualizer ──────────────────────────────────────────────────────────────
class _OttoPainter extends CustomPainter {
  final List<ServoConfig> servos;
  _OttoPainter({required this.servos});

  @override
  void paint(Canvas canvas, Size size) {
    // Otto default angles: 90. Swing is (angle - 90)
    final leftLegAng = (servos.isNotEmpty ? servos[0].angle : 90) - 90;
    final rightLegAng = (servos.length > 1 ? servos[1].angle : 90) - 90;
    final leftFootAng = (servos.length > 2 ? servos[2].angle : 90) - 90;
    final rightFootAng = (servos.length > 3 ? servos[3].angle : 90) - 90;
    final leftHandAng = (servos.length > 4 ? servos[4].angle : 90) - 90;
    final rightHandAng = (servos.length > 5 ? servos[5].angle : 90) - 90;

    final borderPaint = Paint()..color = AppColors.navy..strokeWidth = 24..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final fillPaint = Paint()..color = AppColors.cardWhite..strokeWidth = 16..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final jointPaint = Paint()..color = AppColors.orange;
    final jointBorder = Paint()..color = AppColors.navy..style = PaintingStyle.stroke..strokeWidth = 2.5;

    final center = Offset(size.width / 2, size.height / 2 - 30);

    // Left Leg
    final leftHip = center + const Offset(-28, 37);
    final leftKnee = leftHip + Offset(math.sin(leftLegAng * math.pi / 180) * 45, math.cos(leftLegAng * math.pi / 180) * 45);

    // Left Foot
    final lfAngle = (leftLegAng + leftFootAng) * math.pi / 180;
    final leftToe = leftKnee + Offset(math.cos(lfAngle) * 22, -math.sin(lfAngle) * 22);
    final leftHeel = leftKnee - Offset(math.cos(lfAngle) * 12, -math.sin(lfAngle) * 12);

    // Right Leg
    final rightHip = center + const Offset(28, 37);
    final rightKnee = rightHip + Offset(math.sin(rightLegAng * math.pi / 180) * 45, math.cos(rightLegAng * math.pi / 180) * 45);

    // Right Foot
    final rfAngle = (rightLegAng + rightFootAng) * math.pi / 180;
    final rightToe = rightKnee + Offset(math.cos(rfAngle) * 22, -math.sin(rfAngle) * 22);
    final rightHeel = rightKnee - Offset(math.cos(rfAngle) * 12, -math.sin(rfAngle) * 12);

    // Hands
    final leftShoulder = center + const Offset(-40, 5);
    final leftHand = leftShoulder + Offset(-math.sin(leftHandAng * math.pi / 180) * 35, math.cos(leftHandAng * math.pi / 180) * 35);

    final rightShoulder = center + const Offset(40, 5);
    final rightHand = rightShoulder + Offset(math.sin(rightHandAng * math.pi / 180) * 35, math.cos(rightHandAng * math.pi / 180) * 35);

    // Draw borders
    if (servos.length > 4) canvas.drawLine(leftShoulder, leftHand, borderPaint);
    if (servos.length > 5) canvas.drawLine(rightShoulder, rightHand, borderPaint);
    canvas.drawLine(leftHeel, leftToe, borderPaint);
    canvas.drawLine(rightHeel, rightToe, borderPaint);
    canvas.drawLine(leftHip, leftKnee, borderPaint);
    canvas.drawLine(rightHip, rightKnee, borderPaint);

    // Draw fills
    if (servos.length > 4) canvas.drawLine(leftShoulder, leftHand, fillPaint);
    if (servos.length > 5) canvas.drawLine(rightShoulder, rightHand, fillPaint);
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
    List<Offset> joints = [leftHip, leftKnee, rightHip, rightKnee];
    if (servos.length > 4) joints.add(leftShoulder);
    if (servos.length > 5) joints.add(rightShoulder);
    for (final pt in joints) {
      canvas.drawCircle(pt, 8.5, jointPaint);
      canvas.drawCircle(pt, 8.5, jointBorder);
    }

    // Labels
    drawLabel(canvas, 'Left Leg', leftHip, leftHip + const Offset(-50, -20));
    drawLabel(canvas, 'Right Leg', rightHip, rightHip + const Offset(50, -20));
    drawLabel(canvas, 'Left Foot', leftKnee, leftKnee + const Offset(-50, 20));
    drawLabel(canvas, 'Right Foot', rightKnee, rightKnee + const Offset(50, 20));
    if (servos.length > 4) drawLabel(canvas, 'Left Hand', leftShoulder, leftShoulder + const Offset(-40, -10));
    if (servos.length > 5) drawLabel(canvas, 'Right Hand', rightShoulder, rightShoulder + const Offset(40, -10));
  }

  @override
  bool shouldRepaint(covariant _OttoPainter oldDelegate) => true;
}
