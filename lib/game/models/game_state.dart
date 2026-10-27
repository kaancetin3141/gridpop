import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import 'game_mode.dart';
import 'game_phase.dart';
import 'piece_slot.dart';

/// Immutable snapshot of a run, published by `GameController` after every
/// change.
///
/// Widgets render from this object only, which keeps rendering deterministic
/// and makes the whole game loop trivially testable without a widget tree.
@immutable
class GameState {
  const GameState({
    required this.mode,
    required this.phase,
    required this.score,
    required this.highScore,
    required this.combo,
    required this.bestComboThisRun,
    required this.moves,
    required this.cellsPlaced,
    required this.linesCleared,
    required this.perfectMoves,
    required this.tray,
    required this.remainingSeconds,
    required this.isNewRecord,
    required this.emptyCells,
    required this.boardSize,
    this.boosterSeconds = 0,
  });

  /// Snapshot used before a run is created.
  factory GameState.initial({
    GameMode mode = GameMode.classic,
    int boardSize = 8,
    int highScore = 0,
  }) {
    return GameState(
      mode: mode,
      phase: GamePhase.ready,
      score: 0,
      highScore: highScore,
      combo: 0,
      bestComboThisRun: 0,
      moves: 0,
      cellsPlaced: 0,
      linesCleared: 0,
      perfectMoves: 0,
      tray: const <PieceSlot?>[],
      remainingSeconds: mode.config.timeLimit?.inSeconds,
      isNewRecord: false,
      emptyCells: boardSize * boardSize,
      boardSize: boardSize,
    );
  }

  final GameMode mode;
  final GamePhase phase;

  /// Current score of the run.
  final int score;

  /// Best score ever reached (all modes).
  final int highScore;

  /// Current combo level (0 = broken).
  final int combo;

  /// Highest combo level reached during this run.
  final int bestComboThisRun;

  final int moves;
  final int cellsPlaced;
  final int linesCleared;
  final int perfectMoves;

  /// The pieces the player can pick up. A `null` slot is an empty slot that
  /// was used already: the batch only refills when the whole tray is empty.
  final List<PieceSlot?> tray;

  /// Remaining seconds for timed modes.
  final int? remainingSeconds;

  /// True when the run beat the stored high score.
  final bool isNewRecord;

  /// Free cells left on the board.
  final int emptyCells;

  final int boardSize;

  /// Seconds left on the active score booster (0 = no booster).
  final int boosterSeconds;

  bool get isTimed => remainingSeconds != null;

  bool get boosterActive => boosterSeconds > 0;

  bool get isFinished => phase == GamePhase.finished;

  bool get acceptsInput => phase == GamePhase.playing;

  /// Combo multiplier derived from [combo].
  double get comboMultiplier {
    final double raw = 1 + ScoringConfig.comboStep * combo;
    return raw > ScoringConfig.comboCap ? ScoringConfig.comboCap : raw;
  }

  GameState copyWith({
    GameMode? mode,
    GamePhase? phase,
    int? score,
    int? highScore,
    int? combo,
    int? bestComboThisRun,
    int? moves,
    int? cellsPlaced,
    int? linesCleared,
    int? perfectMoves,
    List<PieceSlot?>? tray,
    int? remainingSeconds,
    bool? isNewRecord,
    int? emptyCells,
    int? boardSize,
    int? boosterSeconds,
  }) {
    return GameState(
      mode: mode ?? this.mode,
      phase: phase ?? this.phase,
      score: score ?? this.score,
      highScore: highScore ?? this.highScore,
      combo: combo ?? this.combo,
      bestComboThisRun: bestComboThisRun ?? this.bestComboThisRun,
      moves: moves ?? this.moves,
      cellsPlaced: cellsPlaced ?? this.cellsPlaced,
      linesCleared: linesCleared ?? this.linesCleared,
      perfectMoves: perfectMoves ?? this.perfectMoves,
      tray: tray ?? this.tray,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isNewRecord: isNewRecord ?? this.isNewRecord,
      emptyCells: emptyCells ?? this.emptyCells,
      boardSize: boardSize ?? this.boardSize,
      boosterSeconds: boosterSeconds ?? this.boosterSeconds,
    );
  }

  @override
  String toString() =>
      'GameState(${mode.name}, ${phase.name}, score: $score, combo: $combo)';
}