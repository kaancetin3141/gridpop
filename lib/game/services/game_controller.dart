import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../audio/audio_manager.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/seeded_random.dart';
import '../logic/board_analyzer.dart';
import '../logic/combo_tracker.dart';
import '../logic/placement_engine.dart';
import '../logic/piece_generator.dart';
import '../logic/scoring_engine.dart';
import '../models/board.dart';
import '../models/game_event.dart';
import '../models/game_mode.dart';
import '../models/game_phase.dart';
import '../models/game_state.dart';
import '../models/grid_position.dart';
import '../models/piece_slot.dart';
import '../models/placement_outcome.dart';
import '../../state/stats_controller.dart';
import '../../state/wallet_controller.dart';
import 'daily_service.dart';
import 'haptics_service.dart';
import 'leaderboard_service.dart';

/// Orchestrates one run: input, rules, timer, sound, haptics and persistence.
///
/// The controller never touches widgets. Everything the UI needs is either in
/// [state] (an immutable snapshot) or in the drained event queue
/// ([drainEvents]).
class GameController extends ChangeNotifier {
  GameController({
    required StatsController stats,
    required LeaderboardService leaderboard,
    required DailyService daily,
    required AudioManager audio,
    required HapticsService haptics,
    required WalletController wallet,
    int preferredBoardSize = BoardConfig.defaultSize,
  })  : _stats = stats,
        _leaderboard = leaderboard,
        _daily = daily,
        _audio = audio,
        _haptics = haptics,
        _wallet = wallet,
        _preferredBoardSize = preferredBoardSize,
        _state = GameState.initial(boardSize: preferredBoardSize) {
    _board = Board(_preferredBoardSize);
  }

  final StatsController _stats;
  final LeaderboardService _leaderboard;
  final DailyService _daily;
  final AudioManager _audio;
  final HapticsService _haptics;
  final WalletController _wallet;

  final int _preferredBoardSize;

  /// Number of palette entries a piece can use.
  static const int colorCount = 8;

  late Board _board;
  late GameState _state;
  PieceGenerator _generator = PieceGenerator();
  final ComboTracker _combo = ComboTracker();
  final List<GameEvent> _events = <GameEvent>[];

  Timer? _timer;
  int _remainingMs = 0;

  /// Incremented on every run start so stale async work can be discarded.
  int _runId = 0;

  /// True while a piece is still settling into the board. The presentation
  /// layer closes the gate; the controller keeps it honest with a safety timer.
  bool _inputLocked = false;

  /// Set while the tray is empty and waiting for the settle window to close
  /// before the whole batch is refilled.
  bool _pendingRefill = false;

  Timer? _safetyTimer;

  /// Drives the countdown of the active score booster.
  Timer? _boosterTimer;

  /// Safety net: periodically verifies that the player still has a move, so a
  /// run can never sit in an unplayable limbo (whatever code path got us
  /// there). Canceled whenever the run is not playing.
  Timer? _deadWatchdog;
  DateTime? _startedAt;
  int _elapsedBeforePause = 0;
  bool _statsSaved = false;

  /// The second chance is offered at most once per run.
  bool _reviveUsed = false;

  // --- public API --------------------------------------------------------

  /// Immutable snapshot of the run.
  GameState get state => _state;

  /// The live board. Treated as read-only by the presentation layer.
  Board get board => _board;

  GameMode get mode => _state.mode;

  GamePhase get phase => _state.phase;

  int get score => _state.score;

  /// True while the previous piece is still settling. The tray keeps the used
  /// piece visible (greyed out) until this is false again.
  bool get inputLocked => _inputLocked;

  /// True when at least one remaining tray piece still fits on the board.
  bool get trayIsPlayable => BoardAnalyzer.hasAnyMove(_board, _piecesInTray);

  /// Remaining (not yet used) pieces of the tray.
  List<PieceSlot> get _piecesInTray => <PieceSlot>[
        for (final PieceSlot? slot in _state.tray)
          if (slot != null) slot,
      ];

