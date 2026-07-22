import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/doodle_background.dart';
import '../../core/widgets/mode_doodle_icons.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/providers/connection_provider.dart';
import '../../core/providers/controller_mode_provider.dart';
import '../../core/widgets/mode_intro_dialog.dart';
import './widgets/product_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(connectionProvider);

    final modes = [
      _ModeItem(label: 'Smart Car\nControl', mode: ControlMode.rcCar, route: '/dpad', color: AppColors.orange,
        subtitle: 'D-Pad • Gyro • Voice'),
      _ModeItem(label: 'Roboic\nArm', mode: ControlMode.robotArm, route: '/arm', color: AppColors.terracotta,
        subtitle: '6-axis servo arm'),
      _ModeItem(label: 'Otto Robot', mode: ControlMode.ottoRobot, route: '/otto', color: AppColors.brandBlue,
        subtitle: '6 servos • Biped walker'),
      _ModeItem(label: 'Spider\nRobot', mode: ControlMode.spiderRobot, route: '/spider', color: AppColors.spiderGreen,
        subtitle: '8-12 servos • Quadruped'),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DoodleBackground(
        child: SafeArea(
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Image.asset(
                      'assests/kidszee_transparent.png',
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(width: 8, height: 8,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          color: conn.isConnected ? AppColors.successGreen : AppColors.lightGray)),
                      const SizedBox(width: 6),
                      Text(conn.isConnected ? conn.deviceName ?? 'Connected' : 'Not Connected',
                        style: AppTypography.statusText().copyWith(
                          color: conn.isConnected ? AppColors.successGreen : AppColors.textMuted)),
                    ]),
                  ]),
                ),
                IconButton(tooltip: 'Welcome Info',
                  icon: const Icon(Icons.info_outline, color: AppColors.navy, size: 26),
                  onPressed: () => context.push('/onboarding')),
              ]),
            ),
            const SizedBox(height: 20),
            // Scrollable Content Area
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: modes.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.95),
                        itemBuilder: (ctx, i) {
                          final m = modes[i];
                          return _ModeCard(item: m, onTap: () async {
                            ref.read(controllerModeProvider.notifier).state = m.mode;
                            await showModeIntroIfNeeded(context, m.mode);
                            if (context.mounted) context.push(m.route);
                          }).animate().fadeIn(delay: (i * 80).ms).scale(
                            begin: const Offset(0.9, 0.9), end: const Offset(1, 1),
                            duration: 400.ms, curve: Curves.easeOutBack);
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Discover Kits Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text('More to Explore', style: AppTypography.headline1().copyWith(fontSize: 20)),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: const [
                          ProductCard(
                            title: 'DIY Mechanical Robotic Arm Learning Kit',
                            price: '₹849',
                            imageUrl: 'https://kidszee.toys/cdn/shop/files/ChatGPT_Image_May_6_2026_03_58_42_PM.png?v=1778065626',
                            productUrl: 'https://kidszee.toys/products/robotic-arm-diy-kit',
                          ),
                          ProductCard(
                            title: 'Quadruped Spider Robot',
                            price: '₹697',
                            imageUrl: 'https://cdn.shopify.com/s/files/1/0798/1786/7476/files/k81.jpg?v=1776235526',
                            productUrl: 'https://kidszee.toys/products/quadruped-spider-4-legged-walking-robot',
                          ),
                          ProductCard(
                            title: 'DIY Drone Building Kit',
                            price: '₹2,599',
                            imageUrl: 'https://cdn.shopify.com/s/files/1/0798/1786/7476/files/ChatGPT_Image_May_6_2026_03_56_20_PM.png?v=1778065627',
                            productUrl: 'https://kidszee.toys/products/robocraze-diy-drone-kit-with-manual-camera-not-included',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Bottom nav — rounded
            const AppBottomNav(activeTab: NavTab.home),
          ]),
        ),
      ),
    );
  }
}

class _ModeItem {
  final String label, route, subtitle;
  final ControlMode mode;
  final Color color;
  const _ModeItem({required this.label, required this.route, required this.mode, required this.color, required this.subtitle});
}

// Highlights the card border/shadow only while actively pressed/touched —
// no persistent "selected" state is kept once the finger lifts.
class _ModeCard extends StatefulWidget {
  final _ModeItem item;
  final VoidCallback onTap;
  const _ModeCard({required this.item, required this.onTap});

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: (_pressed ? item.color : Colors.black).withValues(alpha: _pressed ? 0.18 : 0.06),
          offset: const Offset(0, 2), blurRadius: 10)],
      ),
      child: Material(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: _setPressed,
          borderRadius: BorderRadius.circular(18),
          splashColor: item.color.withValues(alpha: 0.3),
          highlightColor: item.color.withValues(alpha: 0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _pressed ? item.color : AppColors.border, width: _pressed ? 2.0 : 1.0),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                ModeDoodleIcon(mode: item.mode, accentColor: item.color, size: 72),
                const SizedBox(height: 8),
                Text(item.label, style: AppTypography.headline3().copyWith(fontSize: 14, height: 1.3)),
                const SizedBox(height: 3),
                Text(item.subtitle, style: AppTypography.statusText().copyWith(fontSize: 11, color: AppColors.textMuted)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

