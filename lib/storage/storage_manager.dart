import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/safe_numbers.dart';

/// Thin persistence layer on top of `shared_preferences`.
///
/// Works on Android, iOS, Windows, macOS, Linux and Web. If the platform
/// channel is unavailable (for example in a unit test or an exotic embedder)
/// the manager transparently falls back to an in-memory map so the game keeps
/// running instead of crashing.
class StorageManager {
  StorageManager._(this._prefs, this.usingBackend);

  final SharedPreferences? _prefs;
  final bool usingBackend;

  final Map<String, Object> _memory = <String, Object>{};

  /// Boots the storage layer. Never throws.
  static Future<StorageManager> create() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return StorageManager._(prefs, true);
    } catch (_) {
      return StorageManager._(null, false);
    }
  }

  /// In-memory instance, handy for tests and previews.
  factory StorageManager.inMemory() => StorageManager._(null, false);

  // --- reads -------------------------------------------------------------

  int? getInt(String key) => jsonInt(_read(key));

  double? getDouble(String key) {
    final Object? raw = _read(key);
    if (raw is double) {
      return raw.isFinite ? raw : null;
    }
    if (raw is int) {
      return raw.toDouble();
    }
    return null;
  }

  String? getString(String key) {
    final Object? raw = _read(key);
    return raw is String ? raw : null;
  }

  bool? getBool(String key) {
    final Object? raw = _read(key);
    return raw is bool ? raw : null;
  }

  /// Reads a stored map, or `null` when missing / corrupted.
  Map<String, dynamic>? getMap(String key) {
    final String? raw = getString(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Reads a stored list of maps, skipping malformed entries.
  List<Map<String, dynamic>> getMapList(String key) {
    final String? raw = getString(key);
    if (raw == null || raw.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <Map<String, dynamic>>[];
      }
      final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
      for (final Object? entry in decoded) {
        if (entry is Map<String, dynamic>) {
          result.add(entry);
        }
      }
      return result;
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Object? _read(String key) {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) {
      return _memory[key];
    }
    final Object? value = prefs.get(key);
    return value ?? _memory[key];
  }

  // --- writes ------------------------------------------------------------

  Future<void> setInt(String key, int value) async {
    _memory[key] = value;
    await _prefs?.setInt(key, value);
  }

  Future<void> setDouble(String key, double value) async {
    _memory[key] = value;
    await _prefs?.setDouble(key, value);
  }

  Future<void> setString(String key, String value) async {
    _memory[key] = value;
    await _prefs?.setString(key, value);
  }

  Future<void> setBool(String key, bool value) async {
    _memory[key] = value;
    await _prefs?.setBool(key, value);
  }

  Future<void> setMap(String key, Map<String, dynamic> value) =>
      setString(key, jsonEncode(value));

  Future<void> setMapList(String key, List<Map<String, dynamic>> value) =>
      setString(key, jsonEncode(value));

  Future<void> remove(String key) async {
    _memory.remove(key);
    await _prefs?.remove(key);
  }

  /// Removes every key starting with the GridPop prefix.
  Future<void> clearAppData(String prefix) async {
    _memory.removeWhere((String key, Object _) => key.startsWith(prefix));
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final List<String> keys = prefs
        .getKeys()
        .where((String key) => key.startsWith(prefix))
        .toList(growable: false);
    for (final String key in keys) {
      await prefs.remove(key);
    }
  }
}