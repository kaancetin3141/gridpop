import 'package:flutter/services.dart';

import '../audio_manager.dart';

/// Zero dependency backend built on the platform system sounds.
///
/// It gives GridPop instant tactile feedback out of the box (and disappears
/// completely on the web, where [SystemSound] is a no-op). Replace it with a
/// real asset based backend when the sound pack is produced.
class SystemSoundAudioBackend implements AudioBackend {
  SystemSoundAudioBackend({this.usePlatformTones = true});

  /// Set to `false` for tests so nothing is played.
  final bool usePlatformTones;

  @override
  String get name => 'system-sound';

  @override
  Future<void> prepare() async {}

  @override
  Future<void> play(GameSound sound, {double volume = 1}) async {
    if (!usePlatformTones) {
      return;
    }
    final SystemSoundType type;
    switch (sound) {
      case GameSound.lineClear:
      case GameSound.combo:
      case GameSound.highScore:
      case GameSound.perfect:
      case GameSound.gameOver:
        type = SystemSoundType.alert;
      case GameSound.blockPickup:
      case GameSound.blockPlace:
      case GameSound.buttonClick:
        type = SystemSoundType.click;
    }
    await SystemSound.play(type);
  }

  @override
  Future<void> startMusic({double volume = 1}) async {}

  @override
  Future<void> stopMusic() async {}

  @override
  Future<void> dispose() async {}
}