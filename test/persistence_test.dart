import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridpop/core/constants/app_strings.dart';
import 'package:gridpop/core/utils/date_keys.dart';
import 'package:gridpop/core/utils/responsive.dart';
import 'package:gridpop/core/utils/score_format.dart';
import 'package:gridpop/core/utils/seeded_random.dart';
import 'package:gridpop/game/models/game_mode.dart';
import 'package:gridpop/game/models/score_record.dart';
import 'package:gridpop/game/services/daily_service.dart';
import 'package:gridpop/game/services/leaderboard_service.dart';
import 'package:gridpop/state/settings_controller.dart';
import 'package:gridpop/state/stats_controller.dart';
import 'package:gridpop/storage/storage_manager.dart';
import 'package:gridpop/audio/audio_manager.dart';
import 'package:gridpop/game/services/haptics_service.dart';
import 'package:gridpop/core/constants/storage_keys.dart';

void main() {
  group('StorageManager', () {
    test('round trips primitives, maps and lists', () async {
      final StorageManager storage = StorageManager.inMemory();
      await storage.setInt('a', 7);
      await storage.setString('b', 'hello');
      await storage.setBool('c', true);
      await storage.setMap('d', <String, dynamic>{'x': 1});
      await storage.setMapList('e', <Map<String, dynamic>>[
        <String, dynamic>{'y': 2},
      ]);

      expect(storage.getInt('a'), 7);
      expect(storage.getString('b'), 'hello');
      expect(storage.getBool('c'), isTrue);
      expect(storage.getMap('d')?['x'], 1);
      expect(storage.getMapList('e').length, 1);
    });

    test('missing keys return null instead of throwing', () {
      final StorageManager storage = StorageManager.inMemory();
      expect(storage.getInt('nope'), isNull);
      expect(storage.getMap('nope'), isNull);
      expect(storage.getMapList('nope'), isEmpty);
    });

    test('clearAppData only removes the app prefix', () async {
      final StorageManager storage = StorageManager.inMemory();
      await storage.setInt('${StorageKeys.prefix}score', 10);
      await storage.setInt('other.score', 99);

      await storage.clearAppData(StorageKeys.prefix);

      expect(storage.getInt('${StorageKeys.prefix}score'), isNull);
      expect(storage.getInt('other.score'), 99);
    });
  });

  group('StatsController', () {
    test('a finished run is aggregated and persisted', () async {
      final StorageManager storage = StorageManager.inMemory();
      final StatsController stats = StatsController(storage);

      final bool isRecord = await stats.registerRun(
        score: 120,
        combo: 3,
        linesCleared: 5,
        cellsPlaced: 22,
        perfectMoves: 1,
        playSeconds: 60,
      );

      expect(isRecord, isTrue);
      expect(stats.highScore, 120);
      expect(stats.totalScore, 120);
      expect(stats.gamesPlayed, 1);
      expect(stats.bestCombo, 3);
      expect(stats.totalLinesCleared, 5);
      expect(stats.perfectMoves, 1);
      expect(stats.totalPlayTime, const Duration(seconds: 60));

      // A second, weaker run must not overwrite the record.
      final bool second = await stats.registerRun(
        score: 40,
        combo: 1,
        linesCleared: 2,
        cellsPlaced: 10,
        perfectMoves: 0,
        playSeconds: 30,
      );
      expect(second, isFalse);
      expect(stats.highScore, 120);
      expect(stats.gamesPlayed, 2);
      expect(stats.totalScore, 160);
    });

    test('data survives a controller restart', () async {
      final StorageManager storage = StorageManager.inMemory();
      final StatsController first = StatsController(storage);
      await first.registerRun(
        score: 500,
        combo: 7,
        linesCleared: 12,
        cellsPlaced: 40,
        perfectMoves: 2,
        playSeconds: 120,
      );

      // Simulates an app restart: new controllers, same storage.
      final StatsController second = StatsController(storage);
      expect(second.highScore, 500);
      expect(second.bestCombo, 7);
      expect(second.gamesPlayed, 1);
    });

    test('reset clears everything', () async {
      final StorageManager storage = StorageManager.inMemory();
      final StatsController stats = StatsController(storage);
      await stats.registerRun(
        score: 900,
        combo: 2,
        linesCleared: 4,
        cellsPlaced: 20,
        perfectMoves: 0,
        playSeconds: 10,
      );
      await stats.reset();

      expect(stats.highScore, 0);
      expect(stats.gamesPlayed, 0);
      expect(StatsController(storage).highScore, 0);
    });
  });

  group('SettingsController', () {
    test('defaults are sensible', () {
      final SettingsController settings = SettingsController(
        storage: StorageManager.inMemory(),
        audio: AudioManager(backend: SilentAudioBackend()),
        haptics: HapticsService(enabled: false),
      );
      expect(settings.soundEnabled, isTrue);
      expect(settings.musicEnabled, isTrue);
      expect(settings.vibrationEnabled, isTrue);
      expect(settings.boardSize, 8);
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.languageCode, 'en');
    });

    test('preferences persist across instances', () async {
      final StorageManager storage = StorageManager.inMemory();
      final SettingsController first = SettingsController(
        storage: storage,
        audio: AudioManager(backend: SilentAudioBackend()),
        haptics: HapticsService(enabled: false),
      );
      first.setBoardSize(9);
      first.setLanguageCode('tr');
      first.setThemeMode(ThemeMode.dark);
      first.setSoundEnabled(false);
      first.setVibrationEnabled(false);
      first.setShowGhost(false);

      final SettingsController second = SettingsController(
        storage: storage,
        audio: AudioManager(backend: SilentAudioBackend()),
        haptics: HapticsService(enabled: false),
      );
      expect(second.boardSize, 9);
      expect(second.languageCode, 'tr');
      expect(second.themeMode, ThemeMode.dark);
      expect(second.soundEnabled, isFalse);
      expect(second.vibrationEnabled, isFalse);
      expect(second.showGhost, isFalse);
    });

    test('unsupported board sizes are ignored', () {
      final SettingsController settings = SettingsController(
        storage: StorageManager.inMemory(),
        audio: AudioManager(backend: SilentAudioBackend()),
        haptics: HapticsService(enabled: false),
      );
      settings.setBoardSize(12);
      expect(settings.boardSize, 8);
    });
  });

  group('LeaderboardService', () {
    test('records are ranked, capped and persisted', () async {
      final StorageManager storage = StorageManager.inMemory();
      final LeaderboardService board = LeaderboardService(storage);

      for (int i = 0; i < LeaderboardService.maxEntries + 10; i++) {
        await board.add(
          ScoreRecord(
            score: i * 10,
            mode: GameMode.classic,
            combo: i,
            clearedLines: i,
            moves: i,
            dateKey: '2026-01-01',
          ),
        );
      }

      final List<ScoreRecord> top =
          board.top(GameMode.classic, limit: LeaderboardService.maxEntries);
      expect(top.length, LeaderboardService.maxEntries);
      expect(top.first.score, (LeaderboardService.maxEntries + 9) * 10);
      expect(board.top(GameMode.classic).length, 20,
          reason: 'the default view shows the top 20');
      expect(board.bestFor(GameMode.classic), top.first.score);

      // Persisted: a new instance on the same storage keeps the board.
      final LeaderboardService reloaded = LeaderboardService(storage);
      expect(reloaded.bestFor(GameMode.classic), top.first.score);
      expect(reloaded.isEmpty(GameMode.timeAttack), isTrue);
    });

    test('modes do not leak into each other', () async {
      final LeaderboardService board =
          LeaderboardService(StorageManager.inMemory());
      await board.add(
        ScoreRecord(
          score: 500,
          mode: GameMode.zen,
          combo: 1,
          clearedLines: 1,
          moves: 1,
          dateKey: '2026-01-01',
        ),
      );
      expect(board.bestFor(GameMode.zen), 500);
      expect(board.bestFor(GameMode.classic), 0);
    });

    test('records survive a JSON round trip', () {
      const ScoreRecord record = ScoreRecord(
        score: 1234,
        mode: GameMode.daily,
        combo: 4,
        clearedLines: 9,
        moves: 30,
        dateKey: '2026-02-03',
      );
      final List<ScoreRecord> restored =
          ScoreRecord.decodeList(ScoreRecord.encodeList(<ScoreRecord>[record]));
      expect(restored.length, 1);
      expect(restored.first.score, 1234);
      expect(restored.first.mode, GameMode.daily);
      expect(restored.first.combo, 4);
      expect(restored.first.dateKey, '2026-02-03');
    });
  });

  group('DailyService', () {
    test('the seed of a day is deterministic', () {
      final DailyService daily = DailyService(StorageManager.inMemory());
      final SeededRandom a = daily.generatorFor('2026-03-04');
      final SeededRandom b = daily.generatorFor('2026-03-04');
      expect(a.nextInt(1000), b.nextInt(1000));
    });

    test('only the best score of a day is kept', () async {
      final DailyService daily = DailyService(StorageManager.inMemory());
      await daily.submit(score: 100, stars: 1);
      await daily.submit(score: 50, stars: 0);

      expect(daily.todayBestScore, 100);
      expect(daily.todayStars, 1);
      expect(daily.isCompletedToday, isTrue);
    });

    test('results persist', () async {
      final StorageManager storage = StorageManager.inMemory();
      final DailyService first = DailyService(storage);
      await first.submit(score: 777, stars: 2);

      final DailyService second = DailyService(storage);
      expect(second.todayBestScore, 777);
      expect(second.streak, 1);
    });
  });

  group('Utilities', () {
    test('score formatting', () {
      expect(ScoreFormat.number(0), '0');
      expect(ScoreFormat.number(999), '999');
      expect(ScoreFormat.number(1000), '1,000');
      expect(ScoreFormat.number(1234567), '1,234,567');
      expect(ScoreFormat.compact(1500), '1.5K');
      expect(ScoreFormat.clock(65), '1:05');
      expect(ScoreFormat.ordinal(1), '1st');
      expect(ScoreFormat.ordinal(11), '11th');
      expect(ScoreFormat.ordinal(22), '22nd');
    });

    test('date keys', () {
      expect(DateKeys.key(DateTime(2026, 2, 3)), '2026-02-03');
      expect(DateKeys.shortLabel(DateTime(2026, 2, 3)), '03 Feb');
      expect(
        DateKeys.daysBetween('2026-02-03', '2026-02-06'),
        3,
      );
      expect(DateKeys.parseKey('2026-02-03').day, 3);
    });

    test('seeded random is stable and bounded', () {
      final SeededRandom a = SeededRandom.fromString('gridpop');
      final SeededRandom b = SeededRandom.fromString('gridpop');
      for (int i = 0; i < 50; i++) {
        expect(a.nextInt(97), b.nextInt(97));
      }
      final SeededRandom random = SeededRandom(1234);
      for (int i = 0; i < 200; i++) {
        final int value = random.nextInt(10);
        expect(value, inInclusiveRange(0, 9));
      }
    });

    test('responsive breakpoints', () {
      expect(Responsive.classify(const Size(360, 800)), ScreenClass.compact);
      expect(Responsive.classify(const Size(800, 600)), ScreenClass.medium);
      expect(Responsive.classify(const Size(1440, 900)), ScreenClass.expanded);
    });

    test('localization falls back to english', () {
      final AppStrings english = AppStrings.ofLanguage('en');
      final AppStrings turkish = AppStrings.ofLanguage('tr');
      expect(english.t('home.play'), 'Play');
      expect(turkish.t('home.play'), 'Oyna');
      expect(english.t('unknown.key'), 'unknown.key');
      expect(turkish.t('unknown.key'), 'unknown.key',
          reason: 'falls back to english then to the key itself');
    });
  });
}