  /// True when the tray has no piece left.
  bool get trayIsEmpty => _isTrayEmpty(_state.tray);

  /// True when the tray still holds pieces but none of them fits any more.
  ///
  /// This is the real "no moves left" state: an empty tray is normal, it just
  /// waits for the batch refill.
  bool get trayIsDead =>
      !trayIsEmpty && !BoardAnalyzer.hasAnyMove(_board, _piecesInTray);

  /// Ends the run when the tray is dead and the mode allows a game over.
  ///
  /// Called from every interaction that can strand the player (an invalid
  /// drop, a dead hint, a failed tray refresh) **and** from the watchdog timer,
  /// so a run always ends once nothing fits any more.
  bool checkForDeadTray() {
    if (_state.phase != GamePhase.playing || !trayIsDead) {
      return false;
    }
    if (_state.mode.config.allowsGameOver) {
      _stopWatchdog();
      _events.add(const GameEvent(GameEventType.noMove));
      _resolveStuckRun();
      return true;
    }
    // Relaxed modes refill instead of ending.
    ensurePlayable();
    return false;
  }

  /// True while the second chance dialog is waiting for an answer.
  bool get reviveOffered => _state.phase == GamePhase.revive;

  /// True once the player already used (or declined) the second chance.
  bool get reviveUsed => _reviveUsed;

  /// Coins the second chance costs when the player does not watch an ad.
  int get reviveCost => ReviveConfig.cost;

  /// Offers the second chance, or ends the run when it is spent.
  ///
  /// Nothing is persisted here: the run is only written once the player
  /// declines (or the revived run really ends), which keeps the statistics
  /// exactly once per run.
  void _resolveStuckRun() {
    _stopWatchdog();
    if (!_reviveUsed) {
      _state = _state.copyWith(phase: GamePhase.revive);
      _events.add(
        const GameEvent(GameEventType.reviveOffered, ReviveConfig.cost),
      );
      _audio.play(GameSound.gameOver);
      notifyListeners();
      return;
    }
    _events.add(const GameEvent(GameEventType.settled));
    notifyListeners();
    unawaited(finish());
  }

  /// Accepts the second chance: the fullest rows are wiped so the board has
  /// room again, and a guaranteed playable tray is dealt.
  ///
  /// [free] skips the coin cost (a rewarded ad was watched instead).
  Future<bool> revive({bool free = false}) async {
    if (_state.phase != GamePhase.revive || _reviveUsed) {
      return false;
    }
    if (!free) {
      final bool paid = await _guardBool(
        () => _wallet.spend(ReviveConfig.cost),
      );
      if (!paid || _state.phase != GamePhase.revive) {
        return false;
      }
    }

    final List<TintedCell> wiped = _wipeFullestRows(ReviveConfig.rowsToClear);
    final GameModeConfig config = _state.mode.config;
    final List<PieceSlot> tray = _generator.generateTray(
      board: _board,
      traySize: config.traySize,
      score: _state.score,
      largePieceBias: config.largePieceBias,
      colorCount: colorCount,
      forcePlayable: true,
    );

    _reviveUsed = true;
    _combo.reset();
    _state = _state.copyWith(
      phase: GamePhase.playing,
      combo: 0,
      tray: List<PieceSlot?>.of(tray),
      emptyCells: _board.size * _board.size - _board.filledCount,
    );
    _events.add(GameEvent(GameEventType.reviveStarted, wiped));
    _startWatchdog();
    _audio.play(GameSound.perfect);
    _haptics.clear(lines: 2);
    notifyListeners();

    // Paranoia: if the fresh tray somehow does not fit, the run ends now.
    if (trayIsDead) {
      _events.add(const GameEvent(GameEventType.noMove));
      _resolveStuckRun();
    }
    return true;
  }

