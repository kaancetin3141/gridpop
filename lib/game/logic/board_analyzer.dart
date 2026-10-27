import '../models/board.dart';
import '../models/grid_position.dart';
import '../models/piece_slot.dart';

/// Search based helpers: move validation, hint generation and the
/// "no moves left" detection.
class BoardAnalyzer {
  const BoardAnalyzer._();

  /// Position a piece would need in order to be dropped at the centre of the
  /// given pointer location. Returns `null` when the piece would leave the
  /// grid, which the UI uses to snap the piece back.
  static GridAnchor? anchorForDrop(
    Board board,
    PieceSlot piece,
    int pointerRow,
    int pointerCol,
  ) {
    final GridExtent extent = piece.extent;
    final int topRow = pointerRow - extent.height ~/ 2;
    final int leftCol = pointerCol - extent.width ~/ 2;
    if (topRow < 0 || leftCol < 0) {
      return null;
    }
    if (topRow + extent.height > board.size || leftCol + extent.width > board.size) {
      return null;
    }
    return GridAnchor(topRow, leftCol);
  }

  /// First valid anchor for [piece], scanning top-left to bottom-right.
  static GridAnchor? anyPlacement(Board board, PieceSlot piece) {
    for (int rotation = 0; rotation < piece.shape.uniqueRotations; rotation++) {
      final PieceSlot oriented = piece.copyWith(rotation: rotation);
      final List<GridPosition> cells = oriented.cells;
      for (int row = 0; row < board.size; row++) {
        for (int col = 0; col < board.size; col++) {
          if (board.canPlace(cells, row, col)) {
            return GridAnchor(row, col);
          }
        }
      }
    }
    return null;
  }

  /// True when [piece] can be placed somewhere on [board] in any orientation.
  static bool canPlaceSomewhere(Board board, PieceSlot piece) =>
      anyPlacement(board, piece) != null;

  /// True when at least one of [pieces] still fits. `null` entries (used tray
  /// slots) are ignored.
  static bool hasAnyMove(Board board, List<PieceSlot?> pieces) {
    for (final PieceSlot? piece in pieces) {
      if (piece == null) {
        continue;
      }
      if (canPlaceSomewhere(board, piece)) {
        return true;
      }
    }
    return false;
  }

  /// Suggested move: prefers positions that immediately clear a line, and
  /// otherwise the lowest possible placement (keeping the top of the board
  /// free looks intentional).
  static PlacementHint? suggestMove(Board board, List<PieceSlot?> pieces) {
    _Candidate? best;

    for (final PieceSlot? piece in pieces) {
      if (piece == null) {
        continue;
      }
      for (int rotation = 0; rotation < piece.shape.uniqueRotations; rotation++) {
        final PieceSlot oriented = piece.copyWith(rotation: rotation);
        final List<GridPosition> cells = oriented.cells;
        for (int row = 0; row < board.size; row++) {
          for (int col = 0; col < board.size; col++) {
            if (!board.canPlace(cells, row, col)) {
              continue;
            }
            final Board probe = board.copy();
            probe.place(cells, row, col, oriented.colorIndex);
            final int cleared =
                probe.fullRows().length + probe.fullColumns().length;
            // Clearing lines wins, then filling from the bottom, then the
            // left-most column: the natural "pack the board" strategy.
            final int weight = cleared * 1000 + row * 10 + (board.size - col);
            if (best == null || weight > best.weight) {
              best = _Candidate(
                PlacementHint(
                  slotIndex: oriented.index,
                  rotation: oriented.rotation,
                  topRow: row,
                  leftCol: col,
                ),
                weight,
              );
            }
          }
        }
      }
    }
    return best?.hint;
  }

  /// Fraction of the board that is occupied, 0 to 1.
  static double fillRatio(Board board) =>
      board.filledCount / (board.size * board.size);
}

/// Internal scoring wrapper used while searching for the best move.
class _Candidate {
  const _Candidate(this.hint, this.weight);

  final PlacementHint hint;
  final int weight;
}