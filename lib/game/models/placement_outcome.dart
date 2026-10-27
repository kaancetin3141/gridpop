import 'grid_position.dart';

/// A board cell together with the palette index it is painted with.
///
/// Cleared cells are captured *before* the board is wiped so the effects layer
/// can still render the blocks that are about to disappear.
class TintedCell {
  const TintedCell(this.position, this.colorIndex);

  final GridPosition position;
  final int colorIndex;

  @override
  String toString() => 'TintedCell($position, c$colorIndex)';
}

/// Detailed score breakdown of a single move, used by the score popup and by
/// the How To Play screen.
class ScoreBreakdown {
  const ScoreBreakdown({
    required this.cellScore,
    required this.lineScore,
    required this.multiBonus,
    required this.perfectBonus,
    required this.comboBonus,
    required this.comboMultiplier,
  });

  final int cellScore;
  final int lineScore;
  final int multiBonus;
  final int perfectBonus;

  /// Extra points granted by the combo multiplier.
  final int comboBonus;

  /// Combo multiplier that was active for this move.
  final double comboMultiplier;

  /// Sum of every component.
  int get total =>
      cellScore + lineScore + multiBonus + perfectBonus + comboBonus;

  @override
  String toString() => 'ScoreBreakdown(total: $total)';
}

/// Result of a successful placement, containing everything the presentation
/// layer needs: cells to animate, lines to clear, points to award.
class PlacementOutcome {
  const PlacementOutcome({
    required this.placedCells,
    required this.colorIndex,
    required this.clearedRows,
    required this.clearedColumns,
    required this.clearedCells,
    required this.cellsCleared,
    required this.score,
    required this.comboLevel,
    required this.comboMultiplier,
    required this.isPerfect,
    required this.isCleanSweep,
    required this.remainingTime,
  });

  /// Cells written by the player, in board coordinates.
  final List<GridPosition> placedCells;

  /// Palette index used for the placed block.
  final int colorIndex;

  final List<int> clearedRows;
  final List<int> clearedColumns;

  /// Every cell removed by the clear, including its palette index.
  final List<TintedCell> clearedCells;

  /// How many cells were removed by the clear.
  final int cellsCleared;

  final ScoreBreakdown score;

  /// Combo level *after* this move (0 when the move cleared nothing).
  final int comboLevel;

  /// Multiplier applied to the line related points.
  final double comboMultiplier;

  /// True for three or more lines in a single move.
  final bool isPerfect;

  /// True when a move clears every line at once.
  final bool isCleanSweep;

  /// Remaining seconds for timed modes, `null` for untimed modes.
  final int? remainingTime;

  int get lineCount => clearedRows.length + clearedColumns.length;

  bool get hasClear => lineCount > 0;
}