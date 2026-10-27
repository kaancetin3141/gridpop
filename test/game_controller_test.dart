import 'package:flutter_test/flutter_test.dart';
import 'package:gridpop/audio/audio_manager.dart';
import 'package:gridpop/core/constants/app_constants.dart';
import 'package:gridpop/core/utils/seeded_random.dart';
import 'package:gridpop/game/models/board.dart';
import 'package:gridpop/game/models/game_event.dart';
import 'package:gridpop/game/models/game_mode.dart';
import 'package:gridpop/game/models/game_phase.dart';
import 'package:gridpop/game/models/grid_position.dart';
import 'package:gridpop/game/models/piece_slot.dart';
import 'package:gridpop/game/models/placement_outcome.dart';
import 'package:gridpop/game/services/daily_service.dart';
import 'package:gridpop/game/services/game_controller.dart';
import 'package:gridpop/game/services/haptics_service.dart';
import 'package:gridpop/game/services/leaderboard_service.dart';
import 'package:gridpop/state/stats_controller.dart';
import 'package:gridpop/state/wallet_controller.dart';
import 'package:gridpop/storage/storage_manager.dart';
import 'support.dart';

/// Test harness: everything is wired to in-memory storage and a silent backend,
/// which is exactly how the real app is composed minus the platform plugins.
class Harness {
  Harness() {
    storage = StorageManager.inMemory();
    audio = AudioManager(backend: SilentAudioBackend());
    haptics = HapticsService(enabled: false);
    stats = StatsController(storage);
    leaderboard = LeaderboardService(storage);
    daily = DailyService(storage);
    wallet = WalletController(storage);
    controller = GameController(
      stats: stats,
      leaderboard: leaderboard,
      daily: daily,
      audio: audio,
      haptics: haptics,
      wallet: wallet,
    );
  }

  late final StorageManager storage;
  late final AudioManager audio;
  late final HapticsService haptics;
  late final StatsController stats;
  late final LeaderboardService leaderboard;
  late final DailyService daily;
  late final WalletController wallet;
  late final GameController controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameController - run lifecycle', () {
    test('start creates a board, a tray and the playing phase', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.classic);

      expect(harness.controller.phase, GamePhase.playing);
      expect(harness.controller.board.size, 8);
      expect(harness.controller.state.tray.length, 3);
      expect(harness.controller.state.score, 0);
      expect(harness.controller.state.emptyCells, 64);

      final List<GameEventType> types = harness.controller
          .drainEvents()
          .map((GameEvent event) => event.type)
          .toList();
      expect(types, contains(GameEventType.started));
    });

    test('classic honours the preferred board size', () async {
      final Harness harness = Harness();
      final GameController controller = GameController(
        stats: harness.stats,
        leaderboard: harness.leaderboard,
        daily: harness.daily,
        audio: harness.audio,
        haptics: harness.haptics,
        wallet: harness.wallet,
        preferredBoardSize: 9,
      );
      await controller.start(mode: GameMode.classic);
      expect(controller.board.size, 9);
    });

    test('time attack starts with the full timer', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.timeAttack);
      expect(harness.controller.board.size, 9);
      expect(
        harness.controller.state.remainingSeconds,
        GameMode.timeAttack.config.timeLimit!.inSeconds,
      );
    });
  });

  group('GameController - moves', () {
    test('a used slot stays empty until the whole tray is played', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.classic);

      expect(harness.controller.state.tray.length, 3);
      expect(harness.controller.trayIsEmpty, isFalse);

      // Three legal moves, always on the piece in the first free slot.
      for (int move = 0; move < 3; move++) {
        final _LegalMove? play = _firstLegalPlacement(harness.controller);
        expect(play, isNotNull, reason: 'move $move must be legal');
        _playMove(harness.controller, play!);

        expect(harness.controller.state.tray[play.slot], isNull,
            reason: 'slot ${play.slot} is empty right after the placement');

        harness.controller.completePlacement();

        if (move < 2) {
          expect(harness.controller.state.tray[play.slot], isNull,
              reason: 'no new piece until the whole tray is used');
        }
      }

      expect(harness.controller.trayIsEmpty, isFalse,
          reason: 'the batch refilled all three slots at once');
      for (int i = 0; i < 3; i++) {
        expect(harness.controller.state.tray[i], isNotNull,
            reason: 'slot $i refilled by the batch');
      }
      expect(harness.controller.state.moves, 3);
    });

    test('the input gate blocks moves until the settle window closes', () async {
      final Harness harness = Harness();
      await harness.controller.start(
        mode: GameMode.classic,
        random: SeededRandom(11),
      );

      harness.controller.placePiece(0, 0, 0);
      harness.controller.lockInput();

      expect(harness.controller.inputLocked, isTrue);
      expect(harness.controller.placePiece(1, 4, 4), isNull,
          reason: 'the second move is refused while the first is settling');

      harness.controller.completePlacement();

      expect(harness.controller.inputLocked, isFalse);
      expect(harness.controller.placePiece(1, 4, 4), isNotNull);
    });

    test('the safety timer releases the gate if nothing calls back', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.classic);

      harness.controller.placePiece(0, 0, 0);
      harness.controller.lockInput();
      expect(harness.controller.inputLocked, isTrue);

      // Nothing drives the animation in this test, so the safety timer has to
      // release the gate on its own.
      final bool released = await _waitFor(() => !harness.controller.inputLocked);
      expect(released, isTrue);
    });

    test('an invalid move is rejected and reported', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.classic);

      final PlacementOutcome? outcome =
          harness.controller.placePiece(0, -1, -1);

      expect(outcome, isNull);
      expect(harness.controller.state.moves, 0);
      expect(harness.controller.state.score, 0);

      final List<GameEvent> events = harness.controller.drainEvents();
      expect(
        events.any((GameEvent e) => e.type == GameEventType.invalid),
        isTrue,
      );
    });

    test('input is ignored while the run is paused', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.classic);
      harness.controller.pause();

      expect(harness.controller.placePiece(0, 0, 0), isNull);
      expect(harness.controller.state.score, 0);

      harness.controller.resume();
      expect(harness.controller.placePiece(0, 0, 0), isNotNull);
    });

    test('rotation cycles through the distinct orientations', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.classic);
      final PieceSlot? before = harness.controller.state.tray.first;
      if (before != null && before.shape.uniqueRotations > 1) {
        expect(harness.controller.rotateSlot(0), isTrue);
        expect(harness.controller.state.tray.first!.rotation, 1);
      }
    });
  });