  /// Declines the second chance and ends the run normally.
  Future<void> declineRevive() async {
    if (_state.phase != GamePhase.revive) {
      return;
    }
    await finish();
  }

  /// Empties the [count] rows that hold the most blocks.
  List<TintedCell> _wipeFullestRows(int count) {
    final int size = _board.size;
    final List<int> occupancy = <int>[
      for (int row = 0; row < size; row++)
        <int>[
          for (int col = 0; col < size; col++)
            if (_board.valueAt(row, col) != 0) 1,
        ].length,
    ];
    final List<int> order = List<int>.generate(size, (int i) => i)
      ..sort((int a, int b) => occupancy[b].compareTo(occupancy[a]));

    final List<TintedCell> wiped = <TintedCell>[];
    int wipedRows = 0;
    for (final int row in order) {
      if (wipedRows >= count || occupancy[row] == 0) {
        break;
      }
      for (int col = 0; col < size; col++) {
        final int value = _board.valueAt(row, col);
        if (value != 0) {
          wiped.add(TintedCell(GridPosition(row, col), value));
          _board.setValue(row, col, 0);
        }
      }
      wipedRows++;
    }
    return wiped;
  }

  /// Removes a single block (hammer power-up).
  bool hammerAt(int row, int col) => _smash(row, col, radius: 0);

  /// Removes a 3x3 area (bomb power-up).
  bool bombAt(int row, int col) => _smash(row, col, radius: 1);

  bool _smash(int row, int col, {required int radius}) {
    if (_state.phase != GamePhase.playing) {
      return false;
    }
    final int size = _board.size;
    if (row < 0 || col < 0 || row >= size || col >= size) {
      return false;
    }

    final List<TintedCell> removed = <TintedCell>[];
    for (int r = row - radius; r <= row + radius; r++) {
      for (int c = col - radius; c <= col + radius; c++) {
        if (r < 0 || c < 0 || r >= size || c >= size) {
          continue;
        }
        final int value = _board.valueAt(r, c);
        if (value != 0) {
          removed.add(TintedCell(GridPosition(r, c), value));
          _board.setValue(r, c, 0);
        }
      }
    }
    if (removed.isEmpty) {
      return false;
    }

    _state = _state.copyWith(
      emptyCells: size * size - _board.filledCount,
    );
    _events.add(GameEvent(GameEventType.blocksSmashed, removed));
    _audio.play(GameSound.lineClear);
    _haptics.clear(lines: 1);
    notifyListeners();
    return true;
  }

  /// Starts the watchdog that ends (or refills) a run with no moves left.
  void _startWatchdog() {
    _deadWatchdog?.cancel();
    _deadWatchdog = Timer.periodic(
      DeadTrayConfig.watchdogInterval,
      (Timer timer) {
        if (_state.phase != GamePhase.playing) {
          timer.cancel();
          _deadWatchdog = null;
          return;
        }
        checkForDeadTray();
      },
    );
  }

  void _stopWatchdog() {
    _deadWatchdog?.cancel();
    _deadWatchdog = null;
  }

  /// Best combo of the current run.
  int get bestCombo => _combo.best;

  /// Returns and clears the pending events.
  List<GameEvent> drainEvents() {
    if (_events.isEmpty) {
      return const <GameEvent>[];
    }
    final List<GameEvent> drained = List<GameEvent>.of(_events);
    _events.clear();
    return drained;
  }

  /// Piece in [index], or `null` when the slot does not exist.
  PieceSlot? slotAt(int index) {
    if (index < 0 || index >= _state.tray.length) {
      return null;
    }
    return _state.tray[index];
  }

  /// Feedback cue played the moment a piece leaves the tray.
  void playPickupCue() {
    _audio.play(GameSound.blockPickup);
    _haptics.pickup();
  }

  /// Feedback cue for a rejected move or a dead board.
  void playWarningCue() {
    _haptics.warning();
  }

