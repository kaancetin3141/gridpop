import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridpop/app.dart';
import 'package:gridpop/audio/audio_manager.dart';
import 'package:gridpop/core/constants/app_constants.dart';
import 'package:gridpop/core/theme/app_theme.dart';
import 'package:gridpop/core/utils/grid_geometry.dart';
import 'package:gridpop/game/achievements/achievement_engine.dart';
import 'package:gridpop/game/models/game_mode.dart';
import 'package:gridpop/game/models/grid_position.dart';
import 'package:gridpop/game/models/piece_slot.dart';import 'package:gridpop/game/models/placement_outcome.dart';
import 'package:gridpop/game/services/daily_service.dart';
import 'package:gridpop/game/services/game_controller.dart';
import 'package:gridpop/game/services/haptics_service.dart';
import 'package:gridpop/game/services/leaderboard_service.dart';
import 'package:gridpop/game/widgets/effects/effects_layer.dart';
import 'package:gridpop/game/widgets/game_board_view.dart';
import 'package:gridpop/game/widgets/piece_tray.dart';
import 'package:gridpop/screens/achievements/achievements_screen.dart';
import 'package:gridpop/screens/daily/daily_screen.dart';
import 'package:gridpop/screens/game/game_screen.dart';
import 'package:gridpop/screens/how_to_play/how_to_play_screen.dart';
import 'package:gridpop/screens/leaderboard/leaderboard_screen.dart';
import 'package:gridpop/screens/settings/settings_screen.dart';
import 'package:gridpop/screens/shop/shop_screen.dart';
import 'package:gridpop/shop/ad_reward_service.dart';
import 'package:gridpop/shop/shop_item.dart';
import 'package:gridpop/state/achievements_controller.dart';
import 'package:gridpop/state/app_scope.dart';
import 'package:gridpop/state/inventory_controller.dart';
import 'package:gridpop/state/settings_controller.dart';
import 'package:gridpop/state/stats_controller.dart';
import 'package:gridpop/state/wallet_controller.dart';
import 'package:gridpop/storage/storage_manager.dart';

import 'support.dart';

AppServices buildServices() {
  final StorageManager storage = StorageManager.inMemory();
  final AudioManager audio = AudioManager(backend: SilentAudioBackend());
  final HapticsService haptics = HapticsService(enabled: false);
  return AppServices(
    storage: storage,
    audio: audio,
    haptics: haptics,
    settings: SettingsController(
      storage: storage,
      audio: audio,
      haptics: haptics,
    ),
    stats: StatsController(storage),
    leaderboard: LeaderboardService(storage),
    daily: DailyService(storage),
    wallet: WalletController(storage),
    inventory: InventoryController(storage),
    ads: const AdRewardService(),
    achievements: AchievementsController(storage),
  );
}

Widget wrapWithApp(AppServices services, Widget child) {
  return AppScope(
    services: services,
    child: MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: child,
    ),
  );
}

/// Sizes that must all work: phone portrait, phone landscape, tablet, desktop.
const List<Size> testSizes = <Size>[
  Size(360, 640),
  Size(640, 360),
  Size(768, 1024),
  Size(1024, 768),
  Size(1440, 900),
];

