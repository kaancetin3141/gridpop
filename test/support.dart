import 'package:gridpop/core/utils/seeded_random.dart';
import 'package:gridpop/game/logic/piece_generator.dart';
import 'package:gridpop/game/models/board.dart';
import 'package:gridpop/game/models/piece_slot.dart';

/// Fills every cell except an isolated lattice of holes: none of the holes
/// touch, and every row and column still keeps at least one hole, so no line
/// can ever complete. Only single cell pieces can be placed on it.
void fillPocketLattice(Board board) {
  for (int row = 0; row < board.size; row++) {
    for (int col = 0; col < board.size; col++) {
      final bool hole = (row + col) % 3 == 0;
      board.setValue(row, col, hole ? Board.empty : 1);
    }
  }
}

/// Finds a seed whose first tray holds exactly one single cell piece plus two
/// large pieces (4+ cells). That combination is what traps the pocket lattice:
/// the dot can be played once, then nothing fits any more.
SeededRandom seedForPocket() {
  for (int i = 1; i < 400; i++) {
    final PieceGenerator generator = PieceGenerator(random: SeededRandom(i));
    final List<PieceSlot> tray = generator.generateTray(
      board: Board(8),
      traySize: 3,
      score: 0,
      largePieceBias: 1,
      colorCount: 8,
    );
    final int dots = tray.where((PieceSlot slot) => slot.cellCount == 1).length;
    if (dots == 1 &&
        tray.every(
            (PieceSlot slot) => slot.cellCount == 1 || slot.cellCount >= 4)) {
      return SeededRandom(i);
    }
  }
  throw StateError('no seed produces a single dot with two large pieces');
}
