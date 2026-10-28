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
    final services = AppScope.of(context);
    final stats = services.stats;

    return AppScaffold(
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[stats, services.daily]),
        builder: (BuildContext context, Widget? child) {
          // The best run leads, the lifetime totals follow: a player opens this
          // screen to see the number they are chasing, not to read a table.
          final List<_Stat> entries = <_Stat>[
            _Stat(
              strings.t('stats.totalScore'),
              ScoreFormat.number(stats.totalScore),
              AppColors.indigo,
              Icons.functions_rounded,
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
              AppColors.bubblegum,
              Icons.auto_awesome_rounded,
            ),
            _Stat(
              strings.t('stats.cellsPlaced'),
              ScoreFormat.number(stats.totalCellsPlaced),
              AppColors.coral,
              Icons.grid_on_rounded,
            ),
            _Stat(
              strings.t('stats.averageScore'),
              ScoreFormat.number(stats.averageScore.round()),
              AppColors.amber,
              Icons.trending_up_rounded,
            ),
            _Stat(
              strings.t('daily.streak'),
              '${services.daily.liveStreak}',
              AppColors.sunbeam,
              Icons.calendar_month_rounded,
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
                          _HeroCard(
                            label: strings.t('home.best'),
                            value: ScoreFormat.number(stats.highScore),
                            items: <_Mini>[
                              _Mini(
                                _Stat(
                                  strings.t('stats.gamesPlayed'),
                                  ScoreFormat.number(stats.gamesPlayed),
                                  AppColors.sky,
                                  Icons.sports_esports_rounded,
                                ),
                              ),
                              _Mini(
                                _Stat(
                                  strings.t('stats.playTime'),
                                  ScoreFormat.duration(stats.totalPlayTime),
                                  AppColors.grape,
                                  Icons.schedule_rounded,
                                ),
                              ),
                              _Mini(
                                _Stat(
                                  strings.t('stats.bestCombo'),
                                  'x${stats.bestCombo}',
                                  AppColors.magenta,
                                  Icons.local_fire_department_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          // A fresh install would otherwise show six zeroes;
                          // one friendly panel says the same thing better.
                          if (stats.gamesPlayed == 0)
                            _EmptyStats()
                          else
                            for (int i = 0; i < entries.length; i += 2)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                        child: _StatCard(stat: entries[i])),
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
                          _FooterNote(
                            title: strings.t('settings.original'),
                            message: strings.t('stats.localOnly'),
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

  /// The accent, deepened on a light stage so numbers stay readable.
  Color ink(AppPalette palette) =>
      palette.isDark ? color : AppColors.deep(color, lightness: 0.4);
}

class _Mini {
  const _Mini(this.stat);

  final _Stat stat;
}

/// High score hero: one number the player cares about, plus the three counters
/// that give it context.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.label,
    required this.value,
    required this.items,
  });

  final String label;
  final String value;
  final List<_Mini> items;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Color accent =
        palette.isDark ? AppColors.gold : AppColors.deep(AppColors.gold);
    // The wash is violet, not gold: gold over the dark stage would read as a
    // muddy brown, and the medal already carries the gold.
    final Color wash = AppColors.violet;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        // A BoxDecoration paints its colour only when there is no gradient, so
        // the two stops are pre-blended onto the surface: a translucent stop
        // would let the drop shadow bleed through the card as a purple smear.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              wash.withValues(alpha: palette.isDark ? 0.26 : 0.14),
              palette.surface,
            ),
            palette.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: wash.withValues(alpha: 0.32)),
        boxShadow: AppShadows.soft(
          palette.isDark ? Colors.black : AppColors.indigo,
          strength: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // Solid gold reads as a medal; the same gold as a 16% wash
                  // over the violet hero turns into olive.
                  color:
                      palette.isDark ? accent : accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 24,
                  color: palette.isDark ? const Color(0xFF2A1A00) : accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: palette.textMuted),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: palette.isDark ? accent : palette.text,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: palette.outline),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 26,
                      color: palette.outline,
                    ),
                  Expanded(child: _MiniStat(stat: items[i].stat)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(stat.icon, size: 14, color: stat.ink(palette)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                stat.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          stat.label,
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Color ink = stat.ink(palette);
    return Container(
      height: 108,
      padding: const EdgeInsets.all(14),
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
              // Same 28px tinted tile as the settings rows, so the two list
              // screens share one visual language for icon + label pairs.
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(color: ink.withValues(alpha: 0.26)),
                ),
                child: Icon(stat.icon, size: 15, color: ink),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stat.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: palette.textMuted),
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              stat.value,
              maxLines: 1,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: palette.isDark ? stat.color : palette.text,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiet panel at the end of the list: the credit line plus the promise that
/// nothing leaves the device.
class _FooterNote extends StatelessWidget {
  const _FooterNote({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.outline),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.shield_rounded,
            size: 18,
            color: palette.isDark
                ? AppColors.mint
                : AppColors.deep(AppColors.mint, lightness: 0.34),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: palette.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown before the first finished run.
class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AppStrings strings = AppStrings.of(context);
    final Color accent =
        palette.isDark ? AppColors.violet : AppColors.deep(AppColors.violet);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Icon(
              Icons.insights_rounded,
              size: 26,
              color: accent,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            strings.t('stats.emptyTitle'),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            strings.t('stats.emptyHint'),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}
