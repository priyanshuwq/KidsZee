import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/doodle_background.dart';


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DoodleBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 24.0, top: 16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    backgroundColor: AppColors.cardWhite,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    onTap: _finish,
                    child: Text('Skip', style: AppTypography.buttonText().copyWith(color: AppColors.navy)),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Card 1: 3D Model
                    _WalkthroughCard(
                      title: 'Welcome to KidsZee',
                      description: 'Meet Otto, your friendly DIY Robot! He is here to make robotics fun, easy, and completely interactive. Get ready to build, code, and play!',
                      visual: SizedBox(
                        height: 260,
                        child: ModelViewer(
                          src: 'assests/wombatics_otto_diy_robot.glb', // Local asset path
                          alt: 'A 3D model of an Otto Robot',
                          autoRotate: true,
                          cameraControls: true,
                          disableZoom: true,
                          backgroundColor: Colors.transparent,
                          innerModelViewerHtml: '<div slot="progress-bar"></div><div slot="poster"></div>',
                        ),
                      ),
                    ),
                    // Card 2: Mission
                    _WalkthroughCard(
                      title: 'Real Play, Real Learning',
                      description: 'At KidsZee, we believe play is the most powerful way children learn, explore, and grow. Our mission is to bring joy, creativity, and smart learning into every home.',
                      icon: Icons.extension_outlined,
                      color: AppColors.orange,
                    ),
                    // Card 3: Action
                    _WalkthroughCard(
                      title: 'Ready to Build?',
                      description: 'We champion Real Play, because we believe that great childhood memories shouldn\'t be made on a screen. Let\'s get moving and thinking!',
                      icon: Icons.rocket_launch_outlined,
                      color: AppColors.successGreen,
                    ),
                  ],
                ),
              ),
              // Bottom Controls
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(3, (i) => AnimatedContainer(
                        duration: 300.ms,
                        margin: const EdgeInsets.only(right: 8),
                        height: 10,
                        width: _currentPage == i ? 24 : 10,
                        decoration: BoxDecoration(
                          color: _currentPage == i ? AppColors.navy : AppColors.lightGray,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      )),
                    ),
                    AppButton(
                      backgroundColor: _currentPage == 2 ? AppColors.orange : AppColors.cardWhite,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      onTap: () {
                        if (_currentPage == 2) {
                          _finish();
                        } else {
                          _pageController.nextPage(duration: 300.ms, curve: Curves.easeOutCubic);
                        }
                      },
                      child: Text(
                        _currentPage == 2 ? 'Let\'s Go!' : 'Next',
                        style: AppTypography.headline3().copyWith(
                          color: _currentPage == 2 ? Colors.white : AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _WalkthroughCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget? visual;
  final IconData? icon;
  final Color? color;

  const _WalkthroughCard({
    required this.title,
    required this.description,
    this.visual,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), offset: const Offset(0, 4), blurRadius: 12)
          ],
        ),
        child: Center(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (visual != null)
                visual!
              else if (icon != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (color ?? AppColors.orange).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 80, color: color ?? AppColors.orange),
              ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 32),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headline1().copyWith(fontSize: 28),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 16),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTypography.body().copyWith(height: 1.5),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ), // Close SingleChildScrollView
      ), // Close ScrollConfiguration
      ), // Close Center
      ), // Close Container
    ); // Close Padding
  }
}
