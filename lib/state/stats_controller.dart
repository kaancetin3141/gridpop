import 'package:flutter/foundation.dart';

import '../core/constants/storage_keys.dart';
import '../core/utils/date_keys.dart';
import '../game/models/game_mode.dart';
import '../game/models/score_record.dart';
import '../storage/storage_manager.dart';

/// Aggregate statistics and the global high score.
class StatsController extends ChangeNotifier {
  StatsController(this._storage) {
    _load();
  }

  final StorageManager _storage;

  int _highScore = 0;
  int _totalScore = 0;
  int _gamesPlayed = 0;
  int _bestCombo = 0;
  int _totalLinesCleared = 0;
  int _perfectMoves = 0;
  int _totalCellsPlaced = 0;
  int _totalPlaySeconds = 0;

  int get highScore => _highScore;

  int get totalScore => _totalScore;

  int get gamesPlayed => _gamesPlayed;

  int get bestCombo => _bestCombo;

  int get totalLinesCleared => _totalLinesCleared;

  int get perfectMoves => _perfectMoves;

  int get totalCellsPlaced => _totalCellsPlaced;

  int get totalPlaySeconds => _totalPlaySeconds;

  Duration get totalPlayTime => Duration(seconds: _totalPlaySeconds);

  double get averageScore =>
      _gamesPlayed == 0 ? 0 : (_totalScore / _gamesPlayed).roundToDouble();

  void _load() {
    _highScore = _count(StorageKeys.highScore);
    _totalScore = _count(StorageKeys.totalScore);
    _gamesPlayed = _count(StorageKeys.gamesPlayed);
    _bestCombo = _count(StorageKeys.bestCombo);
    _totalLinesCleared = _count(StorageKeys.totalLinesCleared);
    _perfectMoves = _count(StorageKeys.perfectMoves);
    _totalCellsPlaced = _count(StorageKeys.totalCellsPlaced);
    _totalPlaySeconds = _count(StorageKeys.totalPlaySeconds);
  }

  /// Reads a lifetime counter, treating negative or unusable values as zero.
  int _count(String key) {
    final int value = _storage.getInt(key) ?? 0;
    return value < 0 ? 0 : value;
  }

  /// Registers a finished run and persists the new totals.
  ///
  /// Returns `true` when the run produced a new global record.
  Future<bool> registerRun({
    required int score,
    required int combo,
    required int linesCleared,
    required int cellsPlaced,
    required int perfectMoves,
    required int playSeconds,
  }) async {
    // Every counter is clamped: a negative value would otherwise corrupt the
    // lifetime totals (and a negative score would always count as a record).
    final int runScore = score < 0 ? 0 : score;
    final int runCombo = combo < 0 ? 0 : combo;
    final int runLines = linesCleared < 0 ? 0 : linesCleared;
    final int runCells = cellsPlaced < 0 ? 0 : cellsPlaced;
    final int runPerfect = perfectMoves < 0 ? 0 : perfectMoves;

    _gamesPlayed++;
    _totalScore += runScore;
    _totalLinesCleared += runLines;
    _totalCellsPlaced += runCells;
    _perfectMoves += runPerfect;
    _totalPlaySeconds += playSeconds < 0 ? 0 : playSeconds;
    if (runCombo > _bestCombo) {
      _bestCombo = runCombo;
    }

    final bool isRecord = runScore > _highScore;
    if (isRecord) {
      _highScore = runScore;
    }

    await Future.wait<void>(<Future<void>>[
      _storage.setInt(StorageKeys.gamesPlayed, _gamesPlayed),
      _storage.setInt(StorageKeys.totalScore, _totalScore),
      _storage.setInt(StorageKeys.totalLinesCleared, _totalLinesCleared),
      _storage.setInt(StorageKeys.totalCellsPlaced, _totalCellsPlaced),
      _storage.setInt(StorageKeys.perfectMoves, _perfectMoves),
      _storage.setInt(StorageKeys.totalPlaySeconds, _totalPlaySeconds),
      _storage.setInt(StorageKeys.bestCombo, _bestCombo),
      _storage.setInt(StorageKeys.highScore, _highScore),
    ]);

    notifyListeners();
    return isRecord;
  }

  /// Builds a persistent record out of a finished run.
  ScoreRecord buildRecord({
    required GameMode mode,
    required int score,
    required int combo,
    required int linesCleared,
    required int moves,
  }) {
    return ScoreRecord(
      score: score,
      mode: mode,
      combo: combo,
      clearedLines: linesCleared,
      moves: moves,
      dateKey: DateKeys.today(),
      date: DateTime.now(),
    );
  }

  Future<void> reset() async {
    _highScore = 0;
    _totalScore = 0;
    _gamesPlayed = 0;
    _bestCombo = 0;
    _totalLinesCleared = 0;
    _perfectMoves = 0;
    _totalCellsPlaced = 0;
    _totalPlaySeconds = 0;
    await Future.wait<void>(<Future<void>>[
      _storage.setInt(StorageKeys.highScore, 0),
      _storage.setInt(StorageKeys.totalScore, 0),
      _storage.setInt(StorageKeys.gamesPlayed, 0),
      _storage.setInt(StorageKeys.bestCombo, 0),
      _storage.setInt(StorageKeys.totalLinesCleared, 0),
      _storage.setInt(StorageKeys.perfectMoves, 0),
      _storage.setInt(StorageKeys.totalCellsPlaced, 0),
      _storage.setInt(StorageKeys.totalPlaySeconds, 0),
    ]);
    notifyListeners();
  }
}