  /// Rotates the piece in [index]. Fails when the shape is symmetric or the
  /// run is not accepting input.
  bool rotateSlot(int index) {
    final PieceSlot? slot = slotAt(index);
    if (slot == null || !_state.acceptsInput || slot.shape.uniqueRotations <= 1) {
      return false;
    }
    final List<PieceSlot?> tray = List<PieceSlot?>.of(_state.tray);
    tray[index] = slot.rotated();
    _state = _state.copyWith(tray: tray);
    _events.add(GameEvent(GameEventType.rotated, index));
    _audio.play(GameSound.blockPickup);
    _haptics.pickup();
    notifyListeners();
    return true;
  }

  /// Drops the piece of [slotIndex] with its top-left cell at ([topRow],
  /// [leftCol]). Returns `null` when the move is invalid.
  PlacementOutcome? placePiece(int slotIndex, int topRow, int leftCol) {
    if (!_state.acceptsInput || _inputLocked) {
      return null;
    }
    final PieceSlot? slot = slotAt(slotIndex);
    if (slot == null) {
      return null;
    }

    final PlacementOutcome? outcome = PlacementEngine.apply(
      board: _board,
      piece: slot,
      topRow: topRow,
      leftCol: leftCol,
      comboLevel: _combo.level,
      remainingTime: _state.remainingSeconds,
    );

    if (outcome == null) {
      _events.add(GameEvent(GameEventType.invalid, slotIndex));
      _haptics.warning();
      notifyListeners();
      return null;
    }

    final int lineCount = outcome.lineCount;
    _combo.register(lineCount);

    // The booster doubles every point the move produces.
    final int baseGained = outcome.score.total;
    final int gained = _state.boosterActive
        ? (baseGained * BoosterConfig.multiplier).round()
        : baseGained;
    final int previousScore = _state.score;
    final int newScore = previousScore + gained;
    final bool isRecord = newScore > _stats.highScore;

    // Passing the all time record mid-run starts a short score surge.
    final bool crossedRecord = _stats.highScore > 0 &&
        previousScore <= _stats.highScore &&
        newScore > _stats.highScore;

    _state = _state.copyWith(
      score: newScore,
      combo: _combo.level,
      bestComboThisRun: _combo.best,
      moves: _state.moves + 1,
      cellsPlaced: _state.cellsPlaced + slot.cellCount,
      linesCleared: _state.linesCleared + lineCount,
      perfectMoves: _state.perfectMoves + (outcome.isPerfect ? 1 : 0),
      emptyCells: _board.size * _board.size - _board.filledCount,
      highScore: isRecord ? newScore : _state.highScore,
      isNewRecord: isRecord,
    );

    _events.add(GameEvent(GameEventType.placed, outcome));

    _feedbackFor(outcome);
    notifyListeners();

    if (isRecord) {
      _events.add(GameEvent(GameEventType.newRecord, newScore));
    }

    // The used slot stays empty: the tray only refills as a whole batch once
    // every piece has been played. That is what keeps runs losable.
    final List<PieceSlot?> tray = List<PieceSlot?>.of(_state.tray);
    tray[slotIndex] = null;
    _state = _state.copyWith(tray: tray);
    _events.add(GameEvent(GameEventType.consumed, slotIndex));

    _pendingRefill = _isTrayEmpty(tray);

    // Give up on a dead tray right away instead of waiting for the animation:
    // the player must never be left holding pieces that cannot be placed.
    if (!_pendingRefill) {
      checkForDeadTray();
    }

    if (crossedRecord) {
      _startBooster(BoosterConfig.recordDurationSeconds);
    }

    return outcome;
  }

  /// True when every slot of the tray has been used.
  bool _isTrayEmpty(List<PieceSlot?> tray) {
    for (final PieceSlot? slot in tray) {
      if (slot != null) {
        return false;
      }
    }
    return true;
  }

