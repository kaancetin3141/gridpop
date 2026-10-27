import 'achievement.dart';

/// Every badge shipped with the game, grouped by tier.
///
/// The order is the order shown on the achievements screen: the easy badges
/// first, the long term goals last.
class AchievementCatalog {
  const AchievementCatalog._();

  static const List<Achievement> all = <Achievement>[
    // --- bronze ---------------------------------------------------------
    Achievement(
      id: 'firstSteps',
      metric: AchievementMetric.gamesPlayed,
      target: 1,
      tier: AchievementTier.bronze,
    ),
    Achievement(
      id: 'lineCook',
      metric: AchievementMetric.totalLinesCleared,
      target: 1,
      tier: AchievementTier.bronze,
    ),
    Achievement(
      id: 'comboStarter',
      metric: AchievementMetric.bestCombo,
      target: 3,
      tier: AchievementTier.bronze,
    ),
    Achievement(
      id: 'firstSpark',
      metric: AchievementMetric.perfectMoves,
      target: 1,
      tier: AchievementTier.bronze,
    ),
    Achievement(
      id: 'risingStar',
      metric: AchievementMetric.runScore,
      target: 1000,
      tier: AchievementTier.bronze,
    ),
    Achievement(
      id: 'brickLayer',
      metric: AchievementMetric.totalCellsPlaced,
      target: 1000,
      tier: AchievementTier.bronze,
    ),
    Achievement(
      id: 'dailyDevotion',
      metric: AchievementMetric.dailyCompleted,
      target: 1,
      tier: AchievementTier.bronze,
    ),
    Achievement(
      id: 'steady',
      metric: AchievementMetric.totalPlaySeconds,
      target: 600,
      tier: AchievementTier.bronze,
    ),

    // --- silver ---------------------------------------------------------
    Achievement(
      id: 'regular',
      metric: AchievementMetric.gamesPlayed,
      target: 10,
      tier: AchievementTier.silver,
    ),
    Achievement(
      id: 'carpenter',
      metric: AchievementMetric.totalLinesCleared,
      target: 100,
      tier: AchievementTier.silver,
    ),
    Achievement(
      id: 'comboMaster',
      metric: AchievementMetric.bestCombo,
      target: 8,
      tier: AchievementTier.silver,
    ),
    Achievement(
      id: 'perfectionist',
      metric: AchievementMetric.perfectMoves,
      target: 25,
      tier: AchievementTier.silver,
    ),
    Achievement(
      id: 'builder',
      metric: AchievementMetric.totalCellsPlaced,
      target: 5000,
      tier: AchievementTier.silver,
    ),
    Achievement(
      id: 'highRoller',
      metric: AchievementMetric.runScore,
      target: 2500,
      tier: AchievementTier.silver,
    ),
    Achievement(
      id: 'blitz',
      metric: AchievementMetric.timeAttackScore,
      target: 1500,
      tier: AchievementTier.silver,
    ),
    Achievement(
      id: 'starCollector',
      metric: AchievementMetric.dailyThreeStars,
      target: 1,
      tier: AchievementTier.silver,
    ),

    // --- gold -----------------------------------------------------------
    Achievement(
      id: 'veteran',
      metric: AchievementMetric.gamesPlayed,
      target: 50,
      tier: AchievementTier.gold,
    ),
    Achievement(
      id: 'architect',
      metric: AchievementMetric.totalLinesCleared,
      target: 500,
      tier: AchievementTier.gold,
    ),
    Achievement(
      id: 'grandBuilder',
      metric: AchievementMetric.totalCellsPlaced,
      target: 15000,
      tier: AchievementTier.gold,
    ),
    Achievement(
      id: 'comboFrenzy',
      metric: AchievementMetric.runCombo,
      target: 10,
      tier: AchievementTier.gold,
    ),
    Achievement(
      id: 'gridLegend',
      metric: AchievementMetric.runScore,
      target: 5000,
      tier: AchievementTier.gold,
    ),
    Achievement(
      id: 'marathon',
      metric: AchievementMetric.totalPlaySeconds,
      target: 3600,
      tier: AchievementTier.gold,
    ),
  ];

  /// Looks up an achievement by id, or `null` when unknown.
  static Achievement? byId(String id) {
    for (final Achievement achievement in all) {
      if (achievement.id == id) {
        return achievement;
      }
    }
    return null;
  }

  /// Achievements of one tier, in catalogue order.
  static List<Achievement> ofTier(AchievementTier tier) =>
      all.where((Achievement a) => a.tier == tier).toList(growable: false);
}
