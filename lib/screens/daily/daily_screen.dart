import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_keys.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/score_format.dart';
import '../../game/models/game_mode.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_background.dart';
import '../../widgets/buttons/game_buttons.dart';
import '../game/game_screen.dart';

/// Daily Challenge landing page: today's board, streak and star rating.
class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final AppPalette palette = AppPalette.of(context);
    final services = AppScope.of(context);


    return AppScaffold(
      child: ListenableBuilder(
        listenable: services.daily,
        builder: (BuildContext context, Widget? child) {
          final bool completed = services.daily.isCompletedToday;
          final int stars = services.daily.todayStars;
          final int best = services.daily.todayBestScore;
          final List<int> thresholds = GameMode.daily.config.starThresholds;

          final Widget card = Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: palette.outline),
              boxShadow: AppShadows.soft(
                palette.isDark ? Colors.black : AppColors.indigo,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  DateKeys.today(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: palette.textMuted,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  strings.t('daily.title'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  strings.t('daily.subtitle'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: palette.textMuted),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: <Widget>[
                    for (int i = 0; i < 3; i++)
                      Expanded(
                        child: _StarGoal(
                          index: i,
                          threshold: thresholds[i],
                          score: best,
                          reached: i < stars,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    _MiniStat(
                      label: strings.t('daily.yourBest'),
                      value: best == 0
                          ? strings.t('daily.noRecord')
                          : ScoreFormat.number(best),
                    ),
                    _MiniStat(
                      label: strings.t('daily.streak'),
                      value: '${services.daily.liveStreak}',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _StreakLadder(
                  activeDay: services.daily.ladderDay,
                  doneDays: services.daily.ladderDoneDays,
                  bonus: completed
                      ? services.daily.todayStreakBonus
                      : services.daily.nextStreakBonus,
                ),
                const SizedBox(height: AppSpacing.xl),
                if (completed)
                  SoftButton(
                    label: strings.t('daily.playToday'),
                    icon: Icons.replay_rounded,
                    onPressed: () {
                      services.audio.play(GameSound.buttonClick);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              const GameScreen(mode: GameMode.daily),
                        ),
                      );
                    },
                  )
                else
                  PrimaryButton(
                    label: strings.t('daily.playToday'),
                    icon: Icons.play_arrow_rounded,
                    onPressed: () {
                      services.audio.play(GameSound.buttonClick);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              const GameScreen(mode: GameMode.daily),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  strings.t('daily.comesTomorrow'),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: palette.textMuted),
                ),
              ],
            ),
          );

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
                        strings.t('daily.title'),
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
                    8,
                    20,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: card,
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

class _StarGoal extends StatelessWidget {
  const _StarGoal({
    required this.index,
    required this.threshold,
    required this.score,
    required this.reached,
  });

  final int index;
  final int threshold;
  final int score;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final bool done = score >= threshold;
    final Color color = done ? AppColors.starActive : palette.textMuted;

    return Column(
      children: <Widget>[
        Icon(
          done ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 30,
          color: color,
        ),
        const SizedBox(height: 4),
        Text(
          ScoreFormat.number(threshold),
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Column(
      children: <Widget>[
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: palette.text,
              ),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

/// The seven day coin ladder of the daily streak.
///
/// Days already played in the current cycle are mint, the day on offer is
/// amber, the rest stay quiet, so the next reward is obvious at a glance.
class _StreakLadder extends StatelessWidget {
  const _StreakLadder({
    required this.activeDay,
    required this.doneDays,
    required this.bonus,
  });

  final int activeDay;
  final int doneDays;
  final int bonus;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final AppPalette palette = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.local_fire_department_rounded,
                size: 18,
                color: AppColors.tangerine,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  strings.t('daily.ladder'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: palette.text,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${strings.t('daily.bonus')} +$bonus',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.amber,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              for (int day = 1; day <= StreakConfig.cycleLength; day++)
                Expanded(
                  child: _LadderStep(
                    day: day,
                    coins: StreakConfig.bonuses[day - 1],
                    done: day <= doneDays,
                    isToday: day == activeDay,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            strings.t('daily.ladderHint'),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _LadderStep extends StatelessWidget {
  const _LadderStep({
    required this.day,
    required this.coins,
    required this.done,
    required this.isToday,
  });

  final int day;
  final int coins;
  final bool done;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Color accent = done
        ? AppColors.mint
        : isToday
            ? AppColors.amber
            : palette.textMuted;
    final Color fill = done
        ? AppColors.mint.withOpacity(0.16)
        : isToday
            ? AppColors.amber.withOpacity(0.18)
            : palette.surface;

    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: accent.withOpacity(done || isToday ? 0.7 : 0.22),
          width: isToday ? 1.6 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '$day',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                done ? Icons.check_rounded : Icons.paid_rounded,
                size: 10,
                color: accent,
              ),
              const SizedBox(width: 1),
              Flexible(
                child: Text(
                  ScoreFormat.number(coins),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}