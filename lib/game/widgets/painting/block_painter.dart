import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/piece_palette.dart';
import '../../../core/theme/visual_style.dart';

/// Draws one GridPop block.
///
/// The look is a glossy toy cube: a chunky rounded square body with a bright
/// top bevel, a darker bottom lip that gives it thickness, a rectangular
/// specular highlight and a soft cast shadow on the board. It reads as a
/// physical cube on a dark stage - the opposite of a flat grid of squares.
class BlockPainter {
  const BlockPainter._();

  /// Depth of the lip as a fraction of the block size.
  static const double lipFactor = 0.085;

  /// Flat light band opacity across the top of the tile.
  static const double glossOpacity = 0.30;

  /// Inner bottom shade opacity.
  static const double shadeOpacity = 0.20;

  /// Radius factor, shared with the board cell design.
  ///
  /// Pixel blocks keep hard corners, the printed style sits between the two.
  static double radiusFor(double size, {BlockStyle style = BlockStyle.soft}) {
    return switch (style) {
      BlockStyle.soft => size * BoardConfig.cornerRadiusFactor,
      BlockStyle.neon => size * 0.26,
      BlockStyle.matte => size * 0.16,
      BlockStyle.retro => size * 0.05,
    };
  }

  /// Paints a block inside [rect].
  ///
  /// [scale] shrinks the block around its centre (used for pops and for the
  /// drop animation), [alpha] fades it and [ghost] renders a preview.
  static void paint(
    Canvas canvas,
    Rect rect,
    PieceColor color, {
    double alpha = 1,
    double scale = 1,
    bool ghost = false,
    BlockStyle style = BlockStyle.soft,
  }) {
    if (rect.isEmpty || alpha <= 0) {
      return;
    }

    final Rect target = scale == 1
        ? rect
        : Rect.fromCenter(
            center: rect.center,
            width: rect.width * scale,
            height: rect.height * scale,
          );

    if (ghost) {
      _paintGhost(canvas, target, color, alpha, style);
      return;
    }

    switch (style) {
      case BlockStyle.soft:
        break;
      case BlockStyle.neon:
        _paintNeon(canvas, target, color, alpha);
        return;
      case BlockStyle.matte:
        _paintMatte(canvas, target, color, alpha);
        return;
      case BlockStyle.retro:
        _paintRetro(canvas, target, color, alpha);
        return;
    }

    final double lip = target.shortestSide * lipFactor;
    final double radius = radiusFor(target.shortestSide);

    // Cast shadow on the board below the tile: this soft drop is what makes
    // the blocks feel like objects sitting on a surface instead of flat
    // coloured squares. Two stacked layers keep it cheap (no blur filter).
    final Rect shadowRect = Rect.fromLTWH(
      target.left + target.width * 0.06,
      target.top + target.height * 0.12,
      target.width * 0.88,
      target.height * 0.88,
    );
    final RRect shadowRRect = RRect.fromRectAndRadius(
      shadowRect,
      Radius.circular(radius),
    );
    canvas.drawRRect(
      shadowRRect.shift(Offset(0, target.shortestSide * 0.05)),
      Paint()..color = Colors.black.withOpacity(0.22 * alpha),
    );
    canvas.drawRRect(
      shadowRRect.shift(Offset(0, target.shortestSide * 0.10)),
      Paint()..color = Colors.black.withOpacity(0.14 * alpha),
    );

    // Bottom lip: the visible thickness of the cube.
    final RRect lipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        target.left,
        target.top + lip,
        target.width,
        target.height - lip,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(
      lipRect,
      Paint()..color = Color.lerp(color.dark, Colors.black, 0.28)!.withOpacity(alpha),
    );

    // Body: saturated cube face with a bright top and a deep bottom.
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        target.left,
        target.top,
        target.width,
        target.height - lip * 0.55,
      ),
      Radius.circular(radius),
    );
    final Rect bodyRect = body.outerRect;
    canvas.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          bodyRect.topCenter,
          bodyRect.bottomCenter,
          <Color>[
            Color.lerp(color.light, Colors.white, 0.30)!.withOpacity(alpha),
            color.base.withOpacity(alpha),
            Color.lerp(color.base, color.dark, 0.35)!.withOpacity(alpha),
            Color.lerp(color.base, color.dark, 0.70)!.withOpacity(alpha),
          ],
          <double>[0, 0.34, 0.68, 1],
        ),
    );

    canvas.save();
    canvas.clipRRect(body);

    // Top bevel: the lit face of the cube.
    final Rect bevel = Rect.fromLTWH(
      target.left,
      target.top,
      target.width,
      target.height * 0.20,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bevel, Radius.circular(radius)),
      Paint()..color = Colors.white.withOpacity(0.16 * alpha),
    );

    // Specular highlight: a soft rectangle, never a pill or an oval.
    final Rect gloss = Rect.fromLTWH(
      target.left + target.width * 0.13,
      target.top + target.height * 0.10,
      target.width * 0.42,
      target.height * 0.13,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(gloss, Radius.circular(gloss.height * 0.40)),
      Paint()..color = Colors.white.withOpacity(glossOpacity * alpha),
    );

    // Bottom shade for volume.
    final Rect shade = Rect.fromLTWH(
      target.left,
      target.bottom - target.height * 0.34,
      target.width,
      target.height * 0.26,
    );
    canvas.drawRect(
      shade,
      Paint()..color = color.dark.withOpacity(shadeOpacity * alpha),
    );

    // Side vignettes: darker left/right edges sharpen the cube.
    final double edge = target.width * 0.05;
    canvas.drawRect(
      Rect.fromLTWH(target.left, target.top, edge, target.height),
      Paint()..color = color.dark.withOpacity(0.12 * alpha),
    );
    canvas.drawRect(
      Rect.fromLTWH(target.right - edge, target.top, edge, target.height),
      Paint()..color = color.dark.withOpacity(0.12 * alpha),
    );

    canvas.restore();

    // Bright rim around the face.
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = mathMax(1, target.shortestSide * 0.028)
        ..color = Colors.white.withOpacity(0.24 * alpha),
    );
  }

  /// Neon tube: flat face, hot rim and a soft bloom, no cast shadow.
  static void _paintNeon(
    Canvas canvas,
    Rect rect,
    PieceColor color,
    double alpha,
  ) {
    final double radius = radiusFor(rect.shortestSide, style: BlockStyle.neon);
    final RRect body = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // Bloom: one blurred copy of the accent is cheaper than a real glow pass
    // and still reads as light bleeding into the dark stage.
    canvas.drawRRect(
      body,
      Paint()
        ..color = color.accent.withOpacity(0.34 * alpha)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          rect.shortestSide * 0.22,
        ),
    );

    canvas.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          <Color>[
            color.base.withOpacity(alpha),
            Color.lerp(color.base, Colors.black, 0.30)!.withOpacity(alpha),
          ],
        ),
    );

    // Hot rim: the tube itself.
    canvas.drawRRect(
      body.deflate(rect.shortestSide * 0.055),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = mathMax(1.4, rect.shortestSide * 0.055)
        ..color = Color.lerp(color.light, Colors.white, 0.35)!
            .withOpacity(0.95 * alpha),
    );

    // Inner core: a dim centre keeps the tile from looking like a solid disc.
    canvas.drawRRect(
      body.deflate(rect.shortestSide * 0.20),
      Paint()..color = Color.lerp(color.base, Colors.white, 0.10)!
          .withOpacity(0.55 * alpha),
    );
  }

  /// Printed cardboard: flat pastel face, thin ink outline, no shine at all.
  static void _paintMatte(
    Canvas canvas,
    Rect rect,
    PieceColor color,
    double alpha,
  ) {
    final double radius = radiusFor(rect.shortestSide, style: BlockStyle.matte);
    final RRect body = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // A single soft contact shadow keeps the tile glued to the board.
    canvas.drawRRect(
      body.shift(Offset(0, rect.shortestSide * 0.04)),
      Paint()..color = Colors.black.withOpacity(0.16 * alpha),
    );

    // Pastel face: pulled towards white so the ink outline stays readable,
    // but only slightly - a matte print must not look lit from inside.
    final Color face = Color.lerp(color.base, Colors.white, 0.09)!;
    canvas.drawRRect(body, Paint()..color = face.withOpacity(alpha));

    // Ink rim, drawn inside so neighbouring tiles never touch.
    canvas.drawRRect(
      body.deflate(rect.shortestSide * 0.03),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = mathMax(1, rect.shortestSide * 0.035)
        ..color = Color.lerp(color.dark, Colors.black, 0.25)!
            .withOpacity(0.55 * alpha),
    );

    // Flat paper highlight: a thin light band, no gradient.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + rect.width * 0.14,
          rect.top + rect.height * 0.11,
          rect.width * 0.72,
          rect.height * 0.07,
        ),
        Radius.circular(rect.height * 0.035),
      ),
      Paint()..color = Colors.white.withOpacity(0.13 * alpha),
    );
  }

  /// Pixel block: hard square, chunky bevel, quantised shading, no blur.
  static void _paintRetro(
    Canvas canvas,
    Rect rect,
    PieceColor color,
    double alpha,
  ) {
    final double radius = radiusFor(rect.shortestSide, style: BlockStyle.retro);
    final RRect body = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final double bevel = mathMax(2, rect.shortestSide * 0.14);

    canvas.drawRRect(
      body,
      Paint()..color = Color.lerp(color.base, Colors.black, 0.10)!
          .withOpacity(alpha),
    );

    // Hard top bevel and bottom shade: the 8-bit cube read.
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, rect.width, bevel),
      Paint()..color = color.light.withOpacity(0.95 * alpha),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        rect.left,
        rect.bottom - bevel,
        rect.width,
        bevel,
      ),
      Paint()..color = color.dark.withOpacity(0.95 * alpha),
    );

    // Dark pixel border.
    canvas.drawRRect(
      body.deflate(rect.shortestSide * 0.02),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = mathMax(1.5, rect.shortestSide * 0.045)
        ..color = Color.lerp(color.dark, Colors.black, 0.55)!
            .withOpacity(alpha),
    );

    // Corner pixels: a tiny light square keeps the block from reading flat.
    final double dot = mathMax(2, rect.shortestSide * 0.10);
    canvas.drawRect(
      Rect.fromLTWH(
        rect.left + rect.width * 0.14,
        rect.top + rect.height * 0.22,
        dot,
        dot,
      ),
      Paint()..color = Colors.white.withOpacity(0.35 * alpha),
    );
  }

  static void _paintGhost(
    Canvas canvas,
    Rect rect,
    PieceColor color,
    double alpha,
    BlockStyle style,
  ) {
    final RRect rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(radiusFor(rect.shortestSide, style: style)),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = color.base.withOpacity(0.26 * alpha),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = mathMax(1.5, rect.shortestSide * 0.05)
        ..color = Colors.white.withOpacity(0.55 * alpha),
    );
  }

  /// Paints the empty cell socket of the board.
  static void paintCellSocket(
    Canvas canvas,
    Rect rect,
    Color color, {
    BlockStyle style = BlockStyle.soft,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(radiusFor(rect.shortestSide, style: style)),
      ),
      Paint()..color = color,
    );
  }

  static double mathMax(double a, double b) => a > b ? a : b;
}

