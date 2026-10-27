import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../models/placement_outcome.dart';

/// Pure scoring maths. No state, no side effects: this is what makes the score
/// system unit testable.
class ScoringEngine {
  const ScoringEngine._();

  /// Multiplier belonging to [comboLevel] (0 -> 1.0x, 5 -> 2.0x, capped).
  static double multiplierFor(int comboLevel) {
    final double raw = 1 + ScoringConfig.comboStep * comboLevel;
    return math.min(raw, ScoringConfig.comboCap);
  }

  /// Line count from which a move counts as "perfect".
  static const int perfectLineThreshold = 3;

  /// Computes the full breakdown of one move.
  static ScoreBreakdown evaluate({
    required int cellsPlaced,
    required int rowsCleared,
    required int columnsCleared,
    required int comboLevel,
  }) {
    final int lineCount = rowsCleared + columnsCleared;

    final int cellScore = cellsPlaced * ScoringConfig.pointsPerCell;
    final int lineScore = rowsCleared * ScoringConfig.pointsPerRow +
        columnsCleared * ScoringConfig.pointsPerColumn;
    final int multiBonus =
        lineCount > 1 ? (lineCount - 1) * ScoringConfig.multiLineBonus : 0;

    // The combo multiplier only amplifies the line related points: clearing
    // lines while on a combo should feel far better than dropping cells.
    final int lineRelated = lineScore + multiBonus;
    final double multiplier = multiplierFor(comboLevel);
    final int comboBonus = (lineRelated * (multiplier - 1)).round();

    final int perfectBonus =
        lineCount >= perfectLineThreshold ? ScoringConfig.perfectBonus : 0;

    return ScoreBreakdown(
      cellScore: cellScore,
      lineScore: lineScore,
      multiBonus: multiBonus,
      perfectBonus: perfectBonus,
      comboBonus: comboBonus,
      comboMultiplier: multiplier,
    );
  }

  /// Number of stars (0-3) for [score] given [thresholds].
  static int starsForScore(int score, List<int> thresholds) {
    if (thresholds.isEmpty) {
      return 0;
    }
    int stars = 0;
    for (final int threshold in thresholds) {
      if (score >= threshold) {
        stars++;
      }
    }
    return stars;
  }

  /// Average points per placed cell, used by the statistics screen.
  static double pointsPerCell(int score, int cellsPlaced) {
    if (cellsPlaced <= 0) {
      return 0;
    }
    return score / cellsPlaced;
  }
}