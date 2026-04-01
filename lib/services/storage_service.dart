import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _favoritesKey = 'favorite_paths';
  static const _lastOpenedPathKey = 'last_opened_path';
  static const _cachedSummaryKey = 'cached_summary';
  static const _darkModeKey = 'pref_dark_mode';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<Set<String>> getFavorites() async {
    await init();
    return (_prefs!.getStringList(_favoritesKey) ?? <String>[]).toSet();
  }

  Future<void> setFavorite(String path, bool value) async {
    final favorites = await getFavorites();
    if (value) {
      favorites.add(path);
    } else {
      favorites.remove(path);
    }
    await _prefs!.setStringList(_favoritesKey, favorites.toList()..sort());
  }

  Future<String?> getLastOpenedPath() async {
    await init();
    return _prefs!.getString(_lastOpenedPathKey);
  }

  Future<void> setLastOpenedPath(String path) async {
    await init();
    await _prefs!.setString(_lastOpenedPathKey, path);
  }

  Future<void> clearLastOpenedPath() async {
    await init();
    await _prefs!.remove(_lastOpenedPathKey);
  }

  Future<Map<String, String>> getCachedSummaries() async {
    await init();
    final raw = _prefs!.getString(_cachedSummaryKey);
    if (raw == null || raw.isEmpty) {
      return <String, String>{};
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value as String));
  }

  Future<void> cacheSummary(String path, String summary) async {
    final cache = await getCachedSummaries();
    cache[path] = summary;
    await _prefs!.setString(_cachedSummaryKey, jsonEncode(cache));
  }

  Future<bool> getDarkModeEnabled() async {
    await init();
    return _prefs!.getBool(_darkModeKey) ?? true;
  }

  Future<void> setDarkModeEnabled(bool value) async {
    await init();
    await _prefs!.setBool(_darkModeKey, value);
  }
}
