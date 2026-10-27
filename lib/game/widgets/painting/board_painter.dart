import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/piece_palette.dart';
import '../../../core/utils/grid_geometry.dart';
import '../../models/board.dart';
import '../../models/grid_position.dart';
import 'block_painter.dart';

/// Placement preview shown while dragging.
class GhostPreview {
  const GhostPreview({
    required this.topRow,
    required this.leftCol,
    required this.cells,
    required this.color,
    required this.isValid,
  });

  final int topRow;
  final int leftCol;
  final List<GridPosition> cells;
  final PieceColor color;
  final bool isValid;
}

/// Paints the whole board: sockets, placed blocks and the drop preview.
///
/// It receives the mutable [Board] instance and listenables, so a repaint never
/// rebuilds a single widget.
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.board,
    required this.geometry,
    required this.palette,
    required this.cellColor,
    required this.surfaceColor,
    required ValueListenable<GhostPreview?> ghost,
    required Listenable repaint,
    this.aiming = false,
  })  : _ghost = ghost,
        super(repaint: Listenable.merge(<Listenable>[repaint, ghost]));

  final Board board;
  final BoardGeometry geometry;
  final AppPalette palette;
  final Color cellColor;
  final Color surfaceColor;
  final ValueListenable<GhostPreview?> _ghost;

  /// True while the hammer/bomb is waiting for a target: every block gets a
  /// bright rim so the player can see what can be smashed.
  final bool aiming;

  @override
  void paint(Canvas canvas, Size size) {
    _paintCells(canvas);
    _paintBlocks(canvas);
    if (aiming) {
      _paintAimTargets(canvas);
    }
    _paintGhost(canvas);
  }

  void _paintCells(Canvas canvas) {
    // Sockets are drawn as recessed wells: a light top edge, a dark bottom
    // edge and a soft rim. That depth is what makes the board read as a
    // designed playfield instead of a flat grid of squares.
    final double side = geometry.cellSize - geometry.gap;
    final double radius = BlockPainter.radiusFor(side);
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, side, side),
      Radius.circular(radius),
    );

    final Color top = Color.lerp(cellColor, Colors.white, 0.10) ?? cellColor;
    final Color bottom = Color.lerp(cellColor, Colors.black, 0.30) ?? cellColor;

    for (int row = 0; row < geometry.rows; row++) {
      for (int col = 0; col < geometry.columns; col++) {
        final Rect origin = geometry.cellRect(row, col);
        canvas.save();
        canvas.translate(origin.left, origin.top);
        canvas.drawRRect(
          rrect,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset.zero,
              Offset(0, side),
              <Color>[top, cellColor, bottom],
              <double>[0, 0.55, 1],
            ),
        );
        // Sockets are wells: a dark top lip and a soft lit bottom edge.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, side, side * 0.16),
            Radius.circular(radius),
          ),
          Paint()..color = Colors.black.withOpacity(0.16),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, side * 0.84, side, side * 0.16),
            Radius.circular(radius),
          ),
          Paint()..color = Colors.white.withOpacity(0.05),
        );
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = Colors.white.withOpacity(0.07),
        );
        canvas.restore();
      }
    }
  }

  void _paintBlocks(Canvas canvas) {
    for (int row = 0; row < geometry.rows; row++) {
      for (int col = 0; col < geometry.columns; col++) {
        final int raw = board.valueAt(row, col);
        if (raw == Board.empty) {
          continue;
        }
        BlockPainter.paint(
          canvas,
          geometry.cellRect(row, col),
          PiecePalette.byIndex(raw - 1),
        );
      }
    }
  }

  void _paintGhost(Canvas canvas) {
    final GhostPreview? ghost = _ghost.value;
    if (ghost == null) {
      return;
    }
    final PieceColor color = ghost.isValid ? ghost.color : PiecePalette.byIndex(0);
    for (final GridPosition cell in ghost.cells) {
      final Rect rect = geometry.cellRect(
        cell.row + ghost.topRow,
        cell.col + ghost.leftCol,
      );
      if (!ghost.isValid) {
        BlockPainter.paint(canvas, rect, color, alpha: 0.35, ghost: true);
      } else {
        BlockPainter.paint(canvas, rect, color, alpha: 0.9, ghost: true);
      }
    }
  }

  /// Soft white rim on every block while a smashing power-up is armed.
  void _paintAimTargets(Canvas canvas) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.55);
    for (int row = 0; row < geometry.rows; row++) {
      for (int col = 0; col < geometry.columns; col++) {
        if (board.valueAt(row, col) == Board.empty) {
          continue;
        }
        final Rect rect = geometry.cellRect(row, col).deflate(1.5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(BlockPainter.radiusFor(rect.width)),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) =>
      oldDelegate.board != board ||
      oldDelegate.geometry != geometry ||
      oldDelegate.palette != palette ||
      oldDelegate.cellColor != cellColor ||
      oldDelegate.aiming != aiming ||
      oldDelegate._ghost != _ghost;
}