import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/haptics.dart';

/// KidsZeeButton — Clean, minimal button matching kidszee.toys design.
/// Subtle scale-down on press with soft shadow. No thick borders or hard shadows.
/// Exposes [onPressStart] and [onPressEnd] for D-Pad continuous motor commands.
class AppButton extends ConsumerStatefulWidget {
  /// For navigation buttons — fires on release
  final VoidCallback? onTap;

  /// For D-Pad buttons — fires on TapDown; start a Timer.periodic to send commands
  final VoidCallback? onPressStart;

  /// For D-Pad buttons — fires on TapUp/Cancel; cancel the timer, send STOP
  final VoidCallback? onPressEnd;

  final Widget child;
  final Color backgroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool haptic;

  const AppButton({
    super.key,
    this.onTap,
    this.onPressStart,
    this.onPressEnd,
    required this.child,
    this.backgroundColor = AppColors.orange,
    this.borderRadius = 16.0,
    this.padding,
    this.haptic = true,
  });

  bool get _isEnabled => onTap != null || onPressStart != null;

  @override
  ConsumerState<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends ConsumerState<AppButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (!widget._isEnabled) return;
    setState(() => _isPressed = true);
    if (widget.haptic) ref.hapticFeedback(HapticStrength.light);
    widget.onPressStart?.call();
  }

  void _handleTapUp(TapUpDetails _) {
    if (!widget._isEnabled) return;
    setState(() => _isPressed = false);
    widget.onPressEnd?.call();
  }

  void _handleTapCancel() {
    if (!widget._isEnabled) return;
    setState(() => _isPressed = false);
    widget.onPressEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget._isEnabled;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        transform: Matrix4.diagonal3Values(
          _isPressed ? 0.97 : 1.0, _isPressed ? 0.97 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: !enabled
              ? AppColors.lightGray
              : _isPressed
                  ? widget.backgroundColor.withValues(alpha: 0.85)
                  : widget.backgroundColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isPressed ? 0.02 : 0.08),
              offset: Offset(0, _isPressed ? 2 : 6),
              blurRadius: _isPressed ? 4 : 16,
            ),
          ],
        ),
        child: Padding(
          padding: widget.padding ??
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Compact icon-only variant for D-Pad directional buttons
class AppIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;
  final Color backgroundColor;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.onPressStart,
    this.onPressEnd,
    this.backgroundColor = AppColors.dpadIdle,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: AppButton(
        onTap: onTap,
        onPressStart: onPressStart,
        onPressEnd: onPressEnd,
        backgroundColor: backgroundColor,
        borderRadius: 20,
        padding: EdgeInsets.zero,
        child: Center(child: icon),
      ),
    );
  }
}
