import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/score_format.dart';
import '../../../widgets/buttons/game_buttons.dart';

/// Options offered by the pause overlay.
enum PauseAction { resume, restart, quit }

/// Pause overlay. Returns the action chosen by the player.
Future<PauseAction?> showPauseDialog(
  BuildContext context, {
  required int score,
  required int seconds,
  required int combo,
}) {
  return showDialog<PauseAction>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (BuildContext context) => _PauseDialog(
      score: score,
      seconds: seconds,
      combo: combo,
    ),
  );
}

class _PauseDialog extends StatelessWidget {
  const _PauseDialog({
    required this.score,
    required this.seconds,
    required this.combo,
  });

  /// Snapshot of the run that is on hold, so the player can pick up where the
  /// numbers say they left off.
  final int score;
  final int seconds;
  final int combo;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AppStrings strings = AppStrings.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      palette.accent,
                      Color.lerp(palette.accent, Colors.white, 0.28)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  // A halo ties the badge to the gradient above it, so the
                  // pause mark looks lit rather than pasted on.
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.36),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.pause_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                strings.t('game.paused'),
                style:
                    text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: palette.outline),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _PauseStat(
                        label: strings.t('game.score'),
                        value: ScoreFormat.number(score),
                        icon: Icons.stars_rounded,
                        tint: AppColors.gold,
                      ),
                    ),
                    Container(width: 1, height: 30, color: palette.outline),
                    Expanded(
                      child: _PauseStat(
                        label: strings.t('game.time'),
                        value: ScoreFormat.clock(seconds),
                        icon: Icons.schedule_rounded,
                        tint: AppColors.sky,
                      ),
                    ),
                    Container(width: 1, height: 30, color: palette.outline),
                    Expanded(
                      child: _PauseStat(
                        label: strings.t('game.combo'),
                        value: 'x$combo',
                        icon: Icons.local_fire_department_rounded,
                        tint: AppColors.coral,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: strings.t('common.resume'),
                icon: Icons.play_arrow_rounded,
                onPressed: () => Navigator.of(context).pop(PauseAction.resume),
              ),
              const SizedBox(height: AppSpacing.md),
              SoftButton(
                label: strings.t('common.restart'),
                icon: Icons.refresh_rounded,
                onPressed: () => Navigator.of(context).pop(PauseAction.restart),
              ),
              const SizedBox(height: AppSpacing.md),
              SoftButton(
                label: strings.t('common.quit'),
                icon: Icons.exit_to_app_rounded,
                // The raw coral is too pale on a white dialog, so the tone is
                // deepened there instead of being swapped for another hue.
                tone: palette.isDark
                    ? AppColors.danger
                    : AppColors.deep(AppColors.danger, lightness: 0.4),
                onPressed: () => Navigator.of(context).pop(PauseAction.quit),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                strings.t('app.name'),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: palette.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PauseStat extends StatelessWidget {
  const _PauseStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Color ink =
        palette.isDark ? tint : AppColors.deep(tint, lightness: 0.4);
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 13, color: ink),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: palette.textMuted),
        ),
      ],
    );
  }
}
