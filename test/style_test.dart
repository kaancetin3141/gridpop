import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridpop/audio/audio_manager.dart';
import 'package:gridpop/core/constants/app_strings.dart';
import 'package:gridpop/core/constants/piece_catalog.dart';
import 'package:gridpop/core/constants/storage_keys.dart';
import 'package:gridpop/core/theme/app_colors.dart';
import 'package:gridpop/core/theme/app_theme.dart';
import 'package:gridpop/core/theme/piece_palette.dart';
import 'package:gridpop/core/theme/visual_style.dart';
import 'package:gridpop/core/utils/grid_geometry.dart';
import 'package:gridpop/game/models/board.dart';
import 'package:gridpop/game/models/piece_shape.dart';
import 'package:gridpop/game/models/piece_slot.dart';
import 'package:gridpop/game/services/daily_service.dart';
import 'package:gridpop/game/services/haptics_service.dart';
import 'package:gridpop/game/services/leaderboard_service.dart';
import 'package:gridpop/game/widgets/effects/effects_layer.dart';
import 'package:gridpop/game/widgets/painting/board_painter.dart';
import 'package:gridpop/game/widgets/painting/block_painter.dart';
import 'package:gridpop/game/widgets/painting/effects_painter.dart';
import 'package:gridpop/game/widgets/painting/piece_preview_painter.dart';
import 'package:gridpop/screens/settings/settings_screen.dart';
import 'package:gridpop/shop/ad_reward_service.dart';
import 'package:gridpop/state/achievements_controller.dart';
import 'package:gridpop/state/app_scope.dart';
import 'package:gridpop/state/inventory_controller.dart';
import 'package:gridpop/state/settings_controller.dart';
import 'package:gridpop/state/stats_controller.dart';
import 'package:gridpop/state/wallet_controller.dart';
import 'package:gridpop/storage/storage_manager.dart';
import 'package:gridpop/widgets/app_background.dart';
import 'package:gridpop/widgets/style_swatch.dart';

SettingsController buildSettings([StorageManager? storage]) {
  final StorageManager store = storage ?? StorageManager.inMemory();
  final AudioManager audio = AudioManager(backend: SilentAudioBackend());
  return SettingsController(
    storage: store,
    audio: audio,
    haptics: HapticsService(enabled: false),
  );
}

/// Paints every style aware painter once and returns the produced image.
ui.Image paintEverything(VisualStyle style) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final AppPalette palette = AppPalette.build(style, Brightness.dark);
  const BoardGeometry geometry = BoardGeometry(
    origin: Offset(8, 8),
    cellSize: 34,
    gap: 3,
    rows: 8,
    columns: 8,
  );

  final Board board = Board(8)
    ..setValue(0, 0, 1)
    ..setValue(0, 1, 3)
    ..setValue(1, 0, 5)
    ..setValue(4, 4, 7);
  final ValueNotifier<GhostPreview?> ghost = ValueNotifier<GhostPreview?>(null);

  BlockPainter.paint(
    canvas,
    const Rect.fromLTWH(4, 4, 32, 32),
    PiecePalette.coral,
    style: palette.blockStyle,
  );
  BlockPainter.paintCellSocket(
    canvas,
    const Rect.fromLTWH(40, 4, 32, 32),
    palette.cell,
    style: palette.blockStyle,
  );

  BoardPainter(
    board: board,
    geometry: geometry,
    palette: palette,
    cellColor: palette.cell,
    surfaceColor: palette.board,
    ghost: ghost,
    repaint: ChangeNotifier(),
    aiming: true,
  ).paint(canvas, const Size(300, 300));

  final GameEffects effects = GameEffects();
  EffectsPainter(
    effects: effects,
    geometry: geometry,
    blockStyle: palette.blockStyle,
    repaint: effects,
  ).paint(canvas, const Size(300, 300));

  PiecePreviewPainter(
    slot: PieceSlot(
      index: 0,
      shape: PieceShape.fromBlueprint(PieceCatalog.dot),
      colorIndex: 2,
      token: 1,
    ),
    maxCell: 30,
    blockStyle: palette.blockStyle,
  ).paint(canvas, const Size(120, 60));

  ghost.dispose();
  return recorder.endRecording().toImageSync(300, 300);
}

