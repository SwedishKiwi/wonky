import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../sheet_editor/sheet_editor_controller.dart';

/// A temporary filter view (07 §4.1): local to this device and user, not
/// undoable, usable by viewers.
class TemporaryFilterView {
  TemporaryFilterView({
    required this.id,
    required this.sheetId,
    required this.name,
    required this.range,
    FilterCriteria? criteria,
  }) : criteria = criteria ?? FilterCriteria();

  /// `temp:<n>`.
  final String id;
  final String sheetId;
  String name;
  GridRange range;
  FilterCriteria criteria;
}

/// The filter shown on a sheet: the active filter view, a temporary view or
/// the basic filter.
@immutable
class EffectiveFilter {
  const EffectiveFilter({
    required this.sheetId,
    required this.range,
    required this.criteria,
    this.viewId,
    this.name,
    this.temporary = false,
    this.sort = const [],
  });

  final String sheetId;

  /// Filter range including the header row.
  final GridRect range;
  final FilterCriteria criteria;

  /// The filter view (saved id or `temp:<n>`), null for the basic filter.
  final String? viewId;
  final String? name;
  final bool temporary;

  /// `sortJson` entries `(colId, ascending)` (sort indicators).
  final List<(String, bool)> sort;

  bool get isView => viewId != null;

  /// First data row.
  int get dataTop => range.top + 1;
}

/// A draft of one column's criteria shown live while the column popover is
/// open (07 §3.5: the preview is local only).
@immutable
class FilterDraft {
  const FilterDraft(this.sheetId, this.viewId, this.colId, this.criteria);

  final String sheetId;
  final String? viewId;
  final String colId;
  final ColumnCriteria? criteria;
}

/// The open filter column popover (anchored to a filter button).
@immutable
class FilterPopoverRequest {
  const FilterPopoverRequest(this.sheetId, this.colId, this.anchor);

  final String sheetId;
  final String colId;

  /// The button rectangle in grid coordinates.
  final Rect anchor;
}

/// Computes filter-hidden rows on this device (07 §3.4
/// `FilterVisibilityService`): the basic filter (`filter` hidden layer, read
/// by `SUBTOTAL`) and — while a filter view is active — the view
/// (`filterView` layer, local only), which replaces the basic filter on
/// screen (the `filter` layer is suppressed, formulas keep it). Also holds the local filter view state
/// (active view per sheet, temporary views) and the popover/draft state.
class FilterController extends ChangeNotifier {
  FilterController(this.ed);

  final SheetEditorController ed;

  WorkbookModel get model => ed.model;

  final Map<String, RowVisibility?> _visibility = {};
  final Map<String, String> _activeView = {};
  final List<TemporaryFilterView> temporaryViews = [];
  int _tempSeq = 0;
  FilterDraft? _draft;
  (String, String)? _sticky;
  StreamSubscription<Object?>? _recalc;
  Timer? _debounce;
  final Set<String> _pending = {};
  bool _started = false;

  /// The open column popover (the grid overlay shows it).
  final ValueNotifier<FilterPopoverRequest?> popover = ValueNotifier(null);

  /// Called when a filter view another user deleted closes (toast).
  VoidCallback? onViewDeleted;

  void start() {
    if (_started) return;
    _started = true;
    model.addListener(_onBatch);
    _recalc = ed.engine.changes.listen((_) => _schedule(_formulaSheets()));
    ed.selection.addListener(_onSelection);
    refreshAll();
  }

