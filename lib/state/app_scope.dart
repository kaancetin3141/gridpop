import 'package:flutter/widgets.dart';

import '../audio/audio_manager.dart';
import '../game/services/daily_service.dart';
import '../game/services/haptics_service.dart';
import '../game/services/leaderboard_service.dart';
import '../shop/ad_reward_service.dart';
import '../storage/storage_manager.dart';
import 'achievements_controller.dart';
import 'inventory_controller.dart';
import 'settings_controller.dart';
import 'stats_controller.dart';
import 'wallet_controller.dart';

/// Composition root of the application.
///
/// Everything is created once in `main()` and injected through [AppScope], so
/// the widget tree stays free of singletons and every screen is trivially
/// testable with fakes.
class AppServices {
  AppServices({
    required this.storage,
    required this.audio,
    required this.haptics,
    required this.settings,
    required this.stats,
    required this.leaderboard,
    required this.daily,
    required this.wallet,
    required this.inventory,
    required this.ads,
    required this.achievements,
  });

  final StorageManager storage;
  final AudioManager audio;
  final HapticsService haptics;
  final SettingsController settings;
  final StatsController stats;
  final LeaderboardService leaderboard;
  final DailyService daily;
  final WalletController wallet;
  final InventoryController inventory;
  final AdRewardService ads;
  final AchievementsController achievements;

  void dispose() {
    settings.dispose();
    stats.dispose();
    leaderboard.dispose();
    daily.dispose();
    wallet.dispose();
    inventory.dispose();
    achievements.dispose();
    audio.dispose();
    haptics.enabled = false;
  }
}

/// Provides [AppServices] to the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.services,
    required super.child,
  });

  final AppServices services;

  static AppServices of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing from the widget tree');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.services != services;
}