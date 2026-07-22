import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/splash/onboarding_screen.dart';
import '../../features/connection/connection_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/controller/dpad_screen.dart';
import '../../features/controller/gyro_screen.dart';
import '../../features/controller/voice_screen.dart';

import '../../features/robotic_arm/arm_controller_screen.dart';
import '../../features/robotic_arm/sequence_screen.dart';
import '../../features/robots/otto_command.dart';
import '../../features/robots/spider_screen.dart';
import '../../features/settings/settings_screen.dart';
import 'route_observer.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  observers: [routeObserver],
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (ctx, state) => _fade(const SplashScreen()),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (ctx, state) => _fade(const OnboardingScreen()),
    ),
    GoRoute(
      path: '/connect',
      pageBuilder: (ctx, state) => _fade(const ConnectionScreen()),
    ),
    GoRoute(
      path: '/dashboard',
      pageBuilder: (ctx, state) => _fade(const DashboardScreen()),
    ),
    GoRoute(
      path: '/dpad',
      pageBuilder: (ctx, state) => _fade(const DpadScreen()),
    ),
    GoRoute(
      path: '/gyro',
      pageBuilder: (ctx, state) => _fade(const GyroScreen()),
    ),
    GoRoute(
      path: '/voice',
      pageBuilder: (ctx, state) => _fade(const VoiceScreen()),
    ),

    GoRoute(
      path: '/arm',
      pageBuilder: (ctx, state) => _fade(const ArmControllerScreen()),
    ),
    GoRoute(
      path: '/sequences',
      pageBuilder: (ctx, state) => _fade(const SequenceScreen()),
    ),
    GoRoute(
      path: '/otto',
      pageBuilder: (ctx, state) => _fade(const OttoScreen()),
    ),
    GoRoute(
      path: '/spider',
      pageBuilder: (ctx, state) => _fade(const SpiderScreen()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (ctx, state) => _fade(const SettingsScreen()),
    ),
  ],
);

CustomTransitionPage<void> _fade(Widget child) {
  return CustomTransitionPage(
    child: child,
    transitionDuration: const Duration(milliseconds: 150),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}
