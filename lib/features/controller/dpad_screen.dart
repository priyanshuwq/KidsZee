import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/doodle_background.dart';
import '../../core/providers/controller_mode_provider.dart';
import '../../core/network/smart_car_commands.dart';
import '../../core/router/route_observer.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/orientation.dart';

class DpadScreen extends ConsumerStatefulWidget {
  const DpadScreen({super.key});
  @override
  ConsumerState<DpadScreen> createState() => _DpadScreenState();
}

class _DpadScreenState extends ConsumerState<DpadScreen> with RouteAware {
  Timer? _cmdTimer;
  CarDirection? _activeCmd;
  late final FocusNode _focusNode;
  PageRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // Auto-launch in landscape — overrides system auto-rotate for this screen only.
    lockLandscape();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _focusNode.requestFocus(); });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _subscribedRoute) {
      if (_subscribedRoute != null) routeObserver.unsubscribe(this);
      routeObserver.subscribe(this, route);
      _subscribedRoute = route;
    }
  }

  @override
  void didPopNext() {
    // Gyro/Voice (pushed on top of us) was popped back here. Its own
    // dispose() no longer forces the app-wide portrait lock (see
    // gyro_screen.dart/voice_screen.dart), but re-assert landscape here too
    // as a defensive backstop so this screen never briefly renders its
    // landscape layout inside a portrait-sized viewport.
    lockLandscape();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    // Restore the app-wide portrait lock for every other screen.
    lockPortrait();
    _cmdTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCmd(CarDirection cmd) {
    if (_activeCmd == cmd) return;
    _activeCmd = cmd;
    _cmdTimer?.cancel();
    SmartCarCommands.send(cmd);
    _cmdTimer = Timer.periodic(const Duration(milliseconds: 50), (_) => SmartCarCommands.send(cmd));
    ref.hapticFeedback(HapticStrength.light);
    setState(() {});
  }

  void _stopCmd() {
    _cmdTimer?.cancel();
    _activeCmd = null;
    SmartCarCommands.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final kF = ref.watch(keybindForwardProvider).toUpperCase();
    final kB = ref.watch(keybindBackwardProvider).toUpperCase();
    final kL = ref.watch(keybindLeftProvider).toUpperCase();
    final kR = ref.watch(keybindRightProvider).toUpperCase();

    return KeyboardListener(
      focusNode: _focusNode, autofocus: true,
      onKeyEvent: (event) {
        final key = event.logicalKey.keyLabel.toUpperCase();
        if (event is KeyDownEvent) {
          if (key == kF) { _startCmd(CarDirection.forward); } else if (key == kB) { _startCmd(CarDirection.backward); }
          else if (key == kL) { _startCmd(CarDirection.left); } else if (key == kR) { _startCmd(CarDirection.right); }
        } else if (event is KeyUpEvent) {
          if ((key == kF && _activeCmd == CarDirection.forward) || (key == kB && _activeCmd == CarDirection.backward) ||
              (key == kL && _activeCmd == CarDirection.left) || (key == kR && _activeCmd == CarDirection.right)) {
            _stopCmd();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: DoodleBackground(
          child: SafeArea(
            child: Column(children: [
              _TopBar(onBack: () => Navigator.of(context).maybePop()),
              Expanded(child: _buildLandscape()),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildLandscape() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: LayoutBuilder(builder: (context, constraints) {
        // Panels are square-ish, sized to fit the available landscape height,
        // leaving comfortable room for the center column between them.
        final panelSize = (constraints.maxHeight).clamp(180.0, 260.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TwoZonePanel(
              size: panelSize,
              axis: Axis.vertical,
              zoneA: _ZoneSpec(icon: Icons.keyboard_arrow_up, label: 'FWD', cmd: CarDirection.forward),
              zoneB: _ZoneSpec(icon: Icons.keyboard_arrow_down, label: 'BACK', cmd: CarDirection.backward),
              activeCmd: _activeCmd,
              onStart: _startCmd,
              onStop: _stopCmd,
            ),
            SizedBox(
              width: 168,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _NavShortcut(icon: Icons.explore, label: 'Gyro', onTap: () => context.push('/gyro')),
                  const SizedBox(width: 12),
                  _NavShortcut(icon: Icons.record_voice_over, label: 'Voice', onTap: () => context.push('/voice')),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: 160,
                  child: AppButton(backgroundColor: AppColors.stopRed, onTap: () { _stopCmd(); ref.hapticFeedback(HapticStrength.heavy); },
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.stop_circle_outlined, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text('STOP', style: AppTypography.headline3().copyWith(color: Colors.white, fontSize: 18)),
                    ]))),
                ),
              ]),
            ),
            _TwoZonePanel(
              size: panelSize,
              axis: Axis.horizontal,
              zoneA: _ZoneSpec(icon: Icons.keyboard_arrow_left, label: 'LEFT', cmd: CarDirection.left),
              zoneB: _ZoneSpec(icon: Icons.keyboard_arrow_right, label: 'RIGHT', cmd: CarDirection.right),
              activeCmd: _activeCmd,
              onStart: _startCmd,
              onStop: _stopCmd,
            ),
          ],
        );
      }),
    );
  }
}

