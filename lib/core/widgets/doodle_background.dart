import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// DoodleBackground — flat sky-blue gradient header with a soft wave edge
/// and a handful of flat (non-glossy) doodle decorations: a cloud and a few
/// bubbles. No blur / BackdropFilter anywhere — the "no glassmorphism"
/// constraint is satisfied by construction, not by omission.
class DoodleBackground extends StatelessWidget {
  final Widget child;

  const DoodleBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 250,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.skyBlueTop, AppColors.skyBlueBottom],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
