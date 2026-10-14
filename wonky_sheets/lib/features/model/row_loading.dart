import 'dart:async';

import 'package:flutter/foundation.dart';

/// Which rows of an open spreadsheet are in memory while it streams in
/// after `WorkbookReady` (viewport-first loading, Sheets 02 §6, 03 §2.8).
///
/// The session loads the sheet metadata and the first visible window of the
/// active sheet, turns ready, then streams the remaining rows' cells in
/// chunks. The grid paints a shimmer over rows that are not loaded yet
/// (`LoadingLayer`) and asks for the rows it shows first ([prioritize]).
/// Rows that did not exist when loading started (inserted since) count as
/// loaded.
abstract class WorkbookRowLoading implements Listenable {
  /// Whether every row's cells are in memory.
  bool get complete;

  /// Loaded share of the rows, 0..1 (1 when [complete]).
  double get progress;

  /// Whether the cells of row [rowId] of [sheetId] are in memory.
  bool isRowLoaded(String sheetId, String rowId);

  /// Whether every row of [sheetId] is in memory.
  bool isSheetLoaded(String sheetId);

  /// Loads the rows [firstRow]..[lastRow] (indexes) of [sheetId] next.
  void prioritize(String sheetId, int firstRow, int lastRow);

  /// Completes when [complete] turns true.
  Future<void> get whenComplete;

  /// A spreadsheet that is fully in memory (memory sessions).
  static const WorkbookRowLoading loaded = _Loaded();
}

class _Loaded implements WorkbookRowLoading {
  const _Loaded();

  @override
  bool get complete => true;

  @override
  double get progress => 1;

  @override
  bool isRowLoaded(String sheetId, String rowId) => true;

  @override
  bool isSheetLoaded(String sheetId) => true;

  @override
  void prioritize(String sheetId, int firstRow, int lastRow) {}

  @override
  Future<void> get whenComplete => Future.value();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// The mutable [WorkbookRowLoading] a streaming session keeps: per sheet the
/// ids of rows whose cells are still missing.
class RowLoadTracker extends ChangeNotifier implements WorkbookRowLoading {
  final Map<String, Set<String>> _missing = {};
  int _total = 0;
  int _remaining = 0;
  bool _complete = false;
  bool _disposed = false;

  /// Requests from the grid, newest last (sheet, first, last).
  final List<(String, int, int)> _requests = [];
  void Function()? _onRequest;

  final Completer<void> _done = Completer<void>();

  /// Starts tracking [sheetId] with the rows [rowIds] missing.
  void track(String sheetId, Iterable<String> rowIds) {
    final set = _missing.putIfAbsent(sheetId, () => <String>{});
    for (final id in rowIds) {
      if (set.add(id)) {
        _total++;
        _remaining++;
      }
    }
  }

  /// Marks [rowIds] of [sheetId] as loaded.
  void markLoaded(String sheetId, Iterable<String> rowIds) {
    final set = _missing[sheetId];
    if (set == null) return;
    for (final id in rowIds) {
      if (set.remove(id)) _remaining--;
    }
    if (set.isEmpty) _missing.remove(sheetId);
  }

  /// Missing row ids of [sheetId] (a copy).
  Set<String> missingOf(String sheetId) => {...?_missing[sheetId]};

  /// Sheets with missing rows.
  Iterable<String> get pendingSheets => _missing.keys;

  /// Marks everything loaded (end of streaming or a full reload).
  void finish() {
    if (_complete) return;
    _complete = true;
    _missing.clear();
    _remaining = 0;
    _requests.clear();
    if (!_done.isCompleted) _done.complete();
    changed();
  }

  /// Notifies listeners (after a chunk).
  void changed() {
    if (!_disposed) notifyListeners();
  }

  /// Called by the streamer to learn about [prioritize] requests.
  set onRequest(void Function()? f) => _onRequest = f;

  /// Takes the newest pending request, or null.
  (String, int, int)? takeRequest() =>
      _requests.isEmpty ? null : _requests.removeLast();

  @override
  bool get complete => _complete;

  @override
  double get progress =>
      _complete || _total == 0 ? 1 : (_total - _remaining) / _total;

  @override
  bool isRowLoaded(String sheetId, String rowId) =>
      _complete || !(_missing[sheetId]?.contains(rowId) ?? false);

  @override
  bool isSheetLoaded(String sheetId) =>
      _complete || !_missing.containsKey(sheetId);

  @override
  void prioritize(String sheetId, int firstRow, int lastRow) {
    if (_complete || !_missing.containsKey(sheetId)) return;
    _requests
      ..removeWhere((r) => r.$1 == sheetId)
      ..add((sheetId, firstRow, lastRow));
    if (_requests.length > 4) _requests.removeAt(0);
    _onRequest?.call();
  }

  @override
  Future<void> get whenComplete => _done.future;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
