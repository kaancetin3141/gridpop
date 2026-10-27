import 'package:flutter/material.dart';

/// The visual families GridPop can be played in.
///
/// A style is more than a colour swap: it changes the stage gradient, the board
/// well, the socket shape and — through [BlockStyle] — how a block is drawn.
/// The default is [aurora], the "Aurora Pop" identity of the game.
enum VisualStyle {
  /// Candy coloured soft-3D blocks on an indigo aurora stage (the original).
  aurora,

  /// Dark arcade cabinet: flat glowing tiles, electric rims, grid floor.
  neon,

  /// Warm paper studio: matte pastel tiles, thin ink outlines, no gloss.
  matte,

  /// Handheld console: square pixels, hard bevels, CRT scanlines.
  retro;

  /// Value written to storage; the enum name doubles as the stored key.
  String get storageKey => name;

  /// Translation key of the style name.
  String get labelKey => 'style.$name';

  /// Translation key of the one line description.
  String get hintKey => 'style.$name.hint';

  /// Never throws: an unknown or tampered value falls back to [aurora].
  static VisualStyle fromStorage(String? raw) {
    for (final VisualStyle style in VisualStyle.values) {
      if (style.storageKey == raw) {
        return style;
      }
    }
    return VisualStyle.aurora;
  }

  /// The block material this style draws.
  BlockStyle get block => switch (this) {
        VisualStyle.aurora => BlockStyle.soft,
        VisualStyle.neon => BlockStyle.neon,
        VisualStyle.matte => BlockStyle.matte,
        VisualStyle.retro => BlockStyle.retro,
      };
}

/// How one block is painted. Kept separate from [VisualStyle] so the brand logo
/// can keep the soft material while the board uses another one.
enum BlockStyle {
  /// Glossy toy cube: lip, gradient face, specular highlight, cast shadow.
  soft,

  /// Neon tube: flat face, hot rim, soft bloom.
  neon,

  /// Printed cardboard: flat pastel, thin ink outline, no shine.
  matte,

  /// Pixel: hard square, chunky bevel, no blur.
  retro,
}

/// Every colour a style needs, for one brightness.
class StylePalette {
  const StylePalette({
    required this.background,
    required this.gradient,
    required this.surface,
    required this.surfaceAlt,
    required this.board,
    required this.cell,
    required this.outline,
    required this.text,
    required this.textMuted,
    required this.accent,
  });

  final Color background;
  final List<Color> gradient;
  final Color surface;
  final Color surfaceAlt;
  final Color board;
  final Color cell;
  final Color outline;
  final Color text;
  final Color textMuted;
  final Color accent;
}

/// Static description of a style: its palettes plus the stage decoration it
/// asks the background painter for.
class VisualStyleSpec {
  const VisualStyleSpec({
    required this.style,
    required this.dark,
    required this.light,
    this.blooms = true,
    this.gridFloor = false,
    this.scanlines = false,
  });

  final VisualStyle style;
  final StylePalette dark;
  final StylePalette light;

  /// Soft colour blooms (aurora family).
  final bool blooms;

  /// Perspective grid behind the content (arcade floors).
  final bool gridFloor;

  /// Horizontal CRT lines over the gradient.
  final bool scanlines;

