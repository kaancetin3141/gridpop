import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/piece_palette.dart';
import '../../../core/utils/grid_geometry.dart';
import '../../models/grid_position.dart';
import '../../models/piece_slot.dart';
import 'block_painter.dart';

/// Paints a single piece inside an arbitrary box (tray slot, gallery, preview).
class PiecePreviewPainter extends CustomPainter {
  PiecePreviewPainter({
    required this.slot,
    required this.maxCell,
    this.opacity = 1,
    super.repaint,
  });

  final PieceSlot slot;
  final double maxCell;
  final double opacity;
  PieceColor? _overrideColor;

  set overrideColor(PieceColor? value) => _overrideColor = value;

  /// Geometry that centres the piece inside [size].
  static BoardGeometry fitGeometry({
    required Size size,
    required GridExtent extent,
    required double maxCell,
    double padding = 0.92,
  }) {
    final double available = math.min(size.width, size.height) * padding;
    final double cell = math.min(
      available / math.max(extent.height, extent.width),
      maxCell,
    );
    final double width = cell * extent.width;
    final double height = cell * extent.height;
    return BoardGeometry(
      origin: Offset(
        (size.width - width) / 2,
        (size.height - height) / 2,
      ),
      cellSize: cell,
      gap: cell * 0.09,
      rows: extent.height,
      columns: extent.width,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final BoardGeometry geometry = fitGeometry(
      size: size,
      extent: slot.extent,
      maxCell: maxCell,
    );
    final PieceColor color = _overrideColor ?? PiecePalette.byIndex(slot.colorIndex);
    for (final GridPosition cell in slot.cells) {
      BlockPainter.paint(
        canvas,
        geometry.cellRect(cell.row, cell.col),
        color,
        alpha: opacity,
      );
    }
  }

  @override
  bool shouldRepaint(PiecePreviewPainter oldDelegate) =>
      oldDelegate.slot != slot ||
      oldDelegate.maxCell != maxCell ||
      oldDelegate.opacity != opacity ||
      oldDelegate._overrideColor != _overrideColor;
}

/// Rounded holder drawn behind a tray piece.
class TraySlotPainter extends CustomPainter {
  const TraySlotPainter({
    required this.fill,
    required this.border,
    required this.radius,
    required this.glow,
    required this.glowStrength,
    this.dashed = false,
  });

  final Color fill;
  final Color border;
  final double radius;

  /// Colour of the hint glow (transparent when there is no hint).
  final Color glow;

  /// 0 to 1.
  final double glowStrength;

  /// Dashed outline, used by empty (already used) slots.
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    if (glowStrength > 0) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[glow.withOpacity(0.45 * glowStrength), Colors.transparent],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawRRect(rrect, Paint()..color = fill);

    if (dashed) {
      _drawDashed(canvas, size, border);
      return;
    }

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = border,
    );
  }

  /// Cheap dashed border: short arcs walking around the rounded rect.
  void _drawDashed(Canvas canvas, Size size, Color color) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color;
    final Rect bounds = Offset.zero & size;
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(bounds.deflate(1), Radius.circular(radius)),
      );
    for (final ui.PathMetric metric in path.computeMetrics()) {
      const double dash = 6;
      const double gap = 5;
      double distance = 0;
      while (distance < metric.length) {
        final double end =
            (distance + dash).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(TraySlotPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.border != border ||
      oldDelegate.radius != radius ||
      oldDelegate.glow != glow ||
      oldDelegate.glowStrength != glowStrength ||
      oldDelegate.dashed != dashed;
}