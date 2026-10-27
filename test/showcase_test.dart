// Screenshot generator for the README gallery.
//
// The images in `docs/screenshots/` are rendered by the real widget tree at
// phone resolution, with the real bundled Roboto files loaded, so they are
// honest pictures of the app instead of mockups.
//
// Regenerate after a UI change:
//
//   $env:SHOWCASE = "1"
//   flutter test test/showcase_test.dart --update-goldens
//
// The test is skipped in a normal `flutter test` run: it only writes files and
// would fail on machines that do not track golden images.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridpop/audio/audio_manager.dart';
import 'package:gridpop/core/constants/storage_keys.dart';
import 'package:gridpop/core/theme/app_theme.dart';
import 'package:gridpop/core/theme/visual_style.dart';
import 'package:gridpop/core/utils/date_keys.dart';
import 'package:gridpop/core/utils/seeded_random.dart';
import 'package:gridpop/game/models/game_mode.dart';
import 'package:gridpop/game/models/placement_outcome.dart';
import 'package:gridpop/game/services/daily_service.dart';
import 'package:gridpop/game/services/game_controller.dart';
import 'package:gridpop/game/services/haptics_service.dart';
import 'package:gridpop/game/services/leaderboard_service.dart';
import 'package:gridpop/screens/achievements/achievements_screen.dart';
import 'package:gridpop/screens/daily/daily_screen.dart';
import 'package:gridpop/screens/game/game_screen.dart';
import 'package:gridpop/screens/home/home_screen.dart';
import 'package:gridpop/screens/settings/settings_screen.dart';
import 'package:gridpop/screens/shop/shop_screen.dart';
import 'package:gridpop/shop/ad_reward_service.dart';
import 'package:gridpop/state/achievements_controller.dart';
import 'package:gridpop/state/app_scope.dart';
import 'package:gridpop/state/inventory_controller.dart';
import 'package:gridpop/state/settings_controller.dart';
import 'package:gridpop/state/stats_controller.dart';
import 'package:gridpop/state/wallet_controller.dart';
import 'package:gridpop/storage/storage_manager.dart';

/// Screens the gallery covers.
const Set<String> _only = <String>{};

final bool _enabled = Platform.environment['SHOWCASE'] == '1';

/// Phone canvas of the generated shots (logical pixels).
const Size _phone = Size(430, 932);

/// Loads the shipped Roboto faces so the shots use the production font instead
/// of the box drawing test fallback.
Future<void> _loadFonts() async {
  final FontLoader loader = FontLoader('Roboto');
  for (final String file in <String>[
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]) {
    loader.addFont(rootBundle.load('assets/fonts/$file'));
  }
  await loader.load();

  // Material icons ship with the SDK; without them every glyph would render as
  // the empty box of the test font.
  for (final String family in <String>['MaterialIcons']) {
    final FontLoader icons = FontLoader(family);
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  }
}

/// Services backed by storage that already looks like an account someone has
/// been playing for a while: a high score, coins, a daily streak and a few
/// power-ups, so the screens are not empty.
Future<AppServices> _seededServices({
  int coins = 1240,
  int streakDays = 4,
  VisualStyle style = VisualStyle.aurora,
}) async {
  final StorageManager storage = StorageManager.inMemory();
  await storage.setString(StorageKeys.visualStyle, style.storageKey);
  await storage.setInt(StorageKeys.highScore, 18240);
  await storage.setInt(StorageKeys.totalScore, 146820);
  await storage.setInt(StorageKeys.gamesPlayed, 63);
  await storage.setInt(StorageKeys.bestCombo, 11);
  await storage.setInt(StorageKeys.totalLinesCleared, 318);
  await storage.setInt(StorageKeys.perfectMoves, 24);
  await storage.setInt(StorageKeys.totalCellsPlaced, 2840);
  await storage.setInt(StorageKeys.totalPlaySeconds, 12480);
  await storage.setInt(StorageKeys.coins, coins);
  await storage.setMap(StorageKeys.inventory, <String, dynamic>{
    'refreshTray': 2,
    'hammer': 3,
    'bomb': 1,
  });
  await storage.setMapList(StorageKeys.achievements, <Map<String, dynamic>>[
    <String, dynamic>{'id': 'firstSteps'},
    <String, dynamic>{'id': 'lineCook'},
    <String, dynamic>{'id': 'comboStarter'},
    <String, dynamic>{'id': 'firstSpark'},
    <String, dynamic>{'id': 'brickLayer'},
    <String, dynamic>{'id': 'dailyDevotion'},
  ]);

  final Map<String, dynamic> history = <String, dynamic>{};
  for (int i = streakDays; i >= 1; i--) {
    history[DateKeys.key(
      DateTime(DateTime.now().year, DateTime.now().month,
          DateTime.now().day - i),
    )] = <String, dynamic>{'score': 3120 + i * 240, 'stars': 2};
  }
  await storage.setString(StorageKeys.dailyRecord, jsonEncode(history));

  final AudioManager audio = AudioManager(backend: SilentAudioBackend());
  final HapticsService haptics = HapticsService(enabled: false);
  final AppServices services = AppServices(
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

  // Settle the badges the lifetime stats already qualify for, so every screen
  // shows the same count (the play screen would otherwise unlock them while
  // the shot is being taken) and no toast lands on a screenshot.
  await services.achievements
      .evaluate(statsAchievementSnapshot(services.stats));
  return services;
}

Widget _frame(
  AppServices services,
  Widget child, {
  VisualStyle style = VisualStyle.aurora,
}) {
  return AppScope(
    services: services,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(style: style),
      darkTheme: AppTheme.dark(style: style),
      themeMode: ThemeMode.dark,
      home: child,
    ),
  );
}