  /// Closes the input gate. Called by the presentation layer as soon as a
  /// placement starts, with a safety timer so the game can never deadlock.
  void lockInput() {
    if (_inputLocked) {
      return;
    }
    _inputLocked = true;
    _safetyTimer?.cancel();
    _safetyTimer = Timer(
      const Duration(milliseconds: MotionConfig.settleSafety),
      completePlacement,
    );
  }

  /// Opens the gate, refills the tray batch when it is empty and evaluates the
  /// board.
  ///
  /// Safe to call any number of times: the tray only changes when a batch is
  /// actually pending.
  void completePlacement() {
    _safetyTimer?.cancel();
    _safetyTimer = null;

    final bool refillAll = _pendingRefill;
    _inputLocked = false;
    _pendingRefill = false;

    if (refillAll) {
      // All three slots refill together, with a stagger in the tray animation.
      final List<PieceSlot> batch = _generator.generateTray(
        board: _board,
        traySize: _state.mode.config.traySize,
        score: _state.score,
        largePieceBias: _state.mode.config.largePieceBias,
        colorCount: colorCount,
        forcePlayable: !_state.mode.config.allowsGameOver,
      );
      _state = _state.copyWith(tray: List<PieceSlot?>.of(batch));
      _events.add(const GameEvent(GameEventType.trayRefilled));
    }

    // Dead tray detection happens here: after the batch, never before.
    if (trayIsPlayable) {
      _events.add(const GameEvent(GameEventType.settled));
      notifyListeners();
      return;
    }

    // Pieces left but none of them fits: the run is stuck.
    _events.add(const GameEvent(GameEventType.noMove));
    if (_state.mode.config.allowsGameOver) {
      _resolveStuckRun();
      return;
    }

    _refillWholeTray();
    _events.add(const GameEvent(GameEventType.settled));
    notifyListeners();
  }

  /// Refills the tray when no piece fits any more in a relaxed mode.
  ///
  /// Returns `true` when a refill happened. Modes that can end keep their
  /// "game over" behaviour instead, so this always returns `false` for them.
  bool ensurePlayable() {
    if (_state.phase != GamePhase.playing ||
        _state.mode.config.allowsGameOver) {
      return false;
    }
    if (BoardAnalyzer.hasAnyMove(_board, _state.tray)) {
      return false;
    }
    _refillWholeTray();
    return true;
  }

  /// Returns a suggested move for the hint button, or `null` when nothing
  /// fits. Does not modify the board.
  PlacementHint? hint() {
    if (!_state.acceptsInput) {
      return null;
    }
    return BoardAnalyzer.suggestMove(_board, _piecesInTray);
  }

  /// Rotates the piece of [slotIndex] so it matches [rotation].
  void _applyRotation(int slotIndex, int rotation) {
    final PieceSlot? slot = slotAt(slotIndex);
    if (slot == null) {
      return;
    }
    for (int i = 0; i < rotation; i++) {
      rotateSlot(slotIndex);
    }
  }

  /// Applies the hint immediately. Handy for one-handed play.
  PlacementOutcome? playHint() {
    final PlacementHint? move = hint();
    if (move == null) {
      return null;
    }
    _applyRotation(move.slotIndex, move.rotation);
    return placePiece(move.slotIndex, move.topRow, move.leftCol);
  }

  // --- power-ups ---------------------------------------------------------

  /// Starts the score booster (shop power-up or the record surge).
  /// Returns `false` when the run is not accepting input.
  bool activateBooster({int seconds = BoosterConfig.manualDurationSeconds}) {
    if (_state.phase != GamePhase.playing || seconds <= 0) {
      return false;
    }
    _startBooster(seconds);
    return true;
  }

