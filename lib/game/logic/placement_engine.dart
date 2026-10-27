import '../models/board.dart';
import '../models/grid_position.dart';
import '../models/piece_slot.dart';
import '../models/placement_outcome.dart';
import 'scoring_engine.dart';

/// Applies a move to the board. Pure logic, no Flutter, no side effects beyond
/// mutating the [Board] that was handed in.
class PlacementEngine {
  const PlacementEngine._();

  /// Tries to drop [piece] with its top-left cell at ([topRow], [leftCol]).
  ///
  /// Returns `null` (and leaves the board untouched) when the move is invalid.
  /// On success the board is mutated and the full outcome - including the new
  /// combo level and the score breakdown - is returned.
  static PlacementOutcome? apply({
    required Board board,
    required PieceSlot piece,
    required int topRow,
    required int leftCol,
    required int comboLevel,
    int? remainingTime,
  }) {
    final List<GridPosition> cells = piece.cells;
    if (!board.canPlace(cells, topRow, leftCol)) {
      return null;
    }

    board.place(cells, topRow, leftCol, piece.colorIndex);

    final List<int> rows = board.fullRows();
    final List<int> columns = board.fullColumns();

    // Snapshot the palette indices before wiping the lines so the effects layer
    // can still draw the blocks that are about to vanish.
    final List<TintedCell> clearedCells = <TintedCell>[];
    for (final int row in rows) {
      for (int col = 0; col < board.size; col++) {
        clearedCells.add(TintedCell(GridPosition(row, col), board.valueAt(row, col) - 1));
      }
    }
    for (final int col in columns) {
      for (int row = 0; row < board.size; row++) {
        if (rows.contains(row)) {
          continue;
        }
        clearedCells.add(TintedCell(GridPosition(row, col), board.valueAt(row, col) - 1));
      }
    }

    final int cleared = board.clearLines(rows, columns);

    final int lineCount = rows.length + columns.length;
    final int nextCombo = lineCount > 0 ? comboLevel + 1 : 0;

    final ScoreBreakdown breakdown = ScoringEngine.evaluate(
      cellsPlaced: cells.length,
      rowsCleared: rows.length,
      columnsCleared: columns.length,
      comboLevel: nextCombo,
    );

    return PlacementOutcome(
      placedCells: _absolute(cells, topRow, leftCol),
      colorIndex: piece.colorIndex,
      clearedRows: rows,
      clearedColumns: columns,
      clearedCells: clearedCells,
      cellsCleared: cleared,
      score: breakdown,
      comboLevel: nextCombo,
      comboMultiplier: breakdown.comboMultiplier,
      isPerfect: lineCount >= ScoringEngine.perfectLineThreshold,
      isCleanSweep: rows.length >= board.size && columns.length >= board.size,
      remainingTime: remainingTime,
    );
  }

  static List<GridPosition> _absolute(
    List<GridPosition> cells,
    int topRow,
    int leftCol,
  ) {
    return <GridPosition>[
      for (final GridPosition cell in cells)
        GridPosition(cell.row + topRow, cell.col + leftCol),
    ];
  }
}