import 'dart:async';

import '../models/arm_pose.dart';
import 'bt_classic_manager.dart';

/// Maps our [ServoId] to the FABRI Creator command digit.
/// FABRI uses s1,s2,s4,s5,s6,s7 (digit 3 is intentionally skipped).
const Map<int, String> _kFabriDigit = {
  ServoId.base: '1', //      s1  -> Base / Waist   (D5  MG995)
  ServoId.shoulder: '2', //  s2  -> Shoulder       (D6  MG995)
  ServoId.elbow: '4', //     s4  -> Elbow          (D7  MG995)
  ServoId.wristRoll: '5', // s5  -> Wrist Rotation (D8  SG90)
  ServoId.wristPitch: '6', //s6  -> Wrist Pitch    (D9  SG90)
  ServoId.gripper: '7', //   s7  -> Gripper        (D10 SG90)
};

/// The single entry point every screen uses to talk to hardware.
///
/// Speaks the **FABRI Creator** serial protocol, because the Arduino is already
/// flashed with the FABRI-compatible firmware:
///   • servo:  `s<digit><angle>`   e.g. `s190`  (no separators, NO newline)
///   • speed:  `ss<value>`         (1..50, lower = faster)
///   • record: `SAVE` / `RUN` / `PAUSE` / `RESET`  (Arduino onboard recording)
///
/// CRITICAL: the FABRI firmware ends a command on a ~10ms silence gap, so two
/// commands sent back-to-back would MERGE and corrupt. Everything therefore goes
/// through a [_pump] that emits at most one command every [_gap], and per-servo
/// values are COALESCED to the latest (rapid slider drags never build a backlog).
///
/// Transport-agnostic: swapping to BLE (HM-10) later only touches this file.
class CommandService {
  CommandService._internal();
  static final CommandService _instance = CommandService._internal();
  factory CommandService() => _instance;

  final BtClassicManager _bt = BtClassicManager();

  // > Arduino's 10ms gap, with margin for any HC-05 buffering. ~40 cmds/sec.
  static const Duration _gap = Duration(milliseconds: 25);

  final Map<int, int> _pendingServos = {}; // servoId -> latest angle (coalesced)
  final List<String> _literalQueue = []; // ss / SAVE / RUN / PAUSE / RESET
  Timer? _pump;

  // ── Streams / state passthrough ────────────────────────────────────────────
  Stream<BtState> get connectionStateStream => _bt.stateStream;
  Stream<String> get incomingLines => _bt.incomingLines;
  bool get isConnected => _bt.isConnected;
  String? get connectedDeviceName => _bt.connectedDeviceName;

  // ── Arm control ─────────────────────────────────────────────────────────────

  /// Send a single servo (slider drags). Coalesced to the latest value.
  void sendSingleServo(int servoId, int angle) {
    if (!_kFabriDigit.containsKey(servoId)) return;
    _pendingServos[servoId] = clampJoint(servoId, angle.toDouble()).round();
    _startPump();
  }

  /// Send a full 6-servo pose (sequence playback / preset load / home).
  /// Each joint is queued as its own FABRI command; the pump spaces them out.
  void sendArmPose(ArmPose pose) {
    for (final id in _kFabriDigit.keys) {
      _pendingServos[id] = clampJoint(id, pose.byServoId(id)).round();
    }
    _startPump();
  }

  /// Move to the home pose (all servos to 90 — matches the Arduino power-on state).
  void sendHome() => sendArmPose(ArmPose.home);

  /// FABRI onboard recording controls (optional — Arduino stores up to 25 steps).
  void saveStep() => _enqueueLiteral('SAVE');
  void run() => _enqueueLiteral('RUN');
  void pause() => _enqueueLiteral('PAUSE');
  void reset() => _enqueueLiteral('RESET');

  /// Playback speed for the Arduino's onboard RUN (1=slow .. 10=fast).
  /// FABRI `ss` is ms-per-degree (1..50, lower = faster).
  void setSpeed(int level) {
    final ms = (50 - (level.clamp(1, 10) - 1) * (49 / 9)).round().clamp(1, 50);
    _enqueueLiteral('ss$ms');
  }

  void _enqueueLiteral(String cmd) {
    _literalQueue.add(cmd);
    _startPump();
  }

  String _servoCmd(int servoId, int angle) => 's${_kFabriDigit[servoId]}$angle';

  // ── The gap-respecting pump ─────────────────────────────────────────────────

  void _startPump() {
    if (_pump != null) return;
    _tick(); // leading-edge: first command goes out immediately
    _pump = Timer.periodic(_gap, (_) => _tick());
  }

  void _tick() {
    if (!_bt.isConnected) {
      _pendingServos.clear();
      _literalQueue.clear();
      _stopPump();
      return;
    }
    // Literal commands (speed/buttons) take priority, then one servo per tick.
    if (_literalQueue.isNotEmpty) {
      _bt.sendRaw(_literalQueue.removeAt(0));
      return;
    }
    if (_pendingServos.isNotEmpty) {
      final id = _pendingServos.keys.first;
      final angle = _pendingServos.remove(id)!;
      _bt.sendRaw(_servoCmd(id, angle));
      return;
    }
    _stopPump(); // nothing left to send
  }

  void _stopPump() {
    _pump?.cancel();
    _pump = null;
  }
}
