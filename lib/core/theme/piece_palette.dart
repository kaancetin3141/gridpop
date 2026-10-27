import 'package:flutter/material.dart';

/// One candy coloured block material.
///
/// Every rendered block derives its top highlight and bottom shade from
/// [base], which keeps the whole board visually consistent.
class PieceColor {
  const PieceColor({
    required this.id,
    required this.base,
    required this.light,
    required this.dark,
    required this.accent,
  });

  /// Stable id, used when persisting a finished board (future replays).
  final String id;

  /// Main face colour.
  final Color base;

  /// Top-left highlight.
  final Color light;

  /// Bottom-right shade, also used for the drop shadow tint.
  final Color dark;

  /// Saturated colour used for glows and effects.
  final Color accent;

  /// Shadow colour derived from [dark].
  Color get shadow => dark.withOpacity(0.42);
}

/// The eight original GridPop block materials, tuned for a vivid, high
/// contrast "neon glass" look.
class PiecePalette {
  const PiecePalette._();

  static const PieceColor coral = PieceColor(
    id: 'coral',
    base: Color(0xFFFF4D5E),
    light: Color(0xFFFF8A98),
    dark: Color(0xFFC81F3C),
    accent: Color(0xFFFF6B7B),
  );

  static const PieceColor tangerine = PieceColor(
    id: 'tangerine',
    base: Color(0xFFFF8A00),
    light: Color(0xFFFFB74D),
    dark: Color(0xFFC75E00),
    accent: Color(0xFFFFA033),
  );

  static const PieceColor sunbeam = PieceColor(
    id: 'sunbeam',
    base: Color(0xFFFFC400),
    light: Color(0xFFFFE066),
    dark: Color(0xFFC79100),
    accent: Color(0xFFFFD633),
  );

  static const PieceColor lime = PieceColor(
    id: 'lime',
    base: Color(0xFF6EE714),
    light: Color(0xFFA8F55C),
    dark: Color(0xFF48A800),
    accent: Color(0xFF8DF03D),
  );

  static const PieceColor mint = PieceColor(
    id: 'mint',
    base: Color(0xFF00D9A3),
    light: Color(0xFF5CF0C8),
    dark: Color(0xFF00A37A),
    accent: Color(0xFF2AE6B4),
  );

  static const PieceColor sky = PieceColor(
    id: 'sky',
    base: Color(0xFF1FA8FF),
    light: Color(0xFF6FCBFF),
    dark: Color(0xFF0073C7),
    accent: Color(0xFF47B8FF),
  );

  static const PieceColor grape = PieceColor(
    id: 'grape',
    base: Color(0xFF7B4DFF),
    light: Color(0xFFAA8AFF),
    dark: Color(0xFF4E22D9),
    accent: Color(0xFF9370FF),
  );

  static const PieceColor bubblegum = PieceColor(
    id: 'bubblegum',
    base: Color(0xFFFF3E9E),
    light: Color(0xFFFF7CC2),
    dark: Color(0xFFC71472),
    accent: Color(0xFFFF5FB0),
  );

  /// Ordered palette. Index 0 is the most common spawn colour.
  static const List<PieceColor> all = <PieceColor>[
    grape,
    sky,
    coral,
    mint,
    sunbeam,
    tangerine,
    bubblegum,
    lime,
  ];

  /// Safe lookup with wrap-around, so any int can be used as an index.
  static PieceColor byIndex(int index) =>
      all[index.abs() % all.length];

  /// Looks up a palette entry by id, falling back to the first entry.
  static PieceColor byId(String id) {
    for (final PieceColor color in all) {
      if (color.id == id) {
        return color;
      }
    }
    return all.first;
  }
}