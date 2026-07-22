# KidsZee — Full Feature Activation (Phased Plan) — v3

> **What changed in v3 (read this first):**
> 1. **Kill-switch is REMOVED from Phase 1** and deferred (you don't have time to set up
>    Firebase keys yet). It is fully separable — nothing in the arm/Bluetooth code depends
>    on it. See [kill_switch_plan.md](./kill_switch_plan.md) for when you're ready.
> 2. **Transport changed: HC-05 (Bluetooth Classic) → HM-10 (BLE).** Reason: **HC-05 does
>    not work on iOS** (Apple blocks Bluetooth Classic SPP). HM-10 is BLE and works on
>    **both Android and iOS** with one module. Your codebase already has a `BleManager`, so
>    this reuses existing code and adds **no new packages**.
> 3. All logic issues found in the v2 review are folded in (throttle + coalescing, single
>    source-of-truth home pose, SoftwareSerial firmware, per-joint limits, line buffering).
> 4. The 4 open questions are now **answered** (see §3).

---

## Problem Statement

The KidsZee app has 15+ polished screens, but **all hardware communication is mocked**: no
commands reach real robots, the connection screen shows fake devices, and settings don't
persist. This plan activates everything in phases, starting with the **Robotic Arm over
BLE** as the highest priority.

---

## 1. Why HM-10 (BLE), not HC-05 (Classic)

| | HC-05 | **HM-10 (chosen)** |
| :--- | :--- | :--- |
| Protocol | Bluetooth **Classic** (SPP) | Bluetooth **Low Energy** |
| Android | ✅ | ✅ |
| **iOS** | ❌ **blocked by Apple** | ✅ |
| Flutter package | `flutter_blue_classic` (Android-only, experimental) | `flutter_blue_plus` (**already in your app**) |
| New packages needed | yes | **none** |

**HM-10 is a transparent BLE↔serial bridge.** Whatever bytes the app writes to its
characteristic come out the HM-10's TX pin into the Arduino as plain serial — so the simple
string protocol below still works, and the Arduino code barely changes.

> **Do NOT use both HC-05 + HM-10.** Two radios on one Arduino Uno means two serial ports,
> but the Uno has only one hardware UART and SoftwareSerial can only listen on one port at a
> time — fiddly and bug-prone. One HM-10 covers both platforms. Done.

---

## 2. Hardware Context (Phase 1 — Robotic Arm)

| Joint # | Joint Name | Servo | Arduino Servo ID | Pin |
|---------|-----------|-------|------------------|-----|
| 1 | Gripper | SG90 | 0 | 3 |
| 2 | Wrist Roll | SG90 | 1 | 5 |
| 3 | Wrist Pitch | SG90 | 2 | 6 |
| 4 | Elbow | MG996R* | 3 | 9 |
| 5 | Shoulder | MG996R* | 4 | 10 |
| 6 | Base | MG996R* | 5 | 11 |

\* Confirm whether your kit is **MG995** or **MG996R** — affects current draw/speed. Plan
assumes MG996R (the common kit servo).

- **Controller:** Arduino Uno
- **Radio:** **HM-10 BLE module** on `SoftwareSerial(10, 11)`… ⚠️ wait — pins 10/11 are used
  by servos. **Use `SoftwareSerial(2, 4)` for HM-10** (RX=2, TX=4), keeping the hardware
  UART (pins 0/1) free for sketch upload + Serial Monitor debugging.
- **HM-10 ↔ Arduino UART baud:** **9600** (HM-10 factory default). Must match
  `bluetooth.begin(9600)` in the sketch.
- **Servo power:** separate **5–6V supply rated ≥3A** (NOT the Arduino 5V pin — MG996R stalls
  ~1A each). **Tie the servo-supply ground to the Arduino ground** (common GND) or signals
  float.

---

## 3. Open Questions — RESOLVED

