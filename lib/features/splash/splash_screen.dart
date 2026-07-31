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
    _controller = VideoPlayerController.asset('assests/Splash/kidzee_animation.mp4')
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
      } else if (_controller.value.isInitialized) {
        final position = _controller.value.position;
        final duration = _controller.value.duration;
        
        // Ensure video actually started playing before checking for completion
        if (duration > Duration.zero && position.inMilliseconds > 500) {
          if (!_controller.value.isPlaying && position >= duration) {
            // Once the video finishes playing entirely, navigate to the next screen.
            _navigate();
          }
        }
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
      body: _controller.value.isInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
