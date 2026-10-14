import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:wonky_sheets_core/formula.dart'
    show GridRect, CellPos, ColumnLetters;
import 'package:wonky_sheets_core/model.dart';

import 'grid_selection.dart';

/// Owns the selection of every sheet of a workbook (03 §6): id-based
/// [GridSelection]s, resolved to indices on demand (cached per axis
/// generation), with index-space editing helpers.
class GridSelectionController extends ChangeNotifier {
  GridSelectionController(this.model, {required this._sheetId});

  final WorkbookModel model;
  String _sheetId;
  final Map<String, GridSelection> _bySheet = {};

  /// The row display order of a sheet (a sorted filter view, 07 §4.4), or
  /// null. Selecting on screen then works in display rows: ranges are
  /// stored as display ranges and resolve to the model rows shown.
  ViewRowOrder? Function(String sheetId)? rowOrder;

  ViewRowOrder? get _order => rowOrder?.call(_sheetId);

  ResolvedSelection? _resolved;
  GridSelection? _resolvedFrom;
  (int, int)? _resolvedGen;
  ViewRowOrder? _resolvedOrder;

  /// Last resolved indices of the active cell (fallback when its ids vanish).
  (int, int) _lastActive = (0, 0);

  String get sheetId => _sheetId;

  SheetModel? get sheet => model.sheet(_sheetId);

  /// Switches the selected sheet (selections are kept per sheet).
  void setSheet(String sheetId) {
    if (sheetId == _sheetId) return;
    _sheetId = sheetId;
    _resolved = null;
    notifyListeners();
  }

  /// The id-based selection of the current sheet.
  GridSelection get selection =>
      _bySheet[_sheetId] ??= _initial(_sheetId) ?? _emptyFallback();

  GridSelection? selectionOf(String sheetId) => _bySheet[sheetId];

  GridSelection _emptyFallback() => GridSelection(
    sheetId: _sheetId,
    ranges: const [SelectionRange(kind: SelectionKind.all)],
    activeRangeIndex: 0,
    active: const CellRef('', ''),
    anchor: const CellRef('', ''),
  );

  GridSelection? _initial(String sheetId) {
    final s = model.sheet(sheetId);
    if (s == null || s.rows.length == 0 || s.columns.length == 0) return null;
    final r = s.rows.nextVisible(0, 1) ?? 0;
    final c = s.columns.nextVisible(0, 1) ?? 0;
    return _build(
      s,
      [(SelectionKind.cells, GridRect.cell(r, c))],
      0,
      r,
      c,
      r,
      c,
    );
  }

  /// Replaces the selection (undo restore, MCP).
  void restore(GridSelection selection) {
    _bySheet[selection.sheetId] = selection;
    if (selection.sheetId != _sheetId) {
      _sheetId = selection.sheetId;
    }
    _resolved = null;
    notifyListeners();
  }

  /// Call after model changes: drops the cache so ids re-resolve.
  void modelChanged() {
    _resolved = null;
    notifyListeners();
  }

  /// The selection in index space.
  ResolvedSelection get resolved {
    final s = sheet;
    final sel = selection;
    if (s == null) {
      return ResolvedSelection(
        sheetId: _sheetId,
        ranges: [
          ResolvedSelectionRange(SelectionKind.cells, GridRect.cell(0, 0)),
        ],
        activeRangeIndex: 0,
        activeRow: 0,
        activeCol: 0,
        anchorRow: 0,
        anchorCol: 0,
      );
    }
    final gen = (s.rows.generation, s.columns.generation);
    final order = _order;
    final cached = _resolved;
    if (cached != null &&
        identical(_resolvedFrom, sel) &&
        _resolvedGen == gen &&
        identical(_resolvedOrder, order) &&
        cached.sheetId == _sheetId) {
      return cached;
    }
    final r = _resolve(s, sel);
    _resolved = r;
    _resolvedFrom = sel;
    _resolvedGen = gen;
    _resolvedOrder = order;
    _lastActive = (r.activeRow, r.activeCol);
    return r;
  }

