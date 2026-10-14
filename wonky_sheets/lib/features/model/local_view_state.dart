import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart' show LocalStore;

/// A temporary filter view kept with the view state (07 §4.1: local to this
/// device and user).
@immutable
class SavedTemporaryView {
  const SavedTemporaryView({
    required this.sheetId,
    required this.name,
    required this.rangeJson,
    required this.criteriaJson,
    this.active = false,
  });

  final String sheetId;
  final String name;

  /// `GridRange.toJson()`.
  final Object? rangeJson;

  /// `FilterCriteria.toJson()`.
  final Object? criteriaJson;

  /// Whether it was the sheet's active view.
  final bool active;

  Map<String, Object?> toJson() => {
    'sheet': sheetId,
    'name': name,
    'range': rangeJson,
    'criteria': criteriaJson,
    if (active) 'active': true,
  };

  static SavedTemporaryView? fromJson(Object? j) {
    if (j is! Map) return null;
    final sheet = j['sheet'];
    final name = j['name'];
    if (sheet is! String || name is! String) return null;
    return SavedTemporaryView(
      sheetId: sheet,
      name: name,
      rangeJson: j['range'],
      criteriaJson: j['criteria'],
      active: j['active'] == true,
    );
  }
}

/// Where the user left a spreadsheet on this device (Sheets 02 §4
/// `LocalViewState`): active sheet, selection per sheet, scroll, zoom, the
/// open side panel and the temporary filter views. Restored on open; its
/// sheet and top row also drive viewport-first loading.
@immutable
class LocalViewState {
  const LocalViewState({
    required this.savedAt,
    this.activeSheetId,
    this.selections = const {},
    this.scrollX = 0,
    this.scrollY = 0,
    this.topRow = 0,
    this.zoom = 1,
    this.panelId,
    this.temporaryViews = const [],
    this.showProtectedRanges = true,
  });

  final DateTime savedAt;
  final String? activeSheetId;

  /// `GridSelection.toJson()` by sheet id.
  final Map<String, Object?> selections;

  /// Scroll offsets of the active sheet (screen px at [zoom]).
  final double scrollX;
  final double scrollY;

  /// First row shown (viewport-first loading).
  final int topRow;
  final double zoom;

  /// The open side panel.
  final String? panelId;
  final List<SavedTemporaryView> temporaryViews;

  /// View › Show › Protected ranges (03 §16, per user).
  final bool showProtectedRanges;

  Map<String, Object?> toJson() => {
    'at': savedAt.toUtc().toIso8601String(),
    'sheet': ?activeSheetId,
    if (selections.isNotEmpty) 'sel': selections,
    'x': scrollX,
    'y': scrollY,
    'top': topRow,
    'zoom': zoom,
    'panel': ?panelId,
    if (temporaryViews.isNotEmpty)
      'temp': [for (final v in temporaryViews) v.toJson()],
    if (!showProtectedRanges) 'prot': false,
  };

  static LocalViewState? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = DateTime.tryParse('${j['at']}');
    if (at == null) return null;
    double d(String k, double fallback) =>
        (j[k] is num) ? (j[k] as num).toDouble() : fallback;
    final sel = j['sel'];
    final temp = j['temp'];
    return LocalViewState(
      savedAt: at,
      activeSheetId: j['sheet'] as String?,
      selections: sel is Map ? sel.cast<String, Object?>() : const {},
      scrollX: d('x', 0),
      scrollY: d('y', 0),
      topRow: (j['top'] as num?)?.toInt() ?? 0,
      zoom: d('zoom', 1).clamp(0.5, 2.0),
      panelId: j['panel'] as String?,
      temporaryViews: temp is List
          ? [for (final t in temp) ?SavedTemporaryView.fromJson(t)]
          : const [],
      showProtectedRanges: j['prot'] != false,
    );
  }
}

/// The view states of the signed-in user on this device, in the user's
/// local key-value store (`sheets.view.<spreadsheetId>`; small JSON; the
/// oldest beyond [maxEntries] are dropped). Reads are cached so the editor
/// restores synchronously what `openWorkbookSession` read.
class LocalViewStateStore {
  LocalViewStateStore(this.store);

  final LocalStore store;

  static const prefix = 'sheets.view.';

  /// Spreadsheets remembered per user and device.
  static const maxEntries = 200;

  static final Expando<Map<String, LocalViewState?>> _caches = Expando();

  Map<String, LocalViewState?> get _cache =>
      _caches[store] ??= <String, LocalViewState?>{};

  /// The cached state of [spreadsheetId] (after [read] or [write]).
  LocalViewState? cached(String spreadsheetId) => _cache[spreadsheetId];

  Future<LocalViewState?> read(String spreadsheetId) async {
    if (_cache.containsKey(spreadsheetId)) return _cache[spreadsheetId];
    try {
      final v = LocalViewState.fromJson(
        await store.read('$prefix$spreadsheetId'),
      );
      return _cache[spreadsheetId] = v;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String spreadsheetId, LocalViewState state) async {
    _cache[spreadsheetId] = state;
    try {
      await store.write('$prefix$spreadsheetId', state.toJson());
      if (++_writes % 20 == 1) unawaited(_prune());
    } catch (_) {}
  }

  int _writes = 0;

  Future<void> _prune() async {
    final keys = await store.keys(prefix);
    if (keys.length <= maxEntries) return;
    final dated = <(String, DateTime)>[];
    for (final k in keys) {
      final v = await store.read(k);
      final at = v is Map ? DateTime.tryParse('${v['at']}') : null;
      dated.add((k, at ?? DateTime.fromMillisecondsSinceEpoch(0)));
    }
    dated.sort((a, b) => b.$2.compareTo(a.$2));
    for (final (k, _) in dated.skip(maxEntries)) {
      await store.remove(k);
      _cache.remove(k.substring(prefix.length));
    }
  }

  /// When each spreadsheet was last left on this device (the IndexedDB
  /// cell cap evicts the oldest first).
  Future<Map<String, DateTime>> lastOpened() async {
    final out = <String, DateTime>{};
    for (final k in await store.keys(prefix)) {
      final v = await store.read(k);
      final at = v is Map ? DateTime.tryParse('${v['at']}') : null;
      if (at != null) out[k.substring(prefix.length)] = at;
    }
    return out;
  }
}
