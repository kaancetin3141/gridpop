import 'package:flutter_test/flutter_test.dart';
import 'package:gridpop/game/models/board.dart';
import 'package:gridpop/game/models/grid_position.dart';

void main() {
  group('Board', () {
    test('starts empty with the requested size', () {
      final Board board = Board(8);
      expect(board.size, 8);
      expect(board.cells.length, 64);
      expect(board.filledCount, 0);
      expect(board.isFull, isFalse);
      expect(board.isEmptyAt(0, 0), isTrue);
    });

    test('fromSketch reads rows and columns', () {
      final Board board = Board.fromSketch(<String>[
        '..##',
        '.#..',
        '....',
        '####',
      ]);
      expect(board.size, 4);
      expect(board.filledCount, 7);
      expect(board.valueAt(0, 2), 1);
      expect(board.isEmptyAt(1, 0), isTrue);
      expect(board.toSketch(), '..##/.#../..../####');
    });

    test('values are zero based colour indices offset by one', () {
      final Board board = Board(2);
      board.setValue(0, 0, 3);
      expect(board.valueAt(0, 0), 3);
      expect(board.valueAt(5, 5), Board.empty);
    });

    test('canPlace rejects out of bounds and overlapping cells', () {
      final Board board = Board(4);
      const List<GridPosition> cells = <GridPosition>[
        GridPosition(0, 0),
        GridPosition(0, 1),
      ];

      expect(board.canPlace(cells, 0, 0), isTrue);
      expect(board.canPlace(cells, 4, 0), isFalse, reason: 'leaves the board');
      expect(board.canPlace(cells, 0, 3), isFalse, reason: 'leaves the board');

      board.place(cells, 1, 1, 2);
      expect(board.canPlace(cells, 1, 1), isFalse, reason: 'overlaps');
      expect(board.valueAt(1, 2), 3, reason: 'colourIndex + 1 is stored');
    });

    test('detects and clears full rows and columns', () {
      final Board board = Board(4);
      for (int row = 0; row < 3; row++) {
        for (int col = 0; col < 4; col++) {
          board.setValue(row, col, 1);
        }
      }
      expect(board.fullRows(), <int>[0, 1, 2]);
      expect(board.fullColumns(), isEmpty);

      final int cleared = board.clearLines(<int>[0], const <int>[]);
      expect(cleared, 4);
      expect(board.fullRows(), <int>[1, 2]);
    });

    test('a full board reports isFull', () {
      final Board board = Board(3);
      expect(board.isFull, isFalse);
      for (int i = 0; i < 9; i++) {
        board.setValue(i ~/ 3, i % 3, 1);
      }
      expect(board.isFull, isTrue);
      expect(board.filledCount, 9);
    });

    test('copy is independent from the source board', () {
      final Board board = Board(3);
      board.setValue(1, 1, 4);
      final Board clone = board.copy();
      clone.setValue(0, 0, 1);

      expect(board.valueAt(0, 0), Board.empty);
      expect(clone.valueAt(1, 1), 4);
    });

    test('bytes round trip', () {
      final Board board = Board(4);
      board.setValue(2, 3, 5);
      final Board restored = Board(4)..loadBytes(board.toBytes());
      expect(restored.valueAt(2, 3), 5);
    });
  });
}