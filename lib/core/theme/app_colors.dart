import 'package:flutter/material.dart';

/// GridPop brand colours.
///
/// Identity: "Aurora Pop" - a deep indigo stage lit by candy coloured blocks.
class AppColors {
  const AppColors._();

  // Block palette shortcuts (mirrors `PiecePalette` base colours) ----------
  static const Color sky = Color(0xFF3FBDF5);
  static const Color mint = Color(0xFF2FD6A8);
  static const Color sunbeam = Color(0xFFFFD34E);
  static const Color tangerine = Color(0xFFFF9A3C);
  static const Color grape = Color(0xFF8B6BF5);
  static const Color bubblegum = Color(0xFFFF6FBE);
  static const Color lime = Color(0xFF7ED957);

  // Brand core -----------------------------------------------------------
  static const Color indigo = Color(0xFF4B3FD6);
  static const Color violet = Color(0xFF7A3FF0);
  static const Color magenta = Color(0xFFE64FA6);
  static const Color coral = Color(0xFFFF6B6B);
  static const Color amber = Color(0xFFFFB020);

  /// Background gradient stops (used on every screen shell).
  static const List<Color> auroraGradient = <Color>[
    Color(0xFF3B2FB8),
    Color(0xFF6B3BEF),
    Color(0xFF9B3FE0),
  ];

  static const List<Color> auroraGradientSoft = <Color>[
    Color(0xFFEDE9FF),
    Color(0xFFF6ECFF),
    Color(0xFFEFF6FF),
  ];

  static const List<Color> auroraGradientDark = <Color>[
    Color(0xFF171233),
    Color(0xFF1F1745),
    Color(0xFF241A55),
  ];

  // Light surfaces -------------------------------------------------------
  static const Color lightBackground = Color(0xFFF6F3FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEFEAFF);

  /// The board is a deep stage in every theme, so the colourful blocks pop
  /// like toys on a dark table instead of fading into a pale grid.
  static const Color lightBoard = Color(0xFF171240);
  static const Color lightCell = Color(0xFF221C52);
  static const Color lightOutline = Color(0xFFE2DAF8);
  static const Color lightText = Color(0xFF1D1745);
  static const Color lightTextMuted = Color(0xFF6B6390);

  // Dark surfaces --------------------------------------------------------
  static const Color darkBackground = Color(0xFF120F28);
  static const Color darkSurface = Color(0xFF1D1846);
  static const Color darkSurfaceAlt = Color(0xFF272060);
  static const Color darkBoard = Color(0xFF171240);
  static const Color darkCell = Color(0xFF221C52);
  static const Color darkOutline = Color(0xFF362C7A);
  static const Color darkText = Color(0xFFF4F1FF);
  static const Color darkTextMuted = Color(0xFFA69ED6);

  // Semantic -------------------------------------------------------------
  static const Color success = Color(0xFF2FCB8C);
  static const Color danger = Color(0xFFFF5C7A);
  static const Color warning = Color(0xFFFFA23A);
  static const Color gold = Color(0xFFFFCE3D);
  static const Color starActive = Color(0xFFFFC531);
  static const Color starIdle = Color(0x33FFFFFF);
}

/// Colour roles resolved from the active [ThemeData].
class AppPalette {
  const AppPalette({
    required this.background,
    required this.backgroundGradient,
    required this.surface,
    required this.surfaceAlt,
    required this.board,
    required this.cell,
    required this.outline,
    required this.text,
    required this.textMuted,
    required this.isDark,
  });

  /// Builds the palette for [context].
  factory AppPalette.of(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const AppPalette(
        background: AppColors.darkBackground,
        backgroundGradient: AppColors.auroraGradientDark,
        surface: AppColors.darkSurface,
        surfaceAlt: AppColors.darkSurfaceAlt,
        board: AppColors.darkBoard,
        cell: AppColors.darkCell,
        outline: AppColors.darkOutline,
        text: AppColors.darkText,
        textMuted: AppColors.darkTextMuted,
        isDark: true,
      );
    }
    return const AppPalette(
      background: AppColors.lightBackground,
      backgroundGradient: AppColors.auroraGradientSoft,
      surface: AppColors.lightSurface,
      surfaceAlt: AppColors.lightSurfaceAlt,
      board: AppColors.lightBoard,
      cell: AppColors.lightCell,
      outline: AppColors.lightOutline,
      text: AppColors.lightText,
      textMuted: AppColors.lightTextMuted,
      isDark: false,
    );
  }

  final Color background;
  final List<Color> backgroundGradient;
  final Color surface;
  final Color surfaceAlt;
  final Color board;
  final Color cell;
  final Color outline;
  final Color text;
  final Color textMuted;
  final bool isDark;
}