  /// Replaces the tray with a fresh, guaranteed playable batch.
  bool refreshTray() {
    if (_state.phase != GamePhase.playing) {
      return false;
    }
    final GameModeConfig config = _state.mode.config;
    final List<PieceSlot> tray = _generator.generateTray(
      board: _board,
      traySize: config.traySize,
      score: _state.score,
      largePieceBias: config.largePieceBias,
      colorCount: colorCount,
      forcePlayable: true,
    );
    _pendingRefill = false;
    _state = _state.copyWith(tray: List<PieceSlot?>.of(tray));
    _events.add(const GameEvent(GameEventType.trayRefilled));
    _audio.play(GameSound.combo);
    _haptics.pickup();
    notifyListeners();
    // A refresh must never hand out an unplayable tray.
    checkForDeadTray();
    return true;
  }

  /// Empties the whole board (shop power-up). Returns `false` when there is
  /// nothing to clear or the run is not accepting input.
  bool clearBoard() {
    if (_state.phase != GamePhase.playing) {
      return false;
    }
    final List<(int row, int col, int colorIndex)> filled = _board.filledCells();
    if (filled.isEmpty) {
      return false;
    }
    _board.clear();
    _state = _state.copyWith(
      emptyCells: _board.size * _board.size,
    );
    _events.add(
      GameEvent(
        GameEventType.boardCleared,
        <TintedCell>[
          for (final (int row, int col, int colorIndex) cell in filled)
            TintedCell(GridPosition(cell.$1, cell.$2), cell.$3),
        ],
      ),
    );
    _audio.play(GameSound.lineClear);
    _haptics.clear(lines: 3);
    notifyListeners();
    return true;
  }

  /// Starts (or extends) the score booster countdown.
  void _startBooster(int seconds) {
    final int duration =
        seconds > _state.boosterSeconds ? seconds : _state.boosterSeconds;
    _state = _state.copyWith(boosterSeconds: duration);
    _runBoosterTimer();
    _events.add(GameEvent(GameEventType.booster, duration));
    _audio.play(GameSound.combo);
    _haptics.combo();
    notifyListeners();
  }