/// Gives the shot a phone sized canvas and returns once the entrance
/// animations have played.
Future<void> _prepare(
  WidgetTester tester,
  AppServices services,
  Widget child, {
  VisualStyle style = VisualStyle.aurora,
}) async {
  tester.view.physicalSize = _phone * 2;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_frame(services, child, style: style));
  // The board keeps a repaint loop alive, so `pumpAndSettle` would never
  // return; pumping past the entrance animations is enough.
  await tester.pump();
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 220));
  }
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../docs/screenshots/$name.png'),
  );
}

/// Builds the screen and writes its image.
///
/// `debugDisableShadows` is only unset for the duration of the capture: the
/// test binding asserts at the end of every test that the painting debug flags
/// are back to their defaults.
Future<void> _capture(
  WidgetTester tester,
  AppServices services,
  Widget child,
  String name, {
  Future<void> Function()? afterBuild,
  VisualStyle style = VisualStyle.aurora,
}) async {
  debugDisableShadows = false;
  await _prepare(tester, services, child, style: style);
  if (afterBuild != null) {
    // The play screen starts its own run in a post frame callback, so the
    // board has to be shaped after the first build.
    await afterBuild();
    await tester.pump();
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }
  await _shoot(tester, name);
  debugDisableShadows = true;
}

/// A board that looks like a real mid-run position: clusters spread over the
/// grid instead of the top-left corner an automated "first legal move" fills.
const List<List<int>> _openings = <List<int>>[
  <int>[4, 1],
  <int>[2, 3],
  <int>[5, 5],
  <int>[1, 5],
  <int>[6, 2],
  <int>[3, 6],
  <int>[0, 2],
  <int>[5, 0],
  <int>[2, 6],
  <int>[4, 4],
];

void main() {
  setUpAll(() async {
    if (!_enabled) {
      return;
    }
    await _loadFonts();
  });

  testWidgets('home', (WidgetTester tester) async {
    final AppServices services = await _seededServices();
    await _capture(tester, services, const HomeScreen(), 'home');
  }, skip: !_enabled || (_only.isNotEmpty && !_only.contains('home')));

  /// Shapes a mid-run board so every game shot shows real play, not an empty
  /// grid. Shared by the four style variants.
  Future<void> shootGame(
    WidgetTester tester,
    String name,
    VisualStyle style,
  ) async {
    final AppServices services = await _seededServices(style: style);
    final GameController controller = GameController(
      stats: services.stats,
      leaderboard: services.leaderboard,
      daily: services.daily,
      audio: services.audio,
      haptics: services.haptics,
      wallet: services.wallet,
    );
    addTearDown(controller.dispose);

    await _capture(
      tester,
      services,
      GameScreen(mode: GameMode.classic, controller: controller),
      name,
      style: style,
      afterBuild: () async {
        // Re-deal with a fixed seed so the gallery is reproducible, then fill
        // the board the way a player would: one piece at a time.
        await controller.start(mode: GameMode.classic, random: SeededRandom(17));
        for (final List<int> spot in _openings) {
          for (int slot = 0; slot < 3; slot++) {
            final PlacementOutcome? outcome =
                controller.placePiece(slot, spot[0], spot[1]);
            if (outcome != null) {
              controller.completePlacement();
              break;
            }
          }
        }
      },
    );
    controller.stopTimers();
  }

  testWidgets('game', (WidgetTester tester) async {
    await shootGame(tester, 'game', VisualStyle.aurora);
  }, skip: !_enabled || (_only.isNotEmpty && !_only.contains('game')));

  testWidgets('game-neon', (WidgetTester tester) async {
    await shootGame(tester, 'game-neon', VisualStyle.neon);
  }, skip: !_enabled || (_only.isNotEmpty && !_only.contains('game-neon')));

  testWidgets('game-matte', (WidgetTester tester) async {
    await shootGame(tester, 'game-matte', VisualStyle.matte);
  }, skip: !_enabled || (_only.isNotEmpty && !_only.contains('game-matte')));

  testWidgets('game-retro', (WidgetTester tester) async {
    await shootGame(tester, 'game-retro', VisualStyle.retro);
  }, skip: !_enabled || (_only.isNotEmpty && !_only.contains('game-retro')));

  testWidgets('settings', (WidgetTester tester) async {
    final AppServices services = await _seededServices(style: VisualStyle.neon);
    await _capture(
      tester,
      services,
      const SettingsScreen(),
      'settings',
      style: VisualStyle.neon,
      afterBuild: () async {
        // Bring the appearance block (theme + style picker) to the top of the
        // frame, so the shot reads as "this is the style section".
        await tester.scrollUntilVisible(
          find.text('Visual style'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -380),
        );
      },
    );
  }, skip: !_enabled || (_only.isNotEmpty && !_only.contains('settings')));

  testWidgets('daily', (WidgetTester tester) async {
    final AppServices services = await _seededServices(streakDays: 4);
    await _capture(tester, services, const DailyScreen(), 'daily');
  }, skip: !_enabled || (_only.isNotEmpty && !_only.contains('daily')));

  testWidgets('shop', (WidgetTester tester) async {
    final AppServices services = await _seededServices();
    await _capture(tester, services, const ShopScreen(), 'shop');
  }, skip: !_enabled || (_only.isNotEmpty && !_only.contains('shop')));

  testWidgets('achievements', (WidgetTester tester) async {
    final AppServices services = await _seededServices();
    await _capture(
        tester, services, const AchievementsScreen(), 'achievements');
  },
      skip: !_enabled ||
          (_only.isNotEmpty && !_only.contains('achievements')));
}
