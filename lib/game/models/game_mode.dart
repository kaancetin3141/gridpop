/// Per mode tuning. Keeping it in one immutable object makes the modes
/// data-driven: the game logic never branches on `if (mode == ...)`.
class GameModeConfig {
  const GameModeConfig({
    required this.mode,
    required this.boardSize,
    required this.traySize,
    required this.labelKey,
    required this.descriptionKey,
    required this.allowsGameOver,
    required this.timeLimit,
    required this.largePieceBias,
    this.starThresholds = const <int>[],
  });

  final GameMode mode;

  /// Side length of the board.
  final int boardSize;

  /// Number of pieces offered at the same time.
  final int traySize;

  /// Localization keys.
  final String labelKey;
  final String descriptionKey;

  /// `false` means the run never ends (Zen refill).
  final bool allowsGameOver;

  /// `null` for untimed modes.
  final Duration? timeLimit;

  /// How strongly bigger shapes are favoured as the score grows.
  final double largePieceBias;

  /// Score thresholds for the star rating (Daily only).
  final List<int> starThresholds;

  bool get isTimed => timeLimit != null;

  Duration? get limit => timeLimit;
}

/// Every playable mode of GridPop.
enum GameMode {
  classic(
    labelKey: 'modes.classic',
    descriptionKey: 'modes.classicDesc',
  ),
  daily(
    labelKey: 'modes.daily',
    descriptionKey: 'modes.dailyDesc',
  ),
  timeAttack(
    labelKey: 'modes.timeAttack',
    descriptionKey: 'modes.timeAttackDesc',
  ),
  zen(
    labelKey: 'modes.zen',
    descriptionKey: 'modes.zenDesc',
  );

  const GameMode({
    required this.labelKey,
    required this.descriptionKey,
  });

  final String labelKey;
  final String descriptionKey;

  /// Stable key used for storage and for the leaderboard tabs.
  String get storageKey => name;

  /// Configuration for this mode.
  GameModeConfig get config => configFor(this);

  /// Returns the configuration of [mode].
  static GameModeConfig configFor(GameMode mode) {
    switch (mode) {
      case GameMode.classic:
        return const GameModeConfig(
          mode: GameMode.classic,
          boardSize: 8,
          traySize: 3,
          labelKey: 'modes.classic',
          descriptionKey: 'modes.classicDesc',
          allowsGameOver: true,
          timeLimit: null,
          largePieceBias: 1,
        );
      case GameMode.daily:
        return const GameModeConfig(
          mode: GameMode.daily,
          boardSize: 8,
          traySize: 3,
          labelKey: 'modes.daily',
          descriptionKey: 'modes.dailyDesc',
          allowsGameOver: true,
          timeLimit: null,
          largePieceBias: 0.85,
          starThresholds: <int>[1200, 2200, 3400],
        );
      case GameMode.timeAttack:
        return const GameModeConfig(
          mode: GameMode.timeAttack,
          boardSize: 9,
          traySize: 3,
          labelKey: 'modes.timeAttack',
          descriptionKey: 'modes.timeAttackDesc',
          allowsGameOver: false,
          timeLimit: Duration(seconds: 90),
          largePieceBias: 1.35,
        );
      case GameMode.zen:
        return const GameModeConfig(
          mode: GameMode.zen,
          boardSize: 9,
          traySize: 3,
          labelKey: 'modes.zen',
          descriptionKey: 'modes.zenDesc',
          allowsGameOver: false,
          timeLimit: null,
          largePieceBias: 0.7,
        );
    }
  }

  /// Modes that own a leaderboard tab.
  static List<GameMode> get leaderboardModes => <GameMode>[
        GameMode.classic,
        GameMode.timeAttack,
        GameMode.zen,
        GameMode.daily,
      ];

  /// Parses a stored key back into a mode, defaulting to [GameMode.classic].
  static GameMode fromStorageKey(String? key) {
    for (final GameMode mode in GameMode.values) {
      if (mode.storageKey == key) {
        return mode;
      }
    }
    return GameMode.classic;
  }
}