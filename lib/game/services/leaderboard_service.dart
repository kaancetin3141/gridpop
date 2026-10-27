import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/constants/storage_keys.dart';
import '../models/game_mode.dart';
import '../models/score_record.dart';
import '../../storage/storage_manager.dart';

/// Offline leaderboard.
///
/// Every mode keeps its own top list, capped and persisted. When the online
/// backend arrives (V3) only this class has to change: the UI already talks to
/// a `Listenable`.
class LeaderboardService extends ChangeNotifier {
  LeaderboardService(this._storage) {
    _load();
  }

  final StorageManager _storage;

  /// Maximum number of entries kept per mode.
  static const int maxEntries = 25;

  final Map<GameMode, List<ScoreRecord>> _boards = <GameMode, List<ScoreRecord>>{};

  /// Best score of [mode], 0 when nothing was recorded yet.
  int bestFor(GameMode mode) {
    final List<ScoreRecord>? board = _boards[mode];
    if (board == null || board.isEmpty) {
      return 0;
    }
    return board.first.score;
  }

  /// Ranked list for [mode].
  List<ScoreRecord> top(GameMode mode, {int limit = 20}) {
    final List<ScoreRecord> board = _boards[mode] ?? const <ScoreRecord>[];
    if (board.length <= limit) {
      return List<ScoreRecord>.unmodifiable(board);
    }
    return List<ScoreRecord>.unmodifiable(board.sublist(0, limit));
  }

  /// True when the board of [mode] has no entries.
  bool isEmpty(GameMode mode) => (_boards[mode] ?? const <ScoreRecord>[]).isEmpty;

  /// Inserts [record] when it qualifies and persists the board.
  ///
  /// Returns the 1-based rank of the record, or `0` when it did not make the
  /// cut (the board is capped at [maxEntries]).
  Future<int> add(ScoreRecord record) async {
    final List<ScoreRecord> board = _boards.putIfAbsent(
      record.mode,
      () => <ScoreRecord>[],
    );
    board.add(record);
    board.sort(_compare);
    if (board.length > maxEntries) {
      board.removeRange(maxEntries, board.length);
    }
    await _persist();
    notifyListeners();
    final int index = board.indexOf(record);
    return index < 0 ? 0 : index + 1;
  }

  /// Highest score first, oldest run first on a tie.
  static int _compare(ScoreRecord a, ScoreRecord b) {
    final int byScore = b.score.compareTo(a.score);
    if (byScore != 0) {
      return byScore;
    }
    return a.timestamp.compareTo(b.timestamp);
  }

  /// Removes every stored record.
  Future<void> clear() async {
    for (final GameMode mode in GameMode.values) {
      _boards[mode] = <ScoreRecord>[];
    }
    await _persist();
    notifyListeners();
  }

  void _load() {
    final String? raw = _storage.getString(StorageKeys.leaderboard);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      decoded.forEach((String key, Object? value) {
        if (value is! String) {
          return;
        }
        final GameMode mode = GameMode.fromStorageKey(key);
        // Unknown keys would all fall back to classic and pollute that board.
        if (mode.storageKey != key) {
          return;
        }
        final List<ScoreRecord> records = ScoreRecord.decodeList(value)
          ..sort(_compare);
        if (records.isNotEmpty) {
          _boards[mode] = records.take(maxEntries).toList(growable: true);
        }
      });
    } catch (_) {
      // Corrupted payload: start from an empty board instead of crashing.
    }
  }

  Future<void> _persist() {
    final Map<String, dynamic> payload = <String, dynamic>{};
    _boards.forEach((GameMode mode, List<ScoreRecord> records) {
      if (records.isNotEmpty) {
        payload[mode.storageKey] = ScoreRecord.encodeList(records);
      }
    });
    return _storage.setMap(StorageKeys.leaderboard, payload);
  }
}