group('GameController - game over', () {
    test('classic ends when the remaining pieces no longer fit', () async {
      final Harness harness = Harness();

      // Deterministic trap: a board whose free cells are all isolated, so only a
      // single cell piece can be played. Once the dot is used, the two large
      // pieces left in the tray cannot fit anywhere: the run must end.
      await harness.controller.start(
        mode: GameMode.classic,
        random: seedForPocket(),
      );

      final Board board = harness.controller.board;
      fillPocketLattice(board);

      final int dotSlot = harness.controller.state.tray.indexWhere(
        (PieceSlot? slot) => slot != null && slot.cellCount == 1,
      );
      expect(dotSlot, isNot(-1), reason: 'the seeded tray holds a single cell');

      expect(harness.controller.placePiece(dotSlot, 0, 0), isNotNull);
      harness.controller.completePlacement();

      final bool offered = await _waitFor(
        () => harness.controller.phase == GamePhase.revive,
      );
      expect(offered, isTrue, reason: 'a stuck run offers the second chance');
      expect(harness.stats.gamesPlayed, 0,
          reason: 'nothing is stored while the offer is open');

      await harness.controller.declineRevive();
      final bool finished =
          await _waitFor(() => harness.controller.phase == GamePhase.finished);
      expect(finished, isTrue, reason: 'the run must end on its own');
      expect(harness.stats.gamesPlayed, 1);
      expect(harness.leaderboard.top(GameMode.classic), isNotEmpty);
    });
    test('zen refills the tray instead of ending the run', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.zen);

      // A completely full board leaves no legal move: relaxed modes refill.
      for (int i = 0; i < 81; i++) {
        harness.controller.board.setValue(i ~/ 9, i % 9, 1);
      }

      expect(harness.controller.ensurePlayable(), isTrue);
      expect(harness.controller.phase, GamePhase.playing);
      expect(harness.controller.state.tray.length, 3);
      expect(harness.stats.gamesPlayed, 0);

      final bool sawRefill = harness.controller.drainEvents().any(
        (GameEvent event) => event.type == GameEventType.trayReset,
      );
      expect(sawRefill, isTrue);
    });

    test('classic never refills, it ends the run', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.classic);
      for (int i = 0; i < 64; i++) {
        harness.controller.board.setValue(i ~/ 8, i % 8, 1);
      }
      expect(harness.controller.ensurePlayable(), isFalse);
      expect(harness.controller.phase, GamePhase.playing);
    });

    test('restart resets the score and the board', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.classic);
      harness.controller.placePiece(0, 0, 0);
      expect(harness.controller.state.score, greaterThan(0));

      await harness.controller.restart();
      expect(harness.controller.state.score, 0);
      expect(harness.controller.state.moves, 0);
      expect(harness.controller.board.filledCount, 0);
      expect(harness.controller.phase, GamePhase.playing);
    });
  });

  group('GameController - records', () {
    test('a finished run updates the high score exactly once', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.classic);
      harness.controller.placePiece(0, 0, 0);
      await harness.controller.finish();
      final int firstScore = harness.controller.state.score;

      await harness.controller.finish();
      expect(harness.stats.highScore, firstScore);
      expect(harness.stats.gamesPlayed, 1);
    });

    test('the daily service records the daily result', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.daily);
      harness.controller.placePiece(0, 0, 0);
      await harness.controller.finish();

      expect(harness.daily.isCompletedToday, isTrue);
      expect(harness.daily.todayBestScore, harness.controller.state.score);
    });

    test('a finished daily run awards coins once per day', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.daily);
      expect(harness.controller.placePiece(0, 0, 0), isNotNull);
      await harness.controller.finish();

      final int score = harness.controller.state.score;
      expect(score, greaterThan(0));
      expect(score, lessThan(1200), reason: 'opening move earns no stars');
      expect(harness.wallet.coins, CoinConfig.dailyBase + StreakConfig.bonuses[0]);

      final List<GameEvent> events =
          harness.controller.drainEvents().toList(growable: false);
      final List<GameEvent> coinEvents = events
          .where((GameEvent e) => e.type == GameEventType.coinsEarned)
          .toList(growable: false);
      expect(coinEvents, hasLength(1));
      expect(
        coinEvents.single.payload,
        CoinConfig.dailyBase + StreakConfig.bonuses[0],
      );

      // A second run on the same day earns nothing: no coin farming.
      await harness.controller.start(mode: GameMode.daily);
      expect(harness.controller.placePiece(0, 0, 0), isNotNull);
      await harness.controller.finish();
      expect(harness.wallet.coins, CoinConfig.dailyBase + StreakConfig.bonuses[0]);
    });
  });

  group('GameController - hints', () {
    test('hint returns a move that can actually be played', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.classic);

      final PlacementHint? hint = harness.controller.hint();
      expect(hint, isNotNull);
      // Apply the suggested orientation first, then drop it.
      for (int i = 0; i < hint!.rotation; i++) {
        harness.controller.rotateSlot(hint.slotIndex);
      }
      expect(
        harness.controller.placePiece(hint.slotIndex, hint.topRow, hint.leftCol),
        isNotNull,
        reason: 'the hint must be playable, whatever the orientation',
      );
    });

    test('playHint rotates the piece and places it', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.classic);

      final PlacementOutcome? outcome = harness.controller.playHint();
      expect(outcome, isNotNull);
      expect(harness.controller.state.moves, 1);
    });
  });

  group('GameController - power-ups', () {
    test('passing the record starts a booster that doubles points', () async {
      const int record = 21;
      final Harness harness = Harness();
      await harness.stats.registerRun(
        score: record,
        combo: 0,
        linesCleared: 0,
        cellsPlaced: 5,
        perfectMoves: 0,
        playSeconds: 1,
      );
      expect(harness.stats.highScore, record);

      await harness.controller.start(
        mode: GameMode.classic,
        random: SeededRandom(42),
      );

      // Score monotonically grows on a fresh board until the record falls.
      bool crossed = false;
      for (int i = 0; i < 30 && !crossed; i++) {
        final _LegalMove? play = _firstLegalPlacement(harness.controller);
        expect(play, isNotNull, reason: 'a fresh board always has a move');
        for (int r = 0; r < play!.rotation; r++) {
          harness.controller.rotateSlot(play.slot);
        }
        final int before = harness.controller.score;
        final PlacementOutcome? outcome = harness.controller.placePiece(
          play.slot,
          play.row,
          play.col,
        );
        expect(outcome, isNotNull);
        harness.controller.completePlacement();
        expect(harness.controller.score - before, outcome!.score.total,
            reason: 'the crossing move itself is not boosted yet');
        if (before <= record && harness.controller.score > record) {
          crossed = true;
          expect(harness.controller.state.boosterActive, isTrue);
          expect(harness.controller.state.boosterSeconds, greaterThan(0));

          final _LegalMove? next = _firstLegalPlacement(harness.controller);
          expect(next, isNotNull);
          for (int r = 0; r < next!.rotation; r++) {
            harness.controller.rotateSlot(next.slot);
          }
          final int surgeBase = harness.controller.score;
          final PlacementOutcome? surge =
              harness.controller.placePiece(next.slot, next.row, next.col);
          expect(surge, isNotNull);
          expect(
            harness.controller.score - surgeBase,
            (surge!.score.total * BoosterConfig.multiplier).round(),
            reason: 'points are doubled while the surge is live',
          );
          harness.controller.completePlacement();
        }
      }
      expect(crossed, isTrue, reason: 'the run must pass the record');
    });

    test('refreshTray replaces the tray with playable pieces', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.classic);
      fillPocketLattice(harness.controller.board);

      expect(harness.controller.refreshTray(), isTrue);
      expect(harness.controller.state.tray.length, 3);
      expect(harness.controller.trayIsPlayable, isTrue,
          reason: 'a refreshed tray must fit somewhere');
      expect(
        harness.controller.drainEvents().any(
            (GameEvent e) => e.type == GameEventType.trayRefilled),
        isTrue,
      );
    });

    test('clearBoard empties the board and reports every cell', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.classic);
      expect(harness.controller.placePiece(0, 0, 0), isNotNull);

      final int filled = harness.controller.board.filledCount;
      expect(filled, greaterThan(0));

      expect(harness.controller.clearBoard(), isTrue);
      expect(harness.controller.board.filledCount, 0);
      expect(harness.controller.state.emptyCells,
          harness.controller.board.size * harness.controller.board.size);

      final List<GameEvent> events = harness.controller
          .drainEvents()
          .where((GameEvent e) => e.type == GameEventType.boardCleared)
          .toList(growable: false);
      expect(events, hasLength(1));
      final List<TintedCell> cells = events.single.payload as List<TintedCell>;
      expect(cells, hasLength(filled));
    });
  });

  group('GameController - dead tray', () {
    test('a dead tray ends the run as soon as the last piece is played',
        () async {
      final Harness harness = Harness();
      // Deterministic trap: one dot plus two large pieces on a lattice where
      // only single cells fit.
      await harness.controller.start(
        mode: GameMode.classic,
        random: seedForPocket(),
      );
      fillPocketLattice(harness.controller.board);

      final int dotSlot = harness.controller.state.tray.indexWhere(
        (PieceSlot? slot) => slot != null && slot.cellCount == 1,
      );
      expect(dotSlot, isNot(-1));
      expect(harness.controller.placePiece(dotSlot, 0, 0), isNotNull);

      // No settle call needed: the dead tray is detected immediately so the
      // player can never hold pieces that cannot be placed.
      final bool offered = await _waitFor(
        () => harness.controller.phase == GamePhase.revive,
      );
      expect(offered, isTrue,
          reason: 'a dead tray must offer the second chance without waiting');
      expect(harness.stats.gamesPlayed, 0);

      await harness.controller.declineRevive();
      final bool finished =
          await _waitFor(() => harness.controller.phase == GamePhase.finished);
      expect(finished, isTrue);
      expect(harness.stats.gamesPlayed, 1);
    });

    test('checkForDeadTray ignores a tray that still has a move', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.classic);

      expect(harness.controller.trayIsDead, isFalse);
      expect(harness.controller.checkForDeadTray(), isFalse);
      expect(harness.controller.phase, GamePhase.playing);
    });

    test('checkForDeadTray resolves the limbo after an invalid drop',
        () async {
      final Harness harness = Harness();
      await harness.controller.start(
        mode: GameMode.classic,
        random: seedForPocket(),
      );
      fillPocketLattice(harness.controller.board);
      final int dotSlot = harness.controller.state.tray.indexWhere(
        (PieceSlot? slot) => slot != null && slot.cellCount == 1,
      );
      // Play the dot somewhere valid so the tray becomes unplayable...
      expect(harness.controller.placePiece(dotSlot, 0, 0), isNotNull);
      await harness.controller.finish();
      await harness.controller.restart();

      // ...and now simulate the limbo: a tray full of pieces on a full board.
      fillPocketLattice(harness.controller.board);
      final Board board = harness.controller.board;
      for (int row = 0; row < board.size; row++) {
        for (int col = 0; col < board.size; col++) {
          if ((row + col) % 3 == 0) {
            board.setValue(row, col, 1);
          }
        }
      }
      harness.controller.drainEvents();

      expect(harness.controller.trayIsDead, isTrue,
          reason: 'no piece fits a completely full board');
      expect(harness.controller.checkForDeadTray(), isTrue);
      expect(harness.controller.phase, GamePhase.revive);
      await harness.controller.declineRevive();
      final bool finished =
          await _waitFor(() => harness.controller.phase == GamePhase.finished);
      expect(finished, isTrue);
    });

    test('zen keeps refilling instead of ending on a dead tray', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.zen);
      for (int i = 0; i < 81; i++) {
        harness.controller.board.setValue(i ~/ 9, i % 9, 1);
      }
      expect(harness.controller.trayIsDead, isTrue);
      expect(harness.controller.checkForDeadTray(), isFalse);
      expect(harness.controller.phase, GamePhase.playing);
    });

    test('refreshTray never hands out an unplayable tray', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.classic);
      fillPocketLattice(harness.controller.board);

      expect(harness.controller.refreshTray(), isTrue);
      expect(harness.controller.trayIsDead, isFalse,
          reason: 'a refreshed tray must always fit somewhere');
      expect(harness.controller.phase, GamePhase.playing);
    });

    test('the watchdog ends a stuck run without any interaction', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.classic);

      // Strand the player without telling the controller: a full board and a
      // tray of pieces, reached from the outside (the exact limbo players hit).
      final Board board = harness.controller.board;
      for (int i = 0; i < board.size * board.size; i++) {
        board.setValue(i ~/ board.size, i % board.size, 1);
      }
      expect(harness.controller.trayIsDead, isTrue,
          reason: 'a full board accepts nothing');

      // No placement, no settle call, no button press: the watchdog must react.
      final bool offered = await _waitFor(
        () => harness.controller.phase == GamePhase.revive,
        timeout: const Duration(seconds: 3),
      );
      expect(offered, isTrue,
          reason: 'a run with no moves left must react on its own');

      await harness.controller.declineRevive();
      final bool finished =
          await _waitFor(() => harness.controller.phase == GamePhase.finished);
      expect(finished, isTrue);
      expect(harness.stats.gamesPlayed, 1);
      expect(
        harness.controller.drainEvents().any(
            (GameEvent e) => e.type == GameEventType.gameOver),
        isTrue,
      );
    });

    test('the watchdog never ends a zen run, it keeps refilling', () async {
      final Harness harness = Harness();
      await harness.controller.start(mode: GameMode.zen);
      final Board board = harness.controller.board;
      for (int i = 0; i < board.size * board.size; i++) {
        board.setValue(i ~/ board.size, i % board.size, 1);
      }
      expect(harness.controller.trayIsDead, isTrue);

      await Future<void>.delayed(DeadTrayConfig.watchdogInterval * 3);

      expect(harness.controller.phase, GamePhase.playing,
          reason: 'zen is endless by design');
      expect(harness.stats.gamesPlayed, 0);
      expect(
        harness.controller.drainEvents().any(
            (GameEvent e) => e.type == GameEventType.trayReset),
        isTrue,
        reason: 'a dead tray in zen triggers a refill, not a game over',
      );
    });
  });
}

