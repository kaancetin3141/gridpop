import 'scoring_engine.dart';

/// Tracks the combo of a single run.
///
/// The combo grows by one for every move that clears at least one line and
/// resets as soon as a move clears nothing.
class ComboTracker {
  int _level = 0;
  int _best = 0;

  /// Current combo level.
  int get level => _level;

  /// Highest level reached during the run.
  int get best => _best;

  /// Multiplier that belongs to the current level.
  double get multiplier => ScoringEngine.multiplierFor(_level);

  /// Registers the result of a move and returns the new level.
  int register(int clearedLineCount) {
    if (clearedLineCount > 0) {
      _level++;
      if (_level > _best) {
        _best = _level;
      }
    } else {
      _level = 0;
    }
    return _level;
  }

  void reset() {
    _level = 0;
    _best = 0;
  }
}