# KidsZee — Developer Guide

KidsZee is a Flutter app that lets kids control IoT toys — a robotic arm, a smart car, and
walking robots (Otto, Spider) — over Bluetooth. The UI is a warm, playful "doodle" style:
light mode only, hand-drawn accents, chunky tactile controls.

> Change history and pending cleanup: [CHANGES.md](CHANGES.md)

---

## Stack

| Concern | Choice |
|---------|--------|
| State | `flutter_riverpod` |
| Navigation | `go_router` (`lib/core/router/app_router.dart`) |
| Fonts | `google_fonts` — Fredoka (headings), Quicksand (UI text) |
| Motion | `flutter_animate` |
| Bluetooth | `flutter_blue_classic` (HC-05/06, Android) |
| Sensors | `sensors_plus` (gyro/tilt), `speech_to_text` (voice) |
| Storage | `hive_flutter` (arm poses, sequences), `shared_preferences` (settings) |
| Media | `video_player` (splash), `model_viewer_plus` (3D robot), `url_launcher` |

Run: `flutter pub get` → `flutter run`. Lint: `flutter analyze` (config in `analysis_options.yaml`).

---

## Layout

```
lib/
  core/
    models/        arm_pose, sequence_macro (+ Hive .g.dart adapters)
    network/       bt_classic_manager, command_service, smart_car_commands
    providers/     Riverpod providers (connection, controller_mode, presets, sensors…)
    router/        app_router, route_observer
    theme/         app_colors, app_typography
    widgets/       app_button, app_slider, app_bottom_nav, doodle_background,
                   mode_doodle_icons, mode_intro_dialog
  features/
    splash/        splash_screen, onboarding_screen
    connection/    connection_screen (device scan/pair)
    dashboard/     dashboard_screen + widgets/product_card
    controller/    dpad_screen, gyro_screen, voice_screen   (car control modes)
    robotic_arm/   arm_controller_screen, sequence_screen
    robots/        robot_screens (Otto, Spider)
    settings/      settings_screen
  main.dart        Hive init, light-mode system UI, portrait lock, MaterialApp.router
```

Feature-first: each screen lives under its feature folder; shared building blocks live in `core/`.

---

## Screens & routes

Defined in `lib/core/router/app_router.dart` (initial: `/splash`).

`/splash` → `/onboarding` → `/connect` → `/dashboard`, then per-mode:
`/dpad`, `/gyro`, `/voice` (car), `/arm`, `/sequences` (robotic arm),
`/otto`, `/spider` (walking robots), `/settings`.

---

## Design system

- **Light mode only.** `main.dart` forces `ThemeMode.light`; do not add a dark `ThemeData`.
- **Palette** (`lib/core/theme/app_colors.dart`): white background, brand orange `#E0914B`,
  logo blue `#6BABE7` / orange `#F5A623`, Otto blue, Spider green, soft-red stop `#E85D4A`,
  green connected `#34A853`. Sky-blue header gradients are used on some screens.
- **Type** (`lib/core/theme/app_typography.dart`): Fredoka for bubbly headlines, Quicksand for
  interface text and labels.
- **Feel:** chunky rounded buttons with a short press/depress animation, hand-drawn doodle
  background (`doodle_background.dart`), per-mode doodle icons (`mode_doodle_icons.dart`).
- **Orientation:** app is portrait by default; the D-Pad / gyro / voice car controllers lock to
  landscape while active and restore portrait on exit.

---

## Robot communication

- **Transport:** Bluetooth Classic via `bt_classic_manager.dart` (Android HC-05/HC-06 modules).
- **Commands:** `command_service.dart` builds control messages; `smart_car_commands.dart` holds
  the smart-car command set. Firmware sketches live in `arduino/`.
- **Arm poses & sequences:** captured/replayed via `arm_pose` + `sequence_macro`, persisted in Hive.

Firmware (`arduino/`): the 5-DOF arm sketch and the IR/line-following smart-car sketch.

---

## Conventions

- Widgets that appear on more than one screen belong in `core/widgets/`.
- Use the shared `AppButton` / `AppSlider` rather than raw Material controls.
- Read settings (haptics, speed, sensitivity, calibration) through their Riverpod providers.
- Keep names honest: a file/type name should describe what it currently does. When a feature is
  removed, remove its providers/models too rather than leaving them dangling.
