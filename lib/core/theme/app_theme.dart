import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Corner radii used across the app.
class AppRadius {
  const AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;
}

/// Spacing scale (8pt grid).
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;
}

/// Soft, low contrast shadows that match the premium look.
class AppShadows {
  const AppShadows._();

  static List<BoxShadow> soft(Color tint, {double strength = 1}) => <BoxShadow>[
        BoxShadow(
          color: tint.withOpacity(0.10 * strength),
          blurRadius: 18 * strength,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: tint.withOpacity(0.06 * strength),
          blurRadius: 4 * strength,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> lift(Color tint, {double strength = 1}) =>
      <BoxShadow>[
        BoxShadow(
          color: tint.withOpacity(0.28 * strength),
          blurRadius: 22 * strength,
          offset: const Offset(0, 12),
        ),
      ];
}

/// Builds the light and dark themes for GridPop.
class AppTheme {
  const AppTheme._();

  static const String fontFamily = 'Roboto';

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.indigo,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppColors.violet : AppColors.indigo,
      secondary: AppColors.magenta,
      tertiary: AppColors.coral,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: isDark ? AppColors.darkText : AppColors.lightText,
      error: AppColors.danger,
    );

    final TextTheme text = _textTheme(isDark ? AppColors.darkText : AppColors.lightText);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      fontFamily: fontFamily,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      dividerColor: Colors.transparent,
      iconTheme: IconThemeData(
        color: isDark ? AppColors.darkText : AppColors.lightText,
        size: 22,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: isDark ? AppColors.darkText : AppColors.lightText,
        titleTextStyle: text.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkSurfaceAlt : AppColors.lightText,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? AppColors.mint
              : (isDark ? AppColors.darkCell : AppColors.lightCell),
        ),
        trackOutlineColor: WidgetStateProperty.all<Color>(Colors.transparent),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightText,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: text.bodySmall?.copyWith(color: Colors.white),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(Color color) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 56,
        height: 1.0,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        color: color,
      ),
      displayMedium: TextStyle(
        fontSize: 42,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        color: color,
      ),
      displaySmall: TextStyle(
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: color,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: color,
      ),
      headlineSmall: TextStyle(
        fontSize: 21,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.4, color: color),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: color),
      bodySmall: TextStyle(
        fontSize: 12.5,
        height: 1.4,
        color: color.withOpacity(0.7),
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: color,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: color,
      ),
      labelSmall: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: color.withOpacity(0.6),
      ),
    );
  }
}