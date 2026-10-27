import 'package:flutter/foundation.dart';

import '../core/constants/storage_keys.dart';
import '../shop/shop_item.dart';
import '../storage/storage_manager.dart';

/// Consumable power-ups bought in the shop and spent during a run.
///
/// Counts are persisted as `{ itemId: count }` so the stock survives app
/// restarts.
class InventoryController extends ChangeNotifier {
  InventoryController(this._storage) {
    _load();
  }

  final StorageManager _storage;

  final Map<String, int> _counts = <String, int>{};

  int countOf(ShopItemId item) => _counts[item.storageKey] ?? 0;

  int get totalItems {
    int total = 0;
    for (final int count in _counts.values) {
      total += count;
    }
    return total;
  }

  void _load() {
    final Map<String, dynamic>? stored = _storage.getMap(StorageKeys.inventory);
    if (stored == null) {
      return;
    }
    for (final ShopItem item in ShopCatalog.all) {
      final Object? raw = stored[item.id.storageKey];
      if (raw is int && raw > 0) {
        _counts[item.id.storageKey] = raw;
      }
    }
  }

  /// Adds one [item] to the stock (called after a successful purchase).
  Future<void> add(ShopItemId item) async {
    final String key = item.storageKey;
    _counts[key] = countOf(item) + 1;
    await _persist();
    notifyListeners();
  }

  /// Consumes one [item]. Returns `false` when the stock is empty.
  Future<bool> consume(ShopItemId item) async {
    final int count = countOf(item);
    if (count <= 0) {
      return false;
    }
    final String key = item.storageKey;
    if (count == 1) {
      _counts.remove(key);
    } else {
      _counts[key] = count - 1;
    }
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> _persist() async {
    await _storage.setMap(
      StorageKeys.inventory,
      <String, dynamic>{
        for (final MapEntry<String, int> entry in _counts.entries)
          entry.key: entry.value,
      },
    );
  }

  Future<void> reset() async {
    _counts.clear();
    await _storage.remove(StorageKeys.inventory);
    notifyListeners();
  }
}
