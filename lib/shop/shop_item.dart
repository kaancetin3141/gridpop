import '../core/constants/app_constants.dart';

/// Power-ups sold in the shop.
enum ShopItemId {
  /// Replaces the tray with a fresh, playable batch.
  refreshTray,

  /// Blasts every block off the board.
  clearBoard,

  /// Starts a 15 second double point surge.
  booster,

  /// Removes a single block the player taps (airdrop style).
  hammer,

  /// Blows a 3x3 hole around the tapped block.
  bomb;

  /// Stable key used for persistence and localization.
  String get storageKey => name;
}

/// One purchasable power-up.
class ShopItem {
  const ShopItem({
    required this.id,
    required this.price,
  });

  final ShopItemId id;
  final int price;

  String get nameKey => 'shopItem.${id.storageKey}.name';

  String get descriptionKey => 'shopItem.${id.storageKey}.desc';
}

/// The whole shop catalogue.
class ShopCatalog {
  const ShopCatalog._();

  static const List<ShopItem> all = <ShopItem>[
    ShopItem(
      id: ShopItemId.refreshTray,
      price: ShopConfig.refreshTrayPrice,
    ),
    ShopItem(
      id: ShopItemId.clearBoard,
      price: ShopConfig.clearBoardPrice,
    ),
    ShopItem(
      id: ShopItemId.booster,
      price: ShopConfig.boosterPrice,
    ),
    ShopItem(
      id: ShopItemId.hammer,
      price: ShopConfig.hammerPrice,
    ),
    ShopItem(
      id: ShopItemId.bomb,
      price: ShopConfig.bombPrice,
    ),
  ];

  static ShopItem byId(ShopItemId id) =>
      all.firstWhere((ShopItem item) => item.id == id);
}