void main() {
  testWidgets('home screen renders on every target size',
      (WidgetTester tester) async {
    final AppServices services = buildServices();
    for (final Size size in testSizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(GridPopApp(services: services));
      await tester.pumpAndSettle();

      expect(find.text('GridPop'), findsOneWidget, reason: 'failed at $size');
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Achievements'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'failed at $size');
    }
  });

  testWidgets('settings screen renders and toggles a switch',
      (WidgetTester tester) async {
    final AppServices services = buildServices();
    await tester.pumpWidget(wrapWithApp(services, const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sound effects'), findsOneWidget);

    await tester.tap(find.text('Sound effects'));
    await tester.pumpAndSettle();
    expect(services.settings.soundEnabled, isFalse);
  });

  testWidgets('how to play shows the shape gallery',
      (WidgetTester tester) async {
    final AppServices services = buildServices();
    await tester.pumpWidget(wrapWithApp(services, const HowToPlayScreen()));
    await tester.pumpAndSettle();

    expect(find.text('How To Play'), findsOneWidget);
    expect(find.text('Scoring'.toUpperCase()), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('daily screen shows the seven day streak ladder',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final AppServices services = buildServices();
    await tester.pumpWidget(wrapWithApp(services, const DailyScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Streak rewards'), findsOneWidget);
    expect(find.text('Bonus +10'), findsOneWidget,
        reason: 'an empty streak offers the first step today');
    expect(
      find.text('Play on consecutive days to climb the ladder.'),
      findsOneWidget,
    );
    expect(find.text('1'), findsOneWidget, reason: 'the ladder has day 1');
    expect(find.text('7'), findsOneWidget, reason: 'and day 7');
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaderboard renders its empty state',
      (WidgetTester tester) async {
    final AppServices services = buildServices();
    await tester.pumpWidget(wrapWithApp(services, const LeaderboardScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('No scores yet. Be the first!'), findsOneWidget);
  });

  testWidgets('game screen builds the board and the tray',
      (WidgetTester tester) async {
    final AppServices services = buildServices();
    await tester.pumpWidget(
      wrapWithApp(services, const GameScreen(mode: GameMode.classic)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GameBoardView), findsOneWidget);
    expect(find.text('Score'), findsOneWidget);
    expect(find.textContaining('Best'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('game screen survives small and large viewports',
      (WidgetTester tester) async {
    final AppServices services = buildServices();
    for (final Size size in testSizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrapWithApp(services, const GameScreen(mode: GameMode.classic)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GameBoardView), findsOneWidget, reason: 'size $size');
      expect(tester.takeException(), isNull, reason: 'size $size');
    }
  });

  testWidgets('a stuck board ends the run through the real UI flow',
      (WidgetTester tester) async {
    final AppServices services = buildServices();
    final GameController controller = GameController(
      stats: services.stats,
      leaderboard: services.leaderboard,
      daily: services.daily,
      audio: services.audio,
      haptics: services.haptics,
      wallet: services.wallet,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrapWithApp(
        services,
        GameScreen(mode: GameMode.classic, controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    // Deterministic run: the seeded tray holds exactly one single cell piece
    // plus two large ones, so the lattice below can only take the dot.
    await controller.start(mode: GameMode.classic, random: seedForPocket());
    fillPocketLattice(controller.board);
    await tester.pump(const Duration(milliseconds: 60));

    // Play the dot. The two large pieces left in the tray cannot fit anywhere
    // any more, so the settle path must offer the second chance.
    final PlacementOutcome? outcome = controller.playHint();
    expect(outcome, isNotNull, reason: 'the dot must be playable');
    controller.completePlacement();

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(controller.phase.name, 'revive',
        reason: 'a stuck board offers the second chance first');
    expect(find.text('One more chance?'), findsOneWidget,
        reason: 'the revive sheet must be visible');

    // Refuse it: only now does the run end and the game over sheet appear.
    await tester.tap(find.text('Give up'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(controller.phase.name, 'finished',
        reason: 'declining the second chance ends the run');
    expect(find.text('Game Over'), findsOneWidget,
        reason: 'the game over dialog must be visible');
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepting the revive wipes rows and keeps the run alive',
      (WidgetTester tester) async {
    final AppServices services = buildServices();
    await services.wallet.add(500);
    final GameController controller = GameController(
      stats: services.stats,
      leaderboard: services.leaderboard,
      daily: services.daily,
      audio: services.audio,
      haptics: services.haptics,
      wallet: services.wallet,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrapWithApp(
        services,
        GameScreen(mode: GameMode.classic, controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await controller.start(mode: GameMode.classic, random: seedForPocket());
    fillPocketLattice(controller.board);
    await tester.pump(const Duration(milliseconds: 60));

    controller.playHint();
    controller.completePlacement();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.text('One more chance?'), findsOneWidget);
    await tester.tap(find.textContaining('Revive \u00b7 '));
    await tester.pumpAndSettle();

    expect(controller.phase.name, 'playing',
        reason: 'a revived run keeps going');
    expect(controller.board.filledCount, lessThan(64),
        reason: 'the wiped rows must leave room to play');
    expect(controller.trayIsDead, isFalse,
        reason: 'the fresh tray must fit');
    expect(services.wallet.coins, 350);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pause sheet recaps the run and holds it',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final AppServices services = buildServices();
    final GameController controller = GameController(
      stats: services.stats,
      leaderboard: services.leaderboard,
      daily: services.daily,
      audio: services.audio,
      haptics: services.haptics,
      wallet: services.wallet,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrapWithApp(
        services,
        GameScreen(mode: GameMode.classic, controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await controller.start(mode: GameMode.classic, random: seedForPocket());
    await tester.pump(const Duration(milliseconds: 60));

    await tester.tap(find.byTooltip('Pause'));
    await tester.pumpAndSettle();

    expect(controller.phase.name, 'paused',
        reason: 'the sheet must hold the run');
    expect(find.text('Paused'), findsOneWidget);
    // The sheet repeats the three numbers that tell a player where they are.
    // The HUD shows a score too, so the labels are matched inside the dialog.
    Finder inSheet(String text) => find.descendant(
          of: find.byType(Dialog),
          matching: find.text(text),
        );
    expect(inSheet('Score'), findsOneWidget);
    expect(inSheet('Time'), findsOneWidget);
    expect(inSheet('Combo'), findsOneWidget);
    expect(inSheet('x${controller.bestCombo}'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(controller.phase.name, 'playing',
        reason: 'resume must hand control back');
  });

  testWidgets('dragging a tray piece onto the board places it',
      (WidgetTester tester) async {
    // Portrait phone: the tray sits under the board, which is the layout this
    // test aims at. Other viewports are covered by the render sweep.
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final AppServices services = buildServices();
    final GameController controller = GameController(
      stats: services.stats,
      leaderboard: services.leaderboard,
      daily: services.daily,
      audio: services.audio,
      haptics: services.haptics,
      wallet: services.wallet,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrapWithApp(
        services,
        GameScreen(mode: GameMode.classic, controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.state.phase.name, 'playing');
    expect(controller.state.tray.length, 3);

    final Rect trayRect = tester.getRect(find.byType(PieceTray));
    final GameBoardViewState boardState =
        tester.state(find.byType(GameBoardView));

    // Aim at a cell the engine itself suggests, so the test never depends on
    // the current layout.
    final PlacementHint? hint = controller.hint();
    expect(hint, isNotNull);
    // The hint may require another orientation: turn the piece first, exactly
    // like the hint button does.
    for (int r = 0; r < hint!.rotation; r++) {
      controller.rotateSlot(hint.slotIndex);
    }
    final GridExtent extent =
        controller.slotAt(hint.slotIndex)!.extent;
    // The pointer has to point at the middle of the piece, because the drop
    // anchor is derived from the pointer by centring the shape.
    final int centerRow = hint.topRow + extent.height ~/ 2;
    final int centerCol = hint.leftCol + extent.width ~/ 2;
    final Offset cellLocal =
        boardState.geometry.cellCenter(centerRow, centerCol);
    final Rect boardRect = boardState.boardRect!;
    final Offset boardPoint = boardRect.topLeft + cellLocal;

    // The tray slot of the hinted piece: three equal columns inside the dock.
    final double inner = trayRect.width - 20;
    final double slotWidth = (inner - 20) / 3;
    final Offset trayPoint = Offset(
      trayRect.left + 10 + hint.slotIndex * slotWidth + slotWidth / 2,
      trayRect.center.dy,
    );

    final TestGesture gesture = await tester.startGesture(trayPoint);
    await tester.pump(const Duration(milliseconds: 30));
    await gesture.moveTo(boardPoint);
    await tester.pump(const Duration(milliseconds: 30));
    await gesture.up();

    // The settle window keeps the tray locked until the board view reports
    // that the placement animation is over.
    expect(controller.inputLocked, isTrue);
    expect(controller.board.filledCount, greaterThan(0),
        reason: 'the dragged piece must land on the board');

    // Drive the animation frames until the board view closes the gate.
    for (int i = 0; i < 12 && controller.inputLocked; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(controller.inputLocked, isFalse,
        reason: 'the next piece arrives after the animation');
    expect(controller.state.moves, 1);
    expect(controller.state.score, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('power bar uses a stocked item and spends it',
      (WidgetTester tester) async {
    final AppServices services = buildServices();
    await services.inventory.add(ShopItemId.refreshTray);
    final GameController controller = GameController(
      stats: services.stats,
      leaderboard: services.leaderboard,
      daily: services.daily,
      audio: services.audio,
      haptics: services.haptics,
      wallet: services.wallet,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrapWithApp(
        services,
        GameScreen(mode: GameMode.classic, controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fresh'), findsOneWidget);
    final List<PieceSlot?> trayBefore = controller.state.tray;
    await tester.tap(find.text('Fresh'));
    await tester.pump();

    expect(services.inventory.countOf(ShopItemId.refreshTray), 0);
    expect(identical(controller.state.tray, trayBefore), isFalse,
        reason: 'the tray must be replaced through the UI');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the hammer arms, then smashes the tapped block',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final AppServices services = buildServices();
    await services.inventory.add(ShopItemId.hammer);
    final GameController controller = GameController(
      stats: services.stats,
      leaderboard: services.leaderboard,
      daily: services.daily,
      audio: services.audio,
      haptics: services.haptics,
      wallet: services.wallet,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrapWithApp(
        services,
        GameScreen(mode: GameMode.classic, controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    controller.board.setValue(2, 3, 4);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.gavel_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Tap a block to smash it'), findsOneWidget);

    final GameBoardViewState boardState =
        tester.state(find.byType(GameBoardView));
    final Offset cell = boardState
            .boardRect!
            .topLeft +
        boardState.geometry.cellCenter(2, 3);
    await tester.tapAt(cell);
    await tester.pumpAndSettle();

    expect(controller.board.valueAt(2, 3), 0,
        reason: 'the tapped block must be gone');
    expect(services.inventory.countOf(ShopItemId.hammer), 0,
        reason: 'the tool is spent');
    expect(find.text('Tap a block to smash it'), findsNothing,
        reason: 'aim mode ends after the hit');
    expect(tester.takeException(), isNull);
  });

  testWidgets('shop buys a power-up and the ad grants coins',
      (WidgetTester tester) async {
    final AppServices services = buildServices();
    await services.wallet.add(200);

    await tester.pumpWidget(wrapWithApp(services, const ShopScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Shop'), findsOneWidget);

    // The first card sells fresh blocks.
    await tester.tap(find.text('Buy').first);
    await tester.pumpAndSettle();
    expect(services.inventory.countOf(ShopItemId.refreshTray), 1);
    expect(services.wallet.coins, 200 - ShopConfig.refreshTrayPrice);

    // Out of the flow: the simulated rewarded ad tops the wallet up.
    await tester.ensureVisible(find.text('Watch ad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch ad'));
    await tester.pump();
    expect(find.text('Sponsored break'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.tap(find.textContaining('Claim reward'));
    await tester.pumpAndSettle();

    expect(
      services.wallet.coins,
      200 - ShopConfig.refreshTrayPrice + CoinConfig.adReward,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('achievements screen shows locked and unlocked badges',
      (WidgetTester tester) async {
    final AppServices services = buildServices();
    await services.achievements.evaluate(
      const AchievementSnapshot(
        gamesPlayed: 5,
        totalLinesCleared: 120,
        runScore: 1500,
      ),
    );

    await tester.pumpWidget(
      wrapWithApp(services, const AchievementsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('First Steps'), findsOneWidget);
    expect(find.text('Rising Star'), findsOneWidget);
    expect(find.text('Grid Legend'), findsOneWidget);
    expect(
      find.text(
        '${services.achievements.unlockedCount}/${services.achievements.totalCount}',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  group('BoardGeometry', () {
    const BoardGeometry geometry = BoardGeometry(
      origin: Offset(10, 20),
      cellSize: 40,
      gap: 4,
      rows: 3,
      columns: 3,
    );

    test('cellRect insets by half the gap', () {
      final Rect rect = geometry.cellRect(1, 1);
      expect(rect.left, 10 + 40 + 2);
      expect(rect.top, 20 + 40 + 2);
      expect(rect.width, 36);
      expect(rect.height, 36);
    });

    test('cellAt resolves the cell under a point', () {
      expect(geometry.cellAt(const Offset(15, 25)), (0, 0));
      expect(geometry.cellAt(const Offset(55, 65)), (1, 1));
      expect(geometry.cellAt(const Offset(5, 25)), isNull);
      expect(geometry.cellAt(const Offset(200, 25)), isNull);
    });

    test('grid metrics', () {
      expect(geometry.gridWidth, 120);
      expect(geometry.gridHeight, 120);
      expect(geometry.center, const Offset(70, 80));
      expect(geometry.gridOrigin, const Offset(130, 140));
    });

    test('boundsOf covers every cell', () {
      final Rect bounds = geometry.boundsOf(const <(int, int)>[(0, 0), (2, 2)]);
      expect(bounds.left, 12);
      expect(bounds.top, 22);
      expect(bounds.right, 128);
      expect(bounds.bottom, 138);
    });

    test('fit keeps the board square and centred', () {
      final BoardGeometry fitted = BoardGeometry.fit(
        available: const Size(300, 200),
        rows: 8,
        columns: 8,
        gapFactor: 0.05,
      );
      expect(fitted.gridWidth, fitted.gridHeight);
      expect(fitted.gridWidth, lessThanOrEqualTo(200));
      expect(fitted.origin.dx, greaterThanOrEqualTo(0));
    });

    test('anchorOf reads the row from the top edge', () {
      expect(
        geometry.anchorOf(const Rect.fromLTWH(10, 20 + 40, 40, 40)),
        (1, 0),
      );
      expect(
        geometry.anchorOf(const Rect.fromLTWH(10 + 80, 20, 40, 40)),
        (0, 2),
      );
    });
  });

  group('GameEffects', () {
    test('an empty hint does not start an animation', () {
      final GameEffects effects = GameEffects();
      expect(effects.isActive, isFalse);

      effects.onHint(const <GridPosition>[], 0);
      expect(effects.isActive, isFalse, reason: 'empty hints are ignored');
    });

    test('a hint pulses the suggested cells and then retires', () {
      final GameEffects effects = GameEffects();
      effects.onHint(const <GridPosition>[GridPosition(1, 1)], 2);
      expect(effects.isActive, isTrue);
      expect(effects.hint, isNotNull);

      bool active = true;
      Duration now = Duration.zero;
      while (active) {
        now += const Duration(milliseconds: 100);
        active = effects.tick(now);
      }
      expect(effects.hint, isNull);
    });

    test('reset clears everything', () {
      final GameEffects effects = GameEffects();
      effects.onNewRecord();
      expect(effects.flash, 1);
      effects.reset();
      expect(effects.flash, 0);
      expect(effects.isActive, isFalse);
    });

    test('the flash decays while ticking', () {
      final GameEffects effects = GameEffects();
      effects.onNewRecord();
      final bool active = effects.tick(const Duration(milliseconds: 16));
      expect(effects.flash, lessThan(1));
      expect(active, isTrue);
    });

    test('a rejected drop pulses its cells without gating input', () {
      final GameEffects effects = GameEffects();
      effects.onInvalidDrop(const <GridPosition>[
        GridPosition(2, 3),
        GridPosition(2, 4),
      ]);

      expect(effects.invalid, isNotNull);
      expect(effects.isActive, isTrue);
      expect(
        effects.isSettling,
        isFalse,
        reason: 'an invalid drop must never hold the tray back',
      );

      effects.tick(const Duration(milliseconds: 400));
      expect(effects.invalid, isNull);
    });

    test('an empty rejection is ignored', () {
      final GameEffects effects = GameEffects();
      effects.onInvalidDrop(const <GridPosition>[]);
      expect(effects.invalid, isNull);
      expect(effects.isActive, isFalse);
    });

    test('landing a piece kicks up dust motes', () {
      final GameEffects effects = GameEffects();
      effects.onPlaced(
        PlacementOutcome(
          placedCells: const <GridPosition>[
            GridPosition(4, 4),
            GridPosition(4, 5),
          ],
          colorIndex: 3,
          clearedRows: const <int>[],
          clearedColumns: const <int>[],
          clearedCells: const <TintedCell>[],
          cellsCleared: 0,
          score: const ScoreBreakdown(
            cellScore: 2,
            lineScore: 0,
            multiBonus: 0,
            perfectBonus: 0,
            comboBonus: 0,
            comboMultiplier: 1,
          ),
          comboLevel: 0,
          comboMultiplier: 1,
          isPerfect: false,
          isCleanSweep: false,
          remainingTime: null,
        ),
      );

      final Iterable<Particle> dust =
          effects.particles.where((Particle p) => p.soft);
      expect(dust.length, 6, reason: 'three motes per placed cell');
      expect(effects.placed.length, 2);
    });
  });
}