// ── Components ──────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(children: [
      GestureDetector(onTap: onBack, child: Container(width: 40, height: 40,
        decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: const Icon(Icons.arrow_back_ios_new, color: AppColors.navy, size: 18))),
      const SizedBox(width: 16),
      Text('D-Pad Controller', style: AppTypography.headline3().copyWith(fontSize: 18)),
    ]));
}

/// Describes one half of a [_TwoZonePanel] — icon, label, and which
/// [CarDirection] it drives.
class _ZoneSpec {
  final IconData icon;
  final String label;
  final CarDirection cmd;
  const _ZoneSpec({required this.icon, required this.label, required this.cmd});
}

/// One square soft-shadow "kids UI" panel split into two independently
/// pressable zones — either stacked (Forward/Back) or side-by-side
/// (Left/Right), separated by a thin divider. Matches the app's current
/// rounded, soft-shadow design language (see [AppButton]) — no hard-edge
/// neo-brutalist shadows.
class _TwoZonePanel extends StatelessWidget {
  final double size;
  final Axis axis;
  final _ZoneSpec zoneA, zoneB;
  final CarDirection? activeCmd;
  final void Function(CarDirection) onStart;
  final VoidCallback onStop;

  const _TwoZonePanel({
    required this.size,
    required this.axis,
    required this.zoneA,
    required this.zoneB,
    required this.activeCmd,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final children = [
      Expanded(child: _Zone(spec: zoneA, active: activeCmd == zoneA.cmd, onStart: onStart, onStop: onStop, first: true, axis: axis)),
      Container(
        width: axis == Axis.horizontal ? 2 : null,
        height: axis == Axis.vertical ? 2 : null,
        color: AppColors.border,
      ),
      Expanded(child: _Zone(spec: zoneB, active: activeCmd == zoneB.cmd, onStart: onStart, onStop: onStop, first: false, axis: axis)),
    ];

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), offset: const Offset(0, 6), blurRadius: 16),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: axis == Axis.vertical
            ? Column(children: children)
            : Row(children: children),
      ),
    );
  }
}

class _Zone extends StatelessWidget {
  final _ZoneSpec spec;
  final bool active;
  final void Function(CarDirection) onStart;
  final VoidCallback onStop;
  final bool first;
  final Axis axis;

  const _Zone({
    required this.spec,
    required this.active,
    required this.onStart,
    required this.onStop,
    required this.first,
    required this.axis,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: axis == Axis.vertical && first ? const Radius.circular(28) : Radius.zero,
      bottom: axis == Axis.vertical && !first ? const Radius.circular(28) : Radius.zero,
    );
    return GestureDetector(
      onTapDown: (_) => onStart(spec.cmd),
      onTapUp: (_) => onStop(),
      onTapCancel: onStop,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: active ? AppColors.orange : AppColors.cardWhite,
          borderRadius: axis == Axis.vertical ? radius : null,
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(spec.icon, size: 40, color: active ? Colors.white : AppColors.navy),
            const SizedBox(height: 4),
            Text(spec.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0,
              color: active ? Colors.white : AppColors.textMuted)),
          ]),
        ),
      ),
    );
  }
}

class _NavShortcut extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _NavShortcut({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => AppButton(backgroundColor: AppColors.cardWhite, onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    child: Column(children: [
      Icon(icon, color: AppColors.navy, size: 26), const SizedBox(height: 6),
      Text(label, style: AppTypography.label().copyWith(fontSize: 12)),
    ]));
}
