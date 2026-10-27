/// Keys used by [StorageManager].
///
/// Keeping them in one place avoids typos and makes migrations easy.
class StorageKeys {
  const StorageKeys._();

  static const String prefix = 'gridpop.';

  static const String highScore = '${prefix}highScore';
  static const String totalScore = '${prefix}totalScore';
  static const String gamesPlayed = '${prefix}gamesPlayed';
  static const String bestCombo = '${prefix}bestCombo';
  static const String totalLinesCleared = '${prefix}totalLinesCleared';
  static const String perfectMoves = '${prefix}perfectMoves';
  static const String totalCellsPlaced = '${prefix}totalCellsPlaced';
  static const String totalPlaySeconds = '${prefix}totalPlaySeconds';

  static const String soundEnabled = '${prefix}soundEnabled';
  static const String musicEnabled = '${prefix}musicEnabled';
  static const String vibrationEnabled = '${prefix}vibrationEnabled';
  static const String themeMode = '${prefix}themeMode';
  static const String languageCode = '${prefix}languageCode';

  /// One of `VisualStyle` (aurora, neon, matte, retro).
  static const String visualStyle = '${prefix}visualStyle';
  static const String boardSize = '${prefix}boardSize';
  static const String showGhost = '${prefix}showGhost';
  static const String showHints = '${prefix}showHints';

  static const String leaderboard = '${prefix}leaderboard';
  static const String dailyRecord = '${prefix}dailyRecord';
  static const String lastPlayedDate = '${prefix}lastPlayedDate';

  /// Wallet balance and owned power-ups of the shop.
  static const String coins = '${prefix}coins';
  static const String inventory = '${prefix}inventory';

  /// Earned achievement badges.
  static const String achievements = '${prefix}achievements';
}

/// Modes supported by the in-game settings and by the stats screen.
enum ScoreScope { classic, timeAttack, zen, daily }