import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/grid_geometry.dart';
import '../../models/grid_position.dart';
import '../../models/placement_outcome.dart';
import '../../../core/theme/visual_style.dart';
import 'block_painter.dart';
import '../effects/effects_layer.dart';

/// Draws every transient effect on top of the board.
///
/// The painter is driven entirely by [GameEffects] (passed as `repaint`), so it
/// never triggers a widget rebuild.
class EffectsPainter extends CustomPainter {
  EffectsPainter({
    required this.effects,
    required this.geometry,
    this.blockStyle = BlockStyle.soft,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final GameEffects effects;
  final BoardGeometry geometry;
  final BlockStyle blockStyle;

  @override
  void paint(Canvas canvas, Size size) {
    _paintComboRing(canvas);
    _paintHint(canvas);
    _paintPlaced(canvas);
    _paintClear(canvas);
    _paintBursts(canvas);
    _paintParticles(canvas);
    _paintScoreFloat(canvas);
    _paintBanner(canvas);
    _paintNoMove(canvas);
    _paintInvalid(canvas);
    _paintFlash(canvas, size);
  }

  // --- explosion bursts ---------------------------------------------------

  void _paintBursts(Canvas canvas) {
    if (effects.bursts.isEmpty) {
      return;
    }
    final double cell = geometry.cellSize;
    for (final LineBurst burst in effects.bursts) {
      final double t = ((effects.now - burst.start).inMicroseconds /
              burst.duration.inMicroseconds)
          .clamp(0.0, 1.0);
      final double grow = Curves.easeOutCubic.transform(t);
      final double alpha = (1 - t).clamp(0.0, 1.0);
      if (alpha <= 0.01) {
        continue;
      }
      final Color color = effects.colorFor(burst.colorIndex).accent;
      final bool horizontal = burst.isRow;
      final Rect anchor = horizontal
          ? geometry.cellRect(burst.row, 0)
          : geometry.cellRect(0, burst.column);
      // gridOrigin is the bottom-right corner, so the line centre comes from
      // the top-left origin plus half the grid.
      final Offset center = horizontal
          ? Offset(
              geometry.origin.dx + geometry.gridWidth / 2,
              anchor.center.dy,
            )
          : Offset(
              anchor.center.dx,
              geometry.origin.dy + geometry.gridHeight / 2,
            );

      // Expanding shock band along the cleared line.
      final double thickness = cell * (0.22 + 1.0 * grow);
      final Rect band = horizontal
          ? Rect.fromCenter(
              center: center,
              width: geometry.gridWidth + cell * 0.5,
              height: thickness,
            )
          : Rect.fromCenter(
              center: center,
              width: thickness,
              height: geometry.gridHeight + cell * 0.5,
            );
      canvas.drawRRect(
        RRect.fromRectAndRadius(band, Radius.circular(thickness * 0.24)),
        Paint()
          ..shader = ui.Gradient.linear(
            horizontal ? band.centerLeft : band.topCenter,
            horizontal ? band.centerRight : band.bottomCenter,
            <Color>[
              color.withOpacity(0),
              color.withOpacity(alpha * 0.85),
              Colors.white.withOpacity(alpha * 0.9),
              color.withOpacity(alpha * 0.85),
              color.withOpacity(0),
            ],
            <double>[0, 0.28, 0.5, 0.72, 1],
          ),
      );

      // Expanding shock ring from the middle of the line.
      final double ringRadius = cell * (0.45 + grow * 3.6);
      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.16 * (1 - t)
          ..color = Colors.white.withOpacity(alpha * 0.38),
      );
      canvas.drawCircle(
        center,
        ringRadius * 0.78,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.10 * (1 - t)
          ..color = color.withOpacity(alpha * 0.42),
      );
    }
  }

  // --- combo ring ---------------------------------------------------------

  void _paintComboRing(Canvas canvas) {
    final ComboBanner? banner = effects.banner;
    if (banner == null || banner.level < 3) {
      return;
    }
    final Duration total = banner.duration;
    final double t =
        ((effects.now - banner.start).inMicroseconds / total.inMicroseconds)
            .clamp(0.0, 1.0);
    final double alpha = (1 - t) * 0.5;
    if (alpha <= 0.01) {
      return;
    }

    final Rect grid = Rect.fromPoints(geometry.origin, geometry.gridOrigin);
    final Rect ring = grid.inflate(geometry.cellSize * 0.22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(ring, Radius.circular(geometry.cellSize * 0.4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = geometry.cellSize * 0.14
        ..shader = ui.Gradient.radial(
          ring.center,
          ring.shortestSide / 2,
          <Color>[
            AppColors.gold.withOpacity(alpha),
            AppColors.magenta.withOpacity(alpha * 0.8),
            AppColors.magenta.withOpacity(0),
          ],
          <double>[0, 0.7, 1],
        ),
    );
  }

  // --- hint ---------------------------------------------------------------

  void _paintHint(Canvas canvas) {
    final HintWave? hint = effects.hint;
    if (hint == null) {
      return;
    }
    final double t = ((effects.now - hint.start).inMicroseconds /
            hint.duration.inMicroseconds)
        .clamp(0.0, 1.0);
    // Three soft pulses, then a fade out.
    final double pulse = math.sin(t * math.pi * 3) * 0.5 + 0.5;
    final double alpha = (1 - t) * (0.35 + 0.45 * pulse);
    for (final GridPosition cell in hint.cells) {
      BlockPainter.paint(
        canvas,
        geometry.cellRect(cell.row, cell.col),
        effects.colorFor(hint.colorIndex),
        alpha: alpha,
        ghost: true,
        style: blockStyle,
      );
    }
  }

  // --- placed blocks ------------------------------------------------------

  void _paintPlaced(Canvas canvas) {
    const Duration settle = Duration(milliseconds: 160);
    // Freeze frame: the placed block holds its first pose for a few frames.
    final double hold = effects.hitStopProgress;
    for (final PlacedCell entry in effects.placed) {
      final Duration age = effects.now - entry.start;
      if (age.isNegative) {
        continue;
      }
      final double t = (age.inMicroseconds / settle.inMicroseconds).clamp(0.0, 1.0);
      // Overshoot: quick pop up, then settle onto the board.
      final double scale = t < 0.6
          ? Curves.easeOutBack.transform(t / 0.6)
          : 1 - 0.04 * Curves.easeIn.transform((t - 0.6) / 0.4);
      final double frozen = hold > 0
          ? (Curves.easeOutBack.transform(hold) * 0.12 + 0.9)
          : 1;
      final Rect rect =
          geometry.cellRect(entry.cell.position.row, entry.cell.position.col);
      BlockPainter.paint(
        canvas,
        rect,
        effects.colorFor(entry.cell.colorIndex),
        scale: (scale * frozen).clamp(0.2, 1.3),
        alpha: t < 0.2 ? t / 0.2 : 1,
        style: blockStyle,
      );
    }
  }

  // --- no move warning ---------------------------------------------------

  void _paintNoMove(Canvas canvas) {
    final NoMovePulse? pulse = effects.noMove;
    if (pulse == null) {
      return;
    }
    final double t =
        ((effects.now - pulse.start).inMicroseconds /
                pulse.duration.inMicroseconds)
            .clamp(0.0, 1.0);
    final double wave = math.sin(t * math.pi * 2) * 0.5 + 0.5;
    final Color color = pulse.fatal ? AppColors.danger : AppColors.warning;
    final double alpha = (1 - t) * (0.18 + 0.22 * wave);
    final Rect grid = Rect.fromPoints(geometry.origin, geometry.gridOrigin);
    final Rect board = grid.inflate(geometry.cellSize * 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, Radius.circular(geometry.cellSize * 0.45)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = geometry.cellSize * 0.12
        ..color = color.withOpacity(alpha),
    );
  }

  // --- rejected drop ------------------------------------------------------

  void _paintInvalid(Canvas canvas) {
    final InvalidDrop? drop = effects.invalid;
    if (drop == null) {
      return;
    }
    final double t = ((effects.now - drop.start).inMicroseconds /
            drop.duration.inMicroseconds)
        .clamp(0.0, 1.0);
    final double alpha = (1 - t).clamp(0.0, 1.0);
    final double cell = geometry.cellSize;
    for (final GridPosition position in drop.cells) {
      final Rect rect = geometry.cellRect(position.row, position.col);
      final RRect rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(
            BlockPainter.radiusFor(rect.shortestSide, style: blockStyle)),
      );
      canvas.drawRRect(
        rrect,
        Paint()..color = AppColors.danger.withOpacity(0.20 * alpha),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.4, cell * 0.07 * alpha)
          ..color = AppColors.danger.withOpacity(0.85 * alpha),
      );
    }
  }

  // --- line clear ---------------------------------------------------------

  void _paintClear(Canvas canvas) {
    final ClearWave? wave = effects.clear;
    if (wave == null) {
      return;
    }
    final Duration total = wave.duration;
    final double t =
        ((effects.now - wave.start).inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);

    final Set<int> rows = wave.rows.toSet();
    final Set<int> cols = wave.columns.toSet();
    final double columnCenter = (geometry.columns - 1) / 2;
    final double rowCenter = (geometry.rows - 1) / 2;
    final double halfColumns = math.max(1, geometry.columns / 2);
    final double halfRows = math.max(1, geometry.rows / 2);

    for (final TintedCell cell in wave.cells) {
      final int row = cell.position.row;
      final int col = cell.position.col;

      // Ripple: cells pop away from the middle of the cleared line instead of
      // all at the same instant.
      double delay = 0;
      double spinDir = 0;
      if (rows.contains(row)) {
        final double d = (col - columnCenter) / halfColumns;
        delay = math.max(delay, d.abs() * 0.16);
        spinDir += d;
      }
      if (cols.contains(col)) {
        final double d = (row - rowCenter) / halfRows;
        delay = math.max(delay, d.abs() * 0.16);
        spinDir += d;
      }
      final double localT = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);

      // Phase 1: brief flash + grow. Phase 2: shrink away.
      final double grow = localT < 0.35
          ? Curves.easeOut.transform(localT / 0.35) * 0.22
          : 0.22 * (1 - Curves.easeIn.transform((localT - 0.35) / 0.65));
      final double alpha = localT < 0.45
          ? 1.0
          : (1 - (localT - 0.45) / 0.55).clamp(0.0, 1.0);
      final double angle =
          spinDir * 0.12 * math.sin(localT * math.pi).clamp(0.0, 1.0);

      final Rect rect = geometry.cellRect(row, col);
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(angle);
      canvas.translate(-rect.center.dx, -rect.center.dy);
      BlockPainter.paint(
        canvas,
        rect,
        effects.colorFor(cell.colorIndex),
        scale: 1 + grow,
        alpha: alpha,
        style: blockStyle,
      );
      // White hot core while the cell is flashing.
      if (localT < 0.35) {
        final double core = (1 - localT / 0.35) * 0.85;
        final Rect inner = rect.deflate(rect.shortestSide * 0.08);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            inner,
            Radius.circular(inner.shortestSide * 0.12),
          ),
          Paint()..color = Colors.white.withOpacity(core),
        );
      }
      canvas.restore();
    }

    _paintSweep(canvas, wave, t);
  }

  void _paintSweep(Canvas canvas, ClearWave wave, double t) {
    final double cell = geometry.cellSize;
    final double travel = Curves.easeOutCubic.transform(t);
    final double thickness = cell * 0.42;
    final double alpha = (1 - t).clamp(0.0, 1.0) * 0.75;

    for (final int row in wave.rows) {
      final double y = geometry.cellRect(row, 0).center.dy;
      final double x = geometry.origin.dx + travel * (geometry.gridWidth + cell);
      final Rect band = Rect.fromCenter(
        center: Offset(x - cell, y),
        width: cell * 2.2,
        height: thickness,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(band, Radius.circular(thickness / 2)),
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(
            band.centerLeft,
            band.centerRight,
            <Color>[
              Colors.white.withOpacity(0),
              Colors.white.withOpacity(alpha),
              Colors.white.withOpacity(0),
            ],
            <double>[0, 0.5, 1],
          ),
      );
    }

    for (final int col in wave.columns) {
      final double x = geometry.cellRect(0, col).center.dx;
      final double y = geometry.origin.dy + travel * (geometry.gridHeight + cell);
      final Rect band = Rect.fromCenter(
        center: Offset(x, y - cell),
        width: thickness,
        height: cell * 2.2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(band, Radius.circular(thickness / 2)),
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(
            band.topCenter,
            band.bottomCenter,
            <Color>[
              Colors.white.withOpacity(0),
              Colors.white.withOpacity(alpha),
              Colors.white.withOpacity(0),
            ],
            <double>[0, 0.5, 1],
          ),
      );
    }
  }

  // --- particles ----------------------------------------------------------

  void _paintParticles(Canvas canvas) {
    final double cell = geometry.cellSize;
    for (final Particle particle in effects.particles) {
      final Duration life = particle.life;
      final double t = ((effects.now - particle.start).inMicroseconds / life.inMicroseconds)
          .clamp(0.0, 1.0);
      final Offset position = Offset(
        geometry.origin.dx + particle.column * cell,
        geometry.origin.dy + particle.row * cell,
      );
      final double size = cell * particle.size * (1 - t * 0.5);
      final double angle = particle.spin * t;
      final Color color = effects.colorFor(particle.colorIndex).base;

      if (particle.soft) {
        // Landing dust: a soft mote that puffs out and fades.
        final double puff = 1 + t * 1.5;
        final double radius = cell * particle.size * puff;
        canvas.drawCircle(
          position,
          radius,
          Paint()
            ..shader = ui.Gradient.radial(
              position,
              radius,
              <Color>[
                Color.lerp(color, Colors.white, 0.55)!
                    .withOpacity((1 - t) * 0.34),
                color.withOpacity((1 - t) * 0.16),
                color.withOpacity(0),
              ],
              <double>[0, 0.55, 1],
            ),
        );
        continue;
      }

      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(angle);

      if (particle.star) {
        // Four pointed spark: two crossed tapered quads.
        final Paint paint = Paint()..color = color.withOpacity((1 - t) * 0.95);
        final Path star = Path()
          ..moveTo(0, -size)
          ..lineTo(size * 0.26, 0)
          ..lineTo(0, size)
          ..lineTo(-size * 0.26, 0)
          ..close();
        canvas.drawPath(star, paint);
        canvas.drawPath(
          Path()
            ..moveTo(-size, 0)
            ..lineTo(0, size * 0.26)
            ..lineTo(size, 0)
            ..lineTo(0, -size * 0.26)
            ..close(),
          paint,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: size, height: size),
            Radius.circular(size * 0.08),
          ),
          Paint()..color = color.withOpacity((1 - t) * 0.95),
        );
      }
      canvas.restore();
    }
  }

  // --- score popup -------------------------------------------------------

  void _paintScoreFloat(Canvas canvas) {
    final ScoreFloat? score = effects.score;
    if (score == null) {
      return;
    }
    final Duration total = score.duration;
    final double t =
        ((effects.now - score.start).inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
    final Offset base = geometry.cellCenter(score.row.round(), score.column.round());
    final double rise = Curves.easeOutCubic.transform(t) * geometry.cellSize * 1.6;
    final double alpha = t < 0.7 ? 1 : 1 - (t - 0.7) / 0.3;
    final double scale = t < 0.25
        ? 0.6 + 0.55 * Curves.easeOutBack.transform(t / 0.25)
        : 1.15 - 0.15 * t;

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: '+${score.points}',
        style: TextStyle(
          fontSize: geometry.cellSize * 0.46,
          fontWeight: FontWeight.w800,
          color: Colors.white.withOpacity(alpha),
          shadows: <Shadow>[
            Shadow(
              color: effects.colorFor(score.colorIndex).dark.withOpacity(alpha * 0.9),
              blurRadius: geometry.cellSize * 0.18,
              offset: Offset(0, geometry.cellSize * 0.05),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(base.dx, base.dy - rise);
    canvas.scale(scale);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  // --- combo banner ------------------------------------------------------

  void _paintBanner(Canvas canvas) {
    final ComboBanner? banner = effects.banner;
    if (banner == null) {
      return;
    }
    final Duration total = banner.duration;
    final double t =
        ((effects.now - banner.start).inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
    final double inT = (t / 0.18).clamp(0.0, 1.0);
    final double outT = t > 0.72 ? (t - 0.72) / 0.28 : 0.0;
    final double scale = Curves.elasticOut.transform(inT) * (1 - outT * 0.35);
    final double alpha = (1 - outT).clamp(0.0, 1.0);
    // The headline sits in the upper third and drifts up while it fades: it
    // must never cover the line that is being cleared.
    final Offset center = Offset(
      geometry.origin.dx + geometry.gridWidth / 2,
      geometry.origin.dy +
          geometry.gridHeight * 0.24 -
          t * geometry.gridHeight * 0.08,
    );

    final String headline = banner.label;
    final TextPainter painter = TextPainter(
      text: TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: headline,
            style: TextStyle(
              fontSize: geometry.cellSize * 0.48,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: AppColors.gold.withOpacity(alpha),
              shadows: <Shadow>[
                Shadow(
                  color: AppColors.indigo.withOpacity(alpha * 0.7),
                  blurRadius: geometry.cellSize * 0.4,
                  offset: Offset(0, geometry.cellSize * 0.08),
                ),
              ],
            ),
          ),
          if (banner.level >= 2)
            TextSpan(
              text: '  ${banner.multiplier.toStringAsFixed(1)}x',
              style: TextStyle(
                fontSize: geometry.cellSize * 0.27,
                fontWeight: FontWeight.w800,
                color: Colors.white.withOpacity(alpha),
              ),
            ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    // Sunburst behind the headline: rotating wedges that read as an impact
    // flash without a single blur filter.
    final double rays = alpha * (0.5 + 0.5 * inT);
    if (rays > 0.02) {
      const int count = 12;
      final double radius = geometry.cellSize * 3.2;
      final double rotation = t * 0.8;
      for (int i = 0; i < count; i++) {
        final double angle = rotation + (i / count) * math.pi * 2;
        final Path wedge = Path()
          ..moveTo(0, 0)
          ..lineTo(
            math.cos(angle - 0.055) * radius,
            math.sin(angle - 0.055) * radius,
          )
          ..lineTo(
            math.cos(angle + 0.055) * radius,
            math.sin(angle + 0.055) * radius,
          )
          ..close();
        canvas.drawPath(
          wedge,
          Paint()
            ..color = (i.isEven ? AppColors.gold : Colors.white)
                .withOpacity(rays * (i.isEven ? 0.20 : 0.12)),
        );
      }
    }

    // Soft plate behind the text for readability on any background.
    final Rect plate = Rect.fromCenter(
      center: Offset.zero,
      width: painter.width + geometry.cellSize * 0.5,
      height: painter.height + geometry.cellSize * 0.28,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        plate,
        Radius.circular(geometry.cellSize * 0.45),
      ),
      Paint()..color = AppColors.indigo.withOpacity(alpha * 0.72),
    );
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  // --- full board flash --------------------------------------------------

  void _paintFlash(Canvas canvas, Size size) {
    final double flash = effects.flash;
    if (flash <= 0) {
      return;
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white.withOpacity(flash * 0.35),
    );
  }

  @override
  bool shouldRepaint(EffectsPainter oldDelegate) =>
      oldDelegate.effects != effects ||
      oldDelegate.geometry != geometry ||
      oldDelegate.blockStyle != blockStyle;
}