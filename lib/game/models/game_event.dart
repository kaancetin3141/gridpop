import 'game_mode.dart';
import 'placement_outcome.dart';

/// Everything the game reports to the presentation layer.
///
/// The UI drains the queue inside its `ChangeNotifier` listener, which keeps the
/// controller free of any animation or sound logic while still allowing
/// perfectly timed reactions.
enum GameEventType {
  /// A run just started.
  started,

  /// A piece was dropped successfully (payload: [PlacementOutcome]).
  placed,

  /// A piece was dropped on an invalid cell (payload: tray index).
  invalid,

  /// A piece was rotated by the player (payload: tray index).
  rotated,

  /// A tray piece was used (payload: tray index). The slot stays empty until
  /// the whole tray has been played.
  consumed,

  /// The whole tray was refilled as one batch (all three slots at once).
  trayRefilled,

  /// The whole tray was regenerated because nothing fitted (Zen / Time Attack).
  trayReset,

  /// The settle animation finished: the input gate is open again.
  settled,

  /// No tray piece fits on the board any more. The mode decides what happens
  /// next (game over for the tense modes, refill for the relaxed ones).
  noMove,

  /// Countdown warning (payload: remaining seconds).
  warning,

  /// The run is over (payload: [GameEndSummary]).
  gameOver,

  /// A new global record was set (payload: score).
  newRecord,

  /// A score booster started (payload: seconds).
  booster,

  /// The running score booster expired.
  boosterEnded,

  /// The whole board was cleared by a power-up (payload: `List<TintedCell>`).
  boardCleared,

  /// The board is stuck and a second chance is offered (payload: coin cost).
  reviveOffered,

  /// The second chance was accepted and some rows were wiped
  /// (payload: `List<TintedCell>`).
  reviveStarted,

  /// Blocks were removed with the hammer or the bomb
  /// (payload: `List<TintedCell>`).
  blocksSmashed,

  /// Coins were granted (payload: amount).
  coinsEarned,
}

/// One event produced by `GameController`.
class GameEvent {
  const GameEvent(this.type, [this.payload]);

  final GameEventType type;
  final Object? payload;

  @override
  String toString() => 'GameEvent(${type.name}, $payload)';
}

/// Summary handed to the game over presentation.
class GameEndSummary {
  const GameEndSummary({
    required this.mode,
    required this.score,
    required this.previousBest,
    required this.isNewRecord,
    required this.stars,
    required this.moves,
    required this.linesCleared,
    required this.bestCombo,
    required this.playSeconds,
  });

  final GameMode mode;
  final int score;

  /// High score before this run was stored.
  final int previousBest;

  final bool isNewRecord;

  /// 0-3, only meaningful for the Daily Challenge.
  final int stars;

  final int moves;
  final int linesCleared;
  final int bestCombo;
  final int playSeconds;

  bool get hasStars => mode == GameMode.daily;
}