  ResolvedSelection _resolve(SheetModel s, GridSelection sel) {
    final maxR = math.max(0, s.rows.length - 1);
    final maxC = math.max(0, s.columns.length - 1);
    final order = rowOrder?.call(sel.sheetId);
    int ri(String? id, int fallback) {
      if (id == null) return fallback;
      final i = s.rows.indexOf(id);
      return i < 0 ? fallback.clamp(0, maxR) : i;
    }

    int ci(String? id, int fallback) {
      if (id == null) return fallback;
      final i = s.columns.indexOf(id);
      return i < 0 ? fallback.clamp(0, maxC) : i;
    }

    final ranges = <ResolvedSelectionRange>[];
    for (var g = 0; g < sel.ranges.length; g++) {
      final r = sel.ranges[g];
      final (top, bottom) = switch (r.kind) {
        SelectionKind.columns || SelectionKind.all => (0, maxR),
        _ => (ri(r.r1, _lastActive.$1), ri(r.r2, _lastActive.$1)),
      };
      final (left, right) = switch (r.kind) {
        SelectionKind.rows || SelectionKind.all => (0, maxC),
        _ => (ci(r.c1, _lastActive.$2), ci(r.c2, _lastActive.$2)),
      };
      if (r.display &&
          order != null &&
          (r.kind == SelectionKind.cells || r.kind == SelectionKind.rows)) {
        // A range on screen: the model rows shown between its corners.
        final d1 = order.displayRow(top);
        final d2 = order.displayRow(bottom);
        final dt = math.min(d1, d2);
        final db = math.max(d1, d2);
        final shown = GridRect(dt, left, db, right);
        for (final (mt, mb) in order.modelRuns(dt, db)) {
          ranges.add(
            ResolvedSelectionRange(
              r.kind,
              GridRect(mt, left, mb, right),
              displayRect: shown,
              group: g,
            ),
          );
        }
        continue;
      }
      ranges.add(
        ResolvedSelectionRange(
          r.kind,
          GridRect.normalized(top, left, bottom, right),
          group: g,
        ),
      );
    }
    var ar = ri(sel.active.rowId, _lastActive.$1);
    var ac = ci(sel.active.colId, _lastActive.$2);
    final group = sel.activeRangeIndex.clamp(0, sel.ranges.length - 1);
    var ai = ranges.indexWhere(
      (x) => x.group == group && x.rect.contains(ar, ac),
    );
    if (ai < 0) ai = ranges.indexWhere((x) => x.group == group);
    if (ai < 0) ai = 0;
    final rect = ranges[ai].rect;
    if (!rect.contains(ar, ac)) {
      ar = ar.clamp(rect.top, rect.bottom);
      ac = ac.clamp(rect.left, rect.right);
    }
    return ResolvedSelection(
      sheetId: sel.sheetId,
      ranges: ranges,
      activeRangeIndex: ai,
      activeRow: ar,
      activeCol: ac,
      anchorRow: ri(sel.anchor.rowId, ar),
      anchorCol: ci(sel.anchor.colId, ac),
    );
  }

  GridSelection _build(
    SheetModel s,
    List<(SelectionKind, GridRect)> ranges,
    int activeIndex,
    int activeRow,
    int activeCol,
    int anchorRow,
    int anchorCol, {
    Set<int> display = const {},
  }) {
    String row(int i) => s.rows.idAt(i.clamp(0, s.rows.length - 1));
    String col(int i) => s.columns.idAt(i.clamp(0, s.columns.length - 1));
    final order = _order;
    // Display ranges ([display] indices) hold display rows: their corners
    // are the model rows shown there.
    String rowOf(int i, int d) =>
        display.contains(i) && order != null ? row(order.modelRow(d)) : row(d);
    return GridSelection(
      sheetId: s.id,
      ranges: [
        for (final (i, (kind, r)) in ranges.indexed)
          SelectionRange(
            kind: kind,
            r1: kind == SelectionKind.columns || kind == SelectionKind.all
                ? null
                : rowOf(i, r.top),
            r2: kind == SelectionKind.columns || kind == SelectionKind.all
                ? null
                : rowOf(i, r.bottom),
            c1: kind == SelectionKind.rows || kind == SelectionKind.all
                ? null
                : col(r.left),
            c2: kind == SelectionKind.rows || kind == SelectionKind.all
                ? null
                : col(r.right),
            display: display.contains(i) && order != null,
          ),
      ],
      activeRangeIndex: activeIndex,
      active: CellRef(row(activeRow), col(activeCol)),
      anchor: CellRef(row(anchorRow), col(anchorCol)),
    );
  }

