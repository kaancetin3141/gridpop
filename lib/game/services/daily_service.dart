import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/utils/date_keys.dart';
import '../../core/utils/safe_numbers.dart';
import '../../core/utils/seeded_random.dart';
import '../../storage/storage_manager.dart';

/// Result of one Daily Challenge attempt.
class DailyResult {
  const DailyResult({
    required this.dateKey,
    required this.score,
    required this.stars,
    required this.playedAt,
  });

  final String dateKey;
  final int score;
  final int stars;
  final DateTime playedAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'score': score,
        'stars': stars,
        'ts': playedAt.millisecondsSinceEpoch,
      };

  /// Rebuilds a result from storage, returning `null` for unusable entries.
  ///
  /// The payload is untrusted (local storage is user editable), so every field
  /// is validated instead of cast: a string score, an infinite timestamp or a
  /// forged star count must never crash the boot sequence.
  static DailyResult? fromMap(String dateKey, Map<String, dynamic> map) {
    final int? rawScore = jsonInt(map['score']);
    if (rawScore == null) {
      return null;
    }
    final DateTime fallback = DateKeys.parseKey(dateKey);
    final int ts = jsonInt(map['ts']) ?? 0;
    DateTime playedAt = fallback;
    if (ts > 0) {
      try {
        playedAt = DateTime.fromMillisecondsSinceEpoch(ts);
      } catch (_) {
        playedAt = fallback;
      }
    }
    return DailyResult(
      dateKey: dateKey,
      score: rawScore < 0 ? 0 : rawScore,
      stars: safeRange(map['stars'], min: 0, max: 3),
      playedAt: playedAt,
    );
  }
}

/// Owns the Daily Challenge: the deterministic seed, the per-day record and
/// the streak.
class DailyService extends ChangeNotifier {
  DailyService(this._storage) {
    _load();
  }

  final StorageManager _storage;

  /// `yyyy-mm-dd` -> result.
  final Map<String, DailyResult> _results = <String, DailyResult>{};

  /// `yyyy-mm-dd` for the board currently on offer.
  String get currentDateKey => DateKeys.today();

  /// Seed that reproduces today's piece sequence on every device.
  SeededRandom generatorForToday() => SeededRandom.fromString(DateKeys.dailySeed());

  /// Seed for an arbitrary day (used by tests and by previews).
  SeededRandom generatorFor(String dateKey) =>
      SeededRandom.fromString('$dateKey#pieces');

  /// Today's result, or `null` when the day has not been played yet.
  DailyResult? get todayResult => _results[currentDateKey];

  /// True once today's board has been submitted.
  bool get isCompletedToday => todayResult != null;

  /// Result for [dateKey].
  DailyResult? resultFor(String dateKey) => _results[dateKey];

  /// Best score of today (0 when not played).
  int get todayBestScore => todayResult?.score ?? 0;

  /// Stars earned today (0 when not played).
  int get todayStars => todayResult?.stars ?? 0;

  /// Number of consecutive days played, counting backwards from today.
  int get streak {
    int count = 0;
    DateTime cursor = DateKeys.parseKey(currentDateKey);
    while (true) {
      final String key = DateKeys.key(cursor);
      if (!_results.containsKey(key)) {
        break;
      }
      count++;
      // Calendar arithmetic instead of subtract(Duration(days: 1)): on a DST
      // change that call can land on the same or on a skipped day.
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return count;
  }

  /// 1-based day of the seven day reward ladder on offer.
  ///
  /// Before today's run this is today's own step; once today is played it is
  /// the step that was just paid, so the ladder highlights the right cell.
  int get ladderDay => StreakConfig.dayInCycle(
        isCompletedToday ? streak : previousStreak + 1,
      );

  /// Consecutive days played *before* today, `0` when yesterday is empty.
  ///
  /// [streak] only counts a run of days that ends today, which is why the
  /// ladder needs this separate look-back for a still unplayed day.
  int get previousStreak {
    int count = 0;
    DateTime cursor = DateKeys.parseKey(currentDateKey);
    while (true) {
      // Calendar arithmetic, like [streak]: a DST change must not drop a day.
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
      if (!_results.containsKey(DateKeys.key(cursor))) {
        break;
      }
      count++;
    }
    return count;
  }

  /// The streak the player is currently "on", including a run that was played
  /// yesterday but not yet today. This is what the UI should show.
  int get liveStreak => isCompletedToday ? streak : previousStreak;

  /// Steps already cleared inside the ladder cycle currently on screen.
  int get ladderDoneDays {
    final int day = ladderDay;
    if (isCompletedToday) {
      return day;
    }
    return day == 1 ? 0 : day - 1;
  }

  /// Bonus already paid for today, `0` when today is still unplayed.
  int get todayStreakBonus =>
      isCompletedToday ? StreakConfig.bonusForStreak(streak) : 0;

  /// Bonus the next completed daily pays.
  ///
  /// Before today's run that is today's own reward, afterwards it is tomorrow's
  /// one, so the UI can say "today +40" or "next +60" with the same getter.
  int get nextStreakBonus => isCompletedToday
      ? StreakConfig.bonusForStreak(streak + 1)
      : StreakConfig.bonuses[ladderDay - 1];

  /// 1-based day of the seven day reward ladder, `0` when no streak is running.
  int get streakCycleDay => StreakConfig.dayInCycle(streak);

  /// Stores the result of a finished run. Only the best score of the day is
  /// kept, and re-submitting simply updates it.
  Future<void> submit({required int score, required int stars}) async {
    final String key = currentDateKey;
    final DailyResult? existing = _results[key];
    if (existing != null && existing.score >= score) {
      return;
    }
    // Values come from the game loop, but the service is a public boundary:
    // clamp them so a bad caller cannot persist a negative score or five stars.
    _results[key] = DailyResult(
      dateKey: key,
      score: score < 0 ? 0 : score,
      stars: stars.clamp(0, 3),
      playedAt: DateTime.now(),
    );
    await _prune();
    await _persist();
    notifyListeners();
  }

  /// Keeps at most 30 days of history so storage stays tiny.
  Future<void> _prune() async {
    if (_results.length <= 30) {
      return;
    }
    final List<String> keys = _results.keys.toList(growable: false)..sort();
    for (final String key in keys.take(_results.length - 30)) {
      _results.remove(key);
    }
  }

  void _load() {
    final Map<String, dynamic>? raw = _storage.getMap(StorageKeys.dailyRecord);
    if (raw == null) {
      return;
    }
    raw.forEach((String key, Object? value) {
      // Drop junk keys: a forged key would otherwise sort before the real days
      // and push today's result out of the 30 day window on the next prune.
      if (!DateKeys.isValidKey(key)) {
        return;
      }
      if (value is Map<String, dynamic>) {
        final DailyResult? result = DailyResult.fromMap(key, value);
        if (result != null) {
          _results[key] = result;
        }
      }
    });
  }

  /// Forgets the whole history (used by "reset progress").
  Future<void> reset() async {
    _results.clear();
    await _storage.remove(StorageKeys.dailyRecord);
    notifyListeners();
  }

  Future<void> _persist() {
    final Map<String, dynamic> payload = <String, dynamic>{};
    _results.forEach((String key, DailyResult value) {
      payload[key] = value.toMap();
    });
    return _storage.setMap(StorageKeys.dailyRecord, payload);
  }
}