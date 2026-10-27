import 'package:flutter_test/flutter_test.dart';
import 'package:gridpop/core/constants/piece_catalog.dart';
import 'package:gridpop/core/utils/seeded_random.dart';
import 'package:gridpop/game/logic/board_analyzer.dart';
import 'package:gridpop/game/logic/combo_tracker.dart';
import 'package:gridpop/game/logic/piece_generator.dart';
import 'package:gridpop/game/models/board.dart';
import 'package:gridpop/game/models/grid_position.dart';
import 'package:gridpop/game/models/piece_shape.dart';
import 'package:gridpop/game/models/piece_slot.dart';

PieceSlot slotOf(String id, {int index = 0}) => PieceSlot(
      index: index,
      shape: PieceShape.fromBlueprint(PieceCatalog.byId(id)!),
      colorIndex: 0,
    );

void main() {
  group('ComboTracker', () {
    test('grows on clearing moves and resets otherwise', () {
      final ComboTracker combo = ComboTracker();
      expect(combo.level, 0);

      expect(combo.register(1), 1);
      expect(combo.register(2), 2);
      expect(combo.best, 2);

      expect(combo.register(0), 0);
      expect(combo.best, 2, reason: 'best is kept for the whole run');

      expect(combo.register(1), 1);
      combo.reset();
      expect(combo.level, 0);
      expect(combo.best, 0);
    });

    test('multiplier follows the level', () {
      final ComboTracker combo = ComboTracker();
      expect(combo.multiplier, 1);
      combo.register(1);
      expect(combo.multiplier, greaterThan(1));
    });
  });

  group('BoardAnalyzer', () {
    test('anchorForDrop centres the piece on the pointer cell', () {
      final Board board = Board(8);
      final GridAnchor? anchor =
          BoardAnalyzer.anchorForDrop(board, slotOf('rail'), 4, 4);
      expect(anchor, isNotNull);
      expect(anchor!.topRow, 4, reason: 'one row tall');
      expect(anchor.leftCol, 2, reason: '4 wide, pointer at the 3rd column');
    });

    test('anchorForDrop returns null near the border', () {
      final Board board = Board(8);
      expect(BoardAnalyzer.anchorForDrop(board, slotOf('rail'), 0, 0), isNull);
      expect(BoardAnalyzer.anchorForDrop(board, slotOf('rail'), 0, 7), isNull);
      expect(BoardAnalyzer.anchorForDrop(board, slotOf('spire'), 6, 4), isNull);
    });

    test('hasAnyMove is false on a completely full board', () {
      final Board board = Board(3);
      for (int i = 0; i < 9; i++) {
        board.setValue(i ~/ 3, i % 3, 1);
      }
      expect(
        BoardAnalyzer.hasAnyMove(board, <PieceSlot>[slotOf('dot')]),
        isFalse,
      );
    });

    test('hasAnyMove is true while a single cell fits', () {
      final Board board = Board(3);
      for (int i = 0; i < 8; i++) {
        board.setValue(i ~/ 3, i % 3, 1);
      }
      expect(
        BoardAnalyzer.hasAnyMove(board, <PieceSlot>[slotOf('dot')]),
        isTrue,
      );
      expect(
        BoardAnalyzer.hasAnyMove(board, <PieceSlot>[slotOf('tile')]),
        isFalse,
        reason: 'a 3x3 piece cannot fit into the single free cell',
      );
    });

    test('suggestMove always returns a legal move when one exists', () {
      final Board board = Board(8);
      for (int col = 0; col < 8; col++) {
        board.setValue(7, col, 1);
      }
      final PieceSlot beam = slotOf('beam');
      final PlacementHint? hint =
          BoardAnalyzer.suggestMove(board, <PieceSlot>[beam]);
      expect(hint, isNotNull);
      expect(
        board.canPlace(beam.cells, hint!.topRow, hint.leftCol),
        isTrue,
      );
      expect(hint.slotIndex, beam.index);
    });

    test('suggestMove returns null when nothing fits', () {
      final Board board = Board(3);
      for (int i = 0; i < 9; i++) {
        board.setValue(i ~/ 3, i % 3, 1);
      }
      expect(
        BoardAnalyzer.suggestMove(board, <PieceSlot>[slotOf('dom')]),
        isNull,
      );
    });

    test('fillRatio reports the occupancy', () {
      final Board board = Board.fromSketch(<String>['#..', '...', '...']);
      expect(BoardAnalyzer.fillRatio(board), closeTo(1 / 9, 0.0001));
    });
  });

  group('PieceGenerator', () {
    test('the same seed produces the same tray', () {
      List<String> sequence() {
        final PieceGenerator generator = PieceGenerator(
          random: SeededRandom.fromString('2026-01-01#pieces'),
        );
        return <String>[
          for (final PieceSlot slot in generator.generateTray(
            board: Board(8),
            traySize: 3,
            score: 0,
            largePieceBias: 1,
            colorCount: 8,
          ))
            '${slot.shape.id}:${slot.colorIndex}',
        ];
      }

      expect(sequence(), sequence());
    });

    test('different seeds diverge', () {
      final PieceGenerator a = PieceGenerator(
        random: SeededRandom.fromString('day-one'),
      );
      final PieceGenerator b = PieceGenerator(
        random: SeededRandom.fromString('day-two'),
      );
      List<String> run(PieceGenerator generator) => <String>[
            for (final PieceSlot slot in generator.generateTray(
              board: Board(8),
              traySize: 3,
              score: 0,
              largePieceBias: 1,
              colorCount: 8,
            ))
              slot.shape.id,
          ];

      expect(run(a), isNot(run(b)));
    });

    test('a tray always contains at least one placeable piece', () {
      final PieceGenerator generator = PieceGenerator(
        random: SeededRandom.fromString('fairness'),
      );
      for (int round = 0; round < 25; round++) {
        final Board board = Board(8);
        for (int i = 0; i < 63; i++) {
          board.setValue(i ~/ 8, i % 8, 1);
        }
        final List<PieceSlot> tray = generator.generateTray(
          board: board,
          traySize: 3,
          score: 5000,
          largePieceBias: 1.5,
          colorCount: 8,
        );
        expect(
          BoardAnalyzer.hasAnyMove(board, tray),
          isTrue,
          reason: 'a dead tray must never be generated',
        );
      }
    });

    test('large pieces are rarer at the start than later on', () {
      final PieceGenerator generator = PieceGenerator(
        random: SeededRandom.fromString('difficulty'),
      );
      final Board board = Board(9);

      int bigEarly = 0;
      int bigLate = 0;
      for (int i = 0; i < 200; i++) {
        if (generator
                .generate(
                  index: 0,
                  board: board,
                  score: 0,
                  largePieceBias: 1,
                  colorCount: 8,
                )
                .cellCount >=
            5) {
          bigEarly++;
        }
        if (generator
                .generate(
                  index: 0,
                  board: board,
                  score: 9000,
                  largePieceBias: 1.4,
                  colorCount: 8,
                )
                .cellCount >=
            5) {
          bigLate++;
        }
      }
      expect(bigLate, greaterThan(bigEarly));
    });

    test('pieces that cannot fit any more are never generated', () {
      final PieceGenerator generator = PieceGenerator(random: SeededRandom(7));
      final Board board = Board(4);
      for (int i = 0; i < 15; i++) {
        board.setValue(i ~/ 4, i % 4, 1);
      }
      final List<PieceSlot> tray = generator.generateTray(
        board: board,
        traySize: 3,
        score: 3000,
        largePieceBias: 1,
        colorCount: 8,
      );
      for (final PieceSlot slot in tray) {
        expect(slot.cellCount, lessThanOrEqualTo(1));
      }
    });
  });
}