import 'package:flutter_test/flutter_test.dart';
import 'package:gridpop/core/constants/piece_catalog.dart';
import 'package:gridpop/game/models/grid_position.dart';
import 'package:gridpop/game/models/piece_shape.dart';
import 'package:gridpop/game/models/piece_slot.dart';

PieceShape shapeOf(String id) =>
    PieceShape.fromBlueprint(PieceCatalog.byId(id)!);

PieceSlot slotOf(String id, {int colorIndex = 0, int rotation = 0}) =>
    PieceSlot(index: 0, shape: shapeOf(id), colorIndex: colorIndex, rotation: rotation);

void main() {
  group('PieceShape', () {
    test('every catalogue entry produces a usable shape', () {
      for (final PieceBlueprint blueprint in PieceCatalog.all) {
        final PieceShape shape = PieceShape.fromBlueprint(blueprint);
        expect(shape.id, blueprint.id);
        expect(shape.cellCount, blueprint.cellCount);
        expect(shape.uniqueRotations, inInclusiveRange(1, 4));
        expect(shape.cellsFor(0).length, shape.cellCount);
      }
    });

    test('rotations are normalised to the top-left corner', () {
      final PieceShape shape = shapeOf('spire');
      for (int rotation = 0; rotation < shape.uniqueRotations; rotation++) {
        final List<GridPosition> cells = shape.cellsFor(rotation);
        var minRow = cells.first.row;
        var minCol = cells.first.col;
        for (final GridPosition cell in cells) {
          if (cell.row < minRow) minRow = cell.row;
          if (cell.col < minCol) minCol = cell.col;
        }
        expect(minRow, 0, reason: 'rotation $rotation must start at row 0');
        expect(minCol, 0, reason: 'rotation $rotation must start at col 0');
      }
    });

    test('rotations keep the cell count', () {
      for (final PieceBlueprint blueprint in PieceCatalog.all) {
        final PieceShape shape = PieceShape.fromBlueprint(blueprint);
        for (int rotation = 0; rotation < 4; rotation++) {
          expect(shape.cellsFor(rotation).length, blueprint.cellCount);
        }
      }
    });

    test('symmetric shapes report fewer unique rotations', () {
      expect(shapeOf('beam').uniqueRotations, 2);
      expect(shapeOf('block').uniqueRotations, 1);
      expect(shapeOf('tee').uniqueRotations, 4);
    });

    test('rotating a T four times returns to the original orientation', () {
      final PieceSlot slot = slotOf('tee');
      PieceSlot rotated = slot;
      for (int i = 0; i < slot.shape.uniqueRotations; i++) {
        rotated = rotated.rotated();
      }
      expect(rotated.rotation, 0);
      expect(rotated.cells, slot.cells);
    });

    test('extent reflects the current orientation', () {
      final PieceSlot horizontal = slotOf('rail');
      expect(horizontal.extent.height, 1);
      expect(horizontal.extent.width, 4);

      final PieceSlot vertical = slotOf('rail', rotation: 1);
      expect(vertical.extent.height, 4);
      expect(vertical.extent.width, 1);
    });

    test('rotating a symmetric piece is a no-op', () {
      final PieceSlot slot = slotOf('block');
      expect(slot.shape.uniqueRotations, 1);
      expect(slot.rotated().rotation, 0);
    });
  });
}