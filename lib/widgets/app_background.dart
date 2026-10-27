import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/visual_style.dart';
import 'animations/motion.dart';

/// Signature background of every screen.
///
/// It follows the active [VisualStyle]: the gradient, the blooms, the arcade
/// grid floor and the CRT scanlines all come from the style spec, and a style
/// change plays a short accent flash instead of snapping silently.
class AppBackground extends StatefulWidget {
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
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );

  VisualStyle? _style;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final VisualStyle style = _palette.style;
    if (_style == null) {
      _style = style;
      return;
    }
    if (_style == style) {
      return;
    }
    _style = style;
    if (Motion.reduce(context)) {
      return;
    }
    // Restart after the frame that installed the new palette, so the flash
    // highlights the change instead of the old colours.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _flash.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  AppPalette get _palette {
    final ThemeData theme = Theme.of(context);
    final AppPalette resolved = theme.extension<GridPopTheme>()?.palette ??
        AppPalette.build(VisualStyle.aurora, theme.brightness);
    if (widget.dark == null) {
      return resolved;
    }
    return AppPalette.build(
      resolved.style,
      widget.dark! ? Brightness.dark : Brightness.light,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = _palette;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: palette.backgroundGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (palette.blooms && widget.blooms)
                IgnorePointer(child: CustomPaint(painter: _StagePainter(palette))),
              if (!palette.blooms)
                IgnorePointer(
                  // The flat styles always get their accent glow; the aurora
                  // style only loses it when the screen asked for a quiet
                  // stage, which is why the glow is not unconditional here.
                  child: CustomPaint(painter: _FlatStagePainter(palette)),
                ),
              widget.child,
            ],
          ),
        ),
        // Style swap flash: a quick accent wash that marks the change.
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _flash,
            builder: (BuildContext context, Widget? child) {
              final double t = _flash.value;
              final double alpha = t >= 1 ? 0 : math.sin(t * math.pi) * 0.16;
              if (alpha <= 0) {
                return const SizedBox.shrink();
              }
              return ColoredBox(
                color: palette.accent.withValues(alpha: alpha),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Aurora style stage: colour blooms, a vignette and a printed foil sparkle.
class _StagePainter extends CustomPainter {
  const _StagePainter(this.palette);

  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    void bloom(Offset center, double radius, Color color, double opacity) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    final double shortest = size.shortestSide;
    // Blooms are light on a dark stage, but muddy on a pale one, so the light
    // theme gets a much fainter version of the same composition.
    final double k = palette.isDark ? 1 : 0.38;
    bloom(
      Offset(size.width * 0.18, size.height * 0.08),
      shortest * 0.55,
      palette.accent,
      0.26 * k,
    );
    bloom(
      Offset(size.width * 0.92, size.height * 0.22),
      shortest * 0.48,
      AppColors.magenta,
      0.18 * k,
    );
    bloom(
      Offset(size.width * 0.6, size.height * 0.95),
      shortest * 0.6,
      AppColors.sky,
      0.16 * k,
    );
    bloom(
      Offset(size.width * 0.15, size.height * 0.72),
      shortest * 0.42,
      AppColors.mint,
      0.10 * k,
    );
    bloom(
      Offset(size.width * 0.85, size.height * 0.75),
      shortest * 0.40,
      AppColors.amber,
      0.10 * k,
    );

    _vignette(canvas, size, strength: palette.isDark ? 0.16 : 0.05);

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
      sparkle.color = (random.nextBool() ? Colors.white : palette.accent)
          .withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), r, sparkle);
    }
  }

  @override
  bool shouldRepaint(_StagePainter oldDelegate) => oldDelegate.palette != palette;
}

/// Neon / matte / retro stage: no blooms, but each style gets its own
/// signature decoration — a perspective grid, CRT scanlines or a paper grain.
class _FlatStagePainter extends CustomPainter {
  const _FlatStagePainter(this.palette);

  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final VisualStyleSpec spec = palette.spec;
    if (spec.gridFloor) {
      _paintGridFloor(canvas, size);
    }
    if (spec.scanlines) {
      _paintScanlines(canvas, size);
    }
    if (palette.style == VisualStyle.matte) {
      _paintGrain(canvas, size);
    }

    _vignette(
      canvas,
      size,
      strength: palette.isDark ? (spec.scanlines ? 0.26 : 0.12) : 0.05,
    );

    // A single accent bloom keeps the flat styles from looking dead. Aurora only
    // reaches this painter when the screen disabled its blooms, so the glow
    // stays off there.
    if (palette.blooms) {
      return;
    }
    canvas.drawCircle(
      Offset(size.width * 0.5, -size.height * 0.05),
      size.shortestSide * 0.9,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            palette.accent.withValues(alpha: 0.10),
            palette.accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.5, -size.height * 0.05),
          radius: size.shortestSide * 0.9,
        )),
    );
  }

  /// Arcade floor: a horizon with converging verticals and rows that get
  /// tighter towards the vanishing point.
  void _paintGridFloor(Canvas canvas, Size size) {
    final double horizon = size.height * 0.52;
    final Paint line = Paint()
      ..color = palette.accent.withValues(alpha: 0.10)
      ..strokeWidth = 1;

    const int rows = 10;
    for (int i = 1; i <= rows; i++) {
      final double t = i / rows;
      final double y = horizon + (size.height - horizon) * (t * t);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    const int columns = 9;
    for (int i = -columns; i <= columns; i++) {
      final double bottomX =
          size.width * 0.5 + (i / columns) * size.width * 0.95;
      canvas.drawLine(
        Offset(size.width * 0.5, horizon),
        Offset(bottomX, size.height),
        line,
      );
    }
  }

  /// CRT scanlines, drawn as very light horizontal bands.
  void _paintScanlines(Canvas canvas, Size size) {
    final Paint line = Paint()..color = Colors.black.withValues(alpha: 0.12);
    const double step = 4;
    for (double y = 0; y < size.height; y += step) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
    }
  }

  /// Paper grain for the printed style: deterministic, very low contrast.
  void _paintGrain(Canvas canvas, Size size) {
    final math.Random random = math.Random(7723);
    final int dots = (size.shortestSide / 6).round().clamp(60, 320);
    final Paint grain = Paint();
    for (int i = 0; i < dots; i++) {
      final double x = random.nextDouble() * size.width;
      final double y = random.nextDouble() * size.height;
      grain.color = (random.nextBool() ? Colors.black : Colors.white)
          .withValues(alpha: 0.02 + random.nextDouble() * 0.03);
      canvas.drawCircle(Offset(x, y), 0.6, grain);
    }
  }

  @override
  bool shouldRepaint(_FlatStagePainter oldDelegate) =>
      oldDelegate.palette != palette;
}

void _vignette(Canvas canvas, Size size, {double strength = 0.16}) {
  final Paint vignette = Paint()
    ..shader = RadialGradient(
      colors: <Color>[
        Colors.black.withValues(alpha: 0),
        Colors.black.withValues(alpha: strength),
      ],
      stops: const <double>[0.62, 1],
    ).createShader(Offset.zero & size);
  canvas.drawRect(Offset.zero & size, vignette);
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
