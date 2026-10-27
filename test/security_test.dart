import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gridpop/audio/audio_manager.dart';
import 'package:gridpop/core/constants/storage_keys.dart';
import 'package:gridpop/core/utils/date_keys.dart';
import 'package:gridpop/game/achievements/achievement_catalog.dart';
import 'package:gridpop/game/models/game_event.dart';
import 'package:gridpop/game/models/game_mode.dart';
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

/// Penetration tests for the local-only attack surface.
///
/// GridPop has no server, no accounts and no network calls: the only attacker
/// controlled input is persistent storage. Everything below simulates a user
/// (or an XSS on the same origin) writing arbitrary values into the keys the
/// game reads at boot. The goal is not to make cheating impossible - a local
/// game has no authority - but to guarantee that hostile data can never crash,
/// lock or corrupt a session.
String _dayFromNow(int offset) => DateKeys.key(
      DateTime.now().add(Duration(days: offset)),
    );

SettingsController _settings(StorageManager storage) => SettingsController(
      storage: storage,
      audio: AudioManager(backend: SilentAudioBackend()),
      haptics: HapticsService(enabled: false),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PEN-01 storage bootstrap survivability', () {
    test('every key with a hostile primitive boots without throwing',
        () async {
      final StorageManager storage = StorageManager.inMemory();
      // Numbers that JSON can encode but Dart cannot round.
      for (final String key in <String>[
        StorageKeys.coins,
        StorageKeys.highScore,
        StorageKeys.totalScore,
        StorageKeys.gamesPlayed,
        StorageKeys.bestCombo,
        StorageKeys.totalLinesCleared,
        StorageKeys.perfectMoves,
        StorageKeys.totalCellsPlaced,
        StorageKeys.totalPlaySeconds,
        StorageKeys.boardSize,
      ]) {
        storage.setDouble(key, double.infinity);
      }
      // Booleans and strings where the wrong type is expected.
      for (final String key in <String>[
        StorageKeys.soundEnabled,
        StorageKeys.musicEnabled,
        StorageKeys.vibrationEnabled,
        StorageKeys.showGhost,
        StorageKeys.showHints,
      ]) {
        storage.setString(key, 'true');
      }
      storage.setString(StorageKeys.themeMode, '{"evil":true}');
      storage.setString(StorageKeys.languageCode, '\u0000tr');

      expect(() => WalletController(storage), returnsNormally);
      expect(() => StatsController(storage), returnsNormally);
      expect(() => LeaderboardService(storage), returnsNormally);
      expect(() => DailyService(storage), returnsNormally);
      expect(() => InventoryController(storage), returnsNormally);
      expect(() => AchievementsController(storage), returnsNormally);
      expect(() => _settings(storage), returnsNormally);

      expect(WalletController(storage).coins, 0);
      expect(StatsController(storage).highScore, 0);
      expect(_settings(storage).languageCode, 'en');
    });

    test('a single corrupt key does not take the other keys down', () async {
      final StorageManager storage = StorageManager.inMemory();
      storage.setString(StorageKeys.leaderboard, '<<<not json>>>');
      storage.setString(StorageKeys.dailyRecord, 'null');
      storage.setString(StorageKeys.inventory, '[]');
      storage.setString(StorageKeys.achievements, '{"id":"x"}');
      storage.setInt(StorageKeys.coins, 75);

      expect(WalletController(storage).coins, 75);
      expect(LeaderboardService(storage).isEmpty(GameMode.classic), isTrue);
      expect(DailyService(storage).isCompletedToday, isFalse);
      expect(InventoryController(storage).totalItems, 0);
      expect(AchievementsController(storage).unlockedCount, 0);
    });
  });

  group('PEN-02 coin and inventory tampering', () {
    test('a forged balance is bounded by int and can only be spent down',
        () async {
      final StorageManager storage = StorageManager.inMemory();
      storage.setInt(StorageKeys.coins, 9223372036854775807);
      final WalletController wallet = WalletController(storage);
      expect(wallet.coins, 9223372036854775807);
      expect(await wallet.spend(1), isTrue);
      expect(wallet.coins, 9223372036854775806);
      expect(await wallet.spend(-1), isFalse,
          reason: 'a negative price must not mint coins');
    });

    test('forged item counts cannot go negative or fractional', () {
      final StorageManager storage = StorageManager.inMemory();
      // Written as JSON on purpose: `double.infinity` cannot be encoded by
      // `jsonEncode`, but `1e999` decodes into it and is a realistic payload.
      storage.setString(
        StorageKeys.inventory,
        '{'
            '"${ShopItemId.refreshTray.storageKey}":1e999,'
            '"${ShopItemId.clearBoard.storageKey}":-1e999,'
            '"${ShopItemId.booster.storageKey}":"999",'
            '"__proto__":{"polluted":true}'
            '}',
      );
      final InventoryController inventory = InventoryController(storage);
      expect(inventory.totalItems, 0);
      for (final ShopItemId item in ShopItemId.values) {
        expect(inventory.countOf(item), 0);
      }
    });
  });

  group('PEN-03 leaderboard forgery', () {
    test('a forged payload is sanitised, sorted and capped', () {
      final StorageManager storage = StorageManager.inMemory();
      final List<Object?> forged = <Object?>[
        for (int i = 0; i < 2000; i++)
          <String, dynamic>{
            'score': i.isEven ? i : -i,
            'mode': i.isEven ? 'classic' : 42,
            'combo': i.isEven ? i : 'x',
            'lines': -i,
            'moves': -1,
            'date': i.isEven ? '2026-02-30' : 12345,
            'ts': i.isEven ? 9000000000000000000 : -1,
          },
      ];
      storage.setString(
        StorageKeys.leaderboard,
        jsonEncode(<String, dynamic>{'classic': jsonEncode(forged)}),
      );

      final LeaderboardService board = LeaderboardService(storage);
      final List<ScoreRecord> top =
          board.top(GameMode.classic, limit: 500);
      expect(top.length, LeaderboardService.maxEntries);
      expect(top.first.score, 1998);
      for (final ScoreRecord record in top) {
        expect(record.score, greaterThanOrEqualTo(0));
        expect(record.combo, greaterThanOrEqualTo(0));
        expect(record.clearedLines, greaterThanOrEqualTo(0));
        expect(record.moves, greaterThanOrEqualTo(0));
        expect(DateKeys.isValidKey(record.dateKey), isTrue);
      }
    });

    test('injection strings in dates and modes are not trusted', () {
      final StorageManager storage = StorageManager.inMemory();
      storage.setString(
        StorageKeys.leaderboard,
        jsonEncode(<String, dynamic>{
          'classic': jsonEncode(<Object?>[
            <String, dynamic>{
              'score': 10,
              'mode': 'classic\'; DROP TABLE scores; --',
              'date': '<img src=x onerror=alert(1)>',
              'ts': 'not-a-number',
            },
          ]),
          '"><script>alert(1)</script>': '[]',
        }),
      );
      final LeaderboardService board = LeaderboardService(storage);
      final List<ScoreRecord> top = board.top(GameMode.classic);
      expect(top.length, 1);
      expect(top.first.dateKey, DateKeys.today());
      expect(top.first.mode, GameMode.classic);
    });

    test('duplicate identical records keep their rank', () async {
      final LeaderboardService board =
          LeaderboardService(StorageManager.inMemory());
      final ScoreRecord first = ScoreRecord(
        score: 500,
        mode: GameMode.classic,
        combo: 0,
        clearedLines: 0,
        moves: 1,
        dateKey: '2026-01-01',
        date: DateTime(2026, 1, 1),
      );
      final ScoreRecord second = ScoreRecord(
        score: 500,
        mode: GameMode.classic,
        combo: 0,
        clearedLines: 0,
        moves: 1,
        dateKey: '2026-01-02',
        date: DateTime(2026, 1, 2),
      );
      expect(await board.add(first), 1);
      expect(await board.add(second), 2);
      expect(board.top(GameMode.classic).length, 2);
    });
  });

  group('PEN-04 daily history forgery', () {
    test('forged stars, scores and timestamps are clamped', () {
      final StorageManager storage = StorageManager.inMemory();
      storage.setString(
        StorageKeys.dailyRecord,
        jsonEncode(<String, dynamic>{
          _dayFromNow(0): <String, dynamic>{
            'score': 9223372036854775807,
            'stars': 9223372036854775807,
            'ts': 9223372036854775807,
          },
        }),
      );
      final DailyService daily = DailyService(storage);
      expect(daily.todayStars, 3);
      expect(daily.todayBestScore, greaterThan(0));
      expect(() => daily.todayResult!.playedAt, returnsNormally);
    });

    test('future and junk days cannot fake a streak', () async {
      final StorageManager storage = StorageManager.inMemory();
      storage.setString(
        StorageKeys.dailyRecord,
        jsonEncode(<String, dynamic>{
          _dayFromNow(5): <String, dynamic>{'score': 999, 'stars': 3},
          _dayFromNow(4): <String, dynamic>{'score': 999, 'stars': 3},
          '2030-13-40': <String, dynamic>{'score': 999, 'stars': 3},
          '0000-00-00': <String, dynamic>{'score': 999, 'stars': 3},
        }),
      );
      final DailyService daily = DailyService(storage);
      await daily.submit(score: 10, stars: 1);
      expect(daily.streak, 1,
          reason: 'only today is real; future days do not chain backwards');
    });

    test('a massive history is pruned to the newest 30 days', () async {
      final StorageManager storage = StorageManager.inMemory();
      final Map<String, dynamic> seed = <String, dynamic>{};
      for (int i = 1; i <= 5000; i++) {
        seed[_dayFromNow(-i)] = <String, dynamic>{'score': i, 'stars': 1};
      }
      storage.setString(StorageKeys.dailyRecord, jsonEncode(seed));

      final DailyService daily = DailyService(storage);
      await daily.submit(score: 1, stars: 0);

      expect(daily.resultFor(_dayFromNow(-1)), isNotNull);
      expect(daily.resultFor(_dayFromNow(-29)), isNotNull);
      expect(daily.resultFor(_dayFromNow(-30)), isNull);
      expect(daily.resultFor(_dayFromNow(-5000)), isNull);
    });

    test('a 100 KB junk key is rejected without slow parsing', () {
      final String junk = 'x' * 100000;
      expect(DateKeys.isValidKey(junk), isFalse);
      expect(DateKeys.isValidKey('2026-01-01$junk'), isFalse);
    });
  });

  group('PEN-05 achievement forgery', () {
    test('ten thousand unknown ids unlock nothing', () {
      final StorageManager storage = StorageManager.inMemory();
      storage.setMapList(
        StorageKeys.achievements,
        <Map<String, dynamic>>[
          for (int i = 0; i < 10000; i++)
            <String, dynamic>{'id': 'forged-$i', 'dateKey': '2026-01-01'},
        ],
      );
      final AchievementsController achievements =
          AchievementsController(storage);
      expect(achievements.unlockedCount, 0);
      expect(achievements.unlockedCount,
          lessThanOrEqualTo(achievements.totalCount));
      expect(
        achievements.statusesFromStats(StatsController(storage)).length,
        AchievementCatalog.all.length,
      );
    });

    test('a duplicated real id cannot be counted twice', () {
      final StorageManager storage = StorageManager.inMemory();
      final String known = AchievementCatalog.all.first.id;
      storage.setMapList(
        StorageKeys.achievements,
        <Map<String, dynamic>>[
          for (int i = 0; i < 100; i++) <String, dynamic>{'id': known},
        ],
      );
      final AchievementsController achievements =
          AchievementsController(storage);
      expect(achievements.unlockedCount, 1);
    });
  });

  group('PEN-06 settings injection', () {
    test('oversized and control character locales are rejected', () {
      final StorageManager storage = StorageManager.inMemory();
      storage.setString(StorageKeys.languageCode, 'tr${'A' * 50000}');
      expect(_settings(storage).languageCode, 'en');

      storage.setString(StorageKeys.languageCode, 'tr\u0000;rm -rf /');
      expect(_settings(storage).languageCode, 'en');

      storage.setString(StorageKeys.languageCode, 'TR');
      expect(_settings(storage).languageCode, 'tr');
    });

    test('a boolean flag with the wrong type keeps its safe default', () {
      final StorageManager storage = StorageManager.inMemory();
      storage.setString(StorageKeys.vibrationEnabled, 'false');
      // Defaults to on; the important part is that it does not throw.
      expect(_settings(storage).vibrationEnabled, isTrue);
    });
  });

  group('PEN-07 gameplay input fuzzing', () {
    test('random hostile placements cannot corrupt the run state', () async {
      for (int seed = 0; seed < 6; seed++) {
        final StorageManager storage = StorageManager.inMemory();
        final StatsController stats = StatsController(storage);
        final GameController controller = GameController(
          stats: stats,
          leaderboard: LeaderboardService(storage),
          daily: DailyService(storage),
          audio: AudioManager(backend: SilentAudioBackend()),
          haptics: HapticsService(enabled: false),
          wallet: WalletController(storage),
          preferredBoardSize: seed.isEven ? 8 : 9,
        );
        await controller.start(mode: GameMode.classic);
        final math.Random random = math.Random(seed);

        for (int move = 0; move < 80; move++) {
          final int slot = random.nextInt(6) - 1; // -1..4, two invalid slots
          final int row = random.nextInt(14) - 3;
          final int col = random.nextInt(14) - 3;
          controller.placePiece(slot, row, col);
          if (move % 5 == 0) {
            controller.completePlacement();
          }
          if (move % 17 == 0) {
            controller.rotateSlot(random.nextInt(6) - 1);
          }

          final state = controller.state;
          expect(state.score, greaterThanOrEqualTo(0));
          expect(state.moves, greaterThanOrEqualTo(0));
          expect(state.cellsPlaced, greaterThanOrEqualTo(0));
          expect(state.linesCleared, greaterThanOrEqualTo(0));
          expect(state.tray.length, 3);
          expect(controller.board.size, seed.isEven ? 8 : 9);
          for (final int value in controller.board.cells) {
            expect(value, inInclusiveRange(0, 8));
          }
        }

        final List<GameEvent> events = controller.drainEvents();
        expect(events, isNotNull);
        controller.stopTimers();
        controller.dispose();
      }
    });

    test('a finished run cannot be finished twice, even under spam', () async {
      final StorageManager storage = StorageManager.inMemory();
      final StatsController stats = StatsController(storage);
      final GameController controller = GameController(
        stats: stats,
        leaderboard: LeaderboardService(storage),
        daily: DailyService(storage),
        audio: AudioManager(backend: SilentAudioBackend()),
        haptics: HapticsService(enabled: false),
        wallet: WalletController(storage),
      );
      await controller.start(mode: GameMode.zen);
      await Future.wait<void>(<Future<void>>[
        controller.finish(),
        controller.finish(),
        controller.finish(),
      ]);
      expect(stats.gamesPlayed, 1);
      controller.stopTimers();
      controller.dispose();
    });
  });
}