1. **Servo speed limits — app or firmware?** → **Firmware.** Smooth motion comes from the
   Arduino ramping from current→target angle in small steps with a short `delay()` between
   steps. This is immune to BLE/UI timing jitter (app-side rate-limiting is not). The app
   sends *absolute target angles*; the firmware eases into them. Optionally the app sends one
   global speed value (`SP:<n>`) that sets the firmware step delay. Heavy joints
   (Elbow/Shoulder/Base) get a smaller max step in firmware.

2. **Preset names — custom or auto?** → **Auto-generate ("Pose 1/2/3") instantly, with an
   optional rename.** This is a kids' app; forcing a text dialog on every save is high
   friction. Provide a small rename/emoji option for those who want it.

3. **Wrist roll/pitch range — full 0–180°?** → **No — use a per-joint min/max constants
   map.** If the gripper wire runs through the wrist, unrestricted roll can tangle cables.
   Default Wrist Roll to a reduced range (~20–160°); keep others 0–180°; all tunable in one
   constants file. (Pairs with the firmware speed limits from Q1.)

4. **HC-05/HM-10 pairing PIN?** → **Irrelevant to app code.** BLE (HM-10) doesn't pair with a
   PIN the way Classic does — the app just scans and connects. No PIN handling needed.

---

## 4. Transport & Protocol (App ↔ HM-10 ↔ Arduino)

**Transport:** BLE. The app writes to the HM-10 characteristic; HM-10 relays bytes to the
Arduino over serial; Arduino replies on serial → HM-10 → BLE notification back to the app.

**HM-10 BLE UUIDs (defaults):**
- Service: `FFE0`
- Characteristic: `FFE1` — used for **both** writing commands **and** receiving telemetry
  (write + notify on the same characteristic). *(Your current `BleManager` uses separate
  `ffe4`/`ffe1-3` UUIDs — these must be changed to the single `FFE1` for HM-10. See §5.1.)*

**Protocol — string, newline-terminated (one command per line):**

```
S:<id>,<angle>\n      Single servo.   e.g.  S:0,90      (Gripper → 90°)
A:<g>,<wr>,<wp>,<e>,<sh>,<b>\n   All six at once. e.g. A:90,90,90,90,148,80
H:0\n                 Home (firmware moves to the ONE shared home pose)
SP:<n>\n              Set global speed (firmware step delay), n = 1..10
P:0\n                 Ping/heartbeat → Arduino replies "T:P,OK\n"

Telemetry (Arduino → App):  T:<type>,<value>\n   e.g.  T:P,OK   /   T:V,7.2
```

### ⚠️ BLE 20-byte rule (important)
A classic HM-10 passes **max ~20 bytes per BLE packet**. So:
- **Single-servo `S:` commands (≤8 bytes)** are the default for slider drags — always safe.
- The full **`A:` command can exceed 20 bytes** (e.g. `A:170,170,170,170,170,170\n` = 26B).
  Handle by **chunking the write into ≤20-byte pieces**; the Arduino reads until `\n` and
  reassembles, so a split command still arrives whole. (A line-buffer on both ends makes
  this transparent — see §5.1 and §5.8.)
- Incoming BLE notifications are **not line-aligned** either — buffer received bytes and split
  on `\n` before parsing.

> **Why string, not binary?** Easy to debug in the Arduino Serial Monitor, no MTU math for
> the common case (single-servo commands fit in 20 bytes), and trivially extensible. The
> existing `BleManager.sendArmPose()` binary path (`[0x10, ...]`) is replaced by the string
> path so the same protocol works for arm, car, and other robots.

---

## 5. Phase 1 — Robotic Arm over BLE (no kill-switch)

This is the core phase: a working robotic arm controlled from the phone over BLE on **both
Android and iOS**.

### 5.1 — [MODIFY] BLE Manager for HM-10
**File:** `lib/core/network/network_manager.dart` (existing `BleManager`)

- Change UUIDs to HM-10 defaults: service `FFE0`, single characteristic `FFE1` for write +
  notify (remove the separate `ffe2/ffe3/ffe4` assumptions).