Widget wrap(Widget child, {VisualStyle style = VisualStyle.aurora}) {
  final StorageManager storage = StorageManager.inMemory();
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
  return AppScope(
    services: services,
    child: MaterialApp(
      theme: AppTheme.light(style: style),
      darkTheme: AppTheme.dark(style: style),
      home: child,
    ),
  );
}

void main() {
  group('VisualStyle', () {
    test('every style round trips through its storage key', () {
      for (final VisualStyle style in VisualStyle.values) {
        expect(VisualStyle.fromStorage(style.storageKey), style);
      }
    });

    test('an unknown or tampered value falls back to aurora', () {
      expect(VisualStyle.fromStorage(null), VisualStyle.aurora);
      expect(VisualStyle.fromStorage(''), VisualStyle.aurora);
      expect(VisualStyle.fromStorage('../neon'), VisualStyle.aurora);
      expect(VisualStyle.fromStorage('AURORA'), VisualStyle.aurora);
    });

    test('every style has an English and a Turkish label and hint', () {
      for (final VisualStyle style in VisualStyle.values) {
        for (final String code in <String>['en', 'tr']) {
          final AppStrings strings = AppStrings.ofLanguage(code);
          expect(
            strings.t(style.labelKey),
            isNot(style.labelKey),
            reason: '${style.name} needs a $code label',
          );
          expect(
            strings.t(style.hintKey),
            isNot(style.hintKey),
            reason: '${style.name} needs a $code hint',
          );
        }
      }
    });

    test('each style picks its own block material', () {
      expect(VisualStyle.aurora.block, BlockStyle.soft);
      expect(VisualStyle.neon.block, BlockStyle.neon);
      expect(VisualStyle.matte.block, BlockStyle.matte);
      expect(VisualStyle.retro.block, BlockStyle.retro);
    });

    test('every style has a distinct accent in both brightnesses', () {
      for (final VisualStyle style in VisualStyle.values) {
        final VisualStyleSpec spec = VisualStyleSpec.of(style);
        expect(spec.dark.accent, isNot(spec.light.accent), reason: '$style');
        expect(spec.dark.gradient, hasLength(3), reason: '$style dark');
        expect(spec.light.gradient, hasLength(3), reason: '$style light');
      }
      final Set<Color> accents = <Color>{
        for (final VisualStyle style in VisualStyle.values)
          VisualStyleSpec.of(style).dark.accent,
      };
      expect(accents, hasLength(VisualStyle.values.length));
    });

    test('only the neon style asks for a grid floor', () {
      bool floor(VisualStyle style) =>
          AppPalette.build(style, Brightness.dark).gridFloor;
      expect(floor(VisualStyle.neon), isTrue);
      expect(floor(VisualStyle.aurora), isFalse);
      expect(floor(VisualStyle.matte), isFalse);
      expect(floor(VisualStyle.retro), isFalse);
    });

    test('retro is the only scanline stage and matte the only flat one', () {
      bool scan(VisualStyle style) =>
          AppPalette.build(style, Brightness.dark).scanlines;
      bool blooms(VisualStyle style) =>
          AppPalette.build(style, Brightness.dark).blooms;
      expect(scan(VisualStyle.retro), isTrue);
      expect(scan(VisualStyle.aurora), isFalse);
      expect(blooms(VisualStyle.matte), isFalse);
      expect(blooms(VisualStyle.aurora), isTrue);
    });
  });

  group('SettingsController visual style', () {
    test('defaults to the aurora style', () {
      expect(buildSettings().visualStyle, VisualStyle.aurora);
    });

    test('loads a stored style', () {
      final StorageManager storage = StorageManager.inMemory();
      storage.setString(StorageKeys.visualStyle, 'retro');
      expect(buildSettings(storage).visualStyle, VisualStyle.retro);
    });

    test('a tampered stored value falls back to aurora', () {
      final StorageManager storage = StorageManager.inMemory();
      storage.setString(StorageKeys.visualStyle, 'not-a-style');
      expect(buildSettings(storage).visualStyle, VisualStyle.aurora);
    });

    test('choosing a style persists it and notifies listeners', () {
      final StorageManager storage = StorageManager.inMemory();
      final SettingsController settings = buildSettings(storage);
      int notifications = 0;
      settings.addListener(() => notifications++);

      settings.setVisualStyle(VisualStyle.neon);

      expect(settings.visualStyle, VisualStyle.neon);
      expect(storage.getString(StorageKeys.visualStyle), 'neon');
      expect(notifications, 1);

      // Re-selecting the same style is a no-op.
      settings.setVisualStyle(VisualStyle.neon);
      expect(notifications, 1);
    });

    test('resetToDefaults restores the aurora style', () async {
      final StorageManager storage = StorageManager.inMemory();
      final SettingsController settings = buildSettings(storage);
      settings.setVisualStyle(VisualStyle.retro);

      await settings.resetToDefaults();

      expect(settings.visualStyle, VisualStyle.aurora);
      expect(storage.getString(StorageKeys.visualStyle), 'aurora');
    });
  });

  group('theme wiring', () {
    test('the active style is registered on the theme', () {
      for (final VisualStyle style in VisualStyle.values) {
        final ThemeData theme = AppTheme.dark(style: style);
        final AppPalette? palette = theme.extension<GridPopTheme>()?.palette;
        expect(palette, isNotNull, reason: '$style');
        expect(palette!.style, style);
        expect(palette.blockStyle, style.block);
        expect(theme.scaffoldBackgroundColor, palette.background);
      }
    });

    test('light and dark palettes of one style are different', () {
      for (final VisualStyle style in VisualStyle.values) {
        final AppPalette light = AppTheme.light(style: style)
            .extension<GridPopTheme>()!
            .palette;
        final AppPalette dark = AppTheme.dark(style: style)
            .extension<GridPopTheme>()!
            .palette;
        expect(light.isDark, isFalse);
        expect(dark.isDark, isTrue);
        expect(light.background, isNot(dark.background), reason: '$style');
      }
    });

    test('the theme extension swaps instantly instead of blending', () {
      final GridPopTheme aurora = GridPopTheme(
        palette: AppPalette.build(VisualStyle.aurora, Brightness.dark),
      );
      final GridPopTheme neon = GridPopTheme(
        palette: AppPalette.build(VisualStyle.neon, Brightness.dark),
      );
      expect(aurora.lerp(neon, 0.2).palette.style, VisualStyle.aurora);
      expect(aurora.lerp(neon, 0.8).palette.style, VisualStyle.neon);
    });
  });

  group('painters', () {
    for (final VisualStyle style in VisualStyle.values) {
      test('every painter draws the $style style without throwing', () {
        final ui.Image image = paintEverything(style);
        expect(image.width, 300);
        image.dispose();
      });
    }

    test('block corners follow the material', () {
      final double soft = BlockPainter.radiusFor(100, style: BlockStyle.soft);
      final double neon = BlockPainter.radiusFor(100, style: BlockStyle.neon);
      final double matte = BlockPainter.radiusFor(100, style: BlockStyle.matte);
      final double retro = BlockPainter.radiusFor(100, style: BlockStyle.retro);
      // The neon tube is the roundest, the pixel block the squarest.
      expect(neon, greaterThan(soft));
      expect(soft, greaterThan(matte));
      expect(matte, greaterThan(retro));
      expect(<double>{soft, neon, matte, retro}, hasLength(4));
    });
  });

  group('widgets', () {
    testWidgets('settings screen offers all four styles', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Visual style'), findsOneWidget);
      expect(find.byType(StyleSwatch), findsNWidgets(4));
      for (final VisualStyle style in VisualStyle.values) {
        expect(
          find.text(style.name[0].toUpperCase() + style.name.substring(1)),
          findsOneWidget,
        );
      }
    });

    testWidgets('tapping a style tile updates the controller', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      final AppScope scope = tester.widget<AppScope>(find.byType(AppScope));
      expect(scope.services.settings.visualStyle, VisualStyle.aurora);

      await tester.tap(find.text('Retro'));
      await tester.pumpAndSettle();

      expect(scope.services.settings.visualStyle, VisualStyle.retro);
      expect(
        scope.services.storage.getString(StorageKeys.visualStyle),
        'retro',
      );
      expect(tester.takeException(), isNull);
    });

    for (final VisualStyle style in VisualStyle.values) {
      testWidgets('the stage paints the $style decoration', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            const AppScaffold(child: Center(child: Text('stage'))),
            style: style,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('stage'), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('switching style keeps the screen mounted and settles', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(const AppScaffold(child: Center(child: Text('stage')))),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        wrap(
          const AppScaffold(child: Center(child: Text('stage'))),
          style: VisualStyle.neon,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('stage'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
