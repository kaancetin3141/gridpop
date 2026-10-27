import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/score_format.dart';
import '../../widgets/animations/motion.dart';
import '../../widgets/buttons/game_buttons.dart';
import '../models/game_mode.dart';
import '../services/game_controller.dart';

/// Top bar of the game screen: quit, mode name and pause.
class GameTopBar extends StatelessWidget {
  const GameTopBar({
    super.key,
    required this.controller,
    required this.onQuit,
    required this.onPause,
    this.trailing,
    this.compact = false,
  });

  final GameController controller;
  final VoidCallback onQuit;
  final VoidCallback onPause;

  /// Optional extra control (the hint button on short screens).
  final Widget? trailing;

  /// Smaller controls for landscape phones.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AppStrings strings = AppStrings.of(context);
    final double size = compact ? 38 : 46;

    return Row(
      children: <Widget>[
        IconPillButton(
          icon: Icons.arrow_back_rounded,
          size: size,
          tooltip: strings.t('common.menu'),
          onPressed: onQuit,
        ),
        SizedBox(width: compact ? 8 : AppSpacing.md),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                strings.t(controller.mode.labelKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: compact
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.titleLarge,
              ),
              if (controller.mode.config.isTimed)
                TimerBadge(
                  seconds: controller.state.remainingSeconds ?? 0,
                  compact: compact,
                ),
            ],
          ),
        ),
        SizedBox(width: compact ? 8 : AppSpacing.md),
        if (trailing != null) ...<Widget>[
          trailing!,
          SizedBox(width: compact ? 8 : AppSpacing.md),
        ],
        IconPillButton(
          icon: Icons.pause_rounded,
          size: size,
          tooltip: strings.t('game.pause'),
          tone: palette.text,
          onPressed: onPause,
        ),
      ],
    );
  }
}

/// Countdown pill for Time Attack.
class TimerBadge extends StatelessWidget {
  const TimerBadge({super.key, required this.seconds, this.compact = false});

  final int seconds;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool urgent = seconds <= 10;
    final Color color = urgent ? AppColors.danger : AppColors.mint;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.timer_outlined, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            ScoreFormat.clock(seconds),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}

/// Big score readout with the best score underneath.
class ScorePanel extends StatelessWidget {
  const ScorePanel({
    super.key,
    required this.score,
    required this.best,
    this.label,
    this.compact = false,
  });

  final int score;
  final int best;
  final String? label;

  /// Shrinks the typography for landscape phones and short windows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AppStrings strings = AppStrings.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label ?? strings.t('game.score'),
          style: text.labelSmall,
        ),
        const SizedBox(height: 2),
        CountUpText(
          value: score,
          builder: (BuildContext context, int value) => Text(
            ScoreFormat.number(value),
            style: (compact ? text.headlineMedium : text.displayMedium)
                ?.copyWith(color: palette.text, height: 1),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${strings.t('game.best')}: ${ScoreFormat.number(best)}',
          style: text.bodySmall?.copyWith(color: palette.textMuted),
        ),
      ],
    );
  }
}

/// Combo pill. Pops when the combo level increases.
class ComboBadge extends StatelessWidget {
  const ComboBadge({
    super.key,
    required this.combo,
    required this.multiplier,
    this.compact = false,
  });

  final int combo;
  final double multiplier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool active = combo > 0;
    final Color color = combo >= 4
        ? AppColors.magenta
        : combo >= 2
            ? AppColors.amber
            : AppColors.grape;

    return AnimatedScale(
      scale: active ? 1 : 0.92,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: active ? 1 : 0.55,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[color, Color.lerp(color, Colors.white, 0.28)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.lift(color, strength: 0.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.local_fire_department_rounded,
                size: compact ? 15 : 18,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                combo > 0 ? 'x${multiplier.toStringAsFixed(1)}' : 'x1.0',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Score booster pill: shows while the ×2 surge is running.
class BoosterBadge extends StatelessWidget {
  const BoosterBadge({super.key, required this.seconds, this.compact = false});

  final int seconds;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (seconds <= 0) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.amber, AppColors.tangerine],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.lift(AppColors.amber, strength: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.bolt_rounded,
            size: compact ? 15 : 18,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            'x2  ${seconds}s',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

/// Row with the score panel and the combo badge.
class GameHudRow extends StatelessWidget {
  const GameHudRow({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final GameController controller;

  /// Compact typography for landscape phones and short windows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget score = ScorePanel(
      score: controller.state.score,
      best: controller.state.highScore,
      compact: compact,
    );
    final Widget combo = ComboBadge(
      combo: controller.state.combo,
      multiplier: controller.state.comboMultiplier,
      compact: compact,
    );
    final Widget booster = BoosterBadge(
      seconds: controller.state.boosterSeconds,
      compact: compact,
    );

    final Widget right = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        booster,
        if (controller.state.boosterSeconds > 0) const SizedBox(width: 8),
        combo,
      ],
    );

    if (compact) {
      // One line: score on the left, booster and combo on the right.
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(child: score),
          right,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        score,
        right,
      ],
    );
  }
}

/// Small pill describing the mode, used by the mode list.
class ModeChip extends StatelessWidget {
  const ModeChip({super.key, required this.mode, this.tone});

  final GameMode mode;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final Color color = tone ?? AppColors.indigo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        strings.t(mode.labelKey),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, letterSpacing: 0.6),
      ),
    );
  }
}