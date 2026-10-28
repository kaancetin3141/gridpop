import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/score_format.dart';
import '../../game/models/game_mode.dart';
import '../../state/app_scope.dart';
import '../../widgets/animations/motion.dart';
import '../../widgets/app_background.dart';
import '../../widgets/buttons/game_buttons.dart';
import '../../widgets/logo_mark.dart';
import '../daily/daily_screen.dart';
import '../game/game_screen.dart';
import '../how_to_play/how_to_play_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../settings/settings_screen.dart';
import '../shop/shop_screen.dart';
import '../stats/stats_screen.dart';
import '../achievements/achievements_screen.dart';

/// Main menu of GridPop.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final services = AppScope.of(context);
    final ScreenClass screenClass = Responsive.of(context);

    return AppScaffold(
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          services.stats,
          services.daily,
          services.wallet,
          services.achievements,
        ]),
        builder: (BuildContext context, Widget? child) {
          final int best = services.stats.highScore;
          final int games = services.stats.gamesPlayed;
          final bool dailyDone = services.daily.isCompletedToday;

          final Widget header = _Header(
            best: best,
            games: games,
            streak: services.daily.liveStreak,
            coins: services.wallet.coins,
          );

          final Widget actions = Column(
            children: <Widget>[
              PrimaryButton(
                label: strings.t('home.play'),
                icon: Icons.play_arrow_rounded,
                height: 60,
                onPressed: () {
                  services.audio.play(GameSound.buttonClick);
                  _openGame(context, services, GameMode.classic);
                },
              ),
              const SizedBox(height: 12),
              _DailyCard(
                done: dailyDone,
                stars: services.daily.todayStars,
                bonus: dailyDone
                    ? services.daily.todayStreakBonus
                    : services.daily.nextStreakBonus,
                onTap: () {
                  services.audio.play(GameSound.buttonClick);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const DailyScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              MenuTile(
                icon: Icons.grid_view_rounded,
                label: strings.t('home.modes'),
                subtitle: strings.t('home.modesHint'),
                tint: AppColors.sky,
                onTap: () {
                  services.audio.play(GameSound.buttonClick);
                  _openModes(context, services);
                },
              ),
              MenuTile(
                icon: Icons.emoji_events_rounded,
                label: strings.t('home.leaderboard'),
                subtitle: strings.t('home.leaderboardHint'),
                tint: AppColors.amber,
                onTap: () {
                  services.audio.play(GameSound.buttonClick);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          const LeaderboardScreen(),
                    ),
                  );
                },
              ),
              MenuTile(
                icon: Icons.storefront_rounded,
                label: strings.t('home.shop'),
                subtitle: strings.t('shop.subtitle'),
                tint: AppColors.gold,
                onTap: () {
                  services.audio.play(GameSound.buttonClick);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const ShopScreen(),
                    ),
                  );
                },
              ),
              MenuTile(
                icon: Icons.workspace_premium_rounded,
                label: strings.t('home.achievements'),
                subtitle:
                    '${services.achievements.unlockedCount}/${services.achievements.totalCount}',
                tint: AppColors.bubblegum,
                onTap: () {
                  services.audio.play(GameSound.buttonClick);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          const AchievementsScreen(),
                    ),
                  );
                },
              ),
              MenuTile(
                icon: Icons.insights_rounded,
                label: strings.t('home.stats'),
                subtitle: strings.t('home.statsHint'),
                tint: AppColors.mint,
                onTap: () {
                  services.audio.play(GameSound.buttonClick);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const StatsScreen(),
                    ),
                  );
                },
              ),
              MenuTile(
                icon: Icons.school_rounded,
                label: strings.t('home.howToPlay'),
                subtitle: strings.t('home.howToPlayHint'),
                tint: AppColors.bubblegum,
                onTap: () {
                  services.audio.play(GameSound.buttonClick);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          const HowToPlayScreen(),
                    ),
                  );
                },
              ),
              MenuTile(
                icon: Icons.settings_rounded,
                label: strings.t('home.settings'),
                subtitle: strings.t('home.settingsHint'),
                tint: AppColors.violet,
                onTap: () {
                  services.audio.play(GameSound.buttonClick);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          );

          if (screenClass == ScreenClass.expanded) {
            return Padding(
              padding: Responsive.pagePadding(context),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: Center(child: header)),
                  const SizedBox(width: 40),
                  SizedBox(
                    width: 420,
                    child: SingleChildScrollView(child: actions),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                header,
                const SizedBox(height: 24),
                actions,
              ],
            ),
          );
        },
      ),
    );
  }

  void _openGame(
    BuildContext context,
    AppServices services,
    GameMode mode,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => GameScreen(mode: mode),
      ),
    );
  }

  Future<void> _openModes(BuildContext context, AppServices services) async {
    final AppStrings strings = AppStrings.of(context);
    final GameMode? mode = await showModalBottomSheet<GameMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _ModeSheet(
          strings: strings,
          onPlay: (GameMode selected) => Navigator.of(context).pop(selected),
        );
      },
    );
    if (mode == null || !context.mounted) {
      return;
    }
    if (mode == GameMode.daily) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const DailyScreen(),
        ),
      );
      return;
    }
    _openGame(context, services, mode);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.best,
    required this.games,
    required this.streak,
    required this.coins,
  });

  final int best;
  final int games;
  final int streak;
  final int coins;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AppStrings strings = AppStrings.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const PopIn(child: LogoMark(size: 86, animate: true)),
        const SizedBox(height: 14),
        PopIn(
          delay: const Duration(milliseconds: 60),
          child: _Wordmark(text: strings.t('app.name')),
        ),
        const SizedBox(height: 6),
        PopIn(
          delay: const Duration(milliseconds: 90),
          child: Text(
            strings.t('app.tagline'),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: palette.textMuted),
          ),
        ),
        const SizedBox(height: 18),
        PopIn(
          delay: const Duration(milliseconds: 120),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _StatChip(
                label: strings.t('home.best'),
                value: ScoreFormat.number(best),
                color: AppColors.amber,
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: strings.t('home.games'),
                value: ScoreFormat.number(games),
                color: AppColors.sky,
              ),
              if (streak > 0) ...<Widget>[
                const SizedBox(width: 10),
                _StatChip(
                  label: strings.t('daily.streak'),
                  value: '$streak',
                  color: AppColors.magenta,
                ),
              ],
              if (coins > 0) ...<Widget>[
                const SizedBox(width: 10),
                _CoinChip(coins: coins),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The game name, filled with a warm gradient instead of flat paint.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    // Light mode uses the deepened hues so the gradient keeps its contrast
    // against the pale stage.
    final List<Color> colors = palette.isDark
        ? const <Color>[
            Color(0xFFB79BFF),
            Color(0xFFFF8FD1),
            Color(0xFFFFD34E),
          ]
        : <Color>[
            AppColors.deep(AppColors.violet, lightness: 0.42),
            AppColors.deep(AppColors.magenta, lightness: 0.42),
            AppColors.deep(AppColors.amber, lightness: 0.36),
          ];
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              letterSpacing: 1.2,
              color: Colors.white,
            ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    // Dark stage: the candy hue is the text colour. Light stage: the same hue
    // is tinted into the fill, and the ink version carries the text, otherwise
    // amber on beige would be unreadable.
    final Color ink = palette.isDark ? color : AppColors.ink(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: palette.isDark ? 0.12 : 0.18),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: ink.withValues(alpha: 0.32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: ink, letterSpacing: 0.6),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _CoinChip extends StatelessWidget {
  const _CoinChip({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.gold, AppColors.amber],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.lift(AppColors.amber, strength: 0.6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.paid_rounded, size: 13, color: Colors.white),
              const SizedBox(width: 3),
              Text(
                AppStrings.of(context).t('shop.coinsName'),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.white, letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            ScoreFormat.number(coins),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.done,
    required this.stars,
    required this.bonus,
    required this.onTap,
  });

  final bool done;
  final int stars;

  /// Streak bonus paid today, or the one today's run would pay.
  final int bonus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);

    return Pressable(
      onTap: onTap,
      child: Container(
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
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.today_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    strings.t('home.daily'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    strings.t('modes.dailyDesc'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.85),
                        ),
                  ),
                ],
              ),
            ),
            if (done)
              _Stars(count: stars)
            else ...<Widget>[
              if (bonus > 0) ...<Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.paid_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '+$bonus',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}

