import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/doodle_background.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/providers/controller_mode_provider.dart';
import '../../core/providers/last_device_provider.dart';
import '../../core/providers/preset_provider.dart';
import 'package:url_launcher/url_launcher.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final sensitivity = ref.watch(gyroSensitivityProvider);
    final deadzone = ref.watch(gyroDeadzoneProvider);
    final autoReconnect = ref.watch(autoReconnectProvider);
    final protocol = ref.watch(defaultProtocolProvider);
    final hapticFeedback = ref.watch(hapticFeedbackProvider);
    final buttonSize = ref.watch(buttonSizeProvider);
    final lastDevice = ref.watch(lastDeviceProvider);
    final presetCount = ref.watch(presetProvider).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DoodleBackground(
        child: SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Settings', style: AppTypography.headline2()),
            ),
          ),
          // Scrollable content
          Expanded(child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              _SectionHeader(label: 'Connection'),
              _ToggleTile(label: 'Auto-Reconnect', subtitle: 'Reconnect when signal drops', value: autoReconnect, onChanged: (v) => ref.read(autoReconnectProvider.notifier).state = v),
              const SizedBox(height: 10),
            _DropdownTile(label: 'Default Protocol', value: const ['BT Classic', 'BLE'].contains(protocol) ? protocol : 'BT Classic', options: const ['BT Classic', 'BLE'], onChanged: (v) => ref.read(defaultProtocolProvider.notifier).state = v!),
            const SizedBox(height: 10),
            _ActionTile(label: 'Last Connected Device',
              subtitle: lastDevice.isEmpty ? 'None saved' : (lastDevice.name.isEmpty ? lastDevice.address : lastDevice.name),
              actionLabel: 'Forget', enabled: !lastDevice.isEmpty,
              onTap: () => ref.read(lastDeviceProvider.notifier).forget()),
            const SizedBox(height: 20),
            _SectionHeader(label: 'Controls'),
            _ToggleTile(label: 'Haptic Feedback', subtitle: 'Vibrate on button press', value: hapticFeedback, onChanged: (v) => ref.read(hapticFeedbackProvider.notifier).state = v),
            const SizedBox(height: 10),
            _DropdownTile(label: 'Button Size', value: buttonSize, options: const ['Small', 'Medium', 'Large'], onChanged: (v) => ref.read(buttonSizeProvider.notifier).state = v!),
            const SizedBox(height: 20),
            _SectionHeader(label: 'Sensors'),
            _SliderTile(label: 'Gyro Sensitivity', value: sensitivity, min: 0.5, max: 2.0, onChanged: (v) => ref.read(gyroSensitivityProvider.notifier).state = v),
            const SizedBox(height: 10),
            _SliderTile(label: 'Gyro Deadzone', value: deadzone, min: 0.05, max: 0.4, onChanged: (v) => ref.read(gyroDeadzoneProvider.notifier).state = v),
            const SizedBox(height: 20),
            _SectionHeader(label: 'Data'),
            _ActionTile(label: 'Saved Poses', subtitle: '$presetCount saved',
              actionLabel: 'Clear All', enabled: presetCount > 0,
              onTap: () async {
                final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  title: const Text('Clear all presets?'),
                  content: const Text('This removes every saved arm pose. This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                  ]));
                if (ok == true) ref.read(presetProvider.notifier).clearAll();
              }),
            const SizedBox(height: 20),
            _SectionHeader(label: 'About'),
            _AboutCard(),
          ].animate(interval: 40.ms).fadeIn().slideY(begin: 0.05, end: 0))),
          // Bottom nav
          const AppBottomNav(activeTab: NavTab.settings),
        ]))),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(label, style: AppTypography.headline3().copyWith(fontSize: 13, color: AppColors.orange, letterSpacing: 1.2)),
  );
}

class _Tile extends StatelessWidget {
  final Widget child;
  const _Tile({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: AppColors.cardWhite, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border, width: 1),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), offset: const Offset(0, 2), blurRadius: 8)],
    ),
    child: child,
  );
}

class _ToggleTile extends StatelessWidget {
  final String label, subtitle; final bool value; final ValueChanged<bool> onChanged;
  const _ToggleTile({required this.label, required this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => _Tile(child: Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTypography.body().copyWith(fontWeight: FontWeight.w700)),
      Text(subtitle, style: AppTypography.statusText()),
    ])),
    Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.orange),
  ]));
}

class _DropdownTile extends StatelessWidget {
  final String label, value; final List<String> options; final ValueChanged<String?> onChanged;
  const _DropdownTile({required this.label, required this.value, required this.options, required this.onChanged});
  @override
  Widget build(BuildContext context) => _Tile(child: Row(children: [
    Expanded(child: Text(label, style: AppTypography.body().copyWith(fontWeight: FontWeight.w700))),
    DropdownButton<String>(
      value: value, underline: const SizedBox(), style: AppTypography.body(),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: onChanged,
    ),
  ]));
}

class _ActionTile extends StatelessWidget {
  final String label, subtitle, actionLabel; final bool enabled; final VoidCallback onTap;
  const _ActionTile({required this.label, required this.subtitle, required this.actionLabel, required this.enabled, required this.onTap});
  @override
  Widget build(BuildContext context) => _Tile(child: Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTypography.body().copyWith(fontWeight: FontWeight.w700)),
      Text(subtitle, style: AppTypography.statusText()),
    ])),
    TextButton(onPressed: enabled ? onTap : null,
      child: Text(actionLabel, style: AppTypography.buttonText().copyWith(
        color: enabled ? AppColors.stopRed : AppColors.lightGray, fontSize: 13))),
  ]));
}

class _SliderTile extends StatelessWidget {
  final String label; final double value, min, max; final ValueChanged<double> onChanged;
  const _SliderTile({required this.label, required this.value, required this.min, required this.max, required this.onChanged});
  @override
  Widget build(BuildContext context) => _Tile(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Text(label, style: AppTypography.body().copyWith(fontWeight: FontWeight.w700)),
      const Spacer(),
      Text(value.toStringAsFixed(2), style: AppTypography.mono(size: 13, color: AppColors.orange)),
    ]),
    Slider(value: value, min: min, max: max, onChanged: onChanged, activeColor: AppColors.orange, inactiveColor: AppColors.lightGray),
  ]));
}

class _AboutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _Tile(child: Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('KidsZee', style: AppTypography.headline3()),
      Text('RC Robot Controller v1.0.0', style: AppTypography.statusText()),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: () => launchUrl(Uri.parse('https://kidszee.toys')),
        child: Text('kidszee.toys', style: AppTypography.statusText().copyWith(color: AppColors.orange, decoration: TextDecoration.underline)),
      ),
    ])),
    Container(width: 56, height: 56,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.orangeLight),
      child: const Icon(Icons.precision_manufacturing, color: AppColors.orange, size: 30)),
  ]));
}
