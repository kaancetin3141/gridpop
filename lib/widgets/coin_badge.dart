import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/score_format.dart';
import '../state/app_scope.dart';
import 'animations/motion.dart';

/// Golden coin pill showing the wallet balance.
class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key, this.onTap, this.compact = false});

  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return ListenableBuilder(
      listenable: AppScope.of(context).wallet,
      builder: (BuildContext context, Widget? child) {
        final int coins = AppScope.of(context).wallet.coins;
        // Pop on every change so earning coins is visible at a glance.
        return TweenAnimationBuilder<double>(
          key: ValueKey<int>(coins),
          tween: Tween<double>(begin: 1.14, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          builder: (BuildContext context, double scale, Widget? child) =>
              Transform.scale(scale: scale, child: child),
          child: Pressable(
            onTap: onTap,
            child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 6 : 9,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[AppColors.gold, AppColors.amber],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: AppShadows.lift(AppColors.amber, strength: 0.7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.paid_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  ScoreFormat.number(AppScope.of(context).wallet.coins),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(width: 4),
                Text(
                  strings.t('shop.coinsName'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }
}
