import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../animations/motion.dart';

/// Main call to action: gradient pill with a soft shadow and press animation.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.colors,
    this.height = 56,
    this.width,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final List<Color>? colors;
  final double height;
  final double? width;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final AppPalette palette = AppPalette.of(context);
    if (!enabled) {
      // Half-transparent gradient reads as "tap me but dimmer"; a muted pill
      // with muted ink is unmistakably out of reach, and it stays legible on a
      // white sheet where white-on-washed-purple does not.
      return Container(
        height: height,
        width: expand ? (width ?? double.infinity) : width,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        decoration: BoxDecoration(
          color: palette.surfaceAlt,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: palette.outline, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, color: palette.textMuted, size: height * 0.42),
              const SizedBox(width: AppSpacing.md),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: palette.textMuted,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    final Gradient gradient = LinearGradient(
      colors: colors ?? AppColors.auroraGradient,
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    final Widget content = Container(
      height: height,
      width: expand ? (width ?? double.infinity) : width,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (colors?.first ?? AppColors.indigo).withOpacity(0.36),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, color: Colors.white, size: height * 0.42),
            const SizedBox(width: AppSpacing.md),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );

    return Pressable(onTap: onPressed, child: content);
  }
}

/// Secondary, outlined pill used for "back", "restart" and similar actions.
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.height = 52,
    this.width,
    this.expand = true,
    this.tone,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  final double? width;
  final bool expand;

  /// Optional accent colour.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Color accent = tone ?? palette.text;

    final Widget content = Container(
      height: height,
      width: expand ? (width ?? double.infinity) : width,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: accent.withOpacity(0.22), width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, color: accent, size: height * 0.4),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );

    if (onPressed == null) {
      return Opacity(opacity: 0.5, child: content);
    }
    return Pressable(onTap: onPressed, child: content);
  }
}

/// Circular icon button used in the game HUD.
class IconPillButton extends StatelessWidget {
  const IconPillButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 46,
    this.tooltip,
    this.tone,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;
  final Color? tone;

  /// Small dot / counter drawn in the corner.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Color accent = tone ?? palette.text;

    Widget button = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.surface,
        shape: BoxShape.circle,
        border: Border.all(color: palette.outline, width: 1.4),
        boxShadow:
            AppShadows.soft(palette.isDark ? Colors.black : AppColors.indigo),
      ),
      child: Icon(icon, color: accent, size: size * 0.46),
    );

    if (badge != null) {
      button = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          button,
          Positioned(right: -2, top: -2, child: badge!),
        ],
      );
    }

    final Widget pressable = Pressable(
      onTap: onPressed,
      pressedScale: 0.9,
      child: button,
    );

    if (tooltip == null) {
      return pressable;
    }
    return Tooltip(message: tooltip!, child: pressable);
  }
}

/// Square menu entry (the classic "big button with icon + label" of the home
/// screen).
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.tint,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Color accent = tint ?? AppColors.indigo;
    // White glyphs on pastel candy read badly on a light stage (mint and
    // sunbeam especially). Light mode gets a pastel plate with a deepened
    // glyph instead, the same pairing the settings rows use.
    final bool dark = palette.isDark;
    final Color glyph =
        dark ? Colors.white : AppColors.deep(accent, lightness: 0.4);

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: palette.outline.withOpacity(0.7)),
          boxShadow: AppShadows.soft(
            palette.isDark ? Colors.black : AppColors.indigo,
            strength: 0.7,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: dark
                      ? <Color>[
                          accent.withOpacity(0.9),
                          Color.lerp(accent, Colors.white, 0.25)!,
                        ]
                      : <Color>[
                          accent.withValues(alpha: 0.24),
                          accent.withValues(alpha: 0.12),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color:
                      dark ? Colors.transparent : accent.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(icon, color: glyph, size: 24),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: palette.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
