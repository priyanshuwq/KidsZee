import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/controller_mode_provider.dart';

enum HapticStrength { light, medium, heavy, selection }

extension HapticRef on WidgetRef {
  /// Fire a haptic pulse — but only when the user has haptics enabled
  /// (see [hapticFeedbackProvider]). Centralises the guard that was repeated
  /// across every controller screen.
  void hapticFeedback(HapticStrength strength) {
    if (!read(hapticFeedbackProvider)) return;
    switch (strength) {
      case HapticStrength.light:
        HapticFeedback.lightImpact();
      case HapticStrength.medium:
        HapticFeedback.mediumImpact();
      case HapticStrength.heavy:
        HapticFeedback.heavyImpact();
      case HapticStrength.selection:
        HapticFeedback.selectionClick();
    }
  }
}
