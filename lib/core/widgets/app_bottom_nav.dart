import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

enum NavTab { home, devices, settings }

class AppBottomNav extends StatelessWidget {
  final NavTab activeTab;
  const AppBottomNav({super.key, required this.activeTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), offset: const Offset(0, 4), blurRadius: 14)],
      ),
      child: Row(children: [
        _NavItem(icon: Icons.home_filled, label: 'Home', active: activeTab == NavTab.home,
          onTap: () { if (activeTab != NavTab.home) context.go('/dashboard'); }),
        _NavItem(icon: Icons.bluetooth, label: 'Devices', active: activeTab == NavTab.devices,
          onTap: () { if (activeTab != NavTab.devices) context.go('/connect'); }),
        _NavItem(icon: Icons.settings_outlined, label: 'Settings', active: activeTab == NavTab.settings,
          onTap: () { if (activeTab != NavTab.settings) context.go('/settings'); }),
      ]),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon; final String label; final bool active; final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 24, color: active ? AppColors.orange : AppColors.textMuted),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? AppColors.orange : AppColors.textMuted)),
      ]),
    ),
  );
}