- Add a **string send** API: `Future<void> sendLine(String cmd)` that appends `\n` and
  **chunks the bytes into ≤20-byte writes** (`withoutResponse: true`).
- Add a **receive line-buffer**: accumulate notification bytes, split on `\n`, emit each
  complete line on a `Stream<String> get incomingLines`.
- Keep MTU request on Android (`requestMtu(247)`), but **never depend on it** — chunking to
  20 bytes guarantees correctness even if MTU stays at 23 (iOS negotiates automatically).
- Connection-state stream: `connecting / connected / disconnected / error`.
- Heartbeat: send `P:0` every 3s; if 3 consecutive pongs missed → mark disconnected.
- Auto-reconnect with exponential backoff when the `autoReconnect` setting is on.

### 5.2 — [NEW] CommandService (single entry point)
**File:** `lib/core/network/command_service.dart`

All screens call `CommandService`, never `BleManager` directly — so future transports
(BT Classic, WiFi) are drop-in later.

```dart
class CommandService {
  void sendArmPose(ArmPose pose);          // full A: command, throttled + coalesced
  void sendSingleServo(int id, int angle); // S: command, for slider drags
  void sendHome();                         // H:0
  void setSpeed(int level);                // SP:n
  Stream<TelemetryData> get telemetryStream;
  Stream<ConnectionStatus> get connectionStateStream;
  bool get isConnected;
}
```

**Throttle + coalesce (fixes the v2 lag bug):**
- During slider drags, send **`sendSingleServo` for the joint that moved** (≤8 bytes), not the
  full pose.
- Rate-limit to **~40–50ms** (not 30ms — at 9600 baud a full pose is ~25ms on the wire and
  30ms leaves no margin).
- **Coalesce:** keep only the *latest* pending value per joint; drop intermediate ones. This
  prevents the "arm catches up laggily after you release the slider" problem.

### 5.3 — [MODIFY] ArmPose model: 4 → 6 joints
**File:** `lib/core/models/arm_pose.dart` (+ regenerate `arm_pose.g.dart`)

