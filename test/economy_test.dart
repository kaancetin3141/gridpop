import 'package:flutter_test/flutter_test.dart';
import 'package:gridpop/shop/shop_item.dart';
import 'package:gridpop/state/inventory_controller.dart';
import 'package:gridpop/state/wallet_controller.dart';
import 'package:gridpop/storage/storage_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Wallet', () {
    test('adds coins and refuses to overspend', () async {
      final StorageManager storage = StorageManager.inMemory();
      final WalletController wallet = WalletController(storage);

      expect(wallet.coins, 0);
      await wallet.add(50);
      expect(wallet.coins, 50);
      expect(wallet.canAfford(40), isTrue);
      expect(wallet.canAfford(60), isFalse);

      expect(await wallet.spend(40), isTrue);
      expect(wallet.coins, 10);
      expect(await wallet.spend(40), isFalse);
      expect(wallet.coins, 10);

      await wallet.add(-5);
      await wallet.add(0);
      expect(wallet.coins, 10, reason: 'non positive top-ups are ignored');
    });

    test('balance survives a restart', () async {
      final StorageManager storage = StorageManager.inMemory();
      final WalletController first = WalletController(storage);
      await first.add(77);

      final WalletController second = WalletController(storage);
      expect(second.coins, 77);
    });

    test('reset clears the balance', () async {
      final StorageManager storage = StorageManager.inMemory();
      final WalletController wallet = WalletController(storage);
      await wallet.add(30);
      await wallet.reset();
      expect(wallet.coins, 0);
      expect(WalletController(storage).coins, 0);
    });
  });

  group('Inventory', () {
    test('adds and consumes items with persistence', () async {
      final StorageManager storage = StorageManager.inMemory();
      final InventoryController inventory = InventoryController(storage);

      expect(inventory.countOf(ShopItemId.refreshTray), 0);
      await inventory.add(ShopItemId.refreshTray);
      await inventory.add(ShopItemId.refreshTray);
      await inventory.add(ShopItemId.booster);
      expect(inventory.countOf(ShopItemId.refreshTray), 2);
      expect(inventory.countOf(ShopItemId.booster), 1);
      expect(inventory.totalItems, 3);

      expect(await inventory.consume(ShopItemId.refreshTray), isTrue);
      expect(inventory.countOf(ShopItemId.refreshTray), 1);
      expect(await inventory.consume(ShopItemId.clearBoard), isFalse,
          reason: 'empty stock cannot be consumed');

      final InventoryController reloaded = InventoryController(storage);
      expect(reloaded.countOf(ShopItemId.refreshTray), 1);
      expect(reloaded.countOf(ShopItemId.booster), 1);
      expect(reloaded.totalItems, 2);
    });

    test('reset clears the stock', () async {
      final StorageManager storage = StorageManager.inMemory();
      final InventoryController inventory = InventoryController(storage);
      await inventory.add(ShopItemId.clearBoard);
      await inventory.reset();
      expect(inventory.totalItems, 0);
      expect(InventoryController(storage).totalItems, 0);
    });
  });

  group('Shop catalog', () {
    test('ids are unique and prices are positive', () {
      final Set<String> ids = <String>{};
      for (final ShopItem item in ShopCatalog.all) {
        expect(ids.add(item.id.storageKey), isTrue,
            reason: 'duplicate shop item ${item.id}');
        expect(item.price, greaterThan(0));
        expect(ShopCatalog.byId(item.id), item);
      }
      expect(ShopCatalog.all.length, ShopItemId.values.length);
    });
  });
}
