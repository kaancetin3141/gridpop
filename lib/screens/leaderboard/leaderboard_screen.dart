import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_keys.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/score_format.dart';
import '../../game/models/game_mode.dart';
import '../../game/models/score_record.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_background.dart';
import '../../widgets/animations/motion.dart';
import '../../widgets/buttons/game_buttons.dart';
import '../../widgets/dialogs/app_dialogs.dart';

/// Offline leaderboard with one tab per mode.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  GameMode _mode = GameMode.classic;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final AppPalette palette = AppPalette.of(context);
    final services = AppScope.of(context);
    final DateTime now = DateTime.now();

    return AppScaffold(
      child: ListenableBuilder(
        listenable: services.leaderboard,
        builder: (BuildContext context, Widget? child) {
          final List<ScoreRecord> records = services.leaderboard.top(_mode);

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
                        strings.t('leaderboard.title'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconPillButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: strings.t('common.clear'),
                      onPressed: () => _confirmClear(context, services),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: <Widget>[
                    for (final GameMode mode in GameMode.leaderboardModes)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _ModeTab(
                          label: strings.t(mode.labelKey),
                          selected: mode == _mode,
                          onTap: () => setState(() => _mode = mode),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: records.isEmpty
                    ? _EmptyState(message: strings.t('leaderboard.empty'))
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          4,
                          20,
                          24 + MediaQuery.paddingOf(context).bottom,
                        ),
                        itemCount: records.length,
                        itemBuilder: (BuildContext context, int index) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 620),
                              child: _RecordTile(
                                rank: index + 1,
                                record: records[index],
                                today:
                                    records[index].dateKey == DateKeys.key(now),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  strings.t('leaderboard.local'),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: palette.textMuted),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    AppServices services,
  ) async {
    final AppStrings strings = AppStrings.of(context);
    final bool clear = await showConfirmDialog(
      context,
      title: strings.t('leaderboard.cleared'),
      message: strings.t('leaderboard.local'),
      confirmLabel: strings.t('common.clear'),
      destructive: true,
    );
    if (!clear || !context.mounted) {
      return;
    }
    await services.leaderboard.clear();
    if (context.mounted) {
      showToast(context, strings.t('leaderboard.cleared'));
    }
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.indigo : palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.indigo : palette.outline,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : palette.text,
              ),
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.rank,
    required this.record,
    required this.today,
  });

  final int rank;
  final ScoreRecord record;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AppStrings strings = AppStrings.of(context);
    final bool top = rank <= 3;
    // Podium colours: gold, silver then bronze, so the top three read at a
    // glance instead of needing the ordinal text.
    final Color rawMedal = switch (rank) {
      1 => AppColors.gold,
      2 => const Color(0xFFB8C2D6),
      3 => const Color(0xFFCD7F32),
      _ => palette.textMuted,
    };
    final Color medal =
        palette.isDark ? rawMedal : AppColors.deep(rawMedal, lightness: 0.42);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: top
            ? medal.withOpacity(palette.isDark ? 0.10 : 0.07)
            : palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: top ? medal.withOpacity(0.32) : palette.outline,
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 36,
            child: top
                ? Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: medal,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$rank',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: palette.isDark ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  )
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: palette.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  ScoreFormat.number(record.score),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${strings.shortDate(record.timestamp)}  •  '
                  '${record.clearedLines} ${strings.t('leaderboard.linesShort')}  •  x${record.combo}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: palette.textMuted),
                ),
              ],
            ),
          ),
          if (today)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.mint.withOpacity(0.16),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                strings.t('leaderboard.newRun'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.isDark
                          ? AppColors.mint
                          : AppColors.deep(AppColors.mint, lightness: 0.34),
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AppStrings strings = AppStrings.of(context);
    final Color accent =
        palette.isDark ? AppColors.gold : AppColors.deep(AppColors.gold);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: palette.outline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    size: 32,
                    color: accent,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  strings.t('leaderboard.emptyHint'),
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
    );
  }
}
