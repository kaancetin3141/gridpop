import 'dart:typed_data';

import 'grid_position.dart';

/// The square play field.
///
/// Storage is a flat [Uint8List] of `size * size` bytes where `0` means empty
/// and any other value is `colorIndex + 1`. A flat buffer keeps both the memory
/// footprint and the repaint cost minimal on web.
class Board {
  Board(this.size) : assert(size > 0), _cells = Uint8List(size * size);

  /// Creates a board from a textual sketch, mostly used by tests:
  /// `.` = empty, any other character = a filled cell.
  factory Board.fromSketch(List<String> rows) {
    assert(rows.isNotEmpty, 'the sketch needs at least one row');
    final int size = rows.length;
    final Board board = Board(size);
    for (int r = 0; r < size; r++) {
      final String line = rows[r];
      for (int c = 0; c < size; c++) {
        final bool filled = c < line.length && line[c] != '.';
        board.setValue(r, c, filled ? 1 : 0);
      }
    }
    return board;
  }

  /// Side length of the board (8 or 9 in the shipped modes).
  final int size;

  final Uint8List _cells;

  /// Value stored in an empty cell.
  static const int empty = 0;

  Uint8List get cells => _cells;

  bool isInside(int row, int col) =>
      row >= 0 && col >= 0 && row < size && col < size;

  bool isEmptyAt(int row, int col) => valueAt(row, col) == empty;

  /// Raw stored value at [row], [col] (0 when out of bounds).
  int valueAt(int row, int col) {
    if (!isInside(row, col)) {
      return empty;
    }
    return _cells[row * size + col];
  }

  /// Writes a raw value. Out of bounds writes are ignored.
  void setValue(int row, int col, int value) {
    if (!isInside(row, col)) {
      return;
    }
    _cells[row * size + col] = value;
  }

  /// True when every cell of [cells] fits on the board at ([topRow],
  /// [leftCol]) without overlapping anything.
  bool canPlace(List<GridPosition> cells, int topRow, int leftCol) {
    for (final GridPosition cell in cells) {
      final int row = cell.row + topRow;
      final int col = cell.col + leftCol;
      if (!isInside(row, col)) {
        return false;
      }
      if (!isEmptyAt(row, col)) {
        return false;
      }
    }
    return true;
  }

  /// Writes [cells] with [colorIndex] at ([topRow], [leftCol]).
  /// Callers must check [canPlace] first.
  void place(List<GridPosition> cells, int topRow, int leftCol, int colorIndex) {
    final int value = colorIndex + 1;
    for (final GridPosition cell in cells) {
      setValue(cell.row + topRow, cell.col + leftCol, value);
    }
  }

  /// Indices of every completely filled row.
  List<int> fullRows() {
    final List<int> rows = <int>[];
    for (int r = 0; r < size; r++) {
      bool full = true;
      for (int c = 0; c < size; c++) {
        if (_cells[r * size + c] == empty) {
          full = false;
          break;
        }
      }
      if (full) {
        rows.add(r);
      }
    }
    return rows;
  }

  /// Indices of every completely filled column.
  List<int> fullColumns() {
    final List<int> columns = <int>[];
    for (int c = 0; c < size; c++) {
      bool full = true;
      for (int r = 0; r < size; r++) {
        if (_cells[r * size + c] == empty) {
          full = false;
          break;
        }
      }
      if (full) {
        columns.add(c);
      }
    }
    return columns;
  }

  /// Empties every cell that belongs to one of [rows] or [columns].
  int clearLines(List<int> rows, List<int> columns) {
    int cleared = 0;
    for (final int row in rows) {
      for (int col = 0; col < size; col++) {
        if (_cells[row * size + col] != empty) {
          _cells[row * size + col] = empty;
          cleared++;
        }
      }
    }
    for (final int col in columns) {
      for (int row = 0; row < size; row++) {
        if (_cells[row * size + col] != empty) {
          _cells[row * size + col] = empty;
          cleared++;
        }
      }
    }
    return cleared;
  }

  /// Number of cells that currently hold a block.
  int get filledCount {
    int count = 0;
    for (int i = 0; i < _cells.length; i++) {
      if (_cells[i] != empty) {
        count++;
      }
    }
    return count;
  }

  /// Every filled cell as `(row, col, colorIndex)`, row-major order.
  List<(int row, int col, int colorIndex)> filledCells() {
    final List<(int row, int col, int colorIndex)> result =
        <(int row, int col, int colorIndex)>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final int value = _cells[r * size + c];
        if (value != empty) {
          result.add((r, c, value - 1));
        }
      }
    }
    return result;
  }

  /// Empties the whole board. Returns the number of cells that were cleared.
  int clear() {
    int cleared = 0;
    for (int i = 0; i < _cells.length; i++) {
      if (_cells[i] != empty) {
        _cells[i] = empty;
        cleared++;
      }
    }
    return cleared;
  }

  /// True when the board holds no free cell at all.
  bool get isFull => filledCount == _cells.length;

  /// Independent copy, used for previews and tests.
  Board copy() {
    final Board clone = Board(size);
    clone._cells.setRange(0, _cells.length, _cells);
    return clone;
  }

  /// Raw bytes, used to persist a run (planned cloud save / daily replay).
  Uint8List toBytes() => Uint8List.fromList(_cells);

  /// Restores a board previously produced by [toBytes].
  void loadBytes(Uint8List bytes) {
    final int length = bytes.length < _cells.length ? bytes.length : _cells.length;
    _cells.setRange(0, length, bytes);
  }

  /// Compact textual representation, e.g. `..## / .##.`.
  String toSketch() {
    final StringBuffer buffer = StringBuffer();
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        buffer.write(_cells[r * size + c] == empty ? '.' : '#');
      }
      if (r != size - 1) {
        buffer.write('/');
      }
    }
    return buffer.toString();
  }

  @override
  String toString() => 'Board($size) ${toSketch()}';
}