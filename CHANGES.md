# KidsZee — Change Log & Cleanup Progress

Running record of the codebase consolidation and cleanup. Linked from [agents.md](agents.md).

**Date:** 2026-07-07
**Scope:** Merge the `dashboard-doodle-ui` redesign into the main project, then clean and optimize.

---

## Phase 1 — Move redesign into main folder ✅ DONE

The `dashboard-doodle-ui` git worktree held the finished UI redesign as uncommitted work.
Its working tree was mirrored into the main KidsZee folder. `flutter analyze` → **No issues found**.

### What changed

| Area | Change |
|------|--------|
| `lib/` | Mirrored 1:1 from the redesign (analyzer-clean, self-contained) |
| Widgets | `neo_brutalist_button` / `neo_brutalist_slider` → **`app_button`** / **`app_slider`** |
| Screens removed | `unified_controller_screen`, `telemetry/following_screen`, `telemetry/obstacle_screen` |
| New files | `app_bottom_nav`, `mode_doodle_icons`, `mode_intro_dialog`, `router/route_observer`, `network/smart_car_commands` |
| Assets | Removed `logo.png`; added `kidszee_*` brand images + square launcher-icon source |
| Icons | Regenerated Android mipmaps + iOS AppIcon set |
| `test/`, `tool/` | Brought over (`widget_test`, `mock_video_player`, `make_app_icon.py`) |
| `arduino/` | Redesign firmware `fabri_creator_arm/` copied in (folder-name decision pending) |

### Preserved (not in the redesign, kept intentionally)
- `Extra/` — pitch doc, implementation plans, mockup references
- `.idea/`, `*.iml` — IDE project files
- `arduino/robotic_arm/` — left in place pending the rename decision

### Verification
- `flutter pub get` — OK
- `flutter analyze` — **No issues found**
- `lib/` diffed identical to the redesign source

> The `neo-brutalism` naming is fully gone — 0 occurrences anywhere in `lib/`.

---

## Phase 2 — Cleanup & optimization ✅ DONE

All approved by the user and applied. `flutter analyze` → **No issues found**;
`flutter test` → **All tests passed**.

### 2a. Dead code removed
| Item | Result |
|------|--------|
| `core/network/network_manager.dart` | Deleted (241 lines, unused) |
| `core/theme/app_theme.dart` | Deleted (`main.dart` themes inline) |
| `core/widgets/title_bar.dart` | Deleted (102 lines, unused) |
| `core/models/telemetry_data.dart` | Deleted (dead telemetry chain) |
| `connection_provider.dart` | Removed dead `telemetryProvider` |
| `controller_mode_provider.dart` | Removed ~10 never-read providers (turbo, lights, follow, obstacle, unified-toggle, webSocketPort) |

### 2b. Unused packages removed from `pubspec.yaml`
`flutter_svg`, `audioplayers`, `vibration`, `flutter_blue_plus`, `web_socket_channel`, `mqtt_client`.

### 2c. Duplicate / unused assets removed (~14 MB reclaimed)
- Byte-identical dups: `Kidszee.png`, `Kidszee (1).png`, `Kidszee (2).png`, `kidsZee_backup.mp4`
- Unused PNGs (+ pubspec lines): `kidszee_white_bg.png`, `kidszee_transparent_large.png`
- Non-asset files: `kidszee_prompt.md`, the `wombatics_otto_diy_robot/` gltf+bin source folder (kept the `.glb`)
- Remaining assets: `kidszee_transparent.png`, `kidszee_icon_square.png`, `Splash/KidsZee-splash-animation.mp4`, `wombatics_otto_diy_robot.glb`

### 2d. Structural optimizations
- **New** `core/utils/haptics.dart` — `ref.hapticFeedback(HapticStrength.…)` extension; replaced the
  `if (ref.read(hapticFeedbackProvider)) HapticFeedback.…` guard repeated across 7 sites.
- **New** `core/utils/orientation.dart` — `lockLandscape()` / `lockPortrait()`; replaced 6 inline
  `setPreferredOrientations` calls (per-screen timing/nuances preserved).
- Stripped noisy per-action `debugPrint` traces (`[CAR]`, `[GYRO]`, `[VOICE]`, `[VOICE-RAW]`).
- Removed the commented-out cloud-draw block and its now-empty `_HeaderDecorPainter` in `doodle_background.dart`.

### 2e. Naming
- `neo_brutalism` → fully gone (already done in the redesign).
- Arduino firmware consolidated into **`arduino/robotic_arm/`** (chosen name) holding
  `robotic_arm.ino` (the current arm firmware) + `smart_car.ino`; empty `fabri_creator_arm/` removed.

---

## Verification (final)
- `flutter pub get` — OK
- `flutter analyze` — **No issues found**
- `flutter test` — **All tests passed** (`KidsZeeApp smoke test`)
- No dangling references to any removed file, provider, package, asset, or old name.
