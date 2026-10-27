import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/piece_palette.dart';
import '../game/widgets/painting/block_painter.dart';

/// The GridPop mark: four blocks snapping together plus one block popping out
/// of the grid. Drawn procedurally so it stays crisp at any size and uses the
/// exact same materials as the in-game blocks.
///
/// With [animate] the mark plays a one-shot entrance: each block drops into
/// place and the pop block springs out last. The animation is finite, so it is
/// safe inside `pumpAndSettle` and inside dialogs.
class LogoMark extends StatelessWidget {
  const LogoMark({
    super.key,
    this.size = 72,
    this.showPop = true,
    this.animate = false,
  });

  final double size;

  /// Draws the "pop" block that gives the game its name.
  final bool showPop;

  /// Plays the entrance animation once when first built.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (!animate) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _LogoMarkPainter(showPop: showPop, progress: 1),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: _AnimatedLogoMark(size: size, showPop: showPop),
    );
  }
}

class _AnimatedLogoMark extends StatefulWidget {
  const _AnimatedLogoMark({required this.size, required this.showPop});

  final double size;
  final bool showPop;

  @override
  State<_AnimatedLogoMark> createState() => _AnimatedLogoMarkState();
}

class _AnimatedLogoMarkState extends State<_AnimatedLogoMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 880),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          painter: _LogoMarkPainter(
            showPop: widget.showPop,
            progress: reduced ? 1 : _controller.value,
          ),
        );
      },
    );
  }
}

class _LogoMarkPainter extends CustomPainter {
  const _LogoMarkPainter({required this.showPop, required this.progress});

  final bool showPop;

  /// 0 at the start of the entrance, 1 when everything has settled.
  final double progress;

  static const List<PieceColor> _colors = <PieceColor>[
    PiecePalette.grape,
    PiecePalette.sky,
    PiecePalette.mint,
    PiecePalette.coral,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double unit = size.shortestSide / 3.6;
    final double originX = size.width / 2 - unit * 1.5;
    final double originY = size.height / 2 - unit * 1.5;

    Rect cell(int row, int col) => Rect.fromLTWH(
          originX + col * unit,
          originY + row * unit,
          unit,
          unit,
        );

    // Warm glow behind the mark, rising with the entrance.
    final double glowT = ((progress - 0.45) / 0.55).clamp(0.0, 1.0);
    if (glowT > 0) {
      final Offset center = Offset(size.width / 2, size.height / 2);
      final double radius = unit * 2.6;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              AppColors.gold.withOpacity(0.22 * glowT),
              AppColors.magenta.withOpacity(0.10 * glowT),
              Colors.transparent,
            ],
            stops: const <double>[0, 0.5, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    for (int i = 0; i < 4; i++) {
      final double start = 0.05 * i;
      final double t = ((progress - start) / 0.55).clamp(0.0, 1.0);
      if (t <= 0) {
        continue;
      }
      final double eased = Curves.easeOutBack.transform(t);
      final Rect base = cell(i ~/ 2, i % 2);
      final Rect rect = Rect.fromCenter(
        center: base.center.translate(0, -unit * 0.55 * (1 - t)),
        width: base.width * eased,
        height: base.height * eased,
      );
      BlockPainter.paint(canvas, rect, _colors[i], alpha: t.clamp(0.0, 1.0));
    }

    if (!showPop) {
      return;
    }

    final double popT = ((progress - 0.46) / 0.54).clamp(0.0, 1.0);
    final Rect poppedBase = cell(1, 1).shift(Offset(unit * 0.95, -unit * 0.95));
    final double popEase = Curves.easeOutBack.transform(popT);

    if (popT > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          poppedBase.shift(Offset(0, unit * 0.1)),
          Radius.circular(unit * 0.26),
        ),
        Paint()..color = Colors.black.withOpacity(0.18 * popT),
      );
      BlockPainter.paint(
        canvas,
        Rect.fromCenter(
          center: poppedBase.center,
          width: poppedBase.width * popEase,
          height: poppedBase.height * popEase,
        ),
        PiecePalette.sunbeam,
        alpha: popT.clamp(0.0, 1.0),
      );
    }

    // Sparkles that appear once the pop block has settled.
    final double sparkleT = ((progress - 0.82) / 0.18).clamp(0.0, 1.0);
    if (sparkleT > 0) {
      final Offset center = poppedBase.center;
      for (int i = 0; i < 4; i++) {
        final double angle = math.pi / 4 + i * math.pi / 2;
        final double distance = unit * (0.85 + 0.25 * sparkleT);
        final Offset at = center + Offset(
          math.cos(angle) * distance,
          math.sin(angle) * distance,
        );
        final double r = unit * 0.13 * sparkleT;
        canvas.drawPath(
          Path()
            ..moveTo(at.dx, at.dy - r)
            ..lineTo(at.dx + r * 0.32, at.dy)
            ..lineTo(at.dx, at.dy + r)
            ..lineTo(at.dx - r * 0.32, at.dy)
            ..close(),
          Paint()..color = Colors.white.withOpacity(0.55 * sparkleT),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LogoMarkPainter oldDelegate) =>
      oldDelegate.showPop != showPop || oldDelegate.progress != progress;
}
