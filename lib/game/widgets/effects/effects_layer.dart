import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/piece_palette.dart';
import '../../models/grid_position.dart';
import '../../models/placement_outcome.dart';

/// A placed block that is still settling into the board.
class PlacedCell {
  const PlacedCell(this.cell, this.start);

  final TintedCell cell;
  final Duration start;
}

/// The sweeping clear of one or more lines.
class ClearWave {
  const ClearWave({
    required this.cells,
    required this.rows,
    required this.columns,
    required this.start,
    required this.lineCount,
  });

  final List<TintedCell> cells;
  final List<int> rows;
  final List<int> columns;
  final Duration start;
  final int lineCount;

  Duration get duration => const Duration(milliseconds: MotionConfig.clearSweep);
}

/// Expanding shock line + ring over a cleared row or column. This is the
/// "explosion" that fires the moment a line pops.
class LineBurst {
  const LineBurst({
    required this.row,
    required this.column,
    required this.isRow,
    required this.colorIndex,
    required this.start,
  });

  /// Row of the burst when [isRow], otherwise the column index.
  final int row;

  /// Column of the burst when not [isRow] (kept for the painter).
  final int column;

  final bool isRow;
  final int colorIndex;
  final Duration start;

  Duration get duration => const Duration(milliseconds: 460);
}

/// Floating "+points" text.
class ScoreFloat {
  const ScoreFloat({
    required this.row,
    required this.column,
    required this.points,
    required this.start,
    required this.colorIndex,
  });

  final double row;
  final double column;
  final int points;
  final Duration start;
  final int colorIndex;

  Duration get duration => const Duration(milliseconds: MotionConfig.scorePopup);
}

/// Big combo / milestone banner.
class ComboBanner {
  const ComboBanner({
    required this.level,
    required this.multiplier,
    required this.start,
    required this.isPerfect,
    this.customLabel,
  });

  final int level;
  final double multiplier;
  final Duration start;
  final bool isPerfect;

  /// Overrides the generated headline (used by the score booster).
  final String? customLabel;

  Duration get duration => const Duration(milliseconds: MotionConfig.comboBanner);

  /// Banner headline, resolved by the painter through [label].
  String get label {
    final String? custom = customLabel;
    if (custom != null) {
      return custom;
    }
    if (isPerfect) {
      return 'PERFECT';
    }
    if (level >= 4) {
      return 'COMBO x$level';
    }
    return 'COMBO';
  }
}

/// Highlight produced by the hint button.
class HintWave {
  const HintWave({
    required this.cells,
    required this.colorIndex,
    required this.start,
  });

  final List<GridPosition> cells;
  final int colorIndex;
  final Duration start;

  Duration get duration => const Duration(milliseconds: 1400);
}

/// Freeze frame that sells the impact of a big clear.
class HitStop {
  const HitStop({required this.start, required this.duration});

  final Duration start;
  final Duration duration;
}

/// Warning pulse shown when nothing fits any more.
class NoMovePulse {
  const NoMovePulse({required this.start, required this.fatal});

  final Duration start;

  /// `true` when the run is about to end (tense modes).
  final bool fatal;

  Duration get duration => const Duration(milliseconds: 900);
}

/// One small geometric particle.
class Particle {
  Particle({
    required this.row,
    required this.column,
    required this.velocityRow,
    required this.velocityColumn,
    required this.colorIndex,
    required this.size,
    required this.start,
    required this.spin,
    required this.life,
    this.star = false,
    this.soft = false,
  });

  double row;
  double column;
  double velocityRow;
  double velocityColumn;
  final int colorIndex;
  final double size;
  final Duration start;
  final double spin;
  final Duration life;

  /// Four pointed spark instead of a square.
  final bool star;

  /// Soft round dust mote (landing puff) instead of a hard chip.
  final bool soft;
}

/// Red pulse over the cells a piece could not be dropped onto.
class InvalidDrop {
  const InvalidDrop({required this.cells, required this.start});

  final List<GridPosition> cells;
  final Duration start;

  Duration get duration => const Duration(milliseconds: 340);
}

