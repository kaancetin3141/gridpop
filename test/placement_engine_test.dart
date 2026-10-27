import 'package:flutter_test/flutter_test.dart';
import 'package:gridpop/core/constants/app_constants.dart';
import 'package:gridpop/core/constants/piece_catalog.dart';
import 'package:gridpop/game/logic/placement_engine.dart';
import 'package:gridpop/game/logic/scoring_engine.dart';
import 'package:gridpop/game/models/board.dart';
import 'package:gridpop/game/models/grid_position.dart';
import 'package:gridpop/game/models/piece_shape.dart';
import 'package:gridpop/game/models/piece_slot.dart';
import 'package:gridpop/game/models/placement_outcome.dart';

PieceSlot slotOf(String id, {int colorIndex = 1, int rotation = 0}) => PieceSlot(
      index: 0,
      shape: PieceShape.fromBlueprint(PieceCatalog.byId(id)!),
      colorIndex: colorIndex,
      rotation: rotation,
    );

void main() {
  group('PlacementEngine - normal moves', () {
    test('places a piece and scores the cells', () {
      final Board board = Board(8);
      final PlacementOutcome? outcome = PlacementEngine.apply(
        board: board,
        piece: slotOf('dot'),
        topRow: 3,
        leftCol: 4,
        comboLevel: 0,
      );

      expect(outcome, isNotNull);
      expect(board.valueAt(3, 4), 2, reason: 'colorIndex 1 is stored as 2');
      expect(outcome!.placedCells, <GridPosition>[const GridPosition(3, 4)]);
      expect(outcome.score.cellScore, ScoringConfig.pointsPerCell);
      expect(outcome.lineCount, 0);
      expect(outcome.comboLevel, 0);
    });

    test('rejects an invalid move and leaves the board untouched', () {
      final Board board = Board(8);
      final PlacementOutcome? outcome = PlacementEngine.apply(
        board: board,
        piece: slotOf('rail'),
        topRow: 7,
        leftCol: 6,
        comboLevel: 0,
      );

      expect(outcome, isNull, reason: 'piece leaves the board');
      expect(board.filledCount, 0);
    });

    test('rejects an overlapping move', () {
      final Board board = Board.fromSketch(<String>[
        '....',
        '.##.',
        '....',
        '....',
      ]);
      final PlacementOutcome? outcome = PlacementEngine.apply(
        board: board,
        piece: slotOf('dom'),
        topRow: 1,
        leftCol: 1,
        comboLevel: 0,
      );

      expect(outcome, isNull);
      expect(board.filledCount, 2);
    });
  });

  group('PlacementEngine - line clearing', () {
    test('clears a full row', () {
      final Board board = Board.fromSketch(<String>[
        '...',
        '...',
        '##.',
      ]);
      final PlacementOutcome? outcome = PlacementEngine.apply(
        board: board,
        piece: slotOf('dot'),
        topRow: 2,
        leftCol: 2,
        comboLevel: 0,
      );

      expect(outcome, isNotNull);
      expect(outcome!.clearedRows, <int>[2]);
      expect(outcome.clearedColumns, isEmpty);
      expect(outcome.cellsCleared, 3);
      expect(outcome.comboLevel, 1);
      expect(
        outcome.score.lineScore,
        ScoringConfig.pointsPerRow,
      );
      expect(board.filledCount, 0);
    });

    test('clears a full column', () {
      final Board board = Board.fromSketch(<String>[
        '#..',
        '#..',
        '...',
      ]);
      final PlacementOutcome? outcome = PlacementEngine.apply(
        board: board,
        piece: slotOf('dot'),
        topRow: 2,
        leftCol: 0,
        comboLevel: 0,
      );

      expect(outcome!.clearedColumns, <int>[0]);
      expect(outcome.clearedRows, isEmpty);
      expect(outcome.score.lineScore, ScoringConfig.pointsPerColumn);
    });

    test('clears a row and a column in the same move', () {
      final Board board = Board.fromSketch(<String>[
        '.#.',
        '.#.',
        '...',
      ]);
      // The horizontal 3-piece completes the last row and the middle column.
      final PlacementOutcome? outcome = PlacementEngine.apply(
        board: board,
        piece: slotOf('bar'),
        topRow: 2,
        leftCol: 0,
        comboLevel: 1,
      );

      expect(outcome!.clearedColumns, <int>[1]);
      expect(outcome.clearedRows, <int>[2]);
      expect(outcome.lineCount, 2);
      expect(outcome.cellsCleared, 5, reason: '3 new cells + 2 leftovers');
      expect(
        outcome.score.multiBonus,
        ScoringConfig.multiLineBonus,
        reason: 'one extra line',
      );
      expect(outcome.comboLevel, 2);
      expect(outcome.isPerfect, isFalse);
    });

    test('three lines count as a perfect move', () {
      final Board board = Board.fromSketch(<String>[
        '.##',
        '.##',
        '...',
      ]);
      // Filling the last row also completes two columns: three lines at once.
      final PlacementOutcome? outcome = PlacementEngine.apply(
        board: board,
        piece: slotOf('bar'),
        topRow: 2,
        leftCol: 0,
        comboLevel: 2,
      );

      expect(outcome, isNotNull);
      expect(outcome!.lineCount, 3);
      expect(outcome.clearedRows, <int>[2]);
      expect(outcome.clearedColumns, <int>[1, 2]);
      expect(outcome.isPerfect, isTrue);
      expect(outcome.score.perfectBonus, ScoringConfig.perfectBonus);
    });

    test('cleared cells keep their colour for the effects layer', () {
      final Board board = Board.fromSketch(<String>[
        '..',
        '##',
      ]);
      final PlacementOutcome? outcome = PlacementEngine.apply(
        board: board,
        piece: slotOf('dom', colorIndex: 4),
        topRow: 0,
        leftCol: 0,
        comboLevel: 0,
      );

      expect(outcome!.clearedCells.length, 4);
      for (final dynamic cell in outcome.clearedCells) {
        expect(cell.colorIndex, inInclusiveRange(0, 7));
      }
    });
  });

  group('ScoringEngine', () {
    test('cell points are flat', () {
      final ScoreBreakdown breakdown = ScoringEngine.evaluate(
        cellsPlaced: 5,
        rowsCleared: 0,
        columnsCleared: 0,
        comboLevel: 0,
      );
      expect(breakdown.cellScore, 5);
      expect(breakdown.total, 5);
    });

    test('multi line bonus grows with the number of lines', () {
      expect(
        ScoringEngine.evaluate(
          cellsPlaced: 1,
          rowsCleared: 1,
          columnsCleared: 0,
          comboLevel: 0,
        ).multiBonus,
        0,
      );
      expect(
        ScoringEngine.evaluate(
          cellsPlaced: 1,
          rowsCleared: 2,
          columnsCleared: 0,
          comboLevel: 0,
        ).multiBonus,
        ScoringConfig.multiLineBonus,
      );
      expect(
        ScoringEngine.evaluate(
          cellsPlaced: 1,
          rowsCleared: 1,
          columnsCleared: 2,
          comboLevel: 0,
        ).multiBonus,
        ScoringConfig.multiLineBonus * 2,
      );
    });

    test('combo multiplier only scales line points and is capped', () {
      final ScoreBreakdown base = ScoringEngine.evaluate(
        cellsPlaced: 2,
        rowsCleared: 1,
        columnsCleared: 0,
        comboLevel: 0,
      );
      final ScoreBreakdown combo = ScoringEngine.evaluate(
        cellsPlaced: 2,
        rowsCleared: 1,
        columnsCleared: 0,
        comboLevel: 3,
      );

      expect(combo.cellScore, base.cellScore, reason: 'cells are not scaled');
      expect(combo.lineScore, base.lineScore);
      expect(
        combo.comboMultiplier,
        greaterThan(base.comboMultiplier),
      );
      expect(combo.total, greaterThan(base.total));
      expect(ScoringEngine.multiplierFor(100), ScoringConfig.comboCap);
    });

    test('stars follow the daily thresholds', () {
      const List<int> thresholds = <int>[100, 200, 300];
      expect(ScoringEngine.starsForScore(0, thresholds), 0);
      expect(ScoringEngine.starsForScore(150, thresholds), 1);
      expect(ScoringEngine.starsForScore(250, thresholds), 2);
      expect(ScoringEngine.starsForScore(350, thresholds), 3);
    });
  });
}