/// What an achievement watches.
///
/// Cumulative metrics are read from the lifetime statistics and can show a
/// live progress bar. Run metrics are only meaningful while a run is being
/// evaluated (mid-run or at the end of one).
enum AchievementMetric {
  gamesPlayed,
  totalLinesCleared,
  totalCellsPlaced,
  perfectMoves,
  bestCombo,
  highScore,
  totalPlaySeconds,
  runScore,
  runCombo,
  runPerfectMoves,
  timeAttackScore,
  dailyCompleted,
  dailyThreeStars;

  /// True when the metric comes from the lifetime statistics.
  bool get isCumulative => switch (this) {
        gamesPlayed ||
        totalLinesCleared ||
        totalCellsPlaced ||
        perfectMoves ||
        bestCombo ||
        highScore ||
        totalPlaySeconds =>
          true,
        runScore ||
        runCombo ||
        runPerfectMoves ||
        timeAttackScore ||
        dailyCompleted ||
        dailyThreeStars =>
          false,
      };
}

/// Visual weight of an achievement, used for the badge colour.
enum AchievementTier { bronze, silver, gold }

/// One badge the player can earn.
///
/// The definition is pure data: the title and description live in the
/// localization tables under `achievement.<id>.title` / `.desc`, and the icon
/// is chosen by the presentation layer, so the catalogue stays Flutter free.
class Achievement {
  const Achievement({
    required this.id,
    required this.metric,
    required this.target,
    required this.tier,
  });

  /// Stable id, also the key prefix used by the localization tables.
  final String id;

  /// The value this achievement watches.
  final AchievementMetric metric;

  /// Value of [metric] that unlocks the achievement. Always > 0.
  final int target;

  final AchievementTier tier;

  String get titleKey => 'achievement.$id.title';

  String get descriptionKey => 'achievement.$id.desc';

  /// True for the run-only badges that unlock on the spot.
  bool get isOneShot => !metric.isCumulative;

  @override
  String toString() => 'Achievement($id, ${metric.name}, $target)';
}
