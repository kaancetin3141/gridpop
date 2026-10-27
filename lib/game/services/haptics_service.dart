import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';

/// Thin wrapper around the platform haptic channels.
///
/// Uses `HapticFeedback` only, so there is no plugin dependency and it works on
/// Android, iOS and Web (Web degrades to `selectionClick` where supported).
class HapticsService {
  HapticsService({this.enabled = true});

  bool enabled;

  Future<void> setEnabled(bool value) async {
    enabled = value;
  }

  /// Feedback for picking a piece up.
  Future<void> pickup() => trigger(HapticKind.selection);

  /// Feedback for locking a piece into the grid.
  Future<void> place() => trigger(HapticKind.light);

  /// Feedback for clearing lines.
  Future<void> clear({int lines = 1}) {
    if (lines >= 3) {
      return trigger(HapticKind.success);
    }
    return trigger(HapticKind.medium);
  }

  /// Feedback for a combo level up.
  Future<void> combo() => trigger(HapticKind.heavy);

  /// Feedback for a new record.
  Future<void> record() => trigger(HapticKind.success);

  /// Feedback for invalid input.
  Future<void> warning() => trigger(HapticKind.warning);

  /// Feedback for UI taps.
  Future<void> button() => trigger(HapticKind.selection);

  /// Game over buzz.
  Future<void> gameOver() => trigger(HapticKind.heavy);

  /// Maps [kind] onto a platform channel. Errors are swallowed on purpose:
  /// haptics are decoration, never a failure path.
  Future<void> trigger(HapticKind kind) async {
    if (!enabled) {
      return;
    }
    try {
      switch (kind) {
        case HapticKind.selection:
          await HapticFeedback.selectionClick();
        case HapticKind.light:
          await HapticFeedback.lightImpact();
        case HapticKind.medium:
          await HapticFeedback.mediumImpact();
        case HapticKind.heavy:
          await HapticFeedback.heavyImpact();
        case HapticKind.success:
          await HapticFeedback.vibrate();
        case HapticKind.warning:
          await HapticFeedback.mediumImpact();
      }
    } catch (_) {
      // Platform without haptics (web/desktop) - ignore.
    }
  }
}