  void _set(GridSelection sel) {
    if (sel == _bySheet[_sheetId]) return;
    _bySheet[_sheetId] = sel;
    _resolved = null;
    notifyListeners();
  }

  /// Expands [rect] until it fully contains every merge it intersects.
  static GridRect expandMerges(SheetModel s, GridRect rect) {
    if (s.merges.isEmpty) return rect;
    var r = rect;
    for (var guard = 0; guard < 32; guard++) {
      var grown = r;
      for (final (_, m) in s.mergesIntersecting(r)) {
        grown = GridRect(
          math.min(grown.top, m.top),
          math.min(grown.left, m.left),
          math.max(grown.bottom, m.bottom),
          math.max(grown.right, m.right),
        );
      }
      if (grown == r) return r;
      r = grown;
    }
    return r;
  }

  /// Sets the selection from index ranges. [activeRow]/[activeCol] default
  /// to the top-left of the active range; [anchor] defaults to the active
  /// cell.
  void setRanges(
    List<(SelectionKind, GridRect)> ranges, {
    int? activeIndex,
    int? activeRow,
    int? activeCol,
    int? anchorRow,
    int? anchorCol,
  }) => _setRanges(
    ranges,
    activeIndex: activeIndex,
    activeRow: activeRow,
    activeCol: activeCol,
    anchorRow: anchorRow,
    anchorCol: anchorCol,
  );

  /// [setRanges] where the ranges at [display] indices have display rows
  /// (`activeRow`/`anchorRow` are model rows).
  void _setRanges(
    List<(SelectionKind, GridRect)> ranges, {
    int? activeIndex,
    int? activeRow,
    int? activeCol,
    int? anchorRow,
    int? anchorCol,
    Set<int> display = const {},
  }) {
    final s = sheet;
    if (s == null || ranges.isEmpty || s.rows.length == 0) return;
    final ai = (activeIndex ?? ranges.length - 1).clamp(0, ranges.length - 1);
    final rect = ranges[ai].$2;
    final order = _order;
    final ar =
        activeRow ??
        (display.contains(ai) && order != null
            ? order.modelRow(rect.top)
            : rect.top);
    final ac = activeCol ?? rect.left;
    _set(
      _build(
        s,
        ranges,
        ai,
        ar,
        ac,
        anchorRow ?? ar,
        anchorCol ?? ac,
        display: display,
      ),
    );
  }

  /// Selects one cell (its merge when merged).
  void selectCell(int row, int col, {bool add = false}) {
    final s = sheet;
    if (s == null) return;
    final rect = expandMerges(s, GridRect.cell(row, col));
    final (current, display) = add
        ? _currentGroups()
        : (<(SelectionKind, GridRect)>[], <int>{});
    _setRanges(
      [...current, (SelectionKind.cells, rect)],
      activeRow: rect.top,
      activeCol: rect.left,
      display: display,
    );
  }

  /// Extends the active range from the anchor to (row, col) (Shift+click,
  /// drag, Shift+arrows). The active cell stays.
  void extendTo(int row, int col) {
    final s = sheet;
    if (s == null) return;
    final r = resolved;
    final kind = r.activeRange.kind;
    GridRect rect;
    switch (kind) {
      case SelectionKind.rows:
        rect = GridRect(
          math.min(r.anchorRow, row),
          0,
          math.max(r.anchorRow, row),
          s.columns.length - 1,
        );
      case SelectionKind.columns:
        rect = GridRect(
          0,
          math.min(r.anchorCol, col),
          s.rows.length - 1,
          math.max(r.anchorCol, col),
        );
      case SelectionKind.all:
        return;
      case SelectionKind.cells:
        rect = expandMerges(
          s,
          GridRect.normalized(r.anchorRow, r.anchorCol, row, col),
        );
    }
    final (ranges, display) = _currentGroups();
    final group = r.activeRange.group < 0 ? 0 : r.activeRange.group;
    final order = _order;
    final displayed = order != null && kind != SelectionKind.columns;
    if (displayed) {
      // On screen (07 §4.4): from the anchor's display row to the target's.
      final da = order.displayRow(r.anchorRow);
      final dt = order.displayRow(row);
      final dRect = GridRect(
        math.min(da, dt),
        rect.left,
        math.max(da, dt),
        rect.right,
      );
      ranges[group] = (kind, dRect);
      display.add(group);
    } else {
      ranges[group] = (kind, rect);
      display.remove(group);
    }
    _setRanges(
      ranges,
      activeIndex: group,
      activeRow: r.activeRow,
      activeCol: r.activeCol,
      anchorRow: r.anchorRow,
      anchorCol: r.anchorCol,
      display: display,
    );
  }

