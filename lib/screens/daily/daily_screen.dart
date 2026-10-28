import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
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
                _DatePill(date: DateTime.now()),
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
                  children: <Widget>[
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.emoji_events_rounded,
                        accent: AppColors.gold,
                        label: strings.t('daily.yourBest'),
                        value: best == 0
                            ? strings.t('daily.noRecord')
                            : ScoreFormat.number(best),
                        muted: best == 0,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.local_fire_department_rounded,
                        accent: AppColors.tangerine,
                        label: strings.t('daily.streak'),
                        value: '${services.daily.liveStreak}',
                      ),
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
    final Color star = palette.isDark
        ? AppColors.starActive
        : AppColors.deep(AppColors.starActive, lightness: 0.38);
    final Color color = done ? star : palette.textMuted;

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

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    this.muted = false,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String value;

  /// Renders the value in the quiet style, used for "no result yet".
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Color ink =
        palette.isDark ? accent : AppColors.deep(accent, lightness: 0.42);

    // Both tiles share one fixed height so the pair stays level even when one
    // side shows a sentence instead of a number.
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 15, color: ink),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
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
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: muted
                  ? Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: palette.textMuted,
                        fontWeight: FontWeight.w700,
                      )
                  : Theme.of(context).textTheme.titleLarge?.copyWith(
                        // Dark mode lets the accent carry the number; on a
                        // light surface the ink reads cleaner than a tinted
                        // numeral, so only the icon keeps the colour.
                        color: palette.isDark ? ink : palette.text,
                        fontWeight: FontWeight.w900,
                      ),
            ),
          ),
        ],
      ),
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
              Icon(
                Icons.local_fire_department_rounded,
                size: 18,
                color: palette.isDark
                    ? AppColors.tangerine
                    : AppColors.deep(AppColors.tangerine, lightness: 0.42),
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
                        color: palette.isDark
                            ? AppColors.amber
                            : AppColors.deep(AppColors.amber, lightness: 0.36),
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
    // Light mode needs a deeper ink: mint and amber text on a near white
    // surface is pretty but unreadable.
    final Color mint = palette.isDark
        ? AppColors.mint
        : AppColors.deep(AppColors.mint, lightness: 0.36);
    final Color gold = palette.isDark
        ? AppColors.amber
        : AppColors.deep(AppColors.amber, lightness: 0.36);
    final Color accent = done
        ? mint
        : isToday
            ? gold
            : palette.textMuted;
    final Color fill = done
        ? mint.withOpacity(0.14)
        : isToday
            ? gold.withOpacity(0.18)
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

/// The day the board belongs to, drawn as a quiet pill instead of a raw
/// `yyyy-mm-dd` key: "Today · 28 Oct" reads like a calendar, not like a file
/// name.
class _DatePill extends StatelessWidget {
  const _DatePill({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AppStrings strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.event_available_rounded,
            size: 14,
            color: palette.isDark
                ? AppColors.sky
                : AppColors.deep(AppColors.sky, lightness: 0.4),
          ),
          const SizedBox(width: 6),
          Text(
            '${strings.t("common.today")} · ${strings.shortDate(date)}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
          ),
        ],
      ),
    );
  }
}
