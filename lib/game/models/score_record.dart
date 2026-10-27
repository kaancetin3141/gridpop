import 'dart:convert';

import '../../core/utils/date_keys.dart';
import '../../core/utils/safe_numbers.dart';
import 'game_mode.dart';

/// One finished run, stored locally for the leaderboard and the statistics.
class ScoreRecord {
  const ScoreRecord({
    required this.score,
    required this.mode,
    required this.combo,
    required this.clearedLines,
    required this.moves,
    required this.dateKey,
    this.date,
  });

  final int score;
  final GameMode mode;

  /// Best combo of the run.
  final int combo;

  final int clearedLines;
  final int moves;

  /// `yyyy-mm-dd` of the run.
  final String dateKey;

  /// Exact timestamp, only used for display.
  final DateTime? date;

  DateTime get timestamp => date ?? DateKeys.parseKey(dateKey);

  Map<String, dynamic> toMap() => <String, dynamic>{
        'score': score,
        'mode': mode.storageKey,
        'combo': combo,
        'lines': clearedLines,
        'moves': moves,
        'date': dateKey,
        'ts': timestamp.millisecondsSinceEpoch,
      };

  /// Rebuilds a record from storage, returning `null` for malformed entries.
  ///
  /// Storage is untrusted: every field is read defensively, so strings,
  /// infinity and negative counters cannot crash the app or poison the board.
  static ScoreRecord? fromMap(Map<String, dynamic> map) {
    final int? rawScore = jsonInt(map['score']);
    if (rawScore == null || rawScore < 0) {
      return null;
    }
    final Object? rawDate = map['date'];
    final String dateKey = rawDate is String && DateKeys.isValidKey(rawDate)
        ? rawDate
        : DateKeys.today();
    final Object? rawMode = map['mode'];
    final int ts = jsonInt(map['ts']) ?? 0;
    DateTime date = DateKeys.parseKey(dateKey);
    if (ts > 0) {
      try {
        date = DateTime.fromMillisecondsSinceEpoch(ts);
      } catch (_) {
        date = DateKeys.parseKey(dateKey);
      }
    }
    return ScoreRecord(
      score: rawScore,
      mode: GameMode.fromStorageKey(rawMode is String ? rawMode : null),
      combo: _count(map['combo']),
      clearedLines: _count(map['lines']),
      moves: _count(map['moves']),
      dateKey: dateKey,
      date: date,
    );
  }

  /// Non negative counter from an untrusted value.
  static int _count(Object? raw) {
    final int value = jsonInt(raw) ?? 0;
    return value < 0 ? 0 : value;
  }

  static String encodeList(List<ScoreRecord> records) =>
      jsonEncode(records.map((ScoreRecord r) => r.toMap()).toList(growable: false));

  static List<ScoreRecord> decodeList(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <ScoreRecord>[];
      }
      final List<ScoreRecord> result = <ScoreRecord>[];
      for (final Object? entry in decoded) {
        if (entry is Map<String, dynamic>) {
          final ScoreRecord? record = ScoreRecord.fromMap(entry);
          if (record != null) {
            result.add(record);
          }
        }
      }
      return result;
    } catch (_) {
      return const <ScoreRecord>[];
    }
  }

  @override
  String toString() => 'ScoreRecord(${mode.name}, $score, $dateKey)';
}