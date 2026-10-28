import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/score_format.dart';
import '../../../game/models/game_event.dart';
import '../../../widgets/animations/motion.dart';
import '../../../widgets/buttons/game_buttons.dart';
import '../../../widgets/effects/confetti.dart';
import '../../../widgets/logo_mark.dart';

/// End of run sheet: score, record badge, stars and the next actions.
Future<void> showGameOverDialog(
  BuildContext context, {
  required GameEndSummary summary,
  required Future<void> Function() onRetry,
  required Future<void> Function() onMenu,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (BuildContext context) => _GameOverDialog(
      summary: summary,
      onRetry: onRetry,
      onMenu: onMenu,
    ),
  );
}

class _GameOverDialog extends StatelessWidget {
  const _GameOverDialog({
    required this.summary,
    required this.onRetry,
    required this.onMenu,
  });

  final GameEndSummary summary;
  final Future<void> Function() onRetry;
  final Future<void> Function() onMenu;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AppStrings strings = AppStrings.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const PopIn(child: LogoMark(size: 64, animate: true)),
                  const SizedBox(height: AppSpacing.md),
                  PopIn(
                    delay: const Duration(milliseconds: 60),
                    child: Text(
                      strings.t('game.gameOver'),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PopIn(
                    delay: const Duration(milliseconds: 110),
                    child: Column(
                      children: <Widget>[
                        Text(
                          strings.t('game.score'),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        CountUpText(
                          value: summary.score,
                          duration: const Duration(milliseconds: 700),
                          builder: (BuildContext context, int value) => Text(
                            ScoreFormat.number(value),
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(height: 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (summary.hasStars) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    _Stars(count: summary.stars),
                  ],
                  if (summary.isNewRecord) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    const _RecordBadge(),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _SummaryGrid(summary: summary),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: strings.t('common.retry'),
                    icon: Icons.refresh_rounded,
                    onPressed: () {
                      Navigator.of(context).pop();
                      onRetry();
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SoftButton(
                    label: strings.t('common.menu'),
                    icon: Icons.home_rounded,
                    onPressed: () {
                      Navigator.of(context).pop();
                      onMenu();
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // The icon says "this was a mode" so the line stops reading like
                  // a debug label under the buttons.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.videogame_asset_rounded,
                        size: 13,
                        color: palette.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          strings.t(summary.mode.labelKey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: palette.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (summary.isNewRecord)
            const Positioned.fill(child: ConfettiBurst()),
        ],
      ),
    );
  }
}

class _RecordBadge extends StatelessWidget {
  const _RecordBadge();

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return PopIn(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[AppColors.amber, AppColors.coral],
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppShadows.lift(AppColors.amber, strength: 0.7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.emoji_events_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              strings.t('game.newBest'),
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(
              i < count ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 34,
              color: i < count ? AppColors.starActive : AppColors.starIdle,
            ),
          ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final GameEndSummary summary;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AppStrings strings = AppStrings.of(context);

    /// One summary tile: icon, label, value. The value is scaled down rather
    /// than wrapped, so a long play time ("12m 04s") never breaks the grid.
    Widget cell(String label, String value, Color color, IconData icon) {
      final Color ink = palette.isDark ? color : AppColors.ink(color);
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: palette.isDark ? 0.10 : 0.16),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: ink.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: ink),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: palette.textMuted),
                  ),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: ink,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: cell(
                strings.t('game.best'),
                ScoreFormat.number(summary.previousBest),
                AppColors.amber,
                Icons.emoji_events_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: cell(
                strings.t('game.combo'),
                'x${summary.bestCombo}',
                AppColors.magenta,
                Icons.local_fire_department_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: cell(
                strings.t('score.lines'),
                '${summary.linesCleared}',
                AppColors.mint,
                Icons.stacked_line_chart_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: cell(
                strings.t('stats.playTime'),
                ScoreFormat.duration(Duration(seconds: summary.playSeconds)),
                AppColors.sky,
                Icons.timer_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
