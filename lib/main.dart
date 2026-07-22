import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/utils/orientation.dart';
import 'core/models/arm_pose.dart';
import 'core/models/sequence_macro.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Hive init ────────────────────────────────────────────────────────────────
  await Hive.initFlutter();
  Hive.registerAdapter(ArmPoseAdapter());
  Hive.registerAdapter(SequenceMacroAdapter());

  // ── Force light mode system UI ───────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ── Force portrait mode globally ─────────────────────────────────────────────
  await lockPortrait();

  runApp(const ProviderScope(child: KidsZeeApp()));
}

class KidsZeeApp extends StatelessWidget {
  const KidsZeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KidsZee',
      debugShowCheckedModeBanner: false,

      // ── Force light mode — KidsZee is light-only ─────────────────────────────
      themeMode: ThemeMode.light,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.orange,
          brightness: Brightness.light,
          surface: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.quicksandTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: AppColors.navy),
        ),
        dividerColor: AppColors.divider,
        extensions: const [],
      ),

      routerConfig: appRouter,
    );
  }
}
