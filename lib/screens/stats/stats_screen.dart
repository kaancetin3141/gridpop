import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/score_format.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_background.dart';
import '../../widgets/buttons/game_buttons.dart';

/// Lifetime statistics of the player.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final AppPalette palette = AppPalette.of(context);
    final stats = AppScope.of(context).stats;

    return AppScaffold(
      child: ListenableBuilder(
        listenable: stats,
        builder: (BuildContext context, Widget? child) {
          final List<_Stat> entries = <_Stat>[
            _Stat(
              strings.t('stats.totalScore'),
              ScoreFormat.number(stats.totalScore),
              AppColors.indigo,
              Icons.functions_rounded,
            ),
            _Stat(
              strings.t('stats.gamesPlayed'),
              ScoreFormat.number(stats.gamesPlayed),
              AppColors.sky,
              Icons.sports_esports_rounded,
            ),
            _Stat(
              strings.t('stats.bestCombo'),
              'x${stats.bestCombo}',
              AppColors.magenta,
              Icons.local_fire_department_rounded,
            ),
            _Stat(
              strings.t('stats.linesCleared'),
              ScoreFormat.number(stats.totalLinesCleared),
              AppColors.mint,
              Icons.horizontal_rule_rounded,
            ),
            _Stat(
              strings.t('stats.perfectMoves'),
              ScoreFormat.number(stats.perfectMoves),
              AppColors.amber,
              Icons.auto_awesome_rounded,
            ),
            _Stat(
              strings.t('stats.cellsPlaced'),
              ScoreFormat.number(stats.totalCellsPlaced),
              AppColors.coral,
              Icons.grid_on_rounded,
            ),
            _Stat(
              strings.t('stats.playTime'),
              ScoreFormat.duration(stats.totalPlayTime),
              AppColors.grape,
              Icons.schedule_rounded,
            ),
            _Stat(
              strings.t('home.best'),
              ScoreFormat.number(stats.highScore),
              AppColors.bubblegum,
              Icons.emoji_events_rounded,
            ),
          ];

          return Column(
            children: <Widget>[
              Padding(
                padding: Responsive.pagePadding(context),
                child: Row(
                  children: <Widget>[
                    IconPillButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        strings.t('stats.title'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    28 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (int i = 0; i < entries.length; i += 2)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: <Widget>[
                                  Expanded(child: _StatCard(stat: entries[i])),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: i + 1 < entries.length
                                        ? _StatCard(stat: entries[i + 1])
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            strings.t('settings.original'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: palette.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.color, this.icon);

  final String label;
  final String value;
  final Color color;
  final IconData icon;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Container(
      height: 108,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.outline),
        boxShadow: AppShadows.soft(
          palette.isDark ? Colors.black : AppColors.indigo,
          strength: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(stat.icon, size: 18, color: stat.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stat.label,
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
          Text(
            stat.value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: stat.color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}