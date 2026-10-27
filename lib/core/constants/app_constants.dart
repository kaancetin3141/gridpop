/// Global tuning values for GridPop.
///
/// Everything gameplay related that could be re-balanced later lives here so
/// that no gameplay logic file needs to be touched for balance changes.
library;

/// Board related values.
class BoardConfig {
  const BoardConfig._();

  static const int defaultSize = 8;
  static const int smallSize = 8;
  static const int largeSize = 9;
  static const List<int> selectableSizes = <int>[8, 9];

  /// Number of piece slots the player can choose from at any time.
  static const int traySize = 3;

  /// Radius (relative to cell size) of the chunky rounded tiles. Deliberately
  /// not sharp (that reads as Tetris) and not oval either: a rounded square.
  static const double cornerRadiusFactor = 0.21;

  /// Gap between two neighbouring blocks, relative to the cell size.
  static const double cellGapFactor = 0.06;
}

/// Scoring table. All values are plain integers so the math stays
/// deterministic and easy to unit test.
class ScoringConfig {
  const ScoringConfig._();

  /// Points for every placed cell.
  static const int pointsPerCell = 1;

  /// Points for a completely filled row.
  static const int pointsPerRow = 20;

  /// Points for a completely filled column.
  static const int pointsPerColumn = 20;

  /// Bonus added for each additional line inside the same move.
  static const int multiLineBonus = 30;

  /// Bonus for clearing three or more lines with a single move.
  static const int perfectBonus = 120;

  /// Extra multiplier step for each combo level.
  static const double comboStep = 0.25;

  /// Upper bound of the combo multiplier.
  static const double comboCap = 6.0;

  /// Consecutive clearing moves needed to reach combo level 1, 2, 3...
  static const int comboMovesPerLevel = 1;
}

/// Score booster ("surge") tuning.
class BoosterConfig {
  const BoosterConfig._();

  /// Booster granted when the player passes the all time record.
  static const int recordDurationSeconds = 10;

  /// Booster bought in the shop and used from the power bar.
  static const int manualDurationSeconds = 15;

  /// Score multiplier while a booster is running.
  static const double multiplier = 2;
}

/// Dead tray ("no moves left") detection.
class DeadTrayConfig {
  const DeadTrayConfig._();

  /// How often the controller verifies that a move still exists. Small enough
  /// to feel instant, large enough to be free.
  static const Duration watchdogInterval = Duration(milliseconds: 350);
}

/// Coin economy tuning.
class CoinConfig {
  const CoinConfig._();

  /// Coins granted for finishing the Daily Challenge.
  static const int dailyBase = 20;

  /// Extra coins per star earned on the Daily Challenge.
  static const int dailyPerStar = 10;

  /// One extra coin per this many points scored in the daily run.
  static const int dailyScoreStep = 200;

  /// Coins granted for watching a rewarded ad.
  static const int adReward = 20;
}

/// Seven day ladder paid on top of the Daily Challenge coins for playing on
/// consecutive days.
///
/// The ladder is what turns "I played once" into "I come back tomorrow": the
/// bonus grows every day, and a full week pays more than three shop items.
class StreakConfig {
  const StreakConfig._();

  /// A full ladder; longer streaks wrap around to day 1 of a new cycle.
  static const int cycleLength = 7;

  /// Bonus coins for cycle day 1..7 (`bonuses[0]` is day 1).
  static const List<int> bonuses = <int>[10, 15, 25, 40, 60, 85, 120];

  /// Total paid by one full cycle, used by the docs and the tests.
  static int get cycleTotal => bonuses.fold<int>(0, (int a, int b) => a + b);

  /// 1-based position inside the current cycle for a [streak] of days.
  ///
  /// Returns `0` for an empty streak, and wraps every [cycleLength] days so a
  /// 30 day streak still pays the day 1..7 ladder.
  static int dayInCycle(int streak) {
    if (streak <= 0) {
      return 0;
    }
    return (streak - 1) % cycleLength + 1;
  }

  /// Bonus paid for the [streak]-th consecutive day, `0` when there is none.
  static int bonusForStreak(int streak) {
    final int day = dayInCycle(streak);
    return day == 0 ? 0 : bonuses[day - 1];
  }
}

/// Power-up prices, paid with coins in the shop.
class ShopConfig {
  const ShopConfig._();

  static const int refreshTrayPrice = 40;
  static const int clearBoardPrice = 120;
  static const int boosterPrice = 60;
  static const int hammerPrice = 80;
  static const int bombPrice = 140;
}

/// Second chance offered once per run when the board is stuck.
class ReviveConfig {
  const ReviveConfig._();

  /// Coins the player can pay instead of watching a rewarded ad.
  static const int cost = 150;

  /// The fullest rows are wiped to make room again.
  static const int rowsToClear = 3;
}

/// Animation timings (milliseconds). Kept short and snappy, matching the
/// feel of modern casual puzzle games.
class MotionConfig {
  const MotionConfig._();

  static const int blockPickup = 90;
  static const int blockPlace = 180;

  /// Delay added per cell so a multi cell piece lands like a wave.
  static const int blockSettleStagger = 26;

  static const int clearSweep = 320;
  static const int clearCellFade = 260;
  static const int comboBanner = 900;
  static const int scorePopup = 850;
  static const int trayNewPiece = 320;
  static const int trayNewPieceStagger = 70;
  static const int boardShakeInvalid = 240;
  static const int gameOverFade = 420;
  static const int perfectFlash = 520;
  static const int highScoreFlash = 900;

  /// How long a piece stays "settling" before the tray is refilled. The tray
  /// is never refilled before this window closes, so the player always sees
  /// the result of their move before the next piece arrives.
  static const int settleWindow = 240;

  /// Hard cap for the settle window: if the animation layer is disabled or
  /// stalls, input is released anyway so the game can never deadlock.
  static const int settleSafety = 1200;

  /// Freeze frame on a big clear ("hit stop"). Sells the impact.
  static const int hitStop = 70;

  /// Board squash after a placement: peak scale and settle time.
  static const double boardSquash = 0.028;
  static const int boardSquashTime = 220;

  /// Extra particles spawned on a perfect move.
  static const int perfectStars = 14;

  /// Grace window during which a drag that started before the input gate
  /// closed is still honoured ("input buffering").
  static const int inputGrace = 180;
}

/// Time Attack configuration.
class TimeAttackConfig {
  const TimeAttackConfig._();

  static const int durationSeconds = 90;
  static const Duration tick = Duration(milliseconds: 200);
  static const List<int> warningSeconds = <int>[30, 10, 5];
}

/// Daily Challenge configuration.
class DailyConfig {
  const DailyConfig._();

  static const int boardSize = 8;
  static const int traySize = 3;

  /// Target score to earn three stars.
  static const List<int> starThresholds = <int>[1200, 2200, 3400];
}

/// Animation / feel constants for the board gesture layer.
class InputConfig {
  const InputConfig._();

  /// Distance (logical px) the piece must travel before a drag starts.
  static const double dragSlop = 6;

  /// Vertical gap between the board and the tray on compact layouts.
  static const double trayGap = 18;

  /// Height reserved for the tray area on compact layouts.
  static const double trayAreaHeight = 168;
}

/// Haptic identifiers, mapped to the platform haptic channels in
/// `HapticsService`.
enum HapticKind { selection, light, medium, heavy, success, warning }