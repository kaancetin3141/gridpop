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

  /// One accent per badge.
  ///
  /// The tier still decides the border and the group header, but without an
  /// own hue every bronze badge would be the same orange square. These accents
  /// are picked to sit next to each other without clashing.
  static const Map<String, Color> accents = <String, Color>{
    'firstSteps': AppColors.violet,
    'lineCook': AppColors.sky,
    'comboStarter': AppColors.tangerine,
    'firstSpark': AppColors.magenta,
    'risingStar': AppColors.gold,
    'brickLayer': AppColors.mint,
    'dailyDevotion': AppColors.coral,
    'steady': AppColors.lime,
    'regular': AppColors.grape,
    'carpenter': AppColors.tangerine,
    'comboMaster': AppColors.coral,
    'perfectionist': AppColors.bubblegum,
    'builder': AppColors.amber,
    'highRoller': AppColors.gold,
    'blitz': AppColors.sky,
    'starCollector': AppColors.violet,
    'veteran': AppColors.grape,
    'architect': AppColors.sky,
    'grandBuilder': AppColors.mint,
    'comboFrenzy': AppColors.amber,
    'gridLegend': AppColors.gold,
    'marathon': AppColors.magenta,
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
          final double ratio = rows.isEmpty ? 0 : unlocked / rows.length;

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
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
    final AppPalette palette = AppPalette.of(context);
    final Color tierColor =
        AchievementsScreen.tierColors[tier] ?? AppColors.indigo;
    final String label = switch (tier) {
      AchievementTier.bronze => strings.t('achievements.tierBronze'),
      AchievementTier.silver => strings.t('achievements.tierSilver'),
      AchievementTier.gold => strings.t('achievements.tierGold'),
    };
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm, top: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: palette.isDark ? tierColor : AppColors.ink(tierColor),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: palette.outline,
            ),
          ),
        ],
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
    final Color rawAccent =
        AchievementsScreen.accents[achievement.id] ?? tierColor;
    final Color accent = palette.isDark ? rawAccent : AppColors.ink(rawAccent);
    final IconData glyph =
        AchievementsScreen.icons[achievement.id] ?? Icons.emoji_events_rounded;

    // The tile carries the badge identity, the row border carries the tier, so
    // a list of 22 medals does not read as a wall of identical squares.
    final bool dark = palette.isDark;
    final Color lockedInk = Color.lerp(accent, palette.textMuted, 0.4)!;
    final Color glyphInk =
        dark ? Colors.white : AppColors.ink(rawAccent, amount: 0.35);
    final Widget tile = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        // Dark mode keeps a shaded candy tile with a white glyph; light mode
        // flips to a pastel tile with a deep glyph, which matches the paper
        // feel of the light theme instead of punching dark holes in the card.
        gradient: unlocked && dark
            ? LinearGradient(
                colors: <Color>[
                  Color.lerp(accent, Colors.white, 0.08)!,
                  Color.lerp(accent, Colors.black, 0.26)!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: unlocked
            ? (dark ? null : rawAccent.withValues(alpha: 0.18))
            : lockedInk.withValues(alpha: dark ? 0.12 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: unlocked
            ? (dark
                ? null
                : Border.all(color: rawAccent.withValues(alpha: 0.3)))
            : Border.all(color: lockedInk.withValues(alpha: 0.32)),
      ),
      child: Stack(
        children: <Widget>[
          Center(
            child: Icon(
              glyph,
              size: 22,
              color: unlocked ? glyphInk : lockedInk,
            ),
          ),
          // A locked badge keeps its own symbol and only gains a small lock
          // in the corner, so the player can still see what it looks like.
          if (!unlocked)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: palette.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.outline),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 8,
                  color: palette.textMuted,
                ),
              ),
            ),
        ],
      ),
    );

    return AnimatedOpacity(
      opacity: unlocked ? 1 : 0.92,
      duration: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color:
                unlocked ? tierColor.withValues(alpha: 0.5) : palette.outline,
          ),
          boxShadow: AppShadows.soft(
            palette.isDark ? Colors.black : AppColors.indigo,
            strength: 0.5,
          ),
        ),
        child: Row(
          children: <Widget>[
            tile,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    strings.t(achievement.titleKey),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    strings.t(achievement.descriptionKey),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: palette.textMuted),
                  ),
                  if (!unlocked && achievement.metric.isCumulative) ...<Widget>[
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: status.ratio.clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: palette.outline,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                    const SizedBox(height: 3),
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
              Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: palette.isDark
                    ? AppColors.success
                    : AppColors.ink(AppColors.success),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
