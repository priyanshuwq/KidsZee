
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:kidszee/main.dart';
import 'mock_video_player.dart';

void main() {
  testWidgets('KidsZeeApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'seen_onboarding': true});
    VideoPlayerPlatform.instance = MockVideoPlayerPlatform();

    // Wrap in ProviderScope (required for Riverpod providers)
    await tester.pumpWidget(const ProviderScope(child: KidsZeeApp()));

    // Pump first frame — app builds
    await tester.pump();
    expect(find.byType(KidsZeeApp), findsOneWidget);

    // Advance past ALL splash screen pending timers:
    // Splash screen has a 4-second Future.delayed fallback timer.
    await tester.pump(const Duration(seconds: 5));

    // Pump and settle to finish all animations (flutter_animate, page transitions, etc)
    await tester.pumpAndSettle();
  });
}
