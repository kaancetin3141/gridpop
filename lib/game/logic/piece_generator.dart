import 'dart:math' as math;

import '../../core/constants/piece_catalog.dart';
import '../../core/utils/seeded_random.dart';
import '../models/board.dart';
import '../models/grid_position.dart';
import '../models/piece_shape.dart';
import '../models/piece_slot.dart';
import 'board_analyzer.dart';

/// Decides which shapes the player receives next.
///
/// The generator is seedable, which is what makes the Daily Challenge fair:
/// everybody gets the exact same sequence for a given date.
class PieceGenerator {
  PieceGenerator({PieceShapeLibrary? library, SeededRandom? random})
      : library = library ?? PieceShapeLibrary.build(),
        _random = random ?? SeededRandom(DateTime.now().microsecondsSinceEpoch);

  /// Shapes available to the game.
  final PieceShapeLibrary library;

  final SeededRandom _random;

  /// Score at which the hardest shapes start showing up regularly.
  static const int difficultyRamp = 2400;

  /// Score at which the biggest shapes are fully unlocked.
  static const int fullDifficulty = 4200;

  /// Generates a single piece.
  PieceSlot generate({
    required int index,
    required Board board,
    required int score,
    required double largePieceBias,
    required int colorCount,
    int? forcedColorIndex,
    int token = 0,
  }) {
    final List<PieceShape> pool = _eligibleShapes(board);
    if (pool.isEmpty) {
      // The board has no free cell at all: nothing sensible can be spawned,
      // so the smallest shape is used and the caller refills the tray.
      return PieceSlot(
        index: index,
        shape: library.byId(fallbackBlueprint.id),
        colorIndex: forcedColorIndex ?? 0,
        token: token,
      );
    }
    final PieceShape shape = _random.pickWeighted<PieceShape>(
      pool,
      (PieceShape candidate) => weightFor(candidate, score, largePieceBias, board),
    );
    final int colorIndex =
        forcedColorIndex ?? _random.nextInt(math.max(1, colorCount));
    return PieceSlot(
      index: index,
      shape: shape,
      colorIndex: colorIndex,
      token: token,
    );
  }

  /// Generates a full tray.
  ///
  /// [forcePlayable] guarantees that at least one piece fits whenever that is
  /// mathematically possible. It is used for the very first tray of a run (so
  /// nobody starts dead) and for the relaxed modes, but **not** for ordinary
  /// refills: keeping refills random is what makes a classic run able to end.
  List<PieceSlot> generateTray({
    required Board board,
    required int traySize,
    required int score,
    required double largePieceBias,
    required int colorCount,
    bool forcePlayable = true,
    int attempts = 24,
  }) {
    List<PieceSlot> tray = _trayOf(
      board: board,
      traySize: traySize,
      score: score,
      largePieceBias: largePieceBias,
      colorCount: colorCount,
    );

    if (!forcePlayable) {
      return _distinctColors(tray, colorCount);
    }

    for (int i = 0; i < attempts; i++) {
      if (BoardAnalyzer.hasAnyMove(board, tray)) {
        return _distinctColors(tray, colorCount);
      }
      tray = _trayOf(
        board: board,
        traySize: traySize,
        score: score,
        largePieceBias: largePieceBias,
        colorCount: colorCount,
      );
    }

    // Last resort: force a placeable piece into the first slot.
    for (final PieceShape shape in library.all) {
      final PieceSlot probe =
          PieceSlot(index: 0, shape: shape, colorIndex: 0, token: 1);
      final GridAnchor? spot = BoardAnalyzer.anyPlacement(board, probe);
      if (spot != null) {
        tray[0] = probe;
        break;
      }
    }
    return _distinctColors(tray, colorCount);
  }

  /// Spawn weight of [shape] for the current difficulty.
  double weightFor(
    PieceShape shape,
    int score,
    double largePieceBias,
    Board board,
  ) {
    double weight = shape.weight;
    final double ramp =
        (score / difficultyRamp).clamp(0.0, 1.0).toDouble();
    final double full = (score / fullDifficulty).clamp(0.0, 1.0).toDouble();

    switch (shape.tier) {
      case 1:
        weight *= 1 + 0.15 * ramp;
      case 2:
        weight *= 0.35 + 0.85 * ramp;
      case 3:
        weight *= (0.05 + 0.95 * full) * largePieceBias;
    }

    // Endgame safety net: big shapes get rare once the board is nearly full.
    final int empty = board.size * board.size - board.filledCount;
    if (empty <= 0) {
      return 0;
    }
    if (shape.cellCount > empty) {
      return 0;
    }
    if (shape.cellCount >= 5 && empty <= 14) {
      weight *= 0.3;
    }
    return weight < 0 ? 0 : weight;
  }

  List<PieceSlot> _trayOf({
    required Board board,
    required int traySize,
    required int score,
    required double largePieceBias,
    required int colorCount,
  }) {
    return <PieceSlot>[
      for (int i = 0; i < traySize; i++)
        generate(
          index: i,
          board: board,
          score: score,
          largePieceBias: largePieceBias,
          colorCount: colorCount,
        ),
    ];
  }

  /// Avoids three visually identical colours in the same tray.
  List<PieceSlot> _distinctColors(List<PieceSlot> tray, int colorCount) {
    if (tray.length < 2 || colorCount <= 1) {
      return tray;
    }
    final List<PieceSlot> result = List<PieceSlot>.of(tray);
    for (int i = 1; i < result.length; i++) {
      if (result[i].colorIndex == result[i - 1].colorIndex) {
        int shift = 1;
        while (shift < colorCount &&
            result[i].colorIndex == result[i - 1].colorIndex) {
          result[i] = result[i].copyWith(
            colorIndex: (result[i].colorIndex + shift) % colorCount,
          );
          shift++;
        }
      }
    }
    return result;
  }

  List<PieceShape> _eligibleShapes(Board board) {
    final int empty = board.size * board.size - board.filledCount;
    return library.all
        .where((PieceShape shape) => shape.cellCount <= empty)
        .toList(growable: false);
  }

  /// Shape used when a refill is impossible (board is completely full).
  static PieceBlueprint get fallbackBlueprint => PieceCatalog.dot;
}