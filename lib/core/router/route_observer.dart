import 'package:flutter/widgets.dart';

/// App-wide [RouteObserver] registered on the [GoRouter]'s `observers`.
///
/// Used by the landscape-locked Smart Car controller screens (D-Pad, Gyro,
/// Voice) so a screen can react via [RouteAware.didPopNext] when it becomes
/// visible again after a screen pushed on top of it (e.g. D-Pad → Gyro) is
/// popped off. Without this, the popped screen's own `dispose()` restoring
/// the app-wide portrait lock can race with — and stomp on — the still-open
/// landscape screen underneath, causing a brief portrait-layout overflow
/// right after pressing back.
final routeObserver = RouteObserver<PageRoute<dynamic>>();
