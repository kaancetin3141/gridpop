import 'package:flutter_test/flutter_test.dart';
import 'package:gridpop/game/achievements/achievement.dart';
import 'package:gridpop/game/achievements/achievement_catalog.dart';
import 'package:gridpop/game/achievements/achievement_engine.dart';
import 'package:gridpop/game/models/game_mode.dart';
import 'package:gridpop/state/achievements_controller.dart';
import 'package:gridpop/state/stats_controller.dart';
import 'package:gridpop/storage/storage_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Achievement catalog', () {
    test('ids are unique and every target is positive', () {
      final Set<String> ids = <String>{};
      for (final Achievement achievement in AchievementCatalog.all) {
        expect(ids.add(achievement.id), isTrue,
            reason: 'duplicate ${achievement.id}');
        expect(achievement.target, greaterThan(0));
        expect(achievement.titleKey, 'achievement.${achievement.id}.title');
        expect(
          achievement.descriptionKey,
          'achievement.${achievement.id}.desc',
        );
        expect(AchievementCatalog.byId(achievement.id), achievement);
      }
      expect(AchievementCatalog.byId('no-such-badge'), isNull);
      expect(AchievementCatalog.all.length, 22);
    });

    test('tiers cover bronze, silver and gold', () {
      expect(AchievementCatalog.ofTier(AchievementTier.bronze), isNotEmpty);
      expect(AchievementCatalog.ofTier(AchievementTier.silver), isNotEmpty);
      expect(AchievementCatalog.ofTier(AchievementTier.gold), isNotEmpty);
      expect(
        AchievementCatalog.ofTier(AchievementTier.bronze).length +
            AchievementCatalog.ofTier(AchievementTier.silver).length +
            AchievementCatalog.ofTier(AchievementTier.gold).length,
        AchievementCatalog.all.length,
      );
    });
  });

  group('Achievement engine', () {
    test('an empty snapshot earns and shows nothing', () {
      const AchievementSnapshot snapshot = AchievementSnapshot();
      final List<AchievementStatus> rows = AchievementEngine.statuses(
        snapshot,
        const <String>{},
      );
      expect(rows, hasLength(AchievementCatalog.all.length));
      expect(AchievementEngine.newlyUnlocked(snapshot, const <String>{}),
          isEmpty);
      for (final AchievementStatus row in rows) {
        expect(row.unlocked, isFalse);
        expect(row.progress, 0);
        expect(row.ratio, 0);
      }
    });

    test('cumulative metrics unlock at their thresholds', () {
      const AchievementSnapshot snapshot = AchievementSnapshot(
        gamesPlayed: 10,
        totalLinesCleared: 100,
        perfectMoves: 1,
        totalCellsPlaced: 1000,
        bestCombo: 8,
        highScore: 1500,
        totalPlaySeconds: 600,
      );
      final Set<String> fresh = AchievementEngine.newlyUnlocked(
        snapshot,
        const <String>{},
      ).map((Achievement a) => a.id).toSet();

      expect(
        fresh,
        containsAll(<String>{
          'firstSteps',
          'regular',
          'lineCook',
          'carpenter',
          'comboStarter',
          'comboMaster',
          'firstSpark',
          'brickLayer',
          'steady',
        }),
      );
      expect(fresh, isNot(contains('veteran')));
      expect(fresh, isNot(contains('risingStar')));
    });

    test('run metrics only count inside a run', () {
      const AchievementSnapshot run = AchievementSnapshot(
        runScore: 2600,
        runCombo: 10,
        runPerfectMoves: 2,
        runMode: GameMode.classic,
      );
      final Set<String> fresh = AchievementEngine.newlyUnlocked(
        run,
        const <String>{},
      ).map((Achievement a) => a.id).toSet();
      expect(
        fresh,
        containsAll(<String>{'risingStar', 'highRoller', 'comboFrenzy'}),
      );
      expect(fresh, isNot(contains('gridLegend')));
      expect(fresh, isNot(contains('blitz')));
    });

    test('mode locked badges need their own mode', () {
      const AchievementSnapshot wrongMode = AchievementSnapshot(
        runScore: 5000,
        runMode: GameMode.classic,
        runDailyCompleted: true,
        runDailyStars: 3,
      );
      final Set<String> fresh = AchievementEngine.newlyUnlocked(
        wrongMode,
        const <String>{},
      ).map((Achievement a) => a.id).toSet();
      expect(fresh, contains('dailyDevotion'));
      expect(fresh, contains('starCollector'));
      expect(fresh, isNot(contains('blitz')));
      expect(fresh, contains('risingStar'));
      expect(fresh, contains('highRoller'));
      expect(fresh, contains('gridLegend'));

      const AchievementSnapshot blitz = AchievementSnapshot(
        runScore: 1600,
        runMode: GameMode.timeAttack,
      );
      expect(
        AchievementEngine.newlyUnlocked(blitz, const <String>{})
            .map((Achievement a) => a.id),
        contains('blitz'),
      );
    });

    test('known badges are never reported twice', () {
      const AchievementSnapshot snapshot = AchievementSnapshot(
        gamesPlayed: 60,
        totalLinesCleared: 600,
      );
      final Set<String> known = <String>{'firstSteps', 'regular', 'veteran'};
      final List<Achievement> fresh =
          AchievementEngine.newlyUnlocked(snapshot, known);
      expect(fresh.map((Achievement a) => a.id), isNot(contains('firstSteps')));
      expect(fresh.map((Achievement a) => a.id), isNot(contains('veteran')));
      expect(
        fresh.map((Achievement a) => a.id),
        containsAll(<String>{'lineCook', 'carpenter', 'architect'}),
      );
    });

    test('progress is clamped to the target', () {
      const AchievementSnapshot snapshot = AchievementSnapshot(gamesPlayed: 4);
      final AchievementStatus firstSteps =
          AchievementEngine.statuses(snapshot, const <String>{}).firstWhere(
        (AchievementStatus row) => row.achievement.id == 'firstSteps',
      );
      expect(firstSteps.unlocked, isTrue);
      expect(firstSteps.progress, 1);
      expect(firstSteps.ratio, 1);

      final AchievementStatus regular =
          AchievementEngine.statuses(snapshot, const <String>{}).firstWhere(
        (AchievementStatus row) => row.achievement.id == 'regular',
      );
      expect(regular.unlocked, isFalse);
      expect(regular.progress, 4);
      expect(regular.ratio, closeTo(0.4, 0.0001));
    });
  });

  group('Achievements controller', () {
    (StorageManager, AchievementsController) _setup() {
      final StorageManager storage = StorageManager.inMemory();
      return (storage, AchievementsController(storage));
    }

    test('evaluate returns fresh badges once and persists them', () async {
      final (StorageManager storage, AchievementsController first) = _setup();
      const AchievementSnapshot snapshot =
          AchievementSnapshot(gamesPlayed: 1, runScore: 1200);

      final List<Achievement> fresh = await first.evaluate(snapshot);
      expect(
        fresh.map((Achievement a) => a.id),
        containsAll(<String>{'firstSteps', 'risingStar'}),
      );
      expect(first.unlockedCount, 2);

      expect(await first.evaluate(snapshot), isEmpty,
          reason: 'the same snapshot earns nothing twice');

      final AchievementsController second = AchievementsController(storage);
      expect(second.unlockedCount, 2);
      expect(second.isUnlocked('firstSteps'), isTrue);
    });

    test('syncFromStats catches up silently earned badges', () async {
      final StorageManager storage = StorageManager.inMemory();
      final StatsController stats = StatsController(storage);
      await stats.registerRun(
        score: 3000,
        combo: 9,
        linesCleared: 40,
        cellsPlaced: 500,
        perfectMoves: 2,
        playSeconds: 120,
      );

      final AchievementsController achievements =
          AchievementsController(storage);
      await achievements.syncFromStats(stats);
      expect(achievements.isUnlocked('firstSteps'), isTrue);
      expect(achievements.isUnlocked('comboMaster'), isTrue);
      expect(achievements.isUnlocked('firstSpark'), isTrue);

      final List<AchievementStatus> rows =
          achievements.statusesFromStats(stats);
      expect(rows, hasLength(AchievementCatalog.all.length));
    });

    test('reset clears every badge', () async {
      final (StorageManager storage, AchievementsController controller) =
          _setup();
      await controller.evaluate(const AchievementSnapshot(gamesPlayed: 1));
      expect(controller.unlockedCount, greaterThan(0));
      await controller.reset();
      expect(controller.unlockedCount, 0);
      expect(AchievementsController(storage).unlockedCount, 0);
    });
  });
}
