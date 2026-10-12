import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small local key-value storage for the shell (drive cache, pending drive
/// operations, undo stacks, per-device settings). Values are JSON.
///
/// Suite 12 §3 describes this store as `shell_<userId>.db`; the shell keeps it
/// in platform key-value storage (`shared_preferences`: localStorage on web,
/// a JSON file on desktop) scoped per user — the data is small (≤ 500 cached
/// items) and needs no queries.
abstract class LocalStore {
  Future<Object?> read(String key);

  Future<void> write(String key, Object? value);

  Future<void> remove(String key);

  /// Keys starting with [prefix].
  Future<List<String>> keys(String prefix);

  /// A view whose keys are prefixed with [prefix].
  LocalStore scoped(String prefix) => _ScopedStore(this, prefix);
}

class _ScopedStore extends LocalStore {
  _ScopedStore(this._inner, this._prefix);

  final LocalStore _inner;
  final String _prefix;

  @override
  Future<Object?> read(String key) => _inner.read('$_prefix$key');

  @override
  Future<void> write(String key, Object? value) => _inner.write('$_prefix$key', value);

  @override
  Future<void> remove(String key) => _inner.remove('$_prefix$key');

  @override
  Future<List<String>> keys(String prefix) async => [
    for (final k in await _inner.keys('$_prefix$prefix')) k.substring(_prefix.length),
  ];
}

/// [LocalStore] on `shared_preferences`.
class SharedPreferencesStore extends LocalStore {
  SharedPreferencesStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;
  static const _root = 'wonky.';

  @override
  Future<Object?> read(String key) async {
    final raw = await _prefs.getString('$_root$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, Object? value) =>
      _prefs.setString('$_root$key', jsonEncode(value));

  @override
  Future<void> remove(String key) => _prefs.remove('$_root$key');

  @override
  Future<List<String>> keys(String prefix) async {
    final all = await _prefs.getKeys();
    return [
      for (final k in all)
        if (k.startsWith('$_root$prefix')) k.substring(_root.length),
    ];
  }
}

/// In-memory [LocalStore] (tests, fallback when storage is unavailable).
class MemoryStore extends LocalStore {
  final Map<String, String> values = {};

  @override
  Future<Object?> read(String key) async {
    final v = values[key];
    return v == null ? null : jsonDecode(v);
  }

  @override
  Future<void> write(String key, Object? value) async => values[key] = jsonEncode(value);

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<List<String>> keys(String prefix) async =>
      [for (final k in values.keys) if (k.startsWith(prefix)) k];
}
