import 'package:flutter/foundation.dart';

import 'grid_position.dart';
import 'piece_shape.dart';

/// One of the three (or, in Zen, endless) pieces offered to the player.
///
/// A slot is immutable: rotating or consuming it produces a new instance, which
/// keeps undo / replay / replay-from-daily-seed trivially correct.
@immutable
class PieceSlot {
  const PieceSlot({
    required this.index,
    required this.shape,
    required this.colorIndex,
    this.rotation = 0,
    this.token = 0,
  });

  /// Tray index (0 based).
  final int index;

  /// Geometry of the piece.
  final PieceShape shape;

  /// Index into `PiecePalette`.
  final int colorIndex;

  /// Current orientation (already normalised to `shape.uniqueRotations`).
  final int rotation;

  /// Increments every time this slot is refilled. The tray animation uses it as
  /// a stable identity so it can play the "new piece" pop.
  final int token;

  /// Number of cells, independent of the orientation.
  int get cellCount => shape.cellCount;

  /// Absolute cells for the current orientation.
  List<GridPosition> get cells => shape.cellsFor(rotation);

  /// Absolute cells for an explicit orientation.
  List<GridPosition> cellsWithRotation(int value) =>
      shape.cellsFor(value);

  /// Bounding box of the current orientation.
  GridExtent get extent => shape.extentFor(rotation);

  /// Returns a copy rotated by one step.
  PieceSlot rotated() => copyWith(rotation: shape.nextRotation(rotation));

  /// Returns a copy with an explicit orientation.
  PieceSlot copyWith({int? index, int? rotation, int? colorIndex, int? token}) {
    return PieceSlot(
      index: index ?? this.index,
      shape: shape,
      colorIndex: colorIndex ?? this.colorIndex,
      rotation: rotation ?? this.rotation,
      token: token ?? this.token,
    );
  }

  @override
  String toString() =>
      'PieceSlot(#$index ${shape.id} r$rotation c$colorIndex)';
}