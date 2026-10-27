import '../models/game_mode.dart';
import 'achievement.dart';
import 'achievement_catalog.dart';

/// Everything the engine needs to judge the badges, as one immutable value.
class AchievementSnapshot {
  const AchievementSnapshot({
    this.gamesPlayed = 0,
    this.totalLinesCleared = 0,
    this.totalCellsPlaced = 0,
    this.perfectMoves = 0,
    this.bestCombo = 0,
    this.highScore = 0,
    this.totalPlaySeconds = 0,
    this.runScore = 0,
    this.runCombo = 0,
    this.runPerfectMoves = 0,
    this.runMode,
    this.runDailyCompleted = false,
    this.runDailyStars = 0,
  });

  // --- lifetime ---------------------------------------------------------
  final int gamesPlayed;
  final int totalLinesCleared;
  final int totalCellsPlaced;
  final int perfectMoves;
  final int bestCombo;
  final int highScore;
  final int totalPlaySeconds;

  // --- current or last run ----------------------------------------------
  final int runScore;
  final int runCombo;
  final int runPerfectMoves;
  final GameMode? runMode;
  final bool runDailyCompleted;
  final int runDailyStars;

  /// Value watched by [metric] in this snapshot.
  int valueFor(AchievementMetric metric) => switch (metric) {
        AchievementMetric.gamesPlayed => gamesPlayed,
        AchievementMetric.totalLinesCleared => totalLinesCleared,
        AchievementMetric.totalCellsPlaced => totalCellsPlaced,
        AchievementMetric.perfectMoves => perfectMoves,
        AchievementMetric.bestCombo => bestCombo,
        AchievementMetric.highScore => highScore,
        AchievementMetric.totalPlaySeconds => totalPlaySeconds,
        AchievementMetric.runScore => runScore,
        AchievementMetric.runCombo => runCombo,
        AchievementMetric.runPerfectMoves => runPerfectMoves,
        AchievementMetric.timeAttackScore =>
          runMode == GameMode.timeAttack ? runScore : 0,
        AchievementMetric.dailyCompleted => runDailyCompleted ? 1 : 0,
        AchievementMetric.dailyThreeStars => runDailyStars >= 3 ? 1 : 0,
      };
}

/// One row of the achievements screen.
class AchievementStatus {
  const AchievementStatus({
    required this.achievement,
    required this.progress,
    required this.unlocked,
  });

  final Achievement achievement;

  /// Current value towards the target, clamped to `[0, target]`.
  final int progress;
  final bool unlocked;

  double get ratio => progress / achievement.target;
}

/// Pure badge maths: which badges a snapshot earns and how far the locked
/// ones have come.
class AchievementEngine {
  const AchievementEngine._();

  /// A status row for every badge in catalogue order.
  static List<AchievementStatus> statuses(
    AchievementSnapshot snapshot,
    Set<String> unlockedIds,
  ) =>
      <AchievementStatus>[
        for (final Achievement achievement in AchievementCatalog.all)
          _statusFor(achievement, snapshot, unlockedIds),
      ];

  static AchievementStatus _statusFor(
    Achievement achievement,
    AchievementSnapshot snapshot,
    Set<String> unlockedIds,
  ) {
    final int value = snapshot.valueFor(achievement.metric);
    final bool unlocked =
        unlockedIds.contains(achievement.id) || value >= achievement.target;
    final int progress = value < 0
        ? 0
        : (value > achievement.target ? achievement.target : value);
    return AchievementStatus(
      achievement: achievement,
      progress: progress,
      unlocked: unlocked,
    );
  }

  /// Badges earned by [snapshot] that are not in [knownIds] yet.
  static List<Achievement> newlyUnlocked(
    AchievementSnapshot snapshot,
    Set<String> knownIds,
  ) =>
      <Achievement>[
        for (final Achievement achievement in AchievementCatalog.all)
          if (!knownIds.contains(achievement.id) &&
              snapshot.valueFor(achievement.metric) >= achievement.target)
            achievement,
      ];
}