  /// Whole rows [r1]..[r2] (header click/drag).
  void selectRows(int r1, int r2, {bool add = false, int? activeCol}) {
    final s = sheet;
    if (s == null) return;
    final order = _order;
    // Header drags in a sorted filter view select display rows (07 §4.4).
    final d1 = order?.displayRow(r1) ?? r1;
    final d2 = order?.displayRow(r2) ?? r2;
    final top = math.min(d1, d2);
    final bottom = math.max(d1, d2);
    final rect = GridRect(top, 0, bottom, s.columns.length - 1);
    final (current, display) = add
        ? _currentGroups()
        : (<(SelectionKind, GridRect)>[], <int>{});
    if (order != null) display.add(current.length);
    final ac = activeCol ?? (s.columns.nextVisible(0, 1) ?? 0);
    _setRanges(
      [...current, (SelectionKind.rows, rect)],
      activeRow: r1,
      activeCol: ac,
      anchorRow: r1,
      anchorCol: ac,
      display: display,
    );
  }

  /// Whole columns [c1]..[c2].
  void selectColumns(int c1, int c2, {bool add = false, int? activeRow}) {
    final s = sheet;
    if (s == null) return;
    final left = math.min(c1, c2);
    final right = math.max(c1, c2);
    final rect = GridRect(0, left, s.rows.length - 1, right);
    final (current, display) = add
        ? _currentGroups()
        : (<(SelectionKind, GridRect)>[], <int>{});
    final ar = activeRow ?? (s.rows.nextVisible(0, 1) ?? 0);
    _setRanges(
      [...current, (SelectionKind.columns, rect)],
      activeRow: ar,
      activeCol: c1,
      anchorRow: ar,
      anchorCol: c1,
      display: display,
    );
  }

  /// The whole sheet; the active cell is kept.
  void selectAll() {
    final s = sheet;
    if (s == null) return;
    final r = resolved;
    setRanges(
      [
        (
          SelectionKind.all,
          GridRect(0, 0, s.rows.length - 1, s.columns.length - 1),
        ),
      ],
      activeRow: r.activeRow,
      activeCol: r.activeCol,
    );
  }

  /// Moves the active cell inside the current selection without changing
  /// the ranges (Enter/Tab cycling).
  void setActiveInSelection(int rangeIndex, int row, int col) {
    final r = resolved;
    final (ranges, display) = _currentGroups();
    final g = r.ranges[rangeIndex.clamp(0, r.ranges.length - 1)].group;
    _setRanges(
      ranges,
      activeIndex: g < 0 ? rangeIndex : g,
      activeRow: row,
      activeCol: col,
      anchorRow: row,
      anchorCol: col,
      display: display,
    );
  }

  /// The selected ranges as [_setRanges] input: one entry per selected
  /// range (display ranges in display rows, their indices in the set).
  (List<(SelectionKind, GridRect)>, Set<int>) _currentGroups() {
    final out = <(SelectionKind, GridRect)>[];
    final display = <int>{};
    final seen = <int>{};
    for (final x in resolved.ranges) {
      if (x.group >= 0 && !seen.add(x.group)) continue;
      final d = x.displayRect;
      if (d != null && _order != null) {
        display.add(out.length);
        out.add((x.kind, d));
      } else {
        out.add((x.kind, x.rect));
      }
    }
    return (out, display);
  }

  /// The A1 label of the selection ("B4", "A1:C3", "2:5", "B:D").
  String describe() {
    final r = resolved;
    final x = r.activeRange;
    final rect = x.rect;
    String a1(GridRect g) => g.isSingleCell ? CellPos(g.top, g.left).a1 : g.a1;
    return switch (x.kind) {
      SelectionKind.all => a1(rect),
      SelectionKind.rows => '${rect.top + 1}:${rect.bottom + 1}',
      SelectionKind.columns =>
        '${ColumnLetters.fromIndex(rect.left)}:${ColumnLetters.fromIndex(rect.right)}',
      SelectionKind.cells => a1(rect),
    };
  }
}
