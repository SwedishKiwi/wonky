import 'dart:collection';

import '../values/fvalue.dart';

/// Caches for lookups and criteria functions (05 §11.2). Entries are validated by a stamp
/// built from per-column generation counters (bumped on any content or computed-value change
/// in that column) and a per-sheet structure counter.
final class LookupCache {
  final int capacity;
  final LinkedHashMap<String, (String, Object)> _entries = LinkedHashMap();
  final Map<String, int> _uses = {};
  final Map<String, Map<int, int>> _colGen = {};
  final Map<String, int> _sheetGen = {};
  final Map<String, int> _sheetTotal = {};

  LookupCache({this.capacity = 128});

  void bumpColumn(String sheetId, int col) {
    final m = _colGen[sheetId] ??= {};
    m[col] = (m[col] ?? 0) + 1;
    _sheetTotal[sheetId] = (_sheetTotal[sheetId] ?? 0) + 1;
  }

  void bumpColumns(String sheetId, int left, int right) {
    if (right - left > 256) {
      bumpSheet(sheetId);
      return;
    }
    for (var c = left; c <= right; c++) {
      bumpColumn(sheetId, c);
    }
  }

  /// Structural change: invalidates everything on the sheet.
  void bumpSheet(String sheetId) {
    _sheetGen[sheetId] = (_sheetGen[sheetId] ?? 0) + 1;
    _sheetTotal[sheetId] = (_sheetTotal[sheetId] ?? 0) + 1;
  }

  void bumpAll() {
    for (final k in [..._sheetGen.keys, ..._colGen.keys]) {
      bumpSheet(k);
    }
    _entries.clear();
  }

  /// Validity stamp of an area.
  String stampOf(ResolvedArea a) {
    final s = _sheetGen[a.sheetId] ?? 0;
    if (a.right - a.left > 256) return '$s:t${_sheetTotal[a.sheetId] ?? 0}';
    final m = _colGen[a.sheetId];
    var sum = 0;
    if (m != null) {
      for (var c = a.left; c <= a.right; c++) {
        sum += m[c] ?? 0;
      }
    }
    return '$s:$sum';
  }

  /// Cached value for [key] if the [stamp] matches.
  T? get<T extends Object>(String key, String stamp) {
    final e = _entries.remove(key);
    if (e == null) return null;
    if (e.$1 != stamp) return null;
    _entries[key] = e;
    return e.$2 is T ? e.$2 as T : null;
  }

  void put(String key, String stamp, Object value) {
    _entries.remove(key);
    if (_entries.length >= capacity) _entries.remove(_entries.keys.first);
    _entries[key] = (stamp, value);
  }

  /// Counts uses of [key] (indexes are built on the second use).
  int use(String key) {
    final n = (_uses[key] ?? 0) + 1;
    if (_uses.length > 10000) _uses.clear();
    _uses[key] = n;
    return n;
  }
}