  @override
  void dispose() {
    if (_started) {
      model.removeListener(_onBatch);
      ed.selection.removeListener(_onSelection);
    }
    unawaited(_recalc?.cancel());
    _debounce?.cancel();
    popover.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Queries.

  /// The basic filter of [sheetId] resolved to indices, or null.
  EffectiveFilter? basicFilter(String sheetId) {
    final s = model.sheet(sheetId);
    final bf = s?.basicFilter;
    if (s == null || bf == null) return null;
    var rect = _resolve(s, bf.rangeJson);
    if (rect == null) return null;
    // Open-ended (07 §3.6): down to the last used row, so rows typed below
    // the data join the filter without covering the empty rest of the grid.
    if (basicOpenEnded(sheetId)) {
      final used = s.usedRect()?.bottom ?? rect.top + 1;
      final bottom = math.max(rect.top + 1, used);
      if (bottom < rect.bottom) {
        rect = GridRect(rect.top, rect.left, bottom, rect.right);
      }
    }
    return EffectiveFilter(
      sheetId: sheetId,
      range: rect,
      criteria: FilterCriteria.parse(bf.criteriaJson),
      sort: _parseSort(bf.sortJson),
    );
  }

  /// Whether the basic filter of [sheetId] is stored open-ended (rows
  /// appended below join it, 07 §3.6).
  bool basicOpenEnded(String sheetId) {
    final bf = model.sheet(sheetId)?.basicFilter;
    if (bf == null) return false;
    final g = GridRange.tryParse(bf.rangeJson);
    return g != null && g.r1 != null && g.r2 == null;
  }

  /// The active filter view (saved or temporary) id of [sheetId].
  String? activeViewId(String sheetId) => _activeView[sheetId];

  /// The temporary view [id], or null.
  TemporaryFilterView? temporaryView(String id) {
    for (final v in temporaryViews) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// The filter view [viewId] (saved or temporary) of [sheetId] resolved.
  EffectiveFilter? view(String sheetId, String viewId) {
    final s = model.sheet(sheetId);
    if (s == null) return null;
    final temp = temporaryView(viewId);
    if (temp != null) {
      final rr = s.resolve(temp.range);
      if (rr == null) return null;
      return EffectiveFilter(
        sheetId: sheetId,
        range: rr.rect,
        criteria: temp.criteria,
        viewId: temp.id,
        name: temp.name,
        temporary: true,
      );
    }
    final rec = s.filterViews[viewId];
    if (rec == null) return null;
    final rect = _resolve(s, rec.rangeJson);
    if (rect == null) return null;
    return EffectiveFilter(
      sheetId: sheetId,
      range: rect,
      criteria: FilterCriteria.parse(rec.criteriaJson),
      viewId: rec.id,
      name: rec.name,
      sort: _parseSort(rec.sortJson),
    );
  }

  /// The filter shown on [sheetId]: the active view, else the basic filter
  /// (cached until the next change; painting reads it every frame).
  EffectiveFilter? effective(String sheetId) {
    if (_effective.containsKey(sheetId)) return _effective[sheetId];
    final v = _activeView[sheetId];
    return _effective[sheetId] = v != null
        ? view(sheetId, v)
        : basicFilter(sheetId);
  }

  final Map<String, EffectiveFilter?> _effective = {};

  /// The criteria of [colId] shown in the popover (the draft while editing).
  ColumnCriteria? criteriaOf(EffectiveFilter f, String colId) {
    final d = _draft;
    if (d != null &&
        d.sheetId == f.sheetId &&
        d.viewId == f.viewId &&
        d.colId == colId) {
      return d.criteria;
    }
    return f.criteria.columns[colId];
  }

  /// The computed visibility of the shown filter of [sheetId].
  RowVisibility? visibility(String sheetId) => _visibility[sheetId];

  /// Saved filter views of [sheetId], by name.
  List<FilterRecord> savedViews(String sheetId) {
    final s = model.sheet(sheetId);
    if (s == null) return const [];
    return s.filterViews.values.toList()..sort(
      (a, b) =>
          (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()),
    );
  }

  /// A filter data source for [sheetId] (computed values, display texts,
  /// effective colors).
  FilterDataSource source(String sheetId) => SheetFilterSource(
    sheetId,
    CellTextReader(ed.engine, FormatterDisplayText(locale: ed.locale)),
    formats: EffectiveFormatResolver(model),
  );

  /// The condition evaluator of the spreadsheet.
  ConditionEvaluator get conditions =>
      ConditionEvaluator(locale: ed.locale, hooks: ed.hooks);

  /// The filter input of [f] (draft applied).
  FilterInput input(EffectiveFilter f) => FilterInput.resolve(
    sheet: model.sheet(f.sheetId)!,
    range: f.range,
    criteria: _withDraft(f),
    source: source(f.sheetId),
    conditions: conditions,
  );

  /// The values checklist of column [col] of [f] (07 §3.5).
  List<ChecklistEntry> checklist(EffectiveFilter f, int col) {
    final committed = FilterInput.resolve(
      sheet: model.sheet(f.sheetId)!,
      range: f.range,
      criteria: f.criteria,
      source: source(f.sheetId),
      conditions: conditions,
    );
    return FilterEngine.checklist(committed, col);
  }

  /// Distinct effective fill / text colors of column [col] in [f]'s data rows.
  ({List<String> fills, List<String> texts}) colorsOf(
    EffectiveFilter f,
    int col,
  ) {
    final src = source(f.sheetId);
    final fills = <String>{};
    final texts = <String>{};
    final last = f.range.bottom < f.dataTop + 20000
        ? f.range.bottom
        : f.dataTop + 20000;
    for (var r = f.dataTop; r <= last; r++) {
      final fill = src.fillColorAt(r, col);
      if (fill != null) fills.add(fill.toUpperCase());
      final text = src.textColorAt(r, col);
      if (text != null) texts.add(text.toUpperCase());
    }
    return (fills: fills.toList()..sort(), texts: texts.toList()..sort());
  }

  // ---------------------------------------------------------------------------
  // Local state changes.

  /// Shows the live preview of [criteria] for one column (null = none).
  void setDraft(FilterDraft? draft) {
    _draft = draft;
    final sid = draft?.sheetId ?? ed.activeSheetId;
    refresh(sid);
  }

  /// Ends the preview.
  void clearDraft() {
    final d = _draft;
    if (d == null) return;
    _draft = null;
    refresh(d.sheetId);
  }

  /// Activates filter view [viewId] on [sheetId] (null closes the view).
  void activate(String sheetId, String? viewId) {
    if (viewId == null) {
      _activeView.remove(sheetId);
    } else {
      _activeView[sheetId] = viewId;
    }
    _draft = null;
    refresh(sheetId, force: true);
    ed.overlaySignal.fire();
    ed.contentSignal.fire();
  }

  /// Creates a temporary view on [sheetId] and activates it.
  TemporaryFilterView createTemporary(
    String sheetId,
    GridRange range, {
    FilterCriteria? criteria,
    String? name,
  }) {
    _tempSeq++;
    final v = TemporaryFilterView(
      id: 'temp:$_tempSeq',
      sheetId: sheetId,
      name: name ?? 'Temporary filter $_tempSeq',
      range: range,
      criteria: criteria,
    );
    temporaryViews.add(v);
    activate(sheetId, v.id);
    return v;
  }

  /// Changes a temporary view (criteria/name/range) and refreshes.
  void updateTemporary(
    String id, {
    FilterCriteria? criteria,
    String? name,
    GridRange? range,
  }) {
    final v = temporaryView(id);
    if (v == null) return;
    if (criteria != null) v.criteria = criteria;
    if (name != null) v.name = name;
    if (range != null) v.range = range;
    refresh(v.sheetId, force: true);
  }

  /// Deletes a temporary view (closing it when active).
  void deleteTemporary(String id) {
    final v = temporaryView(id);
    if (v == null) return;
    temporaryViews.remove(v);
    if (_activeView[v.sheetId] == id) {
      activate(v.sheetId, null);
    } else {
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Visibility.

  void refreshAll() {
    for (final s in model.sheets) {
      refresh(s.id, force: true);
    }
  }

  /// Recomputes the hidden rows of [sheetId] and applies them to its row
  /// axis (`filter` / `filterView` hidden layers).
  void refresh(String sheetId, {bool force = false}) {
    _effective.remove(sheetId);
    final s = model.sheet(sheetId);
    if (s == null) {
      _visibility.remove(sheetId);
      return;
    }
    // A deleted view closes (07 §4.3).
    final active = _activeView[sheetId];
    if (active != null &&
        temporaryView(active) == null &&
        !s.filterViews.containsKey(active)) {
      _activeView.remove(sheetId);
      onViewDeleted?.call();
    }
    final viewId = _activeView[sheetId];
    final basic = basicFilter(sheetId);
    final shownView = viewId == null ? null : view(sheetId, viewId);
    // The basic filter always feeds the `filter` layer (SUBTOTAL, 07 §3.1);
    // an active view's rows go to `filterView` and replace the basic
    // filter on screen (the `filter` layer is suppressed, 07 §4.3).
    final basicVis = basic == null ? null : _compute(s, basic);
    final viewVis = shownView == null ? null : _compute(s, shownView);
    _visibility[sheetId] = viewVis ?? basicVis;
    final sticky = _sticky;
    var stickyHidden = false;
    Set<String> hidden(RowVisibility? v, {required bool shown}) {
      final ids = v?.hiddenRowIds(s.rows) ?? <String>{};
      if (shown &&
          sticky != null &&
          sticky.$1 == sheetId &&
          ids.contains(sticky.$2)) {
        stickyHidden = true;
        return {...ids}..remove(sticky.$2);
      }
      return ids;
    }

    final filterIds = hidden(basicVis, shown: shownView == null);
    final viewIds = hidden(viewVis, shown: true);
    var changed = force;
    if (!setEquals(s.rows.hiddenLayer(HiddenLayers.filter), filterIds)) {
      s.rows.setHiddenLayer(HiddenLayers.filter, filterIds);
      ed.engine.filterVisibilityChanged(sheetId);
      changed = true;
    }
    if (!setEquals(s.rows.hiddenLayer(HiddenLayers.filterView), viewIds)) {
      s.rows.setHiddenLayer(HiddenLayers.filterView, viewIds);
      changed = true;
    }
    if (sticky != null && sticky.$1 == sheetId) {
      if (_stickyHidden != stickyHidden) changed = true;
      _stickyHidden = stickyHidden;
    }
    final suppress = shownView != null;
    if (s.rows.isLayerSuppressed(HiddenLayers.filter) != suppress) {
      s.rows.setLayerSuppressed(HiddenLayers.filter, suppress);
      changed = true;
    }
    if (changed) {
      if (sheetId == ed.activeSheetId) {
        ed.contentSignal.fire();
        ed.overlaySignal.fire();
      }
      notifyListeners();
    }
  }

  FilterCriteria _withDraft(EffectiveFilter f) {
    final d = _draft;
    if (d == null || d.sheetId != f.sheetId || d.viewId != f.viewId) {
      return f.criteria;
    }
    return f.criteria.withColumn(d.colId, d.criteria);
  }

  RowVisibility _compute(SheetModel s, EffectiveFilter f) {
    final criteria = _withDraft(f);
    if (criteria.isEmpty) {
      return RowVisibility(
        f.range,
        Uint8List(f.range.rowCount > 1 ? f.range.rowCount - 1 : 0),
      );
    }
    try {
      return FilterEngine.compute(
        FilterInput.resolve(
          sheet: s,
          range: f.range,
          criteria: criteria,
          source: source(s.id),
          conditions: conditions,
        ),
      );
    } catch (e) {
      debugPrint('Filter: $e');
      return RowVisibility(
        f.range,
        Uint8List(f.range.rowCount > 1 ? f.range.rowCount - 1 : 0),
      );
    }
  }

  static GridRect? _resolve(SheetModel s, String rangeJson) {
    final g = GridRange.tryParse(rangeJson);
    if (g == null) return null;
    return s.resolve(g)?.rect;
  }

  static List<(String, bool)> _parseSort(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final d = jsonDecodeList(json);
      return [
        for (final e in d)
          if (e is Map && e['colId'] is String)
            (e['colId'] as String, e['ascending'] != false),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Sheets whose shown filter has criteria (formula results may change
  /// their visibility after a recalculation).
  Iterable<String> _formulaSheets() sync* {
    for (final s in model.sheets) {
      final f = effective(s.id);
      if (f != null && !f.criteria.isEmpty) yield s.id;
    }
  }

  void _schedule(Iterable<String> sheetIds) {
    _pending.addAll(sheetIds);
    if (_pending.isEmpty) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 60), () {
      final ids = {..._pending};
      _pending.clear();
      for (final id in ids) {
        refresh(id);
      }
    });
  }

  void _onBatch(WorkbookChangeBatch batch) {
    _effective.clear();
    final now = <String>{};
    var all = false;
    for (final e in batch.events) {
      switch (e) {
        case RulesChanged(:final sheetId, :final kind)
            when kind == RuleKind.basicFilter || kind == RuleKind.filterView:
          now.add(sheetId);
        case CellsChanged(:final sheetId):
          if (effective(sheetId) != null) {
            _stick(sheetId, e);
            now.add(sheetId);
          }
        case StructureChanged(:final sheetId, :final order):
          if (order) now.add(sheetId);
        case SheetsChanged():
          all = true;
        default:
          break;
      }
    }
    if (all) {
      refreshAll();
    } else {
      for (final id in now) {
        refresh(id);
      }
    }
  }

  /// Sticky edit row (07 §3.4): an edited row in the active cell's row stays
  /// visible on this device until the selection leaves it.
  void _stick(String sheetId, CellsChanged e) {
    if (sheetId != ed.activeSheetId) return;
    final s = model.sheet(sheetId);
    if (s == null) return;
    final row = ed.selection.resolved.activeRow;
    final rowId = s.rows.tryIdAt(row);
    if (rowId == null) return;
    if (e.contentKeys.any((k) => k.rowId == rowId)) _sticky = (sheetId, rowId);
  }

  void _onSelection() {
    final st = _sticky;
    if (st == null) return;
    final s = model.sheet(st.$1);
    final row = ed.selection.resolved.activeRow;
    if (ed.activeSheetId == st.$1 && s?.rows.tryIdAt(row) == st.$2) return;
    _sticky = null;
    refresh(st.$1);
  }

  bool _stickyHidden = false;

  /// The sticky edit row of [sheetId] when the shown filter would hide it
  /// (painted dimmed with a badge, 07 §3.4), else null.
  int? stickyHiddenRow(String sheetId) {
    final st = _sticky;
    if (st == null || st.$1 != sheetId || !_stickyHidden) return null;
    final i = model.sheet(sheetId)?.rows.indexOf(st.$2) ?? -1;
    return i < 0 ? null : i;
  }

  /// Whether [row] of [sheetId] is the sticky edit row.
  bool isSticky(String sheetId, int row) {
    final st = _sticky;
    if (st == null || st.$1 != sheetId) return false;
    return model.sheet(sheetId)?.rows.tryIdAt(row) == st.$2;
  }
}

/// Decodes a JSON list (empty when malformed or not a list).
List<Object?> jsonDecodeList(String json) {
  try {
    final d = jsonDecode(json);
    return d is List ? d : const [];
  } on FormatException {
    return const [];
  }
}
