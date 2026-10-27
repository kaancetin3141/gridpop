/// Immutable cell coordinate.
class GridPosition {
  const GridPosition(this.row, this.col);

  final int row;
  final int col;

  GridPosition translate(int rowOffset, int colOffset) =>
      GridPosition(row + rowOffset, col + colOffset);

  @override
  bool operator ==(Object other) =>
      other is GridPosition && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row, $col)';
}

/// Bounding box of a piece orientation, in cells.
class GridExtent {
  const GridExtent(this.height, this.width);

  final int height;
  final int width;

  @override
  bool operator ==(Object other) =>
      other is GridExtent && other.height == height && other.width == width;

  @override
  int get hashCode => Object.hash(height, width);

  @override
  String toString() => '${width}x$height';
}

/// Where a piece would land: the grid cell its top-left corner sits on.
class GridAnchor {
  const GridAnchor(this.topRow, this.leftCol);

  final int topRow;
  final int leftCol;

  @override
  bool operator ==(Object other) =>
      other is GridAnchor &&
      other.topRow == topRow &&
      other.leftCol == leftCol;

  @override
  int get hashCode => Object.hash(topRow, leftCol);

  @override
  String toString() => '($topRow, $leftCol)';
}

/// A full suggestion produced by the hint system.
class PlacementHint {
  const PlacementHint({
    required this.slotIndex,
    required this.rotation,
    required this.topRow,
    required this.leftCol,
  });

  /// Tray slot that should be used.
  final int slotIndex;

  /// Orientation the piece should be rotated to before dropping.
  final int rotation;

  /// Target cell of the piece's top-left corner.
  final int topRow;
  final int leftCol;
}