/// Life cycle of a single run.
enum GamePhase {
  /// Nothing has started yet.
  ready,

  /// Accepting input.
  playing,

  /// Temporarily suspended (menu opened, app backgrounded).
  paused,

  /// The board is stuck and the player is being offered a second chance.
  /// Input stays closed until [GameController.revive] or the run ends.
  revive,

  /// The run is finished.
  finished,
}

/// Convenience helpers used by the UI.
extension GamePhaseX on GamePhase {
  bool get isPlaying => this == GamePhase.playing;

  bool get isPaused => this == GamePhase.paused;

  bool get isAwaitingRevive => this == GamePhase.revive;

  bool get isFinished => this == GamePhase.finished;

  bool get acceptsInput => this == GamePhase.playing;
}