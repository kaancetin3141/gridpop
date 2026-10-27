import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridpop/audio/audio_manager.dart';
import 'package:gridpop/core/constants/app_constants.dart';
import 'package:gridpop/core/constants/storage_keys.dart';
import 'package:gridpop/core/utils/date_keys.dart';
import 'package:gridpop/core/utils/safe_numbers.dart';
import 'package:gridpop/game/achievements/achievement_catalog.dart';
import 'package:gridpop/game/logic/board_analyzer.dart';
import 'package:gridpop/game/logic/combo_tracker.dart';
import 'package:gridpop/game/logic/piece_generator.dart';
import 'package:gridpop/game/logic/placement_engine.dart';
import 'package:gridpop/game/logic/scoring_engine.dart';
import 'package:gridpop/game/models/board.dart';
import 'package:gridpop/game/models/game_event.dart';
import 'package:gridpop/game/models/game_mode.dart';
import 'package:gridpop/game/models/game_phase.dart';
import 'package:gridpop/game/models/grid_position.dart';
import 'package:gridpop/game/models/piece_slot.dart';
import 'package:gridpop/game/models/placement_outcome.dart';
import 'package:gridpop/game/models/score_record.dart';
import 'package:gridpop/game/services/daily_service.dart';
import 'package:gridpop/game/services/game_controller.dart';
import 'package:gridpop/game/services/haptics_service.dart';
import 'package:gridpop/game/services/leaderboard_service.dart';
import 'package:gridpop/shop/shop_item.dart';
import 'package:gridpop/state/achievements_controller.dart';
import 'package:gridpop/state/inventory_controller.dart';
import 'package:gridpop/state/settings_controller.dart';
import 'package:gridpop/state/stats_controller.dart';
import 'package:gridpop/state/wallet_controller.dart';
import 'package:gridpop/storage/storage_manager.dart';

SettingsController _settings(StorageManager storage) => SettingsController(
      storage: storage,
      audio: AudioManager(backend: SilentAudioBackend()),
      haptics: HapticsService(enabled: false),
    );

