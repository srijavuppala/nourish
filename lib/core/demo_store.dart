import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tiny JSON document store backed by shared_preferences, which on the web
/// is localStorage. Demo data survives a page reload, so a demo can be paused
/// and resumed, and "Reset demo" clears it.
class DemoStore {
  DemoStore._(this._prefs);

  static const _prefix = 'nourish_demo_';
  static DemoStore? _instance;

  final SharedPreferences _prefs;

  static Future<DemoStore> instance() async {
    return _instance ??= DemoStore._(await SharedPreferences.getInstance());
  }

  /// Drops the cached instance so a test can start from fresh mock values.
  @visibleForTesting
  static void resetCache() => _instance = null;

  Map<String, dynamic>? readDoc(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeDoc(String key, Map<String, dynamic> value) =>
      _prefs.setString('$_prefix$key', jsonEncode(value));

  /// A collection is stored as one document of id to value.
  Map<String, Map<String, dynamic>> readCollection(String key) {
    final raw = readDoc(key);
    if (raw == null) return {};
    return {
      for (final entry in raw.entries)
        if (entry.value is Map)
          entry.key: Map<String, dynamic>.from(entry.value as Map),
    };
  }

  Future<void> writeCollection(
    String key,
    Map<String, Map<String, dynamic>> value,
  ) =>
      writeDoc(key, value);

  Future<void> clear() async {
    for (final key in _prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      await _prefs.remove(key);
    }
  }
}
