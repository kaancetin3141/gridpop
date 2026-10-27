import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Signature background: soft aurora gradient with two colour blooms.
///
/// Painted with radial gradients only (no blur filters) so it stays cheap on
/// web and on low end devices.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.dark,
    this.blooms = true,
  });

  final Widget child;

  /// Force a palette; `null` follows the current theme brightness.
  final bool? dark;

  /// Disables the colour blooms for very busy screens.
  final bool blooms;

  @override
  Widget build(BuildContext context) {
    final bool isDark = dark ?? Theme.of(context).brightness == Brightness.dark;
    final List<Color> colors =
        isDark ? AppColors.auroraGradientDark : AppColors.auroraGradientSoft;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (blooms)
            const IgnorePointer(child: CustomPaint(painter: _BloomPainter())),
          child,
        ],
      ),
    );
  }
}

class _BloomPainter extends CustomPainter {
  const _BloomPainter();

  @override
  void paint(Canvas canvas, Size size) {
    void bloom(Offset center, double radius, Color color, double opacity) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              color.withOpacity(opacity),
              color.withOpacity(0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    final double shortest = size.shortestSide;
    bloom(
      Offset(size.width * 0.18, size.height * 0.08),
      shortest * 0.55,
      AppColors.violet,
      0.26,
    );
    bloom(
      Offset(size.width * 0.92, size.height * 0.22),
      shortest * 0.48,
      AppColors.magenta,
      0.18,
    );
    bloom(
      Offset(size.width * 0.6, size.height * 0.95),
      shortest * 0.6,
      AppColors.sky,
      0.16,
    );
    bloom(
      Offset(size.width * 0.15, size.height * 0.72),
      shortest * 0.42,
      AppColors.mint,
      0.10,
    );
    bloom(
      Offset(size.width * 0.85, size.height * 0.75),
      shortest * 0.40,
      AppColors.amber,
      0.10,
    );

    // Corner vignette: pulls the eye towards the board.
    final Paint vignette = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.black.withOpacity(0),
          Colors.black.withOpacity(0.16),
        ],
        stops: const <double>[0.62, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);

    // Static sparkle field: tiny deterministic dots that give the gradient a
    // premium, printed-foil texture. Deterministic so it never shimmers
    // between rebuilds.
    final math.Random random = math.Random(20240517);
    final int dots = (size.shortestSide / 14).round().clamp(18, 54);
    final Paint sparkle = Paint();
    for (int i = 0; i < dots; i++) {
      final double x = random.nextDouble() * size.width;
      final double y = random.nextDouble() * size.height;
      final double r = 0.5 + random.nextDouble() * 1.5;
      final double alpha = 0.05 + random.nextDouble() * 0.14;
      sparkle.color = (random.nextBool() ? Colors.white : AppColors.violet)
          .withOpacity(alpha);
      canvas.drawCircle(Offset(x, y), r, sparkle);
    }
  }

  @override
  bool shouldRepaint(_BloomPainter oldDelegate) => false;
}

/// Centres its child and caps the width, which keeps phone, tablet and desktop
/// layouts consistent without duplicating the maths in every screen.
class ContentColumn extends StatelessWidget {
  const ContentColumn({
    super.key,
    required this.child,
    this.maxWidth = 520,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Full page scaffold used by every screen.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.dark,
    this.blooms = true,
  });

  final Widget child;
  final bool? dark;
  final bool blooms;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        dark: dark,
        blooms: blooms,
        child: SafeArea(child: child),
      ),
    );
  }
}