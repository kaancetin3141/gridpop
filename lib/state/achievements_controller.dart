import 'package:flutter/foundation.dart';

import '../core/constants/storage_keys.dart';
import '../core/utils/date_keys.dart';
import '../game/achievements/achievement.dart';
import '../game/achievements/achievement_catalog.dart';
import '../game/achievements/achievement_engine.dart';
import '../storage/storage_manager.dart';
import 'stats_controller.dart';

/// Owns the earned badges: unlock detection, persistence and gallery rows.
class AchievementsController extends ChangeNotifier {
  AchievementsController(this._storage) {
    _load();
  }

  final StorageManager _storage;

  final Set<String> _unlocked = <String>{};

  Set<String> get unlockedIds => Set<String>.unmodifiable(_unlocked);

  int get unlockedCount => _unlocked.length;

  int get totalCount => AchievementCatalog.all.length;

  bool isUnlocked(String id) => _unlocked.contains(id);

  void _load() {
    final Set<String> known = <String>{
      for (final Achievement achievement in AchievementCatalog.all)
        achievement.id,
    };
    for (final Map<String, dynamic> entry
        in _storage.getMapList(StorageKeys.achievements)) {
      final Object? id = entry['id'];
      // Only accept ids that exist in the catalogue: unknown ids from a
      // tampered payload would inflate "unlocked" past the badge total.
      if (id is String && known.contains(id)) {
        _unlocked.add(id);
      }
    }
  }

  /// Evaluates [snapshot] and persists anything newly earned.
  ///
  /// Returns the badges that were unlocked by this exact call, so the UI can
  /// celebrate them once.
  Future<List<Achievement>> evaluate(AchievementSnapshot snapshot) async {
    final List<Achievement> fresh =
        AchievementEngine.newlyUnlocked(snapshot, _unlocked);
    if (fresh.isEmpty) {
      return const <Achievement>[];
    }
    for (final Achievement achievement in fresh) {
      _unlocked.add(achievement.id);
    }
    await _persist();
    notifyListeners();
    return fresh;
  }

  /// Catches up players that already earned badges before this feature
  /// shipped, without any fanfare.
  Future<void> syncFromStats(StatsController stats) {
    return evaluate(statsAchievementSnapshot(stats));
  }

  /// Gallery rows for the current lifetime statistics.
  List<AchievementStatus> statusesFromStats(StatsController stats) =>
      AchievementEngine.statuses(statsAchievementSnapshot(stats), _unlocked);

  /// Gallery rows for an arbitrary snapshot (tests and previews).
  List<AchievementStatus> statuses(AchievementSnapshot snapshot) =>
      AchievementEngine.statuses(snapshot, _unlocked);

  Future<void> _persist() {
    return _storage.setMapList(
      StorageKeys.achievements,
      <Map<String, dynamic>>[
        for (final String id in _unlocked)
          <String, dynamic>{'id': id, 'dateKey': DateKeys.today()},
      ],
    );
  }

  Future<void> reset() async {
    _unlocked.clear();
    await _storage.remove(StorageKeys.achievements);
    notifyListeners();
  }
}

/// Builds an [AchievementSnapshot] from the lifetime statistics.
AchievementSnapshot statsAchievementSnapshot(StatsController stats) =>
    AchievementSnapshot(
      gamesPlayed: stats.gamesPlayed,
      totalLinesCleared: stats.totalLinesCleared,
      totalCellsPlaced: stats.totalCellsPlaced,
      perfectMoves: stats.perfectMoves,
      bestCombo: stats.bestCombo,
      highScore: stats.highScore,
      totalPlaySeconds: stats.totalPlaySeconds,
    );
