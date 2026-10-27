import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/piece_palette.dart';
import '../core/theme/visual_style.dart';
import '../game/widgets/painting/block_painter.dart';

/// Miniature preview of a [VisualStyle].
///
/// It draws the real stage gradient of the style plus three blocks painted by
/// the very painter the board uses, so the swatch can never drift away from
/// what the player will actually see.
class StyleSwatch extends StatelessWidget {
  const StyleSwatch({
    super.key,
    required this.style,
    this.size = 56,
    this.radius = AppRadius.sm,
  });

  final VisualStyle style;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final StylePalette palette = VisualStyleSpec.of(style).palette(brightness);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StyleSwatchPainter(
          style: style,
          palette: palette,
          radius: radius,
        ),
      ),
    );
  }
}

class _StyleSwatchPainter extends CustomPainter {
  _StyleSwatchPainter({
    required this.style,
    required this.palette,
    required this.radius,
  });

  final VisualStyle style;
  final StylePalette palette;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect card = RRect.fromRectAndRadius(
      rect,
      Radius.circular(radius),
    );
    final VisualStyleSpec spec = VisualStyleSpec.of(style);

    canvas.save();
    canvas.clipRRect(card);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: palette.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );

    if (spec.gridFloor) {
      _paintGrid(canvas, size);
    }
    if (spec.scanlines) {
      _paintScanlines(canvas, size);
    }
    if (spec.blooms) {
      // One cheap radial bloom, the same trick the real stage uses.
      canvas.drawCircle(
        Offset(size.width * 0.28, size.height * 0.24),
        size.width * 0.52,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              palette.accent.withValues(alpha: 0.42),
              palette.accent.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    _paintBlocks(canvas, size);
    canvas.restore();
  }

  void _paintGrid(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = palette.accent.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    const int divisions = 4;
    for (int i = 1; i < divisions; i++) {
      final double t = i / divisions;
      canvas.drawLine(
        Offset(0, size.height * t),
        Offset(size.width, size.height * t),
        line,
      );
      canvas.drawLine(
        Offset(size.width * t, 0),
        Offset(size.width * t, size.height),
        line,
      );
    }
  }

  void _paintScanlines(Canvas canvas, Size size) {
    final Paint line = Paint()..color = Colors.black.withValues(alpha: 0.14);
    final double step = size.height / 16;
    for (double y = 0; y < size.height; y += step) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, step * 0.45), line);
    }
  }

  void _paintBlocks(Canvas canvas, Size size) {
    final double cell = size.width * 0.31;
    const List<Offset> anchors = <Offset>[
      Offset(0.11, 0.16),
      Offset(0.50, 0.30),
      Offset(0.30, 0.54),
    ];
    for (int i = 0; i < anchors.length; i++) {
      final Rect block = Rect.fromLTWH(
        size.width * anchors[i].dx,
        size.height * anchors[i].dy,
        cell,
        cell,
      );
      BlockPainter.paint(
        canvas,
        block,
        PiecePalette.byIndex(i * 2),
        style: style.block,
      );
    }
  }

  @override
  bool shouldRepaint(_StyleSwatchPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.palette != palette ||
      oldDelegate.radius != radius;
}