  StylePalette palette(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static const VisualStyleSpec aurora = VisualStyleSpec(
    style: VisualStyle.aurora,
    dark: StylePalette(
      background: Color(0xFF120F28),
      gradient: <Color>[Color(0xFF171233), Color(0xFF1F1745), Color(0xFF241A55)],
      surface: Color(0xFF1D1846),
      surfaceAlt: Color(0xFF272060),
      board: Color(0xFF171240),
      cell: Color(0xFF221C52),
      outline: Color(0xFF362C7A),
      text: Color(0xFFF4F1FF),
      textMuted: Color(0xFFA69ED6),
      accent: Color(0xFF7A3FF0),
    ),
    light: StylePalette(
      background: Color(0xFFF6F3FF),
      gradient: <Color>[Color(0xFFEDE9FF), Color(0xFFF6ECFF), Color(0xFFEFF6FF)],
      surface: Color(0xFFFFFFFF),
      surfaceAlt: Color(0xFFEFEAFF),
      board: Color(0xFF171240),
      cell: Color(0xFF221C52),
      outline: Color(0xFFE2DAF8),
      text: Color(0xFF1D1745),
      textMuted: Color(0xFF6B6390),
      accent: Color(0xFF6B3BEF),
    ),
  );

  static const VisualStyleSpec neon = VisualStyleSpec(
    style: VisualStyle.neon,
    gridFloor: true,
    dark: StylePalette(
      background: Color(0xFF05040C),
      gradient: <Color>[Color(0xFF070610), Color(0xFF0B0A1E), Color(0xFF120A2A)],
      surface: Color(0xFF0E0C22),
      surfaceAlt: Color(0xFF161235),
      board: Color(0xFF080714),
      cell: Color(0xFF100E24),
      outline: Color(0xFF2A2470),
      text: Color(0xFFEAFBFF),
      textMuted: Color(0xFF7F8FBF),
      accent: Color(0xFF22E0FF),
    ),
    light: StylePalette(
      background: Color(0xFFF2FBFF),
      gradient: <Color>[Color(0xFFEAF7FF), Color(0xFFF4F0FF), Color(0xFFE9FFF8)],
      surface: Color(0xFFFFFFFF),
      surfaceAlt: Color(0xFFE8F6FF),
      board: Color(0xFF0A0A18),
      cell: Color(0xFF141231),
      outline: Color(0xFFBFE9FF),
      text: Color(0xFF0A1230),
      textMuted: Color(0xFF5A6A8C),
      accent: Color(0xFF0090C8),
    ),
  );

  static const VisualStyleSpec matte = VisualStyleSpec(
    style: VisualStyle.matte,
    blooms: false,
    dark: StylePalette(
      background: Color(0xFF23201D),
      gradient: <Color>[Color(0xFF2A2521), Color(0xFF302A25), Color(0xFF241F1C)],
      surface: Color(0xFF2F2A26),
      surfaceAlt: Color(0xFF39322C),
      board: Color(0xFF1B1815),
      cell: Color(0xFF262119),
      outline: Color(0xFF4A4038),
      text: Color(0xFFF6EFE6),
      textMuted: Color(0xFFB5A595),
      accent: Color(0xFFC96F4A),
    ),
    light: StylePalette(
      background: Color(0xFFFBF6EF),
      gradient: <Color>[Color(0xFFFDF9F2), Color(0xFFF7EFE4), Color(0xFFFBF3EA)],
      surface: Color(0xFFFFFFFF),
      surfaceAlt: Color(0xFFF3EADF),
      board: Color(0xFF2A2320),
      cell: Color(0xFF352C26),
      outline: Color(0xFFE7D8C7),
      text: Color(0xFF2B2018),
      textMuted: Color(0xFF7A6A5B),
      accent: Color(0xFFB4552F),
    ),
  );

  static const VisualStyleSpec retro = VisualStyleSpec(
    style: VisualStyle.retro,
    blooms: false,
    scanlines: true,
    dark: StylePalette(
      background: Color(0xFF061014),
      gradient: <Color>[Color(0xFF07161A), Color(0xFF092026), Color(0xFF061418)],
      surface: Color(0xFF0B2027),
      surfaceAlt: Color(0xFF103037),
      board: Color(0xFF041014),
      cell: Color(0xFF0A2228),
      outline: Color(0xFF1E4E52),
      text: Color(0xFFD8FFF4),
      textMuted: Color(0xFF6FA69E),
      accent: Color(0xFF4BE3C0),
    ),
    light: StylePalette(
      background: Color(0xFFF4FBF6),
      gradient: <Color>[Color(0xFFF2FBF4), Color(0xFFEAF6EE), Color(0xFFF6FBF2)],
      surface: Color(0xFFFFFFFF),
      surfaceAlt: Color(0xFFE7F2E9),
      board: Color(0xFF0C2024),
      cell: Color(0xFF143034),
      outline: Color(0xFFCBE3D2),
      text: Color(0xFF0D2A22),
      textMuted: Color(0xFF5B7A6C),
      accent: Color(0xFF1FA37E),
    ),
  );

  /// Spec for [style].
  static VisualStyleSpec of(VisualStyle style) => switch (style) {
        VisualStyle.aurora => aurora,
        VisualStyle.neon => neon,
        VisualStyle.matte => matte,
        VisualStyle.retro => retro,
      };

  /// All specs, in menu order.
  static const List<VisualStyleSpec> all = <VisualStyleSpec>[
    aurora,
    neon,
    matte,
    retro,
  ];
}
