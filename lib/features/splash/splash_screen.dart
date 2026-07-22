import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assests/Splash/animaton1.mp4')
      ..initialize().then((_) {
        _controller.setVolume(0.0); // Mute to ensure playback
        setState(() {});
        _controller.play();
      }).catchError((e) {
        debugPrint('Video init error: $e');
        _navigate(); // Skip if video fails
      });

    _controller.addListener(() {
      if (_controller.value.hasError) {
        _navigate(); // Skip on playback error
      } else if (_controller.value.isInitialized &&
          !_controller.value.isPlaying &&
          _controller.value.position >= _controller.value.duration) {
        _navigate();
      }
    });

    // Fallback just in case video gets permanently stuck (10s)
    Future.delayed(const Duration(seconds: 10), () {
      _navigate();
    });
  }

  void _navigate() async {
    if (_navigating || !mounted) return;
    _navigating = true;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_onboarding') ?? false;
    if (mounted) {
      if (!seen) {
        context.go('/onboarding');
      } else {
        context.go('/dashboard');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_controller.value.isInitialized)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                )
              else
                const CircularProgressIndicator(color: AppColors.orange),
              const SizedBox(height: 32),
              Text('Connecting to your imagination...',
                      style: AppTypography.statusText())
                  .animate(delay: 1000.ms)
                  .fadeIn(),
            ],
          ),
        ),
      ),
    );
  }
}