/// Owns every transient animation of the board.
///
/// The widget layer drives it with a [Ticker] and the painters listen to it as a
/// `repaint` source, so a frame never rebuilds a widget.
class GameEffects extends ChangeNotifier {
  GameEffects({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  final List<PlacedCell> _placed = <PlacedCell>[];
  final List<Particle> _particles = <Particle>[];
  final List<LineBurst> _bursts = <LineBurst>[];

  ClearWave? _clear;
  ScoreFloat? _score;
  ComboBanner? _banner;
  HintWave? _hint;
  HitStop? _hitStop;
  NoMovePulse? _noMove;
  InvalidDrop? _invalid;
  Duration _now = Duration.zero;
  double _flash = 0;

  /// Current wall time used for the animations.
  Duration get now => _now;

  double get flash => _flash;

  ClearWave? get clear => _clear;

  ScoreFloat? get score => _score;

  ComboBanner? get banner => _banner;

  HintWave? get hint => _hint;

  NoMovePulse? get noMove => _noMove;

  InvalidDrop? get invalid => _invalid;

  /// True during the freeze frame: the board holds still for a beat.
  bool get hitStop =>
      _hitStop != null && _now - _hitStop!.start < _hitStop!.duration;

  /// Remaining freeze time, used to keep the placed blocks frozen.
  double get hitStopProgress {
    final HitStop? stop = _hitStop;
    if (stop == null) {
      return 0;
    }
    final double t =
        ((_now - stop.start).inMicroseconds / stop.duration.inMicroseconds)
            .clamp(0.0, 1.0);
    return t < 1 ? t : 0;
  }

  List<PlacedCell> get placed => _placed;

  List<Particle> get particles => _particles;

  List<LineBurst> get bursts => _bursts;

  /// True while at least one effect needs more frames.
  bool get isActive =>
      _placed.isNotEmpty ||
      _particles.isNotEmpty ||
      _bursts.isNotEmpty ||
      _clear != null ||
      _score != null ||
      _banner != null ||
      _hint != null ||
      _noMove != null ||
      _invalid != null ||
      _hitStop != null ||
      _flash > 0;

  /// True while the board is still busy: either the freeze frame or any
  /// remaining animation. The presentation layer uses this to know when the
  /// settle window is over.
  bool get isSettling =>
      isActive && (_placed.isNotEmpty || _clear != null || _hitStop != null);

  // --- effect entry points ------------------------------------------------

  /// Blocks settling in after a successful drop, staggered so a multi cell
  /// piece lands like a wave instead of all at once.
  void onPlaced(PlacementOutcome outcome) {
    final List<GridPosition> sorted = <GridPosition>[...outcome.placedCells]
      ..sort((GridPosition a, GridPosition b) =>
          (a.row * 16 + a.col).compareTo(b.row * 16 + b.col));
    for (int i = 0; i < sorted.length; i++) {
      _placed.add(
        PlacedCell(
          TintedCell(sorted[i], outcome.colorIndex),
          _now + Duration(
            milliseconds: i * MotionConfig.blockSettleStagger,
          ),
        ),
      );
      // A little dust kicked up where the block lands.
      _spawnDust(sorted[i].row, sorted[i].col, outcome.colorIndex);
    }
  }

  /// Line clear: sweep + explosion bursts + particles + score popup + banner.
  void onCleared(
    PlacementOutcome outcome, {
    required int boardSize,
  }) {
    if (!outcome.hasClear) {
      return;
    }

    _clear = ClearWave(
      cells: outcome.clearedCells,
      rows: outcome.clearedRows,
      columns: outcome.clearedColumns,
      start: _now,
      lineCount: outcome.lineCount,
    );

    // Explosion burst on every cleared line.
    for (final int row in outcome.clearedRows) {
      _bursts.add(
        LineBurst(
          row: row,
          column: -1,
          isRow: true,
          colorIndex: outcome.colorIndex,
          start: _now,
        ),
      );
    }
    for (final int col in outcome.clearedColumns) {
      _bursts.add(
        LineBurst(
          row: -1,
          column: col,
          isRow: false,
          colorIndex: outcome.colorIndex,
          start: _now,
        ),
      );
    }

    _spawnParticlesForLines(outcome, boardSize);

    final List<GridPosition> placed = outcome.placedCells;
    if (placed.isNotEmpty) {
      _score = ScoreFloat(
        row: placed.first.row.toDouble(),
        column: placed.first.col.toDouble(),
        points: outcome.score.total,
        start: _now,
        colorIndex: outcome.colorIndex,
      );
    }

    if (outcome.comboLevel >= 2 || outcome.isPerfect) {
      _banner = ComboBanner(
        level: outcome.comboLevel,
        multiplier: outcome.comboMultiplier,
        start: _now,
        isPerfect: outcome.isPerfect,
      );
    }

    if (outcome.isPerfect) {
      _flash = 1;
      _hitStop = HitStop(
        start: _now,
        duration: const Duration(milliseconds: MotionConfig.hitStop),
      );
      _spawnStars(outcome);
    }
  }

  /// Highest record flash, triggered when a run ends with a new best score.
  void onNewRecord() {
    _flash = 1;
  }

  /// Score booster start: banner + flash, so the surge is impossible to miss.
  void onBooster(int seconds) {
    _banner = ComboBanner(
      level: 0,
      multiplier: BoosterConfig.multiplier,
      start: _now,
      isPerfect: false,
      customLabel:
          'BOOST x${BoosterConfig.multiplier.toStringAsFixed(0)}  ${seconds}s',
    );
    _flash = 0.55;
    notifyListeners();
  }

  /// Board clear power-up: every filled cell explodes away at once.
  void onBoardCleared(List<TintedCell> cells) {
    if (cells.isEmpty) {
      return;
    }
    _clear = ClearWave(
      cells: cells,
      rows: const <int>[],
      columns: const <int>[],
      start: _now,
      lineCount: 0,
    );
    _flash = 0.8;
    _hitStop = HitStop(
      start: _now,
      duration: const Duration(milliseconds: MotionConfig.hitStop),
    );
    for (final TintedCell cell in cells) {
      _spawn(
        cell.position.row + 0.5,
        cell.position.col + 0.5,
        cell.colorIndex,
        count: 2,
        speed: 2.2,
      );
    }
    notifyListeners();
  }

  /// Warning pulse for "nothing fits any more".
  void onNoMove({required bool fatal}) {
    _noMove = NoMovePulse(start: _now, fatal: fatal);
  }

  /// Marks the cells of a rejected drop so the player sees exactly where the
  /// piece refused to go.
  void onInvalidDrop(List<GridPosition> cells) {
    if (cells.isEmpty) {
      return;
    }
    _invalid = InvalidDrop(cells: cells, start: _now);
  }

  /// Pulses the cells the hint button suggests.
  void onHint(List<GridPosition> cells, int colorIndex) {
    if (cells.isEmpty) {
      return;
    }
    _hint = HintWave(cells: cells, colorIndex: colorIndex, start: _now);
  }

  /// Removes every running effect (restart / mode switch).
  void reset() {
    _placed.clear();
    _particles.clear();
    _bursts.clear();
    _clear = null;
    _score = null;
    _banner = null;
    _hint = null;
    _hitStop = null;
    _noMove = null;
    _invalid = null;
    _flash = 0;
    notifyListeners();
  }

  // --- ticking -----------------------------------------------------------

  /// Advances the clock and retires finished effects. Returns `true` while the
  /// ticker should keep running.
  bool tick(Duration elapsed) {
    _now = elapsed;

    if (_placed.isNotEmpty) {
      _placed.removeWhere((PlacedCell entry) =>
          elapsed - entry.start >
              const Duration(milliseconds: MotionConfig.blockPlace));
    }
    if (_clear != null &&
        elapsed - _clear!.start > _clear!.duration) {
      _clear = null;
    }
    if (_hitStop != null && elapsed - _hitStop!.start > _hitStop!.duration) {
      _hitStop = null;
    }
    if (_noMove != null && elapsed - _noMove!.start > _noMove!.duration) {
      _noMove = null;
    }
    if (_invalid != null && elapsed - _invalid!.start > _invalid!.duration) {
      _invalid = null;
    }
    if (_score != null && elapsed - _score!.start > _score!.duration) {
      _score = null;
    }
    if (_banner != null && elapsed - _banner!.start > _banner!.duration) {
      _banner = null;
    }
    if (_hint != null && elapsed - _hint!.start > _hint!.duration) {
      _hint = null;
    }
    if (_particles.isNotEmpty) {
      _particles.removeWhere((Particle particle) {
        final Duration age = elapsed - particle.start;
        if (age <= Duration.zero) {
          return false;
        }
        final double seconds = age.inMicroseconds / Duration.microsecondsPerSecond;
        particle.row += particle.velocityRow * seconds;
        particle.column += particle.velocityColumn * seconds;
        particle.velocityRow += 2.4 * seconds;
        return age > particle.life;
      });
    }
    if (_bursts.isNotEmpty) {
      _bursts.removeWhere((LineBurst burst) =>
          elapsed - burst.start > burst.duration);
    }
    if (_flash > 0) {
      _flash = (_flash - 0.045).clamp(0.0, 1.0).toDouble();
      if (_flash <= 0) {
        _flash = 0;
      }
    }

    final bool active = isActive;
    if (active) {
      notifyListeners();
    }
    return active;
  }

  void _spawnParticlesForLines(PlacementOutcome outcome, int boardSize) {
    final Set<int> rows = outcome.clearedRows.toSet();
    final Set<int> cols = outcome.clearedColumns.toSet();

    // Every cleared cell throws debris: the pop must feel like an explosion.
    for (final TintedCell cell in outcome.clearedCells) {
      rows.remove(cell.position.row);
      cols.remove(cell.position.col);
      _spawn(
        cell.position.row.toDouble() + 0.5,
        cell.position.col.toDouble() + 0.5,
        cell.colorIndex,
        count: 2,
        speed: 1.9,
      );
    }

    for (final int row in rows) {
      for (int i = 0; i < boardSize; i++) {
        _spawn(row + 0.5, i + 0.5, outcome.colorIndex, count: 1, speed: 2.4);
      }
    }
    for (final int col in cols) {
      for (int i = 0; i < boardSize; i++) {
        _spawn(i + 0.5, col + 0.5, outcome.colorIndex, count: 1, speed: 2.4);
      }
    }
  }

  /// Three soft motes puffing out from under a freshly landed block.
  void _spawnDust(int row, int col, int colorIndex) {
    for (int i = 0; i < 3; i++) {
      final double side = i - 1.0;
      _particles.add(
        Particle(
          row: row + 0.94,
          column: col + 0.5 + side * 0.16,
          velocityRow: -0.30 - _random.nextDouble() * 0.22,
          velocityColumn: side * (0.55 + _random.nextDouble() * 0.45),
          colorIndex: colorIndex,
          size: 0.045 + _random.nextDouble() * 0.05,
          start: _now,
          spin: 0,
          life: Duration(milliseconds: 300 + _random.nextInt(160)),
          soft: true,
        ),
      );
    }
  }

  void _spawn(double row, double column, int colorIndex, {int count = 1, double speed = 1.5}) {
    for (int i = 0; i < count; i++) {
      final double angle = _random.nextDouble() * math.pi * 2;
      final double velocity = speed * (0.6 + _random.nextDouble() * 0.7);
      _particles.add(
        Particle(
          row: row,
          column: column,
          velocityRow: math.cos(angle) * velocity - 0.6,
          velocityColumn: math.sin(angle) * velocity,
          colorIndex: colorIndex + (_random.nextBool() ? 1 : 0),
          size: 0.10 + _random.nextDouble() * 0.14,
          start: _now,
          spin: (_random.nextDouble() - 0.5) * 6,
          life: Duration(milliseconds: 460 + _random.nextInt(260)),
        ),
      );
    }
  }

  /// Four pointed sparks around the cells of a perfect move.
  void _spawnStars(PlacementOutcome outcome) {
    final List<GridPosition> cells = outcome.clearedCells.isEmpty
        ? outcome.placedCells
        : outcome.clearedCells
            .map((TintedCell cell) => cell.position)
            .toList(growable: false);

    if (cells.isEmpty) {
      return;
    }

    const int total = MotionConfig.perfectStars;
    for (int i = 0; i < total; i++) {
      final GridPosition cell =
          cells[i % cells.length];
      final double angle = (i / total) * math.pi * 2 + _random.nextDouble();
      final double speed = 1.6 + _random.nextDouble() * 1.2;
      _particles.add(
        Particle(
          row: cell.row.toDouble() + 0.5,
          column: cell.col.toDouble() + 0.5,
          velocityRow: math.cos(angle) * speed,
          velocityColumn: math.sin(angle) * speed,
          colorIndex: outcome.colorIndex,
          size: 0.18 + _random.nextDouble() * 0.12,
          start: _now,
          spin: (_random.nextDouble() - 0.5) * 8,
          life: const Duration(milliseconds: 620),
          star: true,
        ),
      );
    }
  }

  /// Palette entry used by the painters.
  PieceColor colorFor(int index) => PiecePalette.byIndex(index);
}