String _dayFromNow(int offset) => DateKeys.key(
      DateTime.now().add(Duration(days: offset)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DateKeys', () {
    test('parseKey never throws on hostile input', () {
      const List<String> hostile = <String>[
        '',
        'junk',
        '2026',
        '2026-01',
        'a-b-c',
        '275760-09-14',
        '999999999999-01-01',
        '-1-2-3',
        '2026-13-99',
        '2026-02-30',
        '9999-12-31',
      ];
      for (final String key in hostile) {
        expect(
          () => DateKeys.parseKey(key),
          returnsNormally,
          reason: 'parseKey($key) must stay total',
        );
      }
      expect(DateKeys.parseKey('2026-02-03').day, 3);
      expect(DateKeys.parseKey('junk').year, greaterThanOrEqualTo(1970));
    });

    test('isValidKey only accepts real calendar days', () {
      expect(DateKeys.isValidKey('2026-02-03'), isTrue);
      expect(DateKeys.isValidKey('2024-02-29'), isTrue, reason: 'leap day');
      expect(DateKeys.isValidKey('2026-02-30'), isFalse);
      expect(DateKeys.isValidKey('2026-13-01'), isFalse);
      expect(DateKeys.isValidKey('2026-2-3'), isFalse);
      expect(DateKeys.isValidKey('275760-09-14'), isFalse);
      expect(DateKeys.isValidKey('junk'), isFalse);
      expect(DateKeys.isValidKey(''), isFalse);
    });

    test('daysBetween counts calendar days, including leap years', () {
      expect(DateKeys.daysBetween('2026-02-03', '2026-02-06'), 3);
      expect(DateKeys.daysBetween('2024-02-28', '2024-03-01'), 2);
      expect(DateKeys.daysBetween('2026-03-28', '2026-03-30'), 2);
      expect(DateKeys.daysBetween('2026-03-30', '2026-03-28'), -2);
      expect(DateKeys.daysBetween('2026-03-30', '2026-03-30'), 0);
    });

    test('nextDay rolls over months and years', () {
      expect(DateKeys.key(DateKeys.nextDay(DateTime(2026, 1, 31))),
          '2026-02-01');
      expect(DateKeys.key(DateKeys.nextDay(DateTime(2026, 12, 31))),
          '2027-01-01');
    });
  });

  group('safe number readers', () {
    test('jsonInt accepts ints, whole doubles and rejects junk', () {
      expect(jsonInt(7), 7);
      expect(jsonInt(7.0), 7);
      expect(jsonInt(7.6), 8);
      expect(jsonInt('7'), isNull);
      expect(jsonInt(null), isNull);
      expect(jsonInt(double.infinity), isNull);
      expect(jsonInt(double.negativeInfinity), isNull);
      expect(jsonInt(double.nan), isNull);
    });

    test('safeRange clamps hostile values', () {
      expect(safeRange(99, min: 0, max: 3), 3);
      expect(safeRange(-4, min: 0, max: 3), 0);
      expect(safeRange('x', min: 0, max: 3), 0);
      expect(safeRange(null, min: 1, max: 3, fallback: 2), 2);
    });
  });

  group('StorageManager', () {
    test('never returns a non finite int or double', () async {
      final StorageManager storage = StorageManager.inMemory();
      await storage.setDouble('inf', double.infinity);
      await storage.setDouble('nan', double.nan);
      expect(storage.getInt('inf'), isNull);
      expect(storage.getInt('nan'), isNull);
      expect(storage.getDouble('inf'), isNull);
      expect(storage.getDouble('nan'), isNull);

      await storage.setInt('whole', 12);
      expect(storage.getDouble('whole'), 12.0);
      await storage.setDouble('fraction', 12.75);
      expect(storage.getInt('fraction'), 13);
    });

    test('malformed JSON degrades to empty instead of throwing', () async {
      final StorageManager storage = StorageManager.inMemory();
      await storage.setString('map', '{not json');
      await storage.setString('list', '{"a":1}');
      await storage.setString('scalar', '42');
      expect(storage.getMap('map'), isNull);
      expect(storage.getMapList('list'), isEmpty);
      expect(storage.getMap('scalar'), isNull);
      expect(storage.getMapList('scalar'), isEmpty);
    });

    test('getMapList skips entries that are not objects', () async {
      final StorageManager storage = StorageManager.inMemory();
      await storage.setString(
        'list',
        jsonEncode(<Object?>[
          <String, dynamic>{'id': 'a'},
          7,
          'text',
          null,
          <String, dynamic>{'id': 'b'},
        ]),
      );
      final List<Map<String, dynamic>> entries = storage.getMapList('list');
      expect(entries.length, 2);
      expect(entries.first['id'], 'a');
      expect(entries.last['id'], 'b');
    });
  });

  group('StatsController', () {
    test('negative stored counters are treated as zero', () {
      final StorageManager storage = StorageManager.inMemory();
      storage.setInt(StorageKeys.highScore, -900);
      storage.setInt(StorageKeys.gamesPlayed, -3);
      storage.setInt(StorageKeys.totalScore, -50);
      storage.setInt(StorageKeys.bestCombo, -1);
      storage.setInt(StorageKeys.totalPlaySeconds, -12);

      final StatsController stats = StatsController(storage);
      expect(stats.highScore, 0);
      expect(stats.gamesPlayed, 0);
      expect(stats.totalScore, 0);
      expect(stats.bestCombo, 0);
      expect(stats.totalPlayTime, Duration.zero);
    });

    test('registerRun clamps negative counters and cannot fake a record',
        () async {
      final StatsController stats = StatsController(StorageManager.inMemory());
      final bool record = await stats.registerRun(
        score: -500,
        combo: -4,
        linesCleared: -2,
        cellsPlaced: -9,
        perfectMoves: -1,
        playSeconds: -30,
      );
      expect(record, isFalse);
      expect(stats.highScore, 0);
      expect(stats.totalScore, 0);
      expect(stats.gamesPlayed, 1);
      expect(stats.bestCombo, 0);
      expect(stats.totalLinesCleared, 0);
      expect(stats.totalCellsPlaced, 0);
      expect(stats.perfectMoves, 0);
      expect(stats.totalPlayTime, Duration.zero);
    });

    test('averageScore is safe before the first run', () async {
      final StatsController stats = StatsController(StorageManager.inMemory());
      expect(stats.averageScore, 0);
      await stats.registerRun(
        score: 100,
        combo: 0,
        linesCleared: 0,
        cellsPlaced: 1,
        perfectMoves: 0,
        playSeconds: 1,
      );
      await stats.registerRun(
        score: 51,
        combo: 0,
        linesCleared: 0,
        cellsPlaced: 1,
        perfectMoves: 0,
        playSeconds: 1,
      );
      expect(stats.averageScore, 76);
    });

    test('buildRecord stamps today and the run totals', () {
      final StatsController stats = StatsController(StorageManager.inMemory());
      final ScoreRecord record = stats.buildRecord(
        mode: GameMode.daily,
        score: 321,
        combo: 4,
        linesCleared: 7,
        moves: 12,
      );
      expect(record.mode, GameMode.daily);
      expect(record.score, 321);
      expect(record.combo, 4);
      expect(record.clearedLines, 7);
      expect(record.moves, 12);
      expect(record.dateKey, DateKeys.today());
    });
  });

  group('DailyService', () {
    test('submit clamps hostile values', () async {
      final DailyService daily = DailyService(StorageManager.inMemory());
      await daily.submit(score: -40, stars: 9);
      expect(daily.isCompletedToday, isTrue);
      expect(daily.todayBestScore, 0);
      expect(daily.todayStars, 3);
    });

    test('a corrupted payload cannot crash the service', () {
      final StorageManager storage = StorageManager.inMemory();
      // Written as raw JSON: `1e999` decodes to `double.infinity`, which
      // `jsonEncode` refuses to produce but a tampered store can contain.
      storage.setString(
        StorageKeys.dailyRecord,
        '{'
            '"${_dayFromNow(0)}":{"score":"lots","stars":"many","ts":"yesterday"},'
            '"${_dayFromNow(-1)}":{"score":1e999,"stars":1e999,"ts":1e999},'
            '"${_dayFromNow(-2)}":{"score":-12,"stars":-9,"ts":-1},'
            '"junk-key":{"score":999},'
            '"275760-09-14":{"score":999}'
            '}',
      );

      expect(() => DailyService(storage), returnsNormally);
      final DailyService daily = DailyService(storage);
      expect(daily.isCompletedToday, isFalse);
      expect(daily.resultFor(_dayFromNow(-2))?.score, 0);
      expect(daily.resultFor(_dayFromNow(-2))?.stars, 0);
      expect(daily.streak, 0, reason: 'today has no valid result');
    });

    test('streak counts consecutive days and stops at a gap', () async {
      final StorageManager storage = StorageManager.inMemory();
      storage.setString(
        StorageKeys.dailyRecord,
        jsonEncode(<String, dynamic>{
          _dayFromNow(-1): <String, dynamic>{'score': 10, 'stars': 1},
          _dayFromNow(-2): <String, dynamic>{'score': 20, 'stars': 2},
          _dayFromNow(-4): <String, dynamic>{'score': 30, 'stars': 3},
        }),
      );
      final DailyService daily = DailyService(storage);
      await daily.submit(score: 50, stars: 3);
      expect(daily.streak, 3, reason: 'today, -1 and -2 are consecutive');
    });

    test('pruning keeps exactly 30 days and never drops recent days', () async {
      final StorageManager storage = StorageManager.inMemory();
      final Map<String, dynamic> seed = <String, dynamic>{};
      for (int i = 1; i <= 35; i++) {
        seed[_dayFromNow(-i)] = <String, dynamic>{'score': i, 'stars': 1};
      }
      storage.setString(StorageKeys.dailyRecord, jsonEncode(seed));

      final DailyService daily = DailyService(storage);
      await daily.submit(score: 100, stars: 3);

      expect(daily.resultFor(_dayFromNow(-1)), isNotNull);
      expect(daily.resultFor(_dayFromNow(-29)), isNotNull);
      expect(daily.resultFor(_dayFromNow(-30)), isNull);
      expect(daily.resultFor(_dayFromNow(-35)), isNull);
    });

    test('reset forgets the history', () async {
      final DailyService daily = DailyService(StorageManager.inMemory());
      await daily.submit(score: 100, stars: 2);
      await daily.reset();
      expect(daily.isCompletedToday, isFalse);
      expect(daily.streak, 0);
    });

    test('the streak ladder wraps every seven days', () {
      expect(StreakConfig.dayInCycle(0), 0);
      expect(StreakConfig.dayInCycle(1), 1);
      expect(StreakConfig.dayInCycle(7), 7);
      expect(StreakConfig.dayInCycle(8), 1, reason: 'a new cycle starts');
      expect(StreakConfig.dayInCycle(14), 7);
      expect(StreakConfig.dayInCycle(15), 1);
      expect(StreakConfig.bonusForStreak(0), 0);
      expect(StreakConfig.bonusForStreak(1), StreakConfig.bonuses[0]);
      expect(StreakConfig.bonusForStreak(7), StreakConfig.bonuses[6]);
      expect(StreakConfig.bonusForStreak(8), StreakConfig.bonuses[0]);
      // The ladder is bounded: a forged 10 000 day streak cannot pay more than
      // the top step.
      expect(
        StreakConfig.bonusForStreak(10000),
        lessThanOrEqualTo(StreakConfig.bonuses.last),
      );
      expect(
        StreakConfig.cycleTotal,
        StreakConfig.bonuses.fold<int>(0, (int a, int b) => a + b),
      );
    });

    test('the streak bonus is offered for today and for tomorrow', () async {
      final StorageManager storage = StorageManager.inMemory();
      storage.setString(
        StorageKeys.dailyRecord,
        jsonEncode(<String, dynamic>{
          for (int i = 1; i <= 6; i++)
            _dayFromNow(-i): <String, dynamic>{'score': 10 * i, 'stars': 1},
        }),
      );

      final DailyService daily = DailyService(storage);
      expect(daily.streak, 0, reason: 'today is still unplayed');
      expect(daily.previousStreak, 6);
      expect(daily.liveStreak, 6, reason: 'the run only breaks at midnight');
      expect(daily.ladderDay, 7, reason: 'today would be the seventh step');
      expect(daily.ladderDoneDays, 6);
      expect(daily.todayStreakBonus, 0);
      expect(daily.nextStreakBonus, StreakConfig.bonuses[6],
          reason: 'finishing today would make it the seventh day');

      await daily.submit(score: 100, stars: 3);
      expect(daily.streak, 7);
      expect(daily.ladderDay, 7);
      expect(daily.ladderDoneDays, 7);
      expect(daily.todayStreakBonus, StreakConfig.bonuses[6]);
      expect(daily.nextStreakBonus, StreakConfig.bonuses[0],
          reason: 'tomorrow starts a new ladder cycle');
      expect(daily.streakCycleDay, 7);
    });

    test('the seed is stable per day and different across days', () {
      final DailyService daily = DailyService(StorageManager.inMemory());
      final int a = daily.generatorFor('2026-05-01').nextInt(1 << 20);
      final int b = daily.generatorFor('2026-05-01').nextInt(1 << 20);
      final int c = daily.generatorFor('2026-05-02').nextInt(1 << 20);
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('LeaderboardService', () {
    ScoreRecord record(int score, {GameMode mode = GameMode.classic}) =>
        ScoreRecord(
          score: score,
          mode: mode,
          combo: 0,
          clearedLines: 0,
          moves: 1,
          dateKey: '2026-01-01',
        );

    test('add reports the rank, or 0 when the record did not qualify',
        () async {
      final LeaderboardService board =
          LeaderboardService(StorageManager.inMemory());
      expect(await board.add(record(100)), 1);
      expect(await board.add(record(300)), 1);
      expect(await board.add(record(200)), 2);

      for (int i = 0; i < LeaderboardService.maxEntries; i++) {
        await board.add(record(1000 + i));
      }
      expect(await board.add(record(1)), 0,
          reason: 'the board is full of better scores');
    });

    test('loading an unordered payload sorts it', () {
      final StorageManager storage = StorageManager.inMemory();
      storage.setString(
        StorageKeys.leaderboard,
        jsonEncode(<String, dynamic>{
          'classic': ScoreRecord.encodeList(<ScoreRecord>[
            record(10),
            record(900),
            record(50),
          ]),
        }),
      );
      final LeaderboardService board = LeaderboardService(storage);
      expect(board.bestFor(GameMode.classic), 900);
      expect(board.top(GameMode.classic).first.score, 900);
      expect(board.top(GameMode.classic).last.score, 10);
    });

    test('unknown mode keys and malformed entries are dropped', () {
      final StorageManager storage = StorageManager.inMemory();
      const String classic =
          '[{"score":-5},{"score":"high"},{"score":null},'
          '{"score":100,"mode":7,"date":42,"ts":1e999},'
          '{"score":200,"combo":-3,"lines":-4,"moves":-5,'
          '"date":"junk","ts":-1}]';
      storage.setString(
        StorageKeys.leaderboard,
        jsonEncode(<String, dynamic>{
          'not-a-mode': ScoreRecord.encodeList(<ScoreRecord>[record(9999)]),
          'classic': classic,
        }),
      );

      final LeaderboardService board = LeaderboardService(storage);
      expect(board.bestFor(GameMode.classic), 200);
      expect(board.top(GameMode.classic).length, 2);
      final ScoreRecord parsed = board.top(GameMode.classic).first;
      expect(parsed.combo, 0);
      expect(parsed.clearedLines, 0);
      expect(parsed.moves, 0);
      expect(parsed.dateKey, DateKeys.today());
    });

    test('a payload with 500 entries is capped on load', () {
      final StorageManager storage = StorageManager.inMemory();
      storage.setString(
        StorageKeys.leaderboard,
        jsonEncode(<String, dynamic>{
          'classic': ScoreRecord.encodeList(<ScoreRecord>[
            for (int i = 0; i < 500; i++) record(i),
          ]),
        }),
      );
      final LeaderboardService board = LeaderboardService(storage);
      expect(board.top(GameMode.classic, limit: 500).length,
          LeaderboardService.maxEntries);
    });

    test('non string payloads are ignored', () {
      final StorageManager storage = StorageManager.inMemory();
      storage.setString(
        StorageKeys.leaderboard,
        jsonEncode(<String, dynamic>{'classic': 42, 'zen': null}),
      );
      final LeaderboardService board = LeaderboardService(storage);
      expect(board.isEmpty(GameMode.classic), isTrue);
      expect(board.isEmpty(GameMode.zen), isTrue);
    });

    test('clear empties every mode', () async {
      final LeaderboardService board =
          LeaderboardService(StorageManager.inMemory());
      await board.add(record(10));
      await board.add(record(20, mode: GameMode.zen));
      await board.clear();
      expect(board.isEmpty(GameMode.classic), isTrue);
      expect(board.isEmpty(GameMode.zen), isTrue);
    });
  });

  group('AchievementsController', () {
    test('forged ids are ignored and known ids are kept', () {
      final StorageManager storage = StorageManager.inMemory();
      final String known = AchievementCatalog.all.first.id;
      storage.setMapList(StorageKeys.achievements, <Map<String, dynamic>>[
        <String, dynamic>{'id': known},
        <String, dynamic>{'id': 'not-a-real-badge'},
        <String, dynamic>{'id': 42},
        <String, dynamic>{'nope': 'x'},
      ]);

      final AchievementsController achievements =
          AchievementsController(storage);
      expect(achievements.isUnlocked(known), isTrue);
      expect(achievements.isUnlocked('not-a-real-badge'), isFalse);
      expect(achievements.unlockedCount, 1);
      expect(achievements.totalCount, AchievementCatalog.all.length);
    });

    test('evaluate is idempotent', () async {
      final StorageManager storage = StorageManager.inMemory();
      final AchievementsController achievements =
          AchievementsController(storage);
      final StatsController stats = StatsController(storage);
      await stats.registerRun(
        score: 10,
        combo: 0,
        linesCleared: 0,
        cellsPlaced: 1,
        perfectMoves: 0,
        playSeconds: 1,
      );

      final List<dynamic> first =
          await achievements.evaluate(statsAchievementSnapshot(stats));
      final List<dynamic> second =
          await achievements.evaluate(statsAchievementSnapshot(stats));
      expect(first, isNotEmpty);
      expect(second, isEmpty);
      expect(AchievementsController(storage).unlockedCount, first.length);
    });
  });

  group('WalletController', () {
    test('ignores non finite and negative balances', () {
      final StorageManager storage = StorageManager.inMemory();
      storage.setDouble(StorageKeys.coins, double.infinity);
      expect(WalletController(storage).coins, 0);

      storage.setInt(StorageKeys.coins, -500);
      expect(WalletController(storage).coins, 0);
    });

    test('boundary amounts do not overflow or go negative', () async {
      final StorageManager storage = StorageManager.inMemory();
      final WalletController wallet = WalletController(storage);
      await wallet.add(9223372036854775807);
      expect(wallet.coins, greaterThan(0));
      expect(await wallet.spend(9223372036854775807), isTrue);
      expect(wallet.coins, 0);
      expect(await wallet.spend(0), isTrue);
      expect(await wallet.spend(-5), isFalse);
      expect(wallet.coins, 0);
    });
  });

  group('InventoryController', () {
    test('only positive integer counts are restored', () {
      final StorageManager storage = StorageManager.inMemory();
      storage.setMap(StorageKeys.inventory, <String, dynamic>{
        ShopItemId.refreshTray.storageKey: 3,
        ShopItemId.clearBoard.storageKey: -2,
        ShopItemId.booster.storageKey: 1.5,
        'unknown.item': 99,
        'str': '4',
      });
      final InventoryController inventory = InventoryController(storage);
      expect(inventory.countOf(ShopItemId.refreshTray), 3);
      expect(inventory.countOf(ShopItemId.clearBoard), 0);
      expect(inventory.countOf(ShopItemId.booster), 0);
      expect(inventory.totalItems, 3);
    });

    test('consume never goes below zero', () async {
      final InventoryController inventory =
          InventoryController(StorageManager.inMemory());
      expect(await inventory.consume(ShopItemId.booster), isFalse);
      await inventory.add(ShopItemId.booster);
      expect(await inventory.consume(ShopItemId.booster), isTrue);
      expect(await inventory.consume(ShopItemId.booster), isFalse);
      expect(inventory.countOf(ShopItemId.booster), 0);
    });
  });

  group('SettingsController', () {
    test('hostile stored preferences fall back to defaults', () {
      final StorageManager storage = StorageManager.inMemory();
      storage.setString(StorageKeys.languageCode, '<script>alert(1)</script>');
      storage.setString(StorageKeys.themeMode, 'neon');
      storage.setInt(StorageKeys.boardSize, 12);
      storage.setString(StorageKeys.soundEnabled, 'yes');

      final SettingsController settings = _settings(storage);
      expect(settings.languageCode, 'en');
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.boardSize, BoardConfig.defaultSize);
      expect(settings.soundEnabled, isTrue);
    });

    test('setLanguageCode whitelists and normalises', () {
      final SettingsController settings =
          _settings(StorageManager.inMemory());
      settings.setLanguageCode('TR');
      expect(settings.languageCode, 'tr');
      settings.setLanguageCode('de');
      expect(settings.languageCode, 'tr');
      settings.setLanguageCode('../../../etc/passwd');
      expect(settings.languageCode, 'tr');
      settings.setLanguageCode('en');
      expect(settings.languageCode, 'en');
    });

    test('resetToDefaults restores the language too', () async {
      final StorageManager storage = StorageManager.inMemory();
      final SettingsController settings = _settings(storage);
      settings.setLanguageCode('tr');
      settings.setThemeMode(ThemeMode.dark);
      settings.setBoardSize(9);

      await settings.resetToDefaults();
      expect(settings.languageCode, 'en');
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.boardSize, BoardConfig.defaultSize);
      expect(_settings(storage).languageCode, 'en');
    });
  });

  group('Pure game logic', () {
    test('placement rejects out of bounds moves without touching the board',
        () {
      final Board board = Board(8);
      final PieceSlot piece = PieceSlot(
        index: 0,
        shape: PieceGenerator().library.byId('dom'),
        colorIndex: 0,
      );
      for (final (int row, int col) in <(int, int)>[
        (-1, 0),
        (0, -1),
        (7, 7),
        (99, 99),
      ]) {
        final PlacementOutcome? outcome = PlacementEngine.apply(
          board: board,
          piece: piece,
          topRow: row,
          leftCol: col,
          comboLevel: 0,
        );
        expect(outcome, isNull);
      }
      expect(board.filledCount, 0);
    });

    test('clearLines counts the row/column intersection once', () {
      final Board board = Board(3);
      // Fill the last row and last column; they intersect at (2, 2).
      for (int i = 0; i < 3; i++) {
        board.setValue(2, i, 1);
        board.setValue(i, 2, 1);
      }
      expect(board.fullRows(), <int>[2]);
      expect(board.fullColumns(), <int>[2]);
      final int cleared = board.clearLines(<int>[2], <int>[2]);
      expect(cleared, 5, reason: '3 + 3 - the shared cell');
      expect(board.filledCount, 0);
    });

    test('the combo multiplier is capped', () {
      expect(ScoringEngine.multiplierFor(0), 1);
      expect(ScoringEngine.multiplierFor(1), 1.25);
      expect(ScoringEngine.multiplierFor(999), ScoringConfig.comboCap);
      final ComboTracker combo = ComboTracker();
      expect(combo.register(1), 1);
      expect(combo.register(2), 2);
      expect(combo.best, 2);
      expect(combo.register(0), 0);
      expect(combo.register(1), 1);
      expect(combo.best, 2);
      combo.reset();
      expect(combo.best, 0);
    });

    test('stars are monotonic and never negative', () {
      final List<int> thresholds = GameMode.daily.config.starThresholds;
      expect(ScoringEngine.starsForScore(-100, thresholds), 0);
      int previous = 0;
      for (int score = 0; score <= 4000; score += 100) {
        final int stars = ScoringEngine.starsForScore(score, thresholds);
        expect(stars, greaterThanOrEqualTo(previous));
        previous = stars;
      }
      expect(ScoringEngine.starsForScore(9999, thresholds), 3);
      expect(ScoringEngine.starsForScore(9999, const <int>[]), 0);
    });

    test('board bytes round trip and are clamped', () {
      final Board board = Board(4);
      board.setValue(1, 2, 5);
      final Board clone = Board(4)..loadBytes(board.toBytes());
      expect(clone.valueAt(1, 2), 5);
      expect(() => clone.loadBytes(Uint8List.fromList(<int>[1, 2])),
          returnsNormally);
      expect(clone.valueAt(0, 0), 1);
      expect(clone.valueAt(0, 2), 0);
      expect(() => clone.loadBytes(Uint8List(100)), returnsNormally);
    });

    test('suggestMove returns a move the engine accepts', () {
      final Board board = Board(8);
      final List<PieceSlot> tray = PieceGenerator().generateTray(
        board: board,
        traySize: 3,
        score: 0,
        largePieceBias: 1,
        colorCount: 8,
      );
      final PlacementHint? hint = BoardAnalyzer.suggestMove(board, tray);
      expect(hint, isNotNull);
      final PieceSlot piece = tray[hint!.slotIndex].copyWith(
        rotation: hint.rotation,
      );
      expect(board.canPlace(piece.cells, hint.topRow, hint.leftCol), isTrue);
    });

    test('forced trays are always playable on an empty board', () {
      for (int seed = 0; seed < 80; seed++) {
        final Board board = Board(8);
        final PieceGenerator generator = PieceGenerator();
        final List<PieceSlot> tray = generator.generateTray(
          board: board,
          traySize: 3,
          score: 0,
          largePieceBias: 1,
          colorCount: 8,
        );
        expect(BoardAnalyzer.hasAnyMove(board, tray), isTrue,
            reason: 'seed $seed produced a dead tray');
      }
    });

    test('anchorForDrop centres the piece and rejects the rim', () {
      final Board board = Board(8);
      final PieceSlot piece = PieceSlot(
        index: 0,
        shape: PieceGenerator().library.byId('dot'),
        colorIndex: 0,
      );
      expect(BoardAnalyzer.anchorForDrop(board, piece, -1, 0), isNull);
      final GridAnchor? anchor =
          BoardAnalyzer.anchorForDrop(board, piece, 4, 4);
      expect(anchor, isNotNull);
      expect(anchor!.topRow, 4);
      expect(anchor.leftCol, 4);
      expect(BoardAnalyzer.anchorForDrop(board, piece, 8, 8), isNull);
    });
  });

  group('GameController revive and smash tools', () {
    late StorageManager storage;
    late StatsController stats;
    late LeaderboardService leaderboard;
    late DailyService daily;
    late WalletController wallet;
    late GameController controller;

    setUp(() {
      storage = StorageManager.inMemory();
      stats = StatsController(storage);
      leaderboard = LeaderboardService(storage);
      daily = DailyService(storage);
      wallet = WalletController(storage);
      controller = GameController(
        stats: stats,
        leaderboard: leaderboard,
        daily: daily,
        audio: AudioManager(backend: SilentAudioBackend()),
        haptics: HapticsService(enabled: false),
        wallet: wallet,
      );
    });

    tearDown(() => controller.stopTimers());

    void fillBoard() {
      final Board board = controller.board;
      for (int row = 0; row < board.size; row++) {
        for (int col = 0; col < board.size; col++) {
          board.setValue(row, col, 1);
        }
      }
    }

    test('a stuck board offers the second chance before saving anything',
        () async {
      await controller.start(mode: GameMode.classic);
      fillBoard();

      expect(controller.checkForDeadTray(), isTrue);
      expect(controller.phase, GamePhase.revive);
      expect(controller.reviveOffered, isTrue);
      expect(stats.gamesPlayed, 0, reason: 'the run is not stored yet');

      await controller.declineRevive();
      expect(controller.phase, GamePhase.finished);
      expect(stats.gamesPlayed, 1, reason: 'declining stores the run once');
    });

    test('reviving pays coins, wipes rows and keeps the run alive', () async {
      await wallet.add(ReviveConfig.cost + 10);
      await controller.start(mode: GameMode.classic);
      fillBoard();
      controller.checkForDeadTray();

      final bool revived = await controller.revive();
      expect(revived, isTrue);
      expect(controller.phase, GamePhase.playing);
      expect(wallet.coins, 10);
      expect(controller.board.filledCount, lessThan(64 - 3 * 8 + 1),
          reason: 'three rows must be wiped');
      expect(controller.trayIsDead, isFalse);
      expect(controller.reviveUsed, isTrue);
      expect(
        controller.drainEvents().any(
            (GameEvent e) => e.type == GameEventType.reviveStarted),
        isTrue,
      );
    });

    test('the second chance only happens once per run', () async {
      await wallet.add(ReviveConfig.cost * 2);
      await controller.start(mode: GameMode.classic);
      fillBoard();
      controller.checkForDeadTray();
      expect(await controller.revive(), isTrue);

      // Stuck again: this time there is no offer, the run simply ends.
      fillBoard();
      expect(controller.checkForDeadTray(), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.phase, GamePhase.finished);
      expect(stats.gamesPlayed, 1);
    });

    test('revive fails when the wallet cannot pay and the run can still end',
        () async {
      await controller.start(mode: GameMode.classic);
      fillBoard();
      controller.checkForDeadTray();

      expect(await controller.revive(), isFalse);
      expect(controller.phase, GamePhase.revive,
          reason: 'a failed payment must not start the run again');
      await controller.declineRevive();
      expect(controller.phase, GamePhase.finished);
    });

    test('revive is free when an ad paid for it', () async {
      await controller.start(mode: GameMode.classic);
      fillBoard();
      controller.checkForDeadTray();

      expect(await controller.revive(free: true), isTrue);
      expect(wallet.coins, 0);
      expect(controller.phase, GamePhase.playing);
    });

    test('the hammer removes exactly the tapped block', () async {
      await controller.start(mode: GameMode.classic);
      controller.board.setValue(3, 4, 2);

      expect(controller.hammerAt(3, 4), isTrue);
      expect(controller.board.valueAt(3, 4), Board.empty);
      expect(controller.board.filledCount, 0);
      expect(controller.hammerAt(3, 4), isFalse,
          reason: 'an empty cell cannot be smashed');
    });

    test('the bomb clears a 3x3 window and clips at the rim', () async {
      await controller.start(mode: GameMode.classic);
      for (int row = 0; row < 8; row++) {
        for (int col = 0; col < 8; col++) {
          controller.board.setValue(row, col, 1);
        }
      }

      expect(controller.bombAt(4, 4), isTrue);
      expect(controller.board.filledCount, 64 - 9);
      expect(controller.board.valueAt(3, 3), Board.empty);
      expect(controller.board.valueAt(5, 5), Board.empty);
      expect(controller.board.valueAt(2, 4), isNot(Board.empty));

      expect(controller.bombAt(0, 0), isTrue);
      expect(controller.board.filledCount, 55 - 4,
          reason: 'a corner blast only covers four cells');
      expect(controller.bombAt(0, 0), isFalse, reason: 'nothing left to blow');
    });

    test('smashing never changes the score or the line count', () async {
      await controller.start(mode: GameMode.classic);
      final int score = controller.state.score;
      final int lines = controller.state.linesCleared;
      controller.board.setValue(0, 0, 1);

      expect(controller.hammerAt(0, 0), isTrue);
      expect(controller.state.score, score);
      expect(controller.state.linesCleared, lines);
      expect(controller.state.phase, GamePhase.playing);
    });

    test('smash tools are rejected outside a playing run', () async {
      expect(controller.hammerAt(0, 0), isFalse);
      expect(controller.bombAt(0, 0), isFalse);
      await controller.start(mode: GameMode.classic);
      controller.board.setValue(0, 0, 1);
      await controller.finish();

      expect(controller.hammerAt(0, 0), isFalse);
      expect(controller.bombAt(0, 0), isFalse);
    });

    test('out of bounds smash targets are ignored', () async {
      await controller.start(mode: GameMode.classic);
      for (final (int, int) target in <(int, int)>[
        (-1, 0),
        (0, -1),
        (8, 0),
        (0, 8),
        (99, 99),
      ]) {
        expect(controller.hammerAt(target.$1, target.$2), isFalse);
        expect(controller.bombAt(target.$1, target.$2), isFalse);
      }
      expect(controller.phase, GamePhase.playing);
    });
  });

  group('GameController guards', () {
    late StorageManager storage;
    late StatsController stats;
    late LeaderboardService leaderboard;
    late DailyService daily;
    late WalletController wallet;
    late GameController controller;

    setUp(() {
      storage = StorageManager.inMemory();
      stats = StatsController(storage);
      leaderboard = LeaderboardService(storage);
      daily = DailyService(storage);
      wallet = WalletController(storage);
      controller = GameController(
        stats: stats,
        leaderboard: leaderboard,
        daily: daily,
        audio: AudioManager(backend: SilentAudioBackend()),
        haptics: HapticsService(enabled: false),
        wallet: wallet,
      );
    });

    tearDown(() => controller.stopTimers());

    test('out of range slots and moves are rejected cleanly', () {
      expect(controller.slotAt(-1), isNull);
      expect(controller.slotAt(99), isNull);
      expect(controller.placePiece(0, 0, 0), isNull,
          reason: 'the run has not started yet');
      expect(controller.rotateSlot(0), isFalse);
      expect(controller.activateBooster(), isFalse);
      expect(controller.refreshTray(), isFalse);
      expect(controller.clearBoard(), isFalse);
    });

    test('finishing before a run starts does not save a phantom run',
        () async {
      await controller.finish();
      expect(stats.gamesPlayed, 0);
      expect(controller.phase, GamePhase.ready);
    });

    test('in-run power-up guards behave', () async {
      await controller.start(mode: GameMode.classic);
      controller.drainEvents();
      expect(controller.clearBoard(), isFalse,
          reason: 'an empty board has nothing to clear');
      expect(controller.activateBooster(seconds: 0), isFalse);
      final List<GameEvent> events = controller.drainEvents();
      expect(events.where((GameEvent e) => e.type == GameEventType.started),
          isEmpty);
    });
  });
}