/// Three star rating used by the daily card.
class _Stars extends StatelessWidget {
  const _Stars({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < 3; i++)
          Icon(
            i < count ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 16,
            color: i < count ? AppColors.starActive : Colors.white24,
          ),
      ],
    );
  }
}

/// Bottom sheet listing every mode.
class _ModeSheet extends StatelessWidget {
  const _ModeSheet({required this.strings, required this.onPlay});

  final AppStrings strings;
  final ValueChanged<GameMode> onPlay;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    const Map<GameMode, IconData> icons = <GameMode, IconData>{
      GameMode.classic: Icons.grid_4x4_rounded,
      GameMode.daily: Icons.today_rounded,
      GameMode.timeAttack: Icons.timer_rounded,
      GameMode.zen: Icons.self_improvement_rounded,
    };
    const Map<GameMode, Color> tints = <GameMode, Color>{
      GameMode.classic: AppColors.indigo,
      GameMode.daily: AppColors.magenta,
      GameMode.timeAttack: AppColors.coral,
      GameMode.zen: AppColors.mint,
    };

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: palette.outline,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(strings.t('modes.title'),
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            for (final GameMode mode in GameMode.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MenuTile(
                  icon: icons[mode] ?? Icons.extension_rounded,
                  label: strings.t(mode.labelKey),
                  subtitle: strings.t(mode.descriptionKey),
                  tint: tints[mode],
                  onTap: () => onPlay(mode),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
