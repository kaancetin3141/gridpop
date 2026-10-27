import 'package:flutter/material.dart';

import '../audio/audio_manager.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';
import '../core/constants/storage_keys.dart';
import '../game/services/haptics_service.dart';
import '../storage/storage_manager.dart';

/// Owns every user preference and mirrors it into storage.
///
/// Reads are synchronous (preferences are tiny), writes are fire-and-forget so
/// the UI never waits on disk.
class SettingsController extends ChangeNotifier {
  SettingsController({
    required StorageManager storage,
    required AudioManager audio,
    required HapticsService haptics,
  })  : _storage = storage,
        _audio = audio,
        _haptics = haptics {
    _load();
    _pushToServices();
  }

  final StorageManager _storage;
  final AudioManager _audio;
  final HapticsService _haptics;

  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _vibrationEnabled = true;
  bool _showGhost = true;
  bool _showHints = true;
  int _boardSize = BoardConfig.defaultSize;
  String _languageCode = 'en';
  ThemeMode _themeMode = ThemeMode.system;

  bool get soundEnabled => _soundEnabled;

  bool get musicEnabled => _musicEnabled;

  bool get vibrationEnabled => _vibrationEnabled;

  bool get showGhost => _showGhost;

  bool get showHints => _showHints;

  int get boardSize => _boardSize;

  String get languageCode => _languageCode;

  Locale get locale => Locale(_languageCode);

  ThemeMode get themeMode => _themeMode;

  bool get usesCustomBoardSize => _boardSize != BoardConfig.defaultSize;

  void _load() {
    _soundEnabled = _storage.getBool(StorageKeys.soundEnabled) ?? true;
    _musicEnabled = _storage.getBool(StorageKeys.musicEnabled) ?? true;
    _vibrationEnabled = _storage.getBool(StorageKeys.vibrationEnabled) ?? true;
    _showGhost = _storage.getBool(StorageKeys.showGhost) ?? true;
    _showHints = _storage.getBool(StorageKeys.showHints) ?? true;
    final int storedSize = _storage.getInt(StorageKeys.boardSize) ?? BoardConfig.defaultSize;
    _boardSize = BoardConfig.selectableSizes.contains(storedSize)
        ? storedSize
        : BoardConfig.defaultSize;
    _languageCode = _normaliseLanguage(
      _storage.getString(StorageKeys.languageCode),
    );
    final String? theme = _storage.getString(StorageKeys.themeMode);
    _themeMode = _themeModeFromStorage(theme);
  }

  void _pushToServices() {
    _haptics.setEnabled(_vibrationEnabled);
    _audio.applySettings(
      soundEnabled: _soundEnabled,
      musicEnabled: _musicEnabled,
    );
  }

  /// Language codes are whitelisted: a tampered value ("../x", an emoji, a 2 MB
  /// string) must never reach `Locale`.
  static String _normaliseLanguage(String? raw) {
    final String code = (raw ?? 'en').toLowerCase();
    return AppStrings.supportedLanguageCodes.contains(code) ? code : 'en';
  }

  static ThemeMode _themeModeFromStorage(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String themeModeToStorage(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  // --- setters -----------------------------------------------------------

  void setSoundEnabled(bool value) {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    _storage.setBool(StorageKeys.soundEnabled, value);
    _audio.applySettings(soundEnabled: _soundEnabled, musicEnabled: _musicEnabled);
    notifyListeners();
  }

  void setMusicEnabled(bool value) {
    if (_musicEnabled == value) return;
    _musicEnabled = value;
    _storage.setBool(StorageKeys.musicEnabled, value);
    _audio.applySettings(soundEnabled: _soundEnabled, musicEnabled: _musicEnabled);
    notifyListeners();
  }

  void setVibrationEnabled(bool value) {
    if (_vibrationEnabled == value) return;
    _vibrationEnabled = value;
    _storage.setBool(StorageKeys.vibrationEnabled, value);
    _haptics.setEnabled(value);
    notifyListeners();
  }

  void setShowGhost(bool value) {
    if (_showGhost == value) return;
    _showGhost = value;
    _storage.setBool(StorageKeys.showGhost, value);
    notifyListeners();
  }

  void setShowHints(bool value) {
    if (_showHints == value) return;
    _showHints = value;
    _storage.setBool(StorageKeys.showHints, value);
    notifyListeners();
  }

  void setBoardSize(int size) {
    if (!BoardConfig.selectableSizes.contains(size) || _boardSize == size) {
      return;
    }
    _boardSize = size;
    _storage.setInt(StorageKeys.boardSize, size);
    notifyListeners();
  }

  void setLanguageCode(String code) {
    final String normalized = code.toLowerCase();
    if (!AppStrings.supportedLanguageCodes.contains(normalized) ||
        _languageCode == normalized) {
      return;
    }
    _languageCode = normalized;
    _storage.setString(StorageKeys.languageCode, normalized);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _storage.setString(StorageKeys.themeMode, themeModeToStorage(mode));
    notifyListeners();
  }

  /// Restores every preference to its default.
  Future<void> resetToDefaults() async {
    _soundEnabled = true;
    _musicEnabled = true;
    _vibrationEnabled = true;
    _showGhost = true;
    _showHints = true;
    _boardSize = BoardConfig.defaultSize;
    _languageCode = 'en';
    _themeMode = ThemeMode.system;
    await Future.wait<void>(<Future<void>>[
      _storage.setBool(StorageKeys.soundEnabled, true),
      _storage.setBool(StorageKeys.musicEnabled, true),
      _storage.setBool(StorageKeys.vibrationEnabled, true),
      _storage.setBool(StorageKeys.showGhost, true),
      _storage.setBool(StorageKeys.showHints, true),
      _storage.setInt(StorageKeys.boardSize, BoardConfig.defaultSize),
      _storage.setString(StorageKeys.languageCode, 'en'),
      _storage.setString(StorageKeys.themeMode, themeModeToStorage(ThemeMode.system)),
    ]);
    _pushToServices();
    notifyListeners();
  }
}