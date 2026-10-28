import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/animations/motion.dart';
import '../../../widgets/buttons/game_buttons.dart';
import '../../../widgets/logo_mark.dart';

/// What the player chose on the second chance sheet.
enum ReviveChoice {
  /// Pay the coin price.
  coins,

  /// Watch a rewarded ad instead.
  ad,

  /// End the run.
  giveUp,
}

/// "One more chance" sheet, shown before the run is written to the stats.
///
/// Returns `null` when the dialog is dismissed without a choice, which the
/// caller treats as giving up.
Future<ReviveChoice?> showReviveDialog(
  BuildContext context, {
  required int cost,
  required bool canAfford,
  required bool adAvailable,
}) {
  return showDialog<ReviveChoice>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (BuildContext context) => _ReviveDialog(
      cost: cost,
      canAfford: canAfford,
      adAvailable: adAvailable,
    ),
  );
}

class _ReviveDialog extends StatelessWidget {
  const _ReviveDialog({
    required this.cost,
    required this.canAfford,
    required this.adAvailable,
  });

  final int cost;
  final bool canAfford;
  final bool adAvailable;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final AppPalette palette = AppPalette.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const PopIn(child: LogoMark(size: 56, animate: true)),
              const SizedBox(height: AppSpacing.md),
              PopIn(
                delay: const Duration(milliseconds: 60),
                child: Text(
                  strings.t('revive.title'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              PopIn(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  strings.t('revive.body'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: palette.textMuted),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                // A middot instead of a dash: the dash read like a minus, so
                // "Revive - 120" looked like a discount.
                label: '${strings.t('revive.coins')} · $cost',
                icon: Icons.monetization_on_rounded,
                onPressed: canAfford
                    ? () => Navigator.of(context).pop(ReviveChoice.coins)
                    : null,
              ),
              if (!canAfford) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                // Say why the big button is dimmed, instead of leaving the
                // player to guess.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: palette.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      strings.t('shop.notEnough'),
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: palette.textMuted),
                    ),
                  ],
                ),
              ],
              if (adAvailable) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                SoftButton(
                  label: strings.t('revive.ad'),
                  icon: Icons.play_circle_fill_rounded,
                  onPressed: () => Navigator.of(context).pop(ReviveChoice.ad),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(context).pop(ReviveChoice.giveUp),
                child: Text(
                  strings.t('revive.giveUp'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        // Coral on a white sheet is too pale to read; deepen
                        // it instead of swapping the hue.
                        color: palette.isDark
                            ? AppColors.coral
                            : AppColors.deep(AppColors.coral, lightness: 0.4),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
