import '../../core/constants/piece_catalog.dart';
import 'grid_position.dart';

/// A rotatable puzzle shape.
///
/// A shape is defined once (see `PieceCatalog`) and pre-computes its four
/// rotations. Symmetric shapes such as a straight line only produce two unique
/// orientations, which is handled automatically by [uniqueRotations].
class PieceShape {
  PieceShape._({
    required this.id,
    required this.labelKey,
    required this.weight,
    required this.tier,
    required List<List<GridPosition>> rotations,
    required int uniqueRotations,
    required this.cellCount,
  })  : _rotations = rotations,
        _uniqueRotations = uniqueRotations;

  /// Builds a shape from its blueprint, pre-computing all rotations.
  factory PieceShape.fromBlueprint(PieceBlueprint blueprint) {
    final List<GridPosition> base = blueprint.cells
        .map((List<int> cell) => GridPosition(cell[0], cell[1]))
        .toList(growable: false);

    final List<List<GridPosition>> rotations = <List<GridPosition>>[base];
    List<GridPosition> current = base;
    for (int i = 1; i < 4; i++) {
      current = _rotateClockwise(current);
      rotations.add(current);
    }

    int unique = 0;
    for (int i = 0; i < rotations.length; i++) {
      bool alreadySeen = false;
      for (int j = 0; j < i; j++) {
        if (_sameCells(rotations[i], rotations[j])) {
          alreadySeen = true;
          break;
        }
      }
      if (!alreadySeen) {
        unique++;
      }
    }

    return PieceShape._(
      id: blueprint.id,
      labelKey: blueprint.labelKey,
      weight: blueprint.weight,
      tier: blueprint.tier,
      rotations: rotations,
      uniqueRotations: unique,
      cellCount: base.length,
    );
  }

  final String id;
  final String labelKey;
  final double weight;
  final int tier;

  final List<List<GridPosition>> _rotations;
  final int _uniqueRotations;
  final int cellCount;

  /// Number of visually distinct orientations (1 to 4).
  int get uniqueRotations => _uniqueRotations;

  /// Cells of the requested orientation, normalised to the top-left corner.
  List<GridPosition> cellsFor(int rotation) =>
      _rotations[rotation % _uniqueRotations];

  /// Bounding box of the requested orientation.
  GridExtent extentFor(int rotation) {
    final List<GridPosition> cells = cellsFor(rotation);
    var maxRow = 0;
    var maxCol = 0;
    for (final GridPosition cell in cells) {
      if (cell.row > maxRow) maxRow = cell.row;
      if (cell.col > maxCol) maxCol = cell.col;
    }
    return GridExtent(maxRow + 1, maxCol + 1);
  }

  /// Next orientation, cycling through the distinct ones.
  int nextRotation(int rotation) => (rotation + 1) % _uniqueRotations;

  @override
  String toString() => 'PieceShape($id)';

  static List<GridPosition> _rotateClockwise(List<GridPosition> cells) {
    final List<GridPosition> turned = cells
        .map((GridPosition cell) => GridPosition(cell.col, -cell.row))
        .toList(growable: true);
    int minRow = turned.first.row;
    int minCol = turned.first.col;
    for (final GridPosition cell in turned) {
      if (cell.row < minRow) minRow = cell.row;
      if (cell.col < minCol) minCol = cell.col;
    }
    for (int i = 0; i < turned.length; i++) {
      turned[i] = GridPosition(turned[i].row - minRow, turned[i].col - minCol);
    }
    return List<GridPosition>.unmodifiable(turned);
  }

  static bool _sameCells(List<GridPosition> a, List<GridPosition> b) {
    if (a.length != b.length) {
      return false;
    }
    final List<String> left = a
        .map((GridPosition c) => '${c.row}:${c.col}')
        .toList(growable: false)
      ..sort();
    final List<String> right = b
        .map((GridPosition c) => '${c.row}:${c.col}')
        .toList(growable: false)
      ..sort();
    for (int i = 0; i < left.length; i++) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }
}

/// Lazily built runtime cache so we never rebuild a shape per game frame.
class PieceShapeLibrary {
  PieceShapeLibrary._(this._shapes);

  final Map<String, PieceShape> _shapes;

  /// Builds (and caches) every shape of the catalogue.
  factory PieceShapeLibrary.build() {
    final Map<String, PieceShape> shapes = <String, PieceShape>{};
    for (final PieceBlueprint blueprint in PieceCatalog.all) {
      shapes[blueprint.id] = PieceShape.fromBlueprint(blueprint);
    }
    return PieceShapeLibrary._(shapes);
  }

  PieceShape byId(String id) => _shapes[id] ?? PieceShape.fromBlueprint(PieceCatalog.dot);

  List<PieceShape> get all => _shapes.values.toList(growable: false);
}