import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../shop/shop_item.dart';
import '../../state/app_scope.dart';
import '../../widgets/animations/motion.dart';
import '../../widgets/app_background.dart';
import '../../widgets/buttons/game_buttons.dart';
import '../../widgets/coin_badge.dart';
import '../../widgets/dialogs/app_dialogs.dart';
import '../game/widgets/power_bar.dart';

/// The coin shop: power-ups for coins, plus a rewarded ad fallback.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final services = AppScope.of(context);

    return AppScaffold(
      child: ListenableBuilder(
        listenable:
            Listenable.merge(<Listenable>[services.wallet, services.inventory]),
        builder: (BuildContext context, Widget? child) {
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
                        strings.t('shop.title'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    CoinBadge(onTap: () {}),
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
                          Text(
                            strings.t('shop.subtitle'),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppPalette.of(context).textMuted,
                                    ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          for (final ShopItem item in ShopCatalog.all)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.md),
                              child: _ShopCard(
                                item: item,
                                owned: services.inventory.countOf(item.id),
                                affordable:
                                    services.wallet.canAfford(item.price),
                                onBuy: () => _buy(context, services, item),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          _AdCard(
                            onWatch: () => _watchAd(context, services),
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

  Future<void> _buy(
    BuildContext context,
    AppServices services,
    ShopItem item,
  ) async {
    final AppStrings strings = AppStrings.of(context);
    final bool paid = await services.wallet.spend(item.price);
    if (!paid) {
      if (context.mounted) {
        showToast(context, strings.t('shop.notEnough'));
      }
      return;
    }
    await services.inventory.add(item.id);
    services.audio.play(GameSound.buttonClick);
    if (context.mounted) {
      showToast(context, strings.t('shop.bought'));
    }
  }

  Future<void> _watchAd(
    BuildContext context,
    AppServices services,
  ) async {
    final bool watched = await services.ads.showRewardedAd(context);
    if (!watched) {
      return;
    }
    await services.wallet.add(CoinConfig.adReward);
    services.audio.play(GameSound.highScore);
    if (context.mounted) {
      showToast(
        context,
        '+${CoinConfig.adReward} ${AppStrings.of(context).t('shop.coinsName')}',
      );
    }
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.item,
    required this.owned,
    required this.affordable,
    required this.onBuy,
  });

  final ShopItem item;
  final int owned;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AppStrings strings = AppStrings.of(context);
    final Color accent = PowerBar.tints[item.id] ?? AppColors.indigo;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.outline),
        boxShadow: AppShadows.soft(
          palette.isDark ? Colors.black : AppColors.indigo,
          strength: 0.6,
        ),
      ),
      child: Stack(
        children: <Widget>[
          // A thin strip in the power-up colour, so each card has its own
          // identity without repainting the whole surface.
          Positioned(
            left: 6,
            top: 18,
            bottom: 18,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.55),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            accent.withOpacity(0.9),
                            Color.lerp(accent, Colors.white, 0.25)!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        PowerBar.icons[item.id],
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strings.t(item.nameKey),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            strings.t(item.descriptionKey),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    if (owned > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: palette.outline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.inventory_2_rounded,
                              size: 13,
                              color: palette.textMuted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'x$owned',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: palette.textMuted,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    // One button that says both what it does and what it costs;
                    // the separate price pill only repeated the same number.
                    Pressable(
                      onTap: onBuy,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: affordable
                                ? const <Color>[
                                    AppColors.indigo,
                                    AppColors.violet
                                  ]
                                : <Color>[
                                    palette.surfaceAlt,
                                    palette.surfaceAlt,
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.paid_rounded,
                              size: 15,
                              color: affordable
                                  ? AppColors.gold
                                  : palette.textMuted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${item.price}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: affordable
                                        ? Colors.white
                                        : palette.textMuted,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 1,
                              height: 14,
                              color: affordable
                                  ? Colors.white.withOpacity(0.35)
                                  : palette.outline,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              strings.t('shop.buy'),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: affordable
                                        ? Colors.white
                                        : palette.textMuted,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdCard extends StatelessWidget {
  const _AdCard({required this.onWatch});

  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AppStrings strings = AppStrings.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.mint.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.mint.withOpacity(0.45)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.mint.withOpacity(0.18),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.play_circle_fill_rounded,
              color: AppColors.mint,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.t('shop.freeCoins'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  strings.t('shop.freeCoinsDesc'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: palette.textMuted),
                ),
              ],
            ),
          ),
          Pressable(
            onTap: onWatch,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                strings.t('shop.watchAd'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
