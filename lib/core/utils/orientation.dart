import 'package:flutter/services.dart';

/// Screen-orientation helpers.
///
/// KidsZee is portrait by default; the D-Pad / gyro / voice car controllers
/// lock to landscape while active and restore portrait on exit. Only the
/// orientation payloads are centralised here — *when* each screen locks or
/// restores is intentional per screen (see e.g. `dpad_screen` initState /
/// didPopNext / dispose), so those call sites keep their own timing.
Future<void> lockLandscape() => SystemChrome.setPreferredOrientations(
      const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );

Future<void> lockPortrait() => SystemChrome.setPreferredOrientations(
      const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    );
