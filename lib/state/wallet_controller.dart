import 'package:flutter/foundation.dart';

import '../core/constants/storage_keys.dart';
import '../storage/storage_manager.dart';

/// The player's coin wallet: earns coins from the Daily Challenge and
/// rewarded ads, spends them in the shop.
class WalletController extends ChangeNotifier {
  WalletController(this._storage) {
    _load();
  }

  final StorageManager _storage;

  int _coins = 0;

  int get coins => _coins;

  bool canAfford(int price) => price >= 0 && _coins >= price;

  void _load() {
    _coins = _storage.getInt(StorageKeys.coins) ?? 0;
    if (_coins < 0) {
      _coins = 0;
    }
  }

  /// Adds [amount] coins (recent dailies, rewarded ads).
  Future<void> add(int amount) async {
    if (amount <= 0) {
      return;
    }
    _coins += amount;
    await _storage.setInt(StorageKeys.coins, _coins);
    notifyListeners();
  }

  /// Spends [price] coins. Returns `false` when the balance is too low.
  Future<bool> spend(int price) async {
    if (price < 0 || _coins < price) {
      return false;
    }
    _coins -= price;
    await _storage.setInt(StorageKeys.coins, _coins);
    notifyListeners();
    return true;
  }

  Future<void> reset() async {
    _coins = 0;
    await _storage.setInt(StorageKeys.coins, 0);
    notifyListeners();
  }
}