/// Polls [condition] until it becomes true or [timeout] elapses.
Future<bool> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
  Duration step = const Duration(milliseconds: 20),
}) async {
  final int steps = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (int i = 0; i < steps; i++) {
    if (condition()) {
      return true;
    }
    await Future<void>.delayed(step);
  }
  return condition();
}

/// A legal move found by the test player.
class _LegalMove {
  const _LegalMove(this.slot, this.rotation, this.row, this.col);

  final int slot;
  final int rotation;
  final int row;
  final int col;
}

/// First legal placement found in scan order. Rotations are considered, exactly
/// like in the real game.
_LegalMove? _firstLegalPlacement(GameController controller) {
  for (int slot = 0; slot < controller.state.tray.length; slot++) {
    final PieceSlot? piece = controller.state.tray[slot];
    if (piece == null) {
      continue;
    }
    for (int rotation = 0; rotation < piece.shape.uniqueRotations; rotation++) {
      final PieceSlot oriented = piece.copyWith(rotation: rotation);
      for (int row = 0; row < controller.board.size; row++) {
        for (int col = 0; col < controller.board.size; col++) {
          if (controller.board.canPlace(oriented.cells, row, col)) {
            return _LegalMove(slot, rotation, row, col);
          }
        }
      }
    }
  }
  return null;
}

/// Rotates [slot] until it matches [rotation] and plays the move.
bool _playMove(GameController controller, _LegalMove move) {
  for (int i = 0; i < move.rotation; i++) {
    controller.rotateSlot(move.slot);
  }
  return controller.placePiece(move.slot, move.row, move.col) != null;
}
