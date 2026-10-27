import 'dart:ui';

/// Pure geometry helpers shared by the board painter, the drag overlay and the
/// hit testing code.
///
/// The class is intentionally free of any game model dependency: cells are
/// addressed with plain `(row, column)` records so `core` never has to import
/// `game`.
class BoardGeometry {
  const BoardGeometry({
    required this.origin,
    required this.cellSize,
    required this.gap,
    required this.rows,
    required this.columns,
  });

  /// Top-left corner of the playable area (inside the board padding).
  final Offset origin;

  /// Size of a single cell *including* its gap.
  final double cellSize;

  /// Visual gap between two neighbouring cells.
  final double gap;

  final int rows;
  final int columns;

  /// Total width of the grid.
  double get gridWidth => cellSize * columns;

  /// Total height of the grid.
  double get gridHeight => cellSize * rows;

  /// Bottom-right corner of the grid.
  Offset get gridOrigin => origin.translate(gridWidth, gridHeight);

  /// Centre of the whole grid.
  Offset get center =>
      origin.translate(gridWidth / 2, gridHeight / 2);

  /// Rectangle of the cell at [row], [col] (the inner face, gap excluded).
  Rect cellRect(int row, int col) {
    final double left = origin.dx + col * cellSize;
    final double top = origin.dy + row * cellSize;
    return Rect.fromLTWH(
      left + gap / 2,
      top + gap / 2,
      cellSize - gap,
      cellSize - gap,
    );
  }

  /// Centre point of the cell at [row], [col].
  Offset cellCenter(int row, int col) {
    final double left = origin.dx + col * cellSize;
    final double top = origin.dy + row * cellSize;
    return Offset(left + cellSize / 2, top + cellSize / 2);
  }

  /// Returns the cell under [point], or `null` when the point is outside of
  /// the grid.
  (int, int)? cellAt(Offset point) {
    if (point.dx < origin.dx ||
        point.dy < origin.dy ||
        point.dx >= origin.dx + gridWidth ||
        point.dy >= origin.dy + gridHeight) {
      return null;
    }
    final int col = ((point.dx - origin.dx) / cellSize).floor();
    final int row = ((point.dy - origin.dy) / cellSize).floor();
    final int safeRow = row.clamp(0, rows - 1);
    final int safeCol = col.clamp(0, columns - 1);
    return (safeRow, safeCol);
  }

  /// Bounding box of a set of cells expressed as `(row, column)` records.
  Rect boundsOf(Iterable<(int, int)> cells) {
    var minRow = rows;
    var minCol = columns;
    var maxRow = -1;
    var maxCol = -1;
    for (final (int row, int col) in cells) {
      if (row < minRow) minRow = row;
      if (col < minCol) minCol = col;
      if (row > maxRow) maxRow = row;
      if (col > maxCol) maxCol = col;
    }
    if (maxRow < 0) {
      return Rect.zero;
    }
    final Rect first = cellRect(minRow, minCol);
    final Rect last = cellRect(maxRow, maxCol);
    return Rect.fromLTRB(first.left, first.top, last.right, last.bottom);
  }

  /// Converts a bounding box into the grid anchor `(row, column)` of its
  /// top-left cell.
  (int, int) anchorOf(Rect bounds) {
    final int row = ((bounds.top - origin.dy) / cellSize)
        .round()
        .clamp(0, rows - 1);
    final int col = ((bounds.left - origin.dx) / cellSize)
        .round()
        .clamp(0, columns - 1);
    return (row, col);
  }

  /// Builds a geometry that fits [columns] x [rows] cells inside
  /// [available] while keeping the aspect ratio.
  factory BoardGeometry.fit({
    required Size available,
    required int rows,
    required int columns,
    required double gapFactor,
    double outerPadding = 0,
  }) {
    final double usableWidth = (available.width - outerPadding * 2).clamp(0.0, double.infinity);
    final double usableHeight = (available.height - outerPadding * 2).clamp(0.0, double.infinity);
    final double cell = usableWidth / columns < usableHeight / rows
        ? usableWidth / columns
        : usableHeight / rows;
    final double side = cell * columns;
    final double originX = (available.width - side) / 2 + outerPadding * 0;
    final double originY = (available.height - cell * rows) / 2;
    return BoardGeometry(
      origin: Offset(originX, originY),
      cellSize: cell,
      gap: cell * gapFactor,
      rows: rows,
      columns: columns,
    );
  }

  BoardGeometry copyWith({Offset? origin, double? cellSize, double? gap}) {
    return BoardGeometry(
      origin: origin ?? this.origin,
      cellSize: cellSize ?? this.cellSize,
      gap: gap ?? this.gap,
      rows: rows,
      columns: columns,
    );
  }
}