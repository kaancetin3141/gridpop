import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/score_format.dart';
import '../../game/achievements/achievement.dart';
import '../../game/achievements/achievement_catalog.dart';
import '../../game/achievements/achievement_engine.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_background.dart';
import '../../widgets/buttons/game_buttons.dart';

/// Gallery of every badge: unlocked, in progress and locked.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  static const Map<String, IconData> icons = <String, IconData>{
    'firstSteps': Icons.flag_rounded,
    'lineCook': Icons.horizontal_rule_rounded,
    'comboStarter': Icons.local_fire_department_rounded,
    'firstSpark': Icons.auto_awesome_rounded,
    'risingStar': Icons.trending_up_rounded,
    'brickLayer': Icons.grid_on_rounded,
    'dailyDevotion': Icons.today_rounded,
    'steady': Icons.schedule_rounded,
    'regular': Icons.sports_esports_rounded,
    'carpenter': Icons.carpenter_rounded,
    'comboMaster': Icons.whatshot_rounded,
    'perfectionist': Icons.stars_rounded,
    'builder': Icons.construction_rounded,
    'highRoller': Icons.attach_money_rounded,
    'blitz': Icons.timer_rounded,
    'starCollector': Icons.star_rounded,
    'veteran': Icons.military_tech_rounded,
    'architect': Icons.architecture_rounded,
    'grandBuilder': Icons.apartment_rounded,
    'comboFrenzy': Icons.bolt_rounded,
    'gridLegend': Icons.emoji_events_rounded,
    'marathon': Icons.hourglass_bottom_rounded,
  };

  static const Map<AchievementTier, Color> tierColors =
      <AchievementTier, Color>{
    AchievementTier.bronze: Color(0xFFCD7F32),
    AchievementTier.silver: Color(0xFF9AA5B1),
    AchievementTier.gold: AppColors.gold,
  };

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final services = AppScope.of(context);

    return AppScaffold(
      child: ListenableBuilder(
        listenable: Listenable.merge(
            <Listenable>[services.achievements, services.stats]),
        builder: (BuildContext context, Widget? child) {
          final List<AchievementStatus> rows =
              services.achievements.statusesFromStats(services.stats);
          final int unlocked =
              rows.where((AchievementStatus r) => r.unlocked).length;
          final double ratio =
              rows.isEmpty ? 0 : unlocked / rows.length;

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
                        strings.t('achievements.title'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    _CountChip(unlocked: unlocked, total: rows.length),
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
                          _SummaryCard(ratio: ratio),
                          const SizedBox(height: AppSpacing.lg),
                          for (final AchievementTier tier
                              in AchievementTier.values) ...<Widget>[
                            _TierHeader(tier: tier),
                            for (final Achievement achievement
                                in AchievementCatalog.ofTier(tier))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _AchievementCard(
                                  status: rows.firstWhere(
                                    (AchievementStatus r) =>
                                        r.achievement.id == achievement.id,
                                  ),
                                ),
                              ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
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

class _CountChip extends StatelessWidget {
  const _CountChip({required this.unlocked, required this.total});

  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.gold.withOpacity(0.45)),
      ),
      child: Text(
        '$unlocked/$total',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.amber,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF6A46F0), Color(0xFFE05AA8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.lift(AppColors.violet, strength: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.t('achievements.subtitle'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(ratio * 100).round()}%',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _TierHeader extends StatelessWidget {
  const _TierHeader({required this.tier});

  final AchievementTier tier;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final String label = switch (tier) {
      AchievementTier.bronze => strings.t('achievements.tierBronze'),
      AchievementTier.silver => strings.t('achievements.tierSilver'),
      AchievementTier.gold => strings.t('achievements.tierGold'),
    };
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: AppSpacing.sm, top: 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppPalette.of(context).textMuted,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.status});

  final AchievementStatus status;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AppStrings strings = AppStrings.of(context);
    final Achievement achievement = status.achievement;
    final Color tierColor =
        AchievementsScreen.tierColors[achievement.tier] ?? AppColors.indigo;
    final bool unlocked = status.unlocked;

    return AnimatedOpacity(
      opacity: unlocked ? 1 : 0.75,
      duration: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: unlocked
                ? tierColor.withOpacity(0.55)
                : palette.outline,
          ),
          boxShadow: AppShadows.soft(
            palette.isDark ? Colors.black : AppColors.indigo,
            strength: 0.5,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: unlocked
                    ? LinearGradient(
                        colors: <Color>[
                          tierColor,
                          Color.lerp(tierColor, Colors.white, 0.25)!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: unlocked ? null : palette.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: unlocked
                    ? null
                    : Border.all(color: palette.outline),
              ),
              child: Icon(
                unlocked
                    ? (AchievementsScreen.icons[achievement.id] ??
                        Icons.emoji_events_rounded)
                    : Icons.lock_rounded,
                color: unlocked ? Colors.white : palette.textMuted,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    strings.t(achievement.titleKey),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    strings.t(achievement.descriptionKey),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: palette.textMuted),
                  ),
                  if (!unlocked && achievement.metric.isCumulative) ...<Widget>[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: status.ratio.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: palette.outline,
                        valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ScoreFormat.number(status.progress)} / ${ScoreFormat.number(achievement.target)}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: palette.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            if (unlocked) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
