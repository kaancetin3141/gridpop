import 'package:flutter/widgets.dart';

/// Responsive breakpoints used by every screen.
enum ScreenClass {
  /// Phone portrait and phone landscape (width < 640).
  compact,

  /// Large phone landscape / small tablet (640 - 1023).
  medium,

  /// Tablet and desktop (>= 1024).
  expanded;

  bool get isCompact => this == ScreenClass.compact;
  bool get isExpanded => this == ScreenClass.expanded;
}

/// Width/height thresholds (logical pixels).
class Breakpoints {
  const Breakpoints._();

  static const double medium = 640;
  static const double expanded = 1024;

  /// Below this height the vertical layout gets tight.
  static const double shortHeight = 560;
}

/// Small helpers so widgets do not have to repeat breakpoint maths.
class Responsive {
  const Responsive._();

  static ScreenClass classify(Size size) {
    if (size.width >= Breakpoints.expanded) {
      return ScreenClass.expanded;
    }
    if (size.width >= Breakpoints.medium) {
      return ScreenClass.medium;
    }
    return ScreenClass.compact;
  }

  static ScreenClass of(BuildContext context) =>
      classify(MediaQuery.sizeOf(context));

  static bool isCompact(BuildContext context) => of(context).isCompact;

  static bool isExpanded(BuildContext context) => of(context).isExpanded;

  static bool isShort(BuildContext context) =>
      MediaQuery.sizeOf(context).height < Breakpoints.shortHeight;

  /// Page padding that grows with the viewport.
  static EdgeInsets pagePadding(BuildContext context) {
    switch (of(context)) {
      case ScreenClass.expanded:
        return const EdgeInsets.symmetric(horizontal: 40, vertical: 24);
      case ScreenClass.medium:
        return const EdgeInsets.symmetric(horizontal: 28, vertical: 20);
      case ScreenClass.compact:
        return const EdgeInsets.symmetric(horizontal: 18, vertical: 16);
    }
  }

  /// Maximum width of a readable content column (menus, settings, dialogs).
  static double contentMaxWidth(BuildContext context) {
    switch (of(context)) {
      case ScreenClass.expanded:
        return 720;
      case ScreenClass.medium:
        return 560;
      case ScreenClass.compact:
        return double.infinity;
    }
  }

  /// Maximum edge length of the game board.
  static double boardMaxExtent(BuildContext context, Size available) {
    final double shortestSide =
        available.shortestSide < 520 ? available.shortestSide : 520;
    switch (of(context)) {
      case ScreenClass.expanded:
        return shortestSide * 0.92;
      case ScreenClass.medium:
        return shortestSide * 0.94;
      case ScreenClass.compact:
        return shortestSide;
    }
  }

  /// Height reserved for the piece tray.
  static double trayHeight(BuildContext context) {
    switch (of(context)) {
      case ScreenClass.expanded:
        return 168;
      case ScreenClass.medium:
        return 156;
      case ScreenClass.compact:
        return 150;
    }
  }
}