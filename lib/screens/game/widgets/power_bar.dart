import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shop/shop_item.dart';
import '../../../state/app_scope.dart';
import '../../../widgets/animations/motion.dart';

/// Compact power-up buttons shown under the board during a run.
class PowerBar extends StatelessWidget {
  const PowerBar({
    super.key,
    required this.onUse,
    this.compact = false,
  });

  final void Function(ShopItemId item) onUse;
  final bool compact;

  static const Map<ShopItemId, IconData> icons = <ShopItemId, IconData>{
    ShopItemId.refreshTray: Icons.autorenew_rounded,
    ShopItemId.clearBoard: Icons.delete_sweep_rounded,
    ShopItemId.booster: Icons.bolt_rounded,
    ShopItemId.hammer: Icons.gavel_rounded,
    ShopItemId.bomb: Icons.bubble_chart_rounded,
  };

  static const Map<ShopItemId, Color> tints = <ShopItemId, Color>{
    ShopItemId.refreshTray: AppColors.sky,
    ShopItemId.clearBoard: AppColors.coral,
    ShopItemId.booster: AppColors.amber,
    ShopItemId.hammer: AppColors.mint,
    ShopItemId.bomb: AppColors.grape,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppScope.of(context).inventory,
      builder: (BuildContext context, Widget? child) {
        final AppStrings strings = AppStrings.of(context);
        final inventory = AppScope.of(context).inventory;
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // Five pills never fit on a narrow phone: wrap instead of
            // overflowing, with icon + stock count as the compact form.
            final bool iconOnly = compact || constraints.maxWidth < 460;
            return Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                for (final ShopItem item in ShopCatalog.all)
                  _PowerPill(
                    item: item,
                    label: strings.t('power.${item.id.storageKey}'),
                    count: inventory.countOf(item.id),
                    iconOnly: iconOnly,
                    onTap: () => onUse(item.id),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PowerPill extends StatelessWidget {
  const _PowerPill({
    required this.item,
    required this.label,
    required this.count,
    required this.onTap,
    required this.iconOnly,
  });

  final ShopItem item;
  final String label;
  final int count;
  final VoidCallback onTap;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Color accent = PowerBar.tints[item.id] ?? AppColors.indigo;
    final bool empty = count <= 0;
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: empty ? 0.45 : 1,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: empty ? palette.surfaceAlt : palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: empty ? palette.outline : accent.withOpacity(0.55),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  PowerBar.icons[item.id],
                  size: 18,
                  color: empty ? palette.textMuted : accent,
                ),
                if (!iconOnly) ...<Widget>[
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: empty ? palette.textMuted : palette.text,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: empty ? palette.outline : accent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: empty ? palette.textMuted : Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