  void _runBoosterTimer() {
    _boosterTimer?.cancel();
    _boosterTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_state.phase != GamePhase.playing) {
        return;
      }
      final int left = _state.boosterSeconds - 1;
      _state = _state.copyWith(boosterSeconds: left < 0 ? 0 : left);
      if (left <= 0) {
        timer.cancel();
        _boosterTimer = null;
        _events.add(const GameEvent(GameEventType.boosterEnded));
      }
      notifyListeners();
    });
  }

  /// Starts a new run.
  Future<void> start({
    required GameMode mode,
    int? boardSize,
    SeededRandom? random,
  }) async {
    _timer?.cancel();
    _safetyTimer?.cancel();
    _safetyTimer = null;
    _boosterTimer?.cancel();
    _boosterTimer = null;
    _stopWatchdog();
    _inputLocked = false;
    _pendingRefill = false;
    _runId++;
    final GameModeConfig config = mode.config;
    final int size = mode == GameMode.classic
        ? (boardSize ?? _preferredBoardSize)
        : config.boardSize;

    _board = Board(size);
    _combo.reset();
    _statsSaved = false;
    _reviveUsed = false;
    _events.clear();

    _generator = PieceGenerator(
      random: mode == GameMode.daily
          ? (_daily.generatorForToday())
          : (random ?? SeededRandom(DateTime.now().microsecondsSinceEpoch)),
    );

    _state = GameState.initial(
      mode: mode,
      boardSize: size,
      highScore: _stats.highScore,
    ).copyWith(
      phase: GamePhase.playing,
      tray: List<PieceSlot?>.of(
        _generator.generateTray(
          board: _board,
          traySize: config.traySize,
          score: 0,
          largePieceBias: config.largePieceBias,
          colorCount: colorCount,
        ),
      ),
    );

    _startedAt = DateTime.now();
    _elapsedBeforePause = 0;
    _remainingMs = (config.timeLimit?.inMilliseconds ?? 0);

    if (config.isTimed) {
      _startTimer();
    }

    _events.add(const GameEvent(GameEventType.started));
    _startWatchdog();
    notifyListeners();
  }

  void pause() {
    if (_state.phase != GamePhase.playing) {
      return;
    }
    _timer?.cancel();
    _boosterTimer?.cancel();
    _boosterTimer = null;
    _stopWatchdog();
    _elapsedBeforePause = _elapsedSeconds;
    _startedAt = null;
    _state = _state.copyWith(phase: GamePhase.paused);
    notifyListeners();
  }

  void resume() {
    if (_state.phase != GamePhase.paused) {
      return;
    }
    _startedAt = DateTime.now().subtract(Duration(seconds: _elapsedBeforePause));
    _state = _state.copyWith(phase: GamePhase.playing);
    if (_state.mode.config.isTimed) {
      _startTimer();
    }
    if (_state.boosterSeconds > 0) {
      _runBoosterTimer();
    }
    _startWatchdog();
    ensurePlayable();
    notifyListeners();
  }

  void togglePause() => _state.phase == GamePhase.playing ? pause() : resume();

  /// Restarts the current run with a fresh board.
  Future<void> restart() async {
    final GameMode mode = _state.mode;
    final int size = _state.boardSize;
    _startedAt = null;
    _elapsedBeforePause = 0;
    _remainingMs = 0;
    await start(
      mode: mode,
      boardSize: mode == GameMode.classic ? size : null,
      random: mode == GameMode.daily ? null : SeededRandom(DateTime.now().microsecondsSinceEpoch),
    );
  }

  /// Ends the run, stores the result and notifies listeners.
  Future<void> finish() async {
    if (_state.phase == GamePhase.finished ||
        _state.phase == GamePhase.ready ||
        _statsSaved) {
      return;
    }
    _timer?.cancel();
    _boosterTimer?.cancel();
    _boosterTimer = null;
    _stopWatchdog();
    _statsSaved = true;

    // The run is stored asynchronously; if the player starts a new run in the
    // meantime the result must be dropped instead of corrupting the new one.
    final int runId = _runId;

    final int playSeconds = _elapsedSeconds;
    final int finalScore = _state.score;
    final int previousBest = _stats.highScore;

    final bool isRecord = await _guardBool(
      () => _stats.registerRun(
        score: finalScore,
        combo: _combo.best,
        linesCleared: _state.linesCleared,
        cellsPlaced: _state.cellsPlaced,
        perfectMoves: _state.perfectMoves,
        playSeconds: playSeconds,
      ),
    );
    if (_runId != runId) {
      return;
    }

    await _guardVoid(
      () => _leaderboard.add(
        _stats.buildRecord(
          mode: _state.mode,
          score: finalScore,
          combo: _combo.best,
          linesCleared: _state.linesCleared,
          moves: _state.moves,
        ),
      ),
    );

    int stars = 0;
    int coinsEarned = 0;
    if (_state.mode == GameMode.daily) {
      stars = ScoringEngine.starsForScore(
        finalScore,
        _state.mode.config.starThresholds,
      );
      final bool firstCompletionToday = !_daily.isCompletedToday;
      await _guardVoid(() => _daily.submit(score: finalScore, stars: stars));
      if (firstCompletionToday && finalScore > 0) {
        // Consecutive days pay more: the ladder is read *after* the submit, so
        // today already counts towards the streak it is paid for.
        final int streakBonus = StreakConfig.bonusForStreak(_daily.streak);
        coinsEarned = CoinConfig.dailyBase +
            stars * CoinConfig.dailyPerStar +
            finalScore ~/ CoinConfig.dailyScoreStep +
            streakBonus;
        await _guardVoid(() => _wallet.add(coinsEarned));
      }
    }

    if (_runId != runId) {
      return;
    }

    if (coinsEarned > 0) {
      _events.add(GameEvent(GameEventType.coinsEarned, coinsEarned));
    }

    _state = _state.copyWith(
      phase: GamePhase.finished,
      highScore: _stats.highScore,
      isNewRecord: isRecord,
      boosterSeconds: 0,
    );

    _audio.play(isRecord ? GameSound.highScore : GameSound.gameOver);
    _haptics.gameOver();

    _events.add(
      GameEvent(
        GameEventType.gameOver,
        GameEndSummary(
          mode: _state.mode,
          score: finalScore,
          previousBest: previousBest,
          isNewRecord: isRecord,
          stars: stars,
          moves: _state.moves,
          linesCleared: _state.linesCleared,
          bestCombo: _combo.best,
          playSeconds: playSeconds,
        ),
      ),
    );
    notifyListeners();
  }

  /// Runs a persistence call and swallows storage errors.
  ///
  /// A failing write (private mode, quota, a locked web database) must never
  /// keep the player from seeing the end of their run.
  Future<bool> _guardBool(Future<bool> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return false;
    }
  }

  /// Same as [_guardBool] for writes that return nothing.
  Future<void> _guardVoid(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Storage is best effort: the run still ends.
    }
  }

  @override
  void dispose() {
    stopTimers();
    super.dispose();
  }

  /// Cancels every timer of the run.
  ///
  /// The play screen calls this when it goes away, so a controller that
  /// outlives its UI (navigation, tests) never keeps ticking in the
  /// background.
  void stopTimers() {
    _timer?.cancel();
    _timer = null;
    _safetyTimer?.cancel();
    _safetyTimer = null;
    _boosterTimer?.cancel();
    _boosterTimer = null;
    _stopWatchdog();
  }

  // --- internals ---------------------------------------------------------

  int get _elapsedSeconds {
    if (_startedAt == null) {
      return _elapsedBeforePause;
    }
    return _elapsedBeforePause + DateTime.now().difference(_startedAt!).inSeconds;
  }

  void _startTimer() {
    _timer?.cancel();
    if (_remainingMs <= 0) {
      _remainingMs = _state.mode.config.timeLimit?.inMilliseconds ?? 0;
    }
    _timer = Timer.periodic(TimeAttackConfig.tick, (Timer timer) {
      if (!_state.acceptsInput) {
        return;
      }
      _remainingMs -= TimeAttackConfig.tick.inMilliseconds;
      if (_remainingMs <= 0) {
        _remainingMs = 0;
        _state = _state.copyWith(
          remainingSeconds: 0,
        );
        notifyListeners();
        unawaited(finish());
        return;
      }
      final int seconds = (_remainingMs / 1000).ceil();
      if (seconds != _state.remainingSeconds) {
        _state = _state.copyWith(remainingSeconds: seconds);
        if (TimeAttackConfig.warningSeconds.contains(seconds)) {
          _events.add(GameEvent(GameEventType.warning, seconds));
        }
        notifyListeners();
      }
    });
  }

  /// Zen and Time Attack never end: a dead tray is simply refilled.
  void _refillWholeTray() {
    final GameModeConfig config = _state.mode.config;
    final List<PieceSlot> tray = _generator.generateTray(
      board: _board,
      traySize: config.traySize,
      score: _state.score,
      largePieceBias: config.largePieceBias,
      colorCount: colorCount,
    );
    _state = _state.copyWith(tray: List<PieceSlot?>.of(tray));
    _events.add(const GameEvent(GameEventType.trayReset));
    _audio.play(GameSound.combo);
  }

  void _feedbackFor(PlacementOutcome outcome) {
    _haptics.place();
    if (outcome.hasClear) {
      _audio.play(GameSound.lineClear);
      _haptics.clear(lines: outcome.lineCount);
    } else {
      _audio.play(GameSound.blockPlace);
    }
    if (outcome.comboLevel >= 2) {
      _audio.play(GameSound.combo);
      _haptics.combo();
    }
    if (outcome.isPerfect) {
      _audio.play(GameSound.perfect);
    }
  }
}