- Add `@HiveField(5) wristRoll` and `@HiveField(6) wristPitch`.
- **One shared home pose** (must equal the firmware's `homeAngles` exactly — see §5.8):
  ```dart
  static ArmPose get home => ArmPose(
    base: 80, shoulder: 148, elbow: 90, wristPitch: 90, wristRoll: 90, gripper: 90,
    label: 'Home');
  ```
  *(Note: v2's elbow=180/gripper=120 home disagreed with the firmware's 90/90 and risked a
  mechanical slam. Reconciled to one safe pose; verify on the real arm.)*
- Replace `toBleBytes()` with:
  ```dart
  String toAllServosCommand() =>
    'A:${gripper.round()},${wristRoll.round()},${wristPitch.round()},'
    '${elbow.round()},${shoulder.round()},${base.round()}';
  ```
- Update `copyWith` and add a per-joint **limits map** (Q3):
  ```dart
  const kJointLimits = {
    'gripper':   (0, 180), 'wristRoll': (20, 160), 'wristPitch': (0, 180),
    'elbow':     (0, 180), 'shoulder':  (0, 180),  'base':       (0, 180),
  };
  ```

> ⚠️ **Hive migration:** adding fields means re-running `build_runner`. Existing saved
> sequences/presets become incompatible and must be re-recorded. (Acceptable — nothing real
> is saved yet.)

**File:** `lib/core/providers/arm_pose_provider.dart`
- Add `updateWristRoll` / `updateWristPitch` (clamped to `kJointLimits`).
- A listener (in `CommandService` or a small bridge provider) watches `armPoseProvider` and
  auto-sends on change (throttled + coalesced per §5.2).

### 5.4 — [MODIFY] Arm Controller Screen (6-DOF + real send)
**File:** `lib/features/robotic_arm/arm_controller_screen.dart`

1. Add **Wrist Roll** and **Wrist Pitch** sliders (between Elbow and Gripper), each clamped to
   its `kJointLimits` range.
2. Visualizer: render the **5 visible DOF** (base-yaw, shoulder, elbow, wrist-pitch, gripper).
   **Wrist roll has no faithful 2D side-view representation** — show it as a small rotation
   dial/number, not a segment. *(v2's "render 6 joints" over-promised.)*
3. Wire **Home** → `armPoseProvider.resetHome()` **and** `commandService.sendHome()`.
4. Wire **Save Pose** → auto-name "Pose N" via `presetProvider`, with optional rename (Q2).
5. Add a **connection status dot** in the AppBar (green=connected, red=disconnected) from
   `commandService.connectionStateStream`.
6. Slider drag → `armPoseProvider` update → auto-send (single-servo, throttled).

**File:** `lib/core/providers/preset_provider.dart` (NEW) — Hive box `arm_presets`:
```dart
class PresetNotifier extends StateNotifier<List<ArmPose>> {
  Future<void> savePreset(ArmPose pose, [String? name]); // auto-names if null
  Future<void> deletePreset(int index);
  Future<void> renamePreset(int index, String newName);
  void loadPreset(ArmPose pose); // updates armPoseProvider + sends to hardware
}
```

### 5.5 — [MODIFY] Sequence Screen (real record + playback)
**File:** `lib/features/robotic_arm/sequence_screen.dart`

1. **Play:** `Timer.periodic(stepDuration)` walks `macro.poses`; each frame updates
   `armPoseProvider` (drives visualizer) **and** `commandService.sendArmPose()`; advances
   `_playIndex`; stops at end or on Stop.
2. **Record:** while `isRecording`, snapshot `armPoseProvider` on each change into
   `recordingBufferProvider`.
3. Add a **step-duration slider** (100–2000ms) and a **loop toggle**.

### 5.6 — [MODIFY] Connection Screen (real BLE scan)
**File:** `lib/features/connection/connection_screen.dart`

1. Keep the **Bluetooth tab = `Protocol.ble`** (already correct); **hide the WiFi tab** for
   now (code stays for future).
2. Replace the hard-coded `_availableDevices` with a **real BLE scan** via `BleManager`
   (`flutter_blue_plus`), filtering for the HM-10 (name often `HMSoft`/`BT05`, or by service
   `FFE0`).
3. Wire **Connect** → `BleManager.connect()` → update `connectionProvider` on success/failure
   (real states, remove the fake `Future.delayed(800ms)`).
4. **Permissions:** request `bluetoothScan` + `bluetoothConnect` (Android 12+) and, on older
   Android, location — via the existing `permission_handler`. **Add the matching entries to
   `AndroidManifest.xml` and `Info.plist`** (`NSBluetoothAlwaysUsageDescription` for iOS).
5. Save last-connected device id to `SharedPreferences` for auto-reconnect.
6. Helper text: "Turn on Bluetooth and keep the robot powered nearby."

### 5.7 — [NEW] Settings Persistence
**File:** `lib/core/providers/settings_persistence.dart`

Load all settings from `SharedPreferences` in `main.dart` before `runApp()` and apply via
`ProviderScope` overrides (simplest, avoids per-provider boilerplate).

| Key | Type | Default |
|-----|------|---------|
| `gyro_sensitivity` | double | 1.0 |
| `gyro_deadzone` | double | 0.15 |
| `auto_reconnect` | bool | true |
| `haptic_feedback` | bool | true |
| `button_size` | String | 'Medium' |
| `default_protocol` | String | 'BLE' |
| `voice_language` | String | 'English' |
| `keybind_*` | String | W/A/S/D |
| `last_device_id` / `last_device_name` | String | '' |

**File:** `lib/features/settings/settings_screen.dart`
- Default-protocol dropdown → only **'BLE'** for now (remove WebSocket/MQTT options).
- Remove WebSocket Port field.
- Add "Last Connected Device" with a **Forget** button, and a **Clear All Presets** button.

**File:** `lib/main.dart`
- Load `SharedPreferences` before `runApp()`; pass values as `ProviderScope` overrides.
- **No Firebase, no LicenseGate** (kill-switch deferred).

### 5.8 — [NEW] Arduino Firmware (HM-10, 6 servos, speed ramping)
**File:** `arduino/kidszee_arm/kidszee_arm.ino`

```cpp
#include <Servo.h>
#include <SoftwareSerial.h>

SoftwareSerial bt(2, 4);            // HM-10: Arduino RX=2 <- HM-10 TX, TX=4 -> HM-10 RX
Servo servos[6];
const int servoPins[6] = {3, 5, 6, 9, 10, 11};      // Gripper,WRoll,WPitch,Elbow,Shoulder,Base
const int homeAngles[6] = {90, 90, 90, 90, 148, 80}; // MUST equal ArmPose.home
int current[6];                     // last commanded angle (for ramping)
int stepDelay = 8;                  // ms between ramp steps (speed) — set via SP:

String buf = "";

void setup() {
  Serial.begin(9600);              // USB debug
  bt.begin(9600);                  // HM-10 default UART baud
  for (int i = 0; i < 6; i++) { servos[i].attach(servoPins[i]); servos[i].write(homeAngles[i]); current[i] = homeAngles[i]; }
}

void loop() {
  while (bt.available()) {
    char c = bt.read();
    if (c == '\n') { parse(buf); buf = ""; }
    else if (c != '\r' && buf.length() < 40) buf += c;   // line buffer
  }
}

void moveTo(int id, int target) {  // ramped move = smooth, immune to BLE jitter
  target = constrain(target, 0, 180);
  int dir = (target > current[id]) ? 1 : -1;
  while (current[id] != target) { current[id] += dir; servos[id].write(current[id]); delay(stepDelay); }
}

void parse(String cmd) {
  if (cmd.startsWith("S:")) {
    int comma = cmd.indexOf(',');
    int id = cmd.substring(2, comma).toInt();
    int ang = cmd.substring(comma + 1).toInt();
    if (id >= 0 && id < 6) moveTo(id, ang);
  } else if (cmd.startsWith("A:")) {
    String d = cmd.substring(2); int idx = 0;
    while (d.length() && idx < 6) {
      int comma = d.indexOf(',');
      int v = (comma == -1) ? d.toInt() : d.substring(0, comma).toInt();
      moveTo(idx++, v);
      d = (comma == -1) ? "" : d.substring(comma + 1);
    }
  } else if (cmd.startsWith("H:")) {
    for (int i = 0; i < 6; i++) moveTo(i, homeAngles[i]);
  } else if (cmd.startsWith("SP:")) {
    stepDelay = constrain(cmd.substring(3).toInt(), 1, 30);
  } else if (cmd.startsWith("P:")) {
    bt.println("T:P,OK");
  }
}
```

> The reference repo (RohitKumar-tech / based on HowToMechatronics) is useful for the
> **3D-printed parts and wiring only** — its firmware uses a different protocol (`s1120` at
> 38400, MIT App Inventor). **Don't reuse its `.ino`;** flash the matching sketch above.

---

## 6. Phases 2–4 (unchanged scope, BLE transport)

> **Prerequisite for all:** Phase 1 complete (BLE manager + `CommandService`).

- **Phase 2 — RC Car:** D-Pad / Gyro / Voice → `commandService.sendMotorCommand()` over BLE
  (`M:F,80`, `M:S,0`, etc.). Same throttle/coalesce rules.
- **Phase 3 — Otto + Spider:** servo-angle commands (`O:`/`X:`) + quick moves (`Q:WALK`),
  either firmware-side gaits or app-side frame playback.
- **Phase 4 — Telemetry + Polish:** replace mock `telemetryProvider` with real `T:` lines
  parsed from `CommandService.telemetryStream`; wire obstacle/following screens; global
  connection indicator, sound/haptics, battery in AppBar.

*(WiFi/WebSocket/MQTT stay in the codebase but out of scope for now.)*

---

## 7. File Change Summary — Phase 1 (no kill-switch)

| Action | Path |
|--------|------|
| [MODIFY] | `lib/core/network/network_manager.dart` (HM-10 UUIDs, string send, line buffer) |
| [NEW]    | `lib/core/network/command_service.dart` |
| [MODIFY] | `lib/core/models/arm_pose.dart` (+ regenerate `arm_pose.g.dart`) |
| [MODIFY] | `lib/core/providers/arm_pose_provider.dart` |
| [NEW]    | `lib/core/providers/preset_provider.dart` |
| [NEW]    | `lib/core/providers/settings_persistence.dart` |
| [MODIFY] | `lib/features/robotic_arm/arm_controller_screen.dart` |
| [MODIFY] | `lib/features/robotic_arm/sequence_screen.dart` |
| [MODIFY] | `lib/features/connection/connection_screen.dart` |
| [MODIFY] | `lib/features/settings/settings_screen.dart` |
| [MODIFY] | `lib/core/providers/connection_provider.dart` (wire real BLE telemetry in Ph4) |
| [MODIFY] | `lib/main.dart` (SharedPreferences load + overrides; **no Firebase**) |
| [MODIFY] | `android/app/src/main/AndroidManifest.xml` (BLE permissions) |
| [MODIFY] | `ios/Runner/Info.plist` (`NSBluetoothAlwaysUsageDescription`) |
| [NEW]    | `arduino/kidszee_arm/kidszee_arm.ino` |

**Dropped from Phase 1 (deferred):** `license_service.dart`, `license_gate.dart`,
`maintenance_screen.dart`, the `app_router.dart` kill guard, and the Firebase setup.

---

## 8. Package Changes (pubspec.yaml)

**Add:** *(nothing!)* — BLE uses the already-present `flutter_blue_plus`, settings use the
already-present `shared_preferences`, presets/sequences use `hive_flutter`.

**No longer needed for Phase 1:** `firebase_core`, `firebase_remote_config`,
`connectivity_plus` (were kill-switch only). `flutter_blue_classic` is **not used** by the
BLE path — keep it only if you still want an Android-only HC-05 fallback later, otherwise it
can be removed.

---

## 9. Verification Plan — Phase 1

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenerate Hive adapters
flutter analyze
flutter build apk --debug          # Android
flutter build ios --debug --no-codesign   # iOS compile check
```

**Manual (on real hardware, both an Android phone and an iPhone):**
- [ ] BLE scan lists the HM-10; Connect works; status dot turns green.
- [ ] All 6 sliders move the matching servo; motion is **smooth** (firmware ramping) with no
      lag after releasing a slider (coalescing works).
- [ ] Visualizer matches the arm for the 5 visible DOF; wrist-roll dial updates.
- [ ] Home button: visualizer **and** physical arm reach the **same** pose.
- [ ] Save Pose → auto-named preset appears; loading it moves the arm; survives restart.
- [ ] Sequence record + playback follows poses with correct timing; loop works.
- [ ] Settings persist across restart; default protocol = BLE; no WiFi options visible.
- [ ] **iOS:** the same connect + control flow works (the whole reason for HM-10).

**Hardware:** Arduino Uno · HM-10 BLE module · 3×SG90 · 3×MG996R · separate 5–6V ≥3A servo
supply with **common ground** · jumper wires/breadboard.

---

## 10. Deferred: Kill-Switch

When you're ready to set up Firebase keys, follow
[kill_switch_plan.md](./kill_switch_plan.md). It plugs in without touching the robot-arm
code: add the 3 packages, the `security/` files, wrap `main.dart` in `LicenseGate`, and add
the router guard. Until then, the app ships fully functional with no kill-switch.
