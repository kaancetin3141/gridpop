import 'package:flutter/material.dart';

import 'app.dart';
import 'audio/audio_manager.dart';
import 'audio/backends/system_sound_backend.dart';
import 'game/services/daily_service.dart';
import 'game/services/haptics_service.dart';
import 'game/services/leaderboard_service.dart';
import 'shop/ad_reward_service.dart';
import 'state/achievements_controller.dart';
import 'state/app_scope.dart';
import 'state/inventory_controller.dart';
import 'state/settings_controller.dart';
import 'state/stats_controller.dart';
import 'state/wallet_controller.dart';
import 'storage/storage_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Composition root: build the services once, inject them everywhere.
  final StorageManager storage = await StorageManager.create();
  final AudioManager audio = AudioManager(backend: SystemSoundAudioBackend());
  final HapticsService haptics = HapticsService();
  final SettingsController settings = SettingsController(
    storage: storage,
    audio: audio,
    haptics: haptics,
  );
  final StatsController stats = StatsController(storage);
  final LeaderboardService leaderboard = LeaderboardService(storage);
  final DailyService daily = DailyService(storage);
  final WalletController wallet = WalletController(storage);
  final InventoryController inventory = InventoryController(storage);
  const AdRewardService ads = AdRewardService();
  final AchievementsController achievements = AchievementsController(storage);
  await achievements.syncFromStats(stats);

  await audio.prepare();

  runApp(
    GridPopApp(
      services: AppServices(
        storage: storage,
        audio: audio,
        haptics: haptics,
        settings: settings,
        stats: stats,
        leaderboard: leaderboard,
        daily: daily,
        wallet: wallet,
        inventory: inventory,
        ads: ads,
        achievements: achievements,
      ),
    ),
  );
}