/// Board outline: rounded panel with a soft outline and an inner vignette.
class BoardSurfacePainter extends CustomPainter {
  const BoardSurfacePainter({
    required this.surfaceColor,
    required this.outlineColor,
    required this.radius,
    required this.shadowColor,
    required this.vignetteColor,
  });

  final Color surfaceColor;
  final Color outlineColor;
  final double radius;
  final Color shadowColor;
  final Color vignetteColor;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect panel = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    // Soft drop shadow under the whole tray.
    canvas.drawRRect(
      panel.shift(const Offset(0, 8)),
      Paint()
        ..color = shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Board body.
    canvas.drawRRect(panel, Paint()..color = surfaceColor);

    canvas.save();
    canvas.clipRRect(panel);

    // Stage light: a soft pool of light over the grid so the eye lands on the
    // playfield instead of the frame.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height * 0.40),
          size.shortestSide * 0.62,
          <Color>[
            Colors.white.withOpacity(0.07),
            Colors.white.withOpacity(0.02),
            Colors.white.withOpacity(0),
          ],
          <double>[0, 0.55, 1],
        ),
    );

    // Inner shadow along the top: the tray is a recessed well.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.16),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height * 0.16),
          <Color>[Colors.black.withOpacity(0.22), Colors.black.withOpacity(0)],
        ),
    );

    // Inner vignette: the board reads as a recessed tray.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          <Color>[
            vignetteColor,
            vignetteColor.withOpacity(0),
            vignetteColor.withOpacity(0),
            vignetteColor.withOpacity(0.55),
          ],
          <double>[0, 0.35, 0.7, 1],
        ),
    );
    canvas.restore();

    // Premium frame: a bright gradient rim instead of a flat outline.
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          <Color>[
            Colors.white.withOpacity(0.55),
            Colors.white.withOpacity(0.12),
            outlineColor.withOpacity(0.9),
          ],
          <double>[0, 0.5, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(BoardSurfacePainter oldDelegate) =>
      oldDelegate.surfaceColor != surfaceColor ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.radius != radius ||
      oldDelegate.shadowColor != shadowColor ||
      oldDelegate.vignetteColor != vignetteColor;
}