import 'package:flutter/foundation.dart';

/// Every sound event of the game. The identifiers match the audio asset names
/// used by the future sound pack:
/// `block_pickup`, `block_place`, `line_clear`, `combo`, `button_click`,
/// `game_over`, `high_score`.
enum GameSound {
  blockPickup('block_pickup'),
  blockPlace('block_place'),
  lineClear('line_clear'),
  combo('combo'),
  buttonClick('button_click'),
  gameOver('game_over'),
  highScore('high_score'),
  perfect('perfect_move');

  const GameSound(this.assetName);

  /// File name (without extension) expected in the audio pack.
  final String assetName;
}

/// Pluggable audio engine.
///
/// GridPop V1 ships without audio assets, so the default backend only emits
/// lightweight system cues. Dropping in real sound files later means writing a
/// new backend (for example `audioplayers`) and registering it with
/// `AudioManager.installBackend` - no gameplay code changes.
abstract class AudioBackend {
  /// Human readable name, useful for debugging.
  String get name;

  /// Prepares resources. Safe to call more than once.
  Future<void> prepare();

  /// Plays a one-shot effect.
  Future<void> play(GameSound sound, {double volume = 1});

  /// Starts / stops the looping background track.
  Future<void> startMusic({double volume = 1});

  Future<void> stopMusic();

  Future<void> dispose();
}

/// Backend that plays nothing at all. Used by tests and when the user turned
/// the sound off.
class SilentAudioBackend implements AudioBackend {
  SilentAudioBackend();

  @override
  String get name => 'silent';

  /// Last sound requested - handy in tests.
  GameSound? lastPlayed;

  @override
  Future<void> prepare() async {}

  @override
  Future<void> play(GameSound sound, {double volume = 1}) async {
    lastPlayed = sound;
  }

  @override
  Future<void> startMusic({double volume = 1}) async {}

  @override
  Future<void> stopMusic() async {}

  @override
  Future<void> dispose() async {}
}

/// Single entry point for every sound in the game.
///
/// Keeps the flags in sync with the settings screen and makes sure gameplay
/// code never talks to a sound engine directly.
class AudioManager extends ChangeNotifier {
  AudioManager({AudioBackend? backend})
      : _backend = backend ?? SilentAudioBackend();

  AudioBackend _backend;
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _musicPlaying = false;
  bool _prepared = false;

  AudioBackend get backend => _backend;

  bool get soundEnabled => _soundEnabled;

  bool get musicEnabled => _musicEnabled;

  bool get musicPlaying => _musicPlaying;

  /// Replaces the active backend (for example when real assets are added).
  Future<void> installBackend(AudioBackend backend) async {
    await _backend.dispose();
    _backend = backend;
    _prepared = false;
    _musicPlaying = false;
    await prepare();
  }

  /// Loads audio resources. Call once during app start-up.
  Future<void> prepare() async {
    if (_prepared) {
      return;
    }
    _prepared = true;
    await _backend.prepare();
    if (_musicEnabled) {
      await _backend.startMusic();
      _musicPlaying = true;
    }
  }

  /// Applies the values coming from the settings controller.
  Future<void> applySettings({
    required bool soundEnabled,
    required bool musicEnabled,
  }) async {
    final bool soundChanged = soundEnabled != _soundEnabled;
    final bool musicChanged = musicEnabled != _musicEnabled;
    _soundEnabled = soundEnabled;
    _musicEnabled = musicEnabled;

    if (musicChanged) {
      if (musicEnabled) {
        await _backend.startMusic();
        _musicPlaying = true;
      } else {
        await _backend.stopMusic();
        _musicPlaying = false;
      }
    }
    if (soundChanged) {
      // Nothing to tear down: one-shot effects simply stop being requested and
      // the music keeps its own flag.
    }
    notifyListeners();
  }

  /// Plays [sound] when sound effects are enabled. Never throws.
  Future<void> play(GameSound sound, {double volume = 1}) async {
    if (!_soundEnabled) {
      return;
    }
    try {
      await _backend.play(sound, volume: volume.clamp(0.0, 1.0));
    } catch (error) {
      debugPrint('AudioManager: failed to play ${sound.assetName}: $error');
    }
  }

  @override
  void dispose() {
    _backend.dispose();
    super.dispose();
  }
}