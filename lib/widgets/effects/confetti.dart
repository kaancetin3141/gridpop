import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/piece_palette.dart';

/// One-shot confetti rain used to celebrate a new personal best.
///
/// Everything is procedural (no image assets) and the animation is finite, so
/// it never keeps a frame scheduler alive once the burst is over.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.pieces = 46,
    this.duration = const Duration(milliseconds: 2400),
    this.seed = 17,
  });

  final int pieces;
  final Duration duration;
  final int seed;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final List<_ConfettiPiece> _pieces =
      _ConfettiPiece.generate(widget.pieces, widget.seed);

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
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ConfettiPainter(progress: _controller, pieces: _pieces),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

enum _ConfettiShape { chip, ribbon, dot }

class _ConfettiPiece {
  const _ConfettiPiece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.color,
    required this.spin,
    required this.sway,
    required this.phase,
    required this.shape,
  });

  final double x;
  final double delay;
  final double speed;
  final double size;
  final Color color;
  final double spin;
  final double sway;
  final double phase;
  final _ConfettiShape shape;

  static List<_ConfettiPiece> generate(int count, int seed) {
    final math.Random random = math.Random(seed);
    return <_ConfettiPiece>[
      for (int i = 0; i < count; i++)
        _ConfettiPiece(
          x: random.nextDouble(),
          delay: random.nextDouble() * 0.22,
          speed: 0.7 + random.nextDouble() * 0.55,
          size: 5 + random.nextDouble() * 6,
          color: PiecePalette.byIndex(random.nextInt(8)).base,
          spin: (random.nextDouble() - 0.5) * 9,
          sway: 0.02 + random.nextDouble() * 0.05,
          phase: random.nextDouble() * math.pi * 2,
          shape: _ConfettiShape.values[random.nextInt(_ConfettiShape.values.length)],
        ),
    ];
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required Animation<double> progress, required this.pieces})
      : _progress = progress,
        super(repaint: progress);

  final Animation<double> _progress;
  final List<_ConfettiPiece> pieces;

  @override
  void paint(Canvas canvas, Size size) {
    final double progress = _progress.value;
    if (progress >= 1) {
      return;
    }
    for (final _ConfettiPiece piece in pieces) {
      final double t = ((progress - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (t <= 0) {
        continue;
      }
      final double y = -0.08 + t * 1.2 * piece.speed;
      if (y > 1.08) {
        continue;
      }
      final double drift =
          math.sin(t * math.pi * 2.2 + piece.phase) * piece.sway;
      final double opacity = t > 0.82 ? (1 - t) / 0.18 : 1.0;

      canvas.save();
      canvas.translate((piece.x + drift) * size.width, y * size.height);
      canvas.rotate(piece.spin * t);
      final Paint paint = Paint()
        ..color = piece.color.withOpacity(opacity.clamp(0.0, 1.0));

      switch (piece.shape) {
        case _ConfettiShape.chip:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: piece.size,
                height: piece.size * 0.55,
              ),
              Radius.circular(piece.size * 0.18),
            ),
            paint,
          );
        case _ConfettiShape.ribbon:
          final Path ribbon = Path()
            ..moveTo(-piece.size * 0.5, -piece.size * 0.22)
            ..quadraticBezierTo(
              piece.size * 0.2,
              -piece.size * 0.7,
              piece.size * 0.5,
              -piece.size * 0.1,
            )
            ..quadraticBezierTo(
              piece.size * 0.2,
              -piece.size * 0.3,
              -piece.size * 0.5,
              piece.size * 0.22,
            )
            ..close();
          canvas.drawPath(ribbon, paint);
        case _ConfettiShape.dot:
          canvas.drawCircle(Offset.zero, piece.size * 0.28, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.pieces != pieces || oldDelegate._progress != _progress;
}
