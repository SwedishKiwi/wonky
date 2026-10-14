import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:wonky_sheets_core/formula.dart'
    show
        CancellationToken,
        CellPos,
        EngineCellInput,
        ErrorKind,
        FEmpty,
        FError,
        FValue,
        FormulaEngine,
        GridRect,
        PivotDataProvider,
        RecalcBatch,
        SpillArea;
import 'package:wonky_sheets_core/model.dart';

/// Why a pivot shows `#REF!` at its anchor instead of its output (07 §7.6).
enum PivotProblem {
  /// The source range no longer resolves.
  invalidSource,

  /// Cells with content (or an earlier pivot) are in the way.
  collision,

  /// The output needs more rows/columns than the sheet has.
  gridEdge,

  /// More than 1M output cells.
  tooLarge,
}

/// The computed state of one pivot table: its record, the result, the laid
/// out grid and where it sits on the sheet.
final class PivotOutput {
  PivotOutput._({
    required this.record,
    required this.spec,
    required this.anchorRow,
    required this.anchorCol,
    required this.source,
    this.result,
    this.grid,
    this.error,
    this.problem,
    this.blocking,
    this.missingRows = 0,
    this.missingColumns = 0,
    this.sourceHasFormulas = false,
    this.yielded = false,
    GridRect? want,
    this.spillSignature = 0,
  }) : rect = grid == null || grid.isEmpty
           ? GridRect.cell(anchorRow, anchorCol)
           : GridRect(
               anchorRow,
               anchorCol,
               anchorRow + grid.rowCount - 1,
               anchorCol + grid.columnCount - 1,
             ),
       wantRect = want ?? GridRect.cell(anchorRow, anchorCol) {
    _inputs = List<EngineCellInput?>.filled(
      rect.rowCount * rect.colCount,
      null,
    );
  }

  final PivotTableRecord record;
  final PivotSpec spec;
  final int anchorRow;
  final int anchorCol;

  /// The source range (header row first), or null when it doesn't resolve.
  final ResolvedRange? source;

  /// The engine result (null in error states).
  final PivotResult? result;

  /// The laid-out output (null in error states).
  final PivotGrid? grid;

  /// `#REF!` shown at the anchor (collision, grid edge, too large, invalid
  /// source).
  final ErrorValue? error;
  final PivotProblem? problem;

  /// The first blocking cell of a collision.
  final CellPos? blocking;

  /// Rows/columns the sheet lacks for the output (grid edge).
  final int missingRows;
  final int missingColumns;

  /// Whether the source range holds formulas (any edit may change them).
  final bool sourceHasFormulas;

  /// The output rectangle (the anchor cell alone in error and message
  /// states).
  final GridRect rect;

  /// The rectangle the output needs (also in error states).
  final GridRect wantRect;

  /// An earlier dynamic array covers the anchor (05 §7.5): the pivot shows
  /// nothing at all, not even its `#REF!`.
  final bool yielded;

  /// Hash of the earlier dynamic arrays overlapping [wantRect] when placed
  /// (a change re-places the pivot).
  final int spillSignature;

  late final List<EngineCellInput?> _inputs;

  /// Whether a recompute is pending (the output is stale).
  bool stale = false;

  String get id => record.id;
  String get sheetId => record.sheetId;

  /// The muted message of an empty spec ("Add rows, columns, or values…").
  String? get message => error == null ? grid?.message : null;

  /// Whether the output shows a grid (no error, not empty).
  bool get hasOutput => error == null && grid != null && !grid!.isEmpty;

  /// The pivot cell at absolute ([row], [col]), or null.
  PivotCell? cellAt(int row, int col) {
    final g = grid;
    if (g == null || error != null) return null;
    return g.cellAt(row - anchorRow, col - anchorCol);
  }

  /// Whether ([row], [col]) is inside the output (or is the anchor).
  bool contains(int row, int col) => rect.contains(row, col);

  EngineCellInput? _inputAt(int row, int col) {
    if (!rect.contains(row, col)) return null;
    final i = (row - rect.top) * rect.colCount + (col - rect.left);
    final cached = _inputs[i];
    if (cached != null) return cached;
    final e = error;
    final FValue v;
    if (e != null) {
      if (yielded || row != anchorRow || col != anchorCol) return null;
      v = e.toFValue();
    } else {
      final c = cellAt(row, col);
      // Blank output cells still occupy the area: dynamic arrays that would
      // spill into it are blocked (the earlier anchor won, 05 §7.5).
      v = c == null || c.value.isBlank() ? FEmpty.instance : c.value.toFValue();
    }
    return _inputs[i] = EngineCellInput.value(v);
  }

  /// The values of the output (change detection).
  List<Object?> get signature => [
    rect,
    error?.message,
    for (var r = 0; r < (grid?.rowCount ?? 0); r++)
      for (var c = 0; c < (grid?.columnCount ?? 0); c++)
        () {
          final cell = grid!.cellAt(r, c);
          return cell == null
              ? null
              : (cell.value, cell.numberFormat, cell.role);
        }(),
  ];
}

/// Computes every pivot table of a workbook and serves the outputs as
/// computed overlays to the formula engine (07 §7.4–7.10): formulas, the
/// grid and the clipboard read them like spilled values; `GETPIVOTDATA`
/// resolves through [getPivotData].
///
/// Pivot record changes (create, edit, undo, remote) recompute at once;
/// source edits (local or remote, formula results included) recompute
/// after [debounce]. Listeners are notified when an output changed.
class PivotOverlayService extends ChangeNotifier
    implements ComputedOverlaySource, PivotDataProvider {
  PivotOverlayService({
    required this.model,
    required this.engine,
    this.hooks,
    this.debounce = const Duration(milliseconds: 300),
    this.backgroundRows = 100000,
    this.useIsolate = !kIsWeb,
    this.snapshotSlice = 4096,
    this.snapshotBudget = const Duration(milliseconds: 8),
  });

  final WorkbookModel model;
  final FormulaEngine engine;
  final FormulaHooks? hooks;
  final Duration debounce;

  /// Sources with at least this many data rows are aggregated in the
  /// background (07 §7.4 step 7): in an isolate on native, time-sliced on
  /// the web and for calculated fields / formula filters (they need the
  /// formula engine). The previous output stays, marked stale, meanwhile.
  final int backgroundRows;

  /// Whether background jobs may use an isolate.
  final bool useIsolate;

  /// Overrides the slicer masks (07 §5, §7.4 step 1): per data row of
  /// [source], 1 = excluded. By default ([slicerMask]) slicers whose data
  /// range is the pivot's source range and that apply to pivot tables
  /// filter it, for everyone (local overrides of viewers don't).
  Uint8List? Function(ResolvedRange source)? rowMask;

  /// The rows of [source] excluded by slicers with `applyToPivotTables` on
  /// the same range (spec JSON of 07 §5), or null.
  Uint8List? slicerMask(ResolvedRange source) {
    final sheet = model.sheet(source.sheetId);
    if (sheet == null) return null;
    final criteria = <String, ColumnCriteria>{};
    for (final s in model.sheets) {
      for (final o in s.objects.values) {
        if (o.kind != EmbeddedObjectKind.slicer) continue;
        Object? d;
        try {
          d = jsonDecode(o.specJson);
        } on FormatException {
          continue;
        }
        if (d is! Map || d['applyToPivotTables'] == false) continue;
        final g = GridRange.tryParse(d['dataRange']);
        final r = g == null ? null : model.resolve(g);
        if (r == null || r.sheetId != source.sheetId || r.rect != source.rect) {
          continue;
        }
        final colId = d['colId'];
        if (colId is! String) continue;
        final c = ColumnCriteria.fromJson(d['criteria']);
        if (c.isEmpty) continue;
        final prev = criteria[colId];
        criteria[colId] = prev == null
            ? c
            : ColumnCriteria(
                hiddenValues: {...prev.hiddenValues, ...c.hiddenValues},
                condition: c.condition ?? prev.condition,
              );
      }
    }
    if (criteria.isEmpty) return null;
    final locale = model.spreadsheet.locale;
    final display = FormatterDisplayText(locale: locale);
    _computing = '~slicers';
    try {
      return FilterEngine.compute(
        FilterInput.resolve(
          sheet: sheet,
          range: source.rect,
          criteria: FilterCriteria(criteria),
          source: SheetFilterSource(
            sheet.id,
            CellTextReader(engine, display),
            formats: EffectiveFormatResolver(model),
          ),
          conditions: ConditionEvaluator(locale: locale, hooks: hooks),
        ),
      ).hidden;
    } on Object {
      return null;
    } finally {
      _computing = null;
    }
  }

  final Map<String, _PivotJob> _jobs = {};
  final Map<String, _Computed> _ready = {};

  /// Number of running background computations (repaints the stale
  /// indicator).
  final ValueNotifier<int> running = ValueNotifier(0);

  /// Whether pivot [id] is being recomputed in the background.
  bool isComputing(String id) => _jobs.containsKey(id);

  final Map<String, PivotOutput> _outputs = {};
  final Set<String> _dirty = {};
  Timer? _timer;
  StreamSubscription<RecalcBatch>? _recalc;
  ModelWorkbookView? _view;
  String? _computing;
  bool _disposed = false;

  /// Installs the service on the engine's [view] and computes every pivot.
  void attach(ModelWorkbookView view) {
    _view = view;
    view.overlays = this;
    engine.pivots = this;
    model.addListener(_onBatch);
    _recalc = engine.changes.listen(_onRecalc);
    for (final sheet in model.sheets) {
      for (final o in sheet.objects.values) {
        if (o.kind == EmbeddedObjectKind.slicer) _knownSlicers.add(o.id);
      }
    }
    refreshAll();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final j in _jobs.values) {
      j.token.cancel();
    }
    _jobs.clear();
    running.dispose();
    _timer?.cancel();
    unawaited(_recalc?.cancel());
    model.removeListener(_onBatch);
    if (_view?.overlays == this) _view!.overlays = null;
    if (engine.pivots == this) engine.pivots = null;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Queries.

  /// Every computed pivot.
  Iterable<PivotOutput> get outputs => _outputs.values;

  /// The pivot with [id], or null.
  PivotOutput? byId(String id) => _outputs[id];

  /// The pivot whose output (or anchor) contains the cell, or null.
  PivotOutput? outputAt(String sheetId, int row, int col) {
    for (final o in _outputs.values) {
      if (o.sheetId == sheetId && o.contains(row, col)) return o;
    }
    return null;
  }

  /// The pivots of [sheetId].
  Iterable<PivotOutput> outputsOf(String sheetId) =>
      _outputs.values.where((o) => o.sheetId == sheetId);

  // ---------------------------------------------------------------------------
  // ComputedOverlaySource.

  @override
  EngineCellInput? inputAt(String sheetId, int row, int col) {
    for (final o in _outputs.values) {
      if (o.sheetId != sheetId || o.id == _computing) continue;
      if (!o.rect.contains(row, col)) continue;
      return o._inputAt(row, col);
    }
    return null;
  }

  @override
  String? numberFormatAt(String sheetId, int row, int col) {
    for (final o in _outputs.values) {
      if (o.sheetId != sheetId || !o.rect.contains(row, col)) continue;
      return o.cellAt(row, col)?.numberFormat;
    }
    return null;
  }

  @override
  Iterable<GridRect> rectsOf(String sheetId) => [
    for (final o in _outputs.values)
      if (o.sheetId == sheetId && o.id != _computing) o.rect,
  ];

  // ---------------------------------------------------------------------------
  // GETPIVOTDATA (07 §7.8).

  @override
  FValue getPivotData(
    String sheetId,
    int row,
    int col,
    String valueName,
    List<(String, FValue)> filters,
  ) {
    final o = outputAt(sheetId, row, col);
    if (o == null) {
      return const FError(
        ErrorKind.ref,
        'The reference is not inside a pivot table.',
      );
    }
    final e = o.error;
    if (e != null) return e.toFValue();
    final r = o.result;
    if (r == null) return const FError(ErrorKind.na);
    final display = FormatterDisplayText(locale: model.spreadsheet.locale);
    return PivotDataLookup.lookup(r, valueName, [
      for (final (f, v) in filters) (f, v.toCellValue()),
    ], labelText: display.displayText).toFValue();
  }

  // ---------------------------------------------------------------------------
  // Refresh.

  /// Recomputes every pivot now.
  void refreshAll() {
    _full.addAll(_allRecords().map((r) => r.id));
    _dirty
      ..clear()
      ..addAll(_allRecords().map((r) => r.id))
      ..addAll(_outputs.keys);
    flush();
  }

  /// Recomputes [pivotId] now (`sheets.pivot.refresh`).
  void refresh(String pivotId) {
    _full.add(pivotId);
    _dirty.add(pivotId);
    flush();
  }

  /// Marks pivots for a debounced recompute.
  void markDirty(Iterable<String> ids) {
    var any = false;
    for (final id in ids) {
      if (_dirty.add(id)) any = true;
      _outputs[id]?.stale = true;
      _jobs[id]?.dirty = true;
    }
    if (!any && _timer != null) return;
    _timer?.cancel();
    _timer = Timer(debounce, flush);
  }

  /// Recomputes the dirty pivots now.
  void flush() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || _dirty.isEmpty) return;
    final ids = Set.of(_dirty);
    _dirty.clear();
    final records = {for (final r in _allRecords()) r.id: r};
    final changed = <(String, GridRect)>[];
    // Removed pivots.
    for (final id in ids) {
      if (records.containsKey(id)) continue;
      _cancelJob(id);
      _ready.remove(id);
      final old = _outputs.remove(id);
      if (old != null) changed.add((old.sheetId, old.rect));
    }
    // Pivots are placed in anchor order per sheet (the earlier anchor wins a
    // collision, 07 §7.6), so recompute the affected sheets in that order.
    final sheets = {
      for (final id in ids)
        if (records[id] case final PivotTableRecord r) r.sheetId,
    };
    for (final sheetId in sheets) {
      final recs = [
        for (final r in records.values)
          if (r.sheetId == sheetId) r,
      ];
      final s = model.sheet(sheetId);
      if (s == null) continue;
      (int, int) pos(PivotTableRecord r) =>
          (s.rows.indexOf(r.anchorRowId), s.columns.indexOf(r.anchorColId));
      recs.sort((a, b) {
        final (ar, ac) = pos(a);
        final (br, bc) = pos(b);
        return ar != br ? ar - br : (ac != bc ? ac - bc : a.id.compareTo(b.id));
      });
      final placed = <GridRect>[];
      for (var i = 0; i < recs.length; i++) {
        final rec = recs[i];
        final old = _outputs[rec.id];
        if (!ids.contains(rec.id) && old != null) {
          // Unchanged; it may still block a later pivot.
          if (old.hasOutput) placed.add(old.rect);
          continue;
        }
        final computed = _compute(rec, s, placed);
        if (identical(computed, _pending)) {
          // Recomputing in the background: the old output stays (stale).
          if (old != null) {
            old.stale = true;
            if (old.hasOutput) placed.add(old.rect);
          }
          continue;
        }
        final next = computed as PivotOutput?;
        if (next == null) {
          if (old != null) changed.add((old.sheetId, old.rect));
          _outputs.remove(rec.id);
          continue;
        }
        if (next.hasOutput) placed.add(next.rect);
        _outputs[rec.id] = next;
        if (old == null || !listEquals(old.signature, next.signature)) {
          if (old != null) changed.add((old.sheetId, old.rect));
          changed.add((next.sheetId, next.rect));
          // Later pivots on the sheet may be (un)blocked now.
          for (final r in recs.skip(i + 1)) {
            ids.add(r.id);
          }
        }
      }
    }
    for (final (sheetId, rect) in changed) {
      if (model.sheet(sheetId) != null) engine.rectChanged(sheetId, rect);
    }
    if (changed.isNotEmpty || ids.isNotEmpty) notifyListeners();
  }

  Iterable<PivotTableRecord> _allRecords() sync* {
    for (final s in model.sheets) {
      yield* s.pivots.values;
    }
  }

  static final Object _pending = Object();

  /// Computes and places [rec]: a [PivotOutput], null (anchor deleted), or
  /// [_pending] when a background job was started.
  Object? _compute(PivotTableRecord rec, SheetModel s, List<GridRect> placed) {
    final row = s.rows.indexOf(rec.anchorRowId);
    final col = s.columns.indexOf(rec.anchorColId);
    if (row < 0 || col < 0) return null;
    final spec = PivotSpec.parse(rec.specJson);
    final g = GridRange.tryParse(rec.sourceRangeJson);
    final source = g == null ? null : model.resolve(g);
    if (source == null || model.sheet(source.sheetId) == null) {
      _ready.remove(rec.id);
      return PivotOutput._(
        record: rec,
        spec: spec,
        anchorRow: row,
        anchorCol: col,
        source: source,
        error: const ErrorValue(
          CellErrorKind.ref,
          'The source range of the pivot table is not valid.',
        ),
        problem: PivotProblem.invalidSource,
      );
    }
    final locale = model.spreadsheet.locale;
    final display = FormatterDisplayText(locale: locale);
    final ready = _ready.remove(rec.id);
    final PivotResult result;
    final PivotGrid grid;
    final bool formulas;
    final delta = ready == null ? _tryDelta(rec, source, s.id, row, col) : null;
    if (ready != null && identical(ready.record, rec)) {
      result = ready.result;
      grid = ready.grid;
      formulas = ready.sourceHasFormulas;
      _deltaCount.remove(rec.id);
    } else if (delta != null) {
      (result, grid) = delta;
      formulas = _outputs[rec.id]!.sourceHasFormulas;
    } else {
      _deltaCount.remove(rec.id);
      // Big sources are read in slices across frames, then aggregated in
      // the background (07 §7.4 step 7): nothing big runs on the UI thread.
      if (_dataRows(source) >= backgroundRows) {
        _startJob(
          rec,
          spec,
          null,
          row,
          col,
          _hasFormulas(source),
          s.id,
          source: source,
        );
        return _pending;
      }
      _computing = rec.id;
      final SourceTable table;
      try {
        table = SourceTable.fromModel(
          model,
          engine,
          source,
          display,
          colorAt: _needsColors(spec) ? _colorReader(source.sheetId) : null,
          rowMask: (rowMask ?? slicerMask)(source),
        );
      } finally {
        _computing = null;
      }
      formulas = _hasFormulas(source);
      if (table.rowCount >= backgroundRows) {
        _startJob(rec, spec, table, row, col, formulas, s.id);
        return _pending;
      }
      _cancelJob(rec.id);
      _computing = rec.id;
      try {
        result = const PivotEngine().compute(
          spec,
          table,
          _context(locale, s.id, row, col),
        );
      } finally {
        _computing = null;
      }
      grid = PivotLayout.build(result, labelText: display.displayText);
    }
    return _place(
      rec,
      s,
      placed,
      spec,
      source,
      row,
      col,
      result,
      grid,
      formulas,
    );
  }

  PivotContext _context(String locale, String sheetId, int row, int col) =>
      PivotContext(
        locale: locale,
        conditions: ConditionEvaluator(locale: locale, hooks: hooks),
        formulas: EnginePivotFormulaEvaluator(
          engine,
          sheetId: sheetId,
          row: row,
          col: col,
        ),
      );

  static bool _needsColors(PivotSpec spec) =>
      spec.filters.any((f) => f.criteria.hasColor);

  ({String? fill, String? text}) Function(int row, int col) _colorReader(
    String sheetId,
  ) {
    final formats = EffectiveFormatResolver(model);
    return (row, col) {
      final f = formats.resolve(sheetId, row, col);
      return (
        fill: formats.color(f.fillColor),
        text: formats.color(f.textColor),
      );
    };
  }

  /// Source rows (sheet indices) whose values changed since a pivot was
  /// computed, for an incremental refresh (07 §7.10, P2).
  final Map<String, Set<int>> _deltaRows = {};

  /// Pivots that changed in a way a delta can't express (structure, spec,
  /// formats, slicers, placement): computed anew.
  final Set<String> _full = {};

  /// Deltas applied since the last full computation (a full one follows
  /// after [maxDeltas] to bound floating-point drift).
  final Map<String, int> _deltaCount = {};

  /// Deltas in a row before a pivot is computed anew.
  static const maxDeltas = 64;

  /// Whether the last computation of a pivot was incremental (tests).
  @visibleForTesting
  bool lastWasDelta(String id) => (_deltaCount[id] ?? 0) > 0;

  /// The incremental refresh of [rec] when only values of known source rows
  /// changed and the aggregates are decomposable ([PivotEngine.applyDelta]);
  /// null computes anew.
  (PivotResult, PivotGrid)? _tryDelta(
    PivotTableRecord rec,
    ResolvedRange source,
    String sheetId,
    int row,
    int col,
  ) {
    final rows = _deltaRows.remove(rec.id);
    final full = _full.remove(rec.id);
    if (full || rows == null || rows.isEmpty) return null;
    final old = _outputs[rec.id];
    final prev = old?.result;
    if (old == null ||
        prev == null ||
        !identical(old.record, rec) ||
        _jobs.containsKey(rec.id) ||
        (_deltaCount[rec.id] ?? 0) >= maxDeltas ||
        prev.source.rowMask != null ||
        (rowMask ?? slicerMask)(source) != null ||
        !PivotEngine.supportsDelta(prev.spec)) {
      return null;
    }
    final sheet = model.sheet(source.sheetId);
    if (sheet == null) return null;
    final rect = SourceTable.clampToUsed(source, sheet.usedRect()?.bottom);
    final table = prev.source;
    if (rect != table.range ||
        rows.length > math.max(256, table.rowCount ~/ 10)) {
      return null;
    }
    final updates = <int, List<(CellValue, String?)>>{};
    _computing = rec.id;
    try {
      for (final r in rows) {
        if (r == rect.top) return null; // A header changed (field names).
        final i = r - rect.top - 1;
        if (i < 0 || i >= table.rowCount) continue;
        updates[i] = [
          for (final c in table.columns)
            (
              engine.valueAt(sheet.id, r, c.sheetCol).toCellValue(),
              engine.numberFormatAt(sheet.id, r, c.sheetCol),
            ),
        ];
      }
    } finally {
      _computing = null;
    }
    final locale = model.spreadsheet.locale;
    final out = const PivotEngine().applyDelta(
      prev,
      updates,
      _context(locale, sheetId, row, col),
    );
    if (out == null) return null;
    _deltaCount[rec.id] = (_deltaCount[rec.id] ?? 0) + 1;
    final display = FormatterDisplayText(locale: locale);
    return (out, PivotLayout.build(out, labelText: display.displayText));
  }

  /// Data rows of [source] (clamped to the used rows for whole columns).
  int _dataRows(ResolvedRange source) {
    final sheet = model.sheet(source.sheetId);
    if (sheet == null) return 0;
    return SourceTable.clampToUsed(source, sheet.usedRect()?.bottom).rowCount -
        1;
  }

  /// Cells read per slice of a background snapshot, between budget checks.
  final int snapshotSlice;

  /// Work per frame of a background snapshot.
  final Duration snapshotBudget;

  /// Reads [source] in slices (between frames); null when the job was
  /// cancelled or its source changed meanwhile (a new job follows).
  Future<SourceTable?> _snapshot(
    _PivotJob job,
    PivotSpec spec,
    ResolvedRange source,
  ) async {
    final display = FormatterDisplayText(locale: model.spreadsheet.locale);
    bool stopped() => _disposed || job.token.isCancelled || job.dirty;
    final b = SourceTableBuilder(
      model,
      engine,
      source,
      display,
      colorAt: _needsColors(spec) ? _colorReader(source.sheetId) : null,
    );
    while (true) {
      final sw = Stopwatch()..start();
      var done = false;
      _computing = job.record.id;
      try {
        do {
          done = b.step(snapshotSlice);
        } while (!done && sw.elapsed < snapshotBudget);
      } finally {
        _computing = null;
      }
      job.snapshotProgress = b.progress;
      if (done) break;
      await Future<void>.delayed(Duration.zero);
      if (stopped()) return null;
    }
    final table = b.build();
    final mask = (rowMask ?? slicerMask)(source);
    if (mask == null) return table;
    return SourceTable(
      sheetId: table.sheetId,
      range: table.range,
      columns: table.columns,
      display: table.display,
      rowMask: mask,
    );
  }

  bool _hasFormulas(ResolvedRange source) {
    final srcSheet = model.sheet(source.sheetId)!;
    for (final (_, _, cell) in srcSheet.cellsIn(
      source.rect,
      contentOnly: true,
    )) {
      if (cell.content?.startsWith('=') ?? false) return true;
    }
    return false;
  }

  /// Formula-backed parts (calculated fields, formula filter conditions)
  /// need the formula engine of this isolate.
  static bool _needsEngine(PivotSpec spec) =>
      spec.values.any((v) => v.isCalculated) ||
      spec.filters.any(
        (f) =>
            f.criteria.condition?.values.any((v) => v is ConditionFormula) ??
            false,
      );

  void _cancelJob(String id) {
    final job = _jobs.remove(id);
    if (job == null) return;
    job.token.cancel();
    running.value = _jobs.length;
  }

  void _startJob(
    PivotTableRecord rec,
    PivotSpec spec,
    SourceTable? table,
    int row,
    int col,
    bool formulas,
    String sheetId, {
    ResolvedRange? source,
  }) {
    final current = _jobs[rec.id];
    if (current != null && identical(current.record, rec) && !current.dirty) {
      return;
    }
    _cancelJob(rec.id);
    final job = _PivotJob(rec);
    _jobs[rec.id] = job;
    running.value = _jobs.length;
    final locale = model.spreadsheet.locale;
    Future<(PivotResult, PivotGrid)> aggregate(SourceTable table) {
      if (useIsolate && !_needsEngine(spec)) {
        return compute(_isolatePivot, (spec, table, locale));
      }
      final display = FormatterDisplayText(locale: locale);
      return () async {
        final r = await const PivotEngine().computeSliced(
          spec,
          table,
          _context(locale, sheetId, row, col),
          cancel: job.token,
        );
        return (r, PivotLayout.build(r, labelText: display.displayText));
      }();
    }

    final Future<(PivotResult, PivotGrid)?> work;
    if (table != null) {
      work = aggregate(table);
    } else {
      work = () async {
        final t = await _snapshot(job, spec, source!);
        return t == null ? null : aggregate(t);
      }();
    }
    unawaited(
      work.then(
        (v) {
          if (_disposed || _jobs[rec.id] != job || job.token.isCancelled) {
            return;
          }
          _jobs.remove(rec.id);
          running.value = _jobs.length;
          if (v == null || v.$1.cancelled) return;
          _ready[rec.id] = _Computed(rec, v.$1, v.$2, formulas);
          _dirty.add(rec.id);
          flush();
        },
        onError: (Object e) {
          if (_disposed || _jobs[rec.id] != job) return;
          _jobs.remove(rec.id);
          running.value = _jobs.length;
        },
      ),
    );
  }

  PivotOutput _place(
    PivotTableRecord rec,
    SheetModel s,
    List<GridRect> placed,
    PivotSpec spec,
    ResolvedRange source,
    int row,
    int col,
    PivotResult result,
    PivotGrid grid,
    bool formulas,
  ) {
    PivotOutput fail(
      PivotProblem p,
      String message, {
      CellPos? blocking,
      int missingRows = 0,
      int missingColumns = 0,
      GridRect? want,
      bool yielded = false,
      int spills = 0,
    }) => PivotOutput._(
      record: rec,
      spec: spec,
      anchorRow: row,
      anchorCol: col,
      source: source,
      result: result,
      error: ErrorValue(CellErrorKind.ref, message),
      problem: p,
      blocking: blocking,
      missingRows: missingRows,
      missingColumns: missingColumns,
      sourceHasFormulas: formulas,
      want: want,
      yielded: yielded,
      spillSignature: spills,
    );
    final anchorRect = GridRect.cell(row, col);
    if (grid.error != null) {
      return fail(
        PivotProblem.tooLarge,
        grid.error!.message ?? PivotGrid.tooLargeMessage,
        spills: Object.hashAll(_earlierSpills(s, row, col, anchorRect)),
      );
    }
    final out = PivotOutput._(
      record: rec,
      spec: spec,
      anchorRow: row,
      anchorCol: col,
      source: source,
      result: result,
      grid: grid,
      sourceHasFormulas: formulas,
    );
    if (grid.isEmpty) {
      return PivotOutput._(
        record: rec,
        spec: spec,
        anchorRow: row,
        anchorCol: col,
        source: source,
        result: result,
        grid: grid,
        sourceHasFormulas: formulas,
        spillSignature: Object.hashAll(_earlierSpills(s, row, col, anchorRect)),
      );
    }
    final rect = out.rect;
    final spills = _earlierSpills(s, row, col, rect);
    final spillSig = Object.hashAll(spills);
    final missingRows = rect.bottom - (s.rows.length - 1);
    final missingCols = rect.right - (s.columns.length - 1);
    if (missingRows > 0 || missingCols > 0) {
      return fail(
        PivotProblem.gridEdge,
        missingRows > 0
            ? 'The pivot table needs $missingRows more rows.'
            : 'The pivot table needs $missingCols more columns.',
        missingRows: missingRows > 0 ? missingRows : 0,
        missingColumns: missingCols > 0 ? missingCols : 0,
        want: rect,
        spills: spillSig,
      );
    }
    CellPos? blocking;
    for (final (r, c, _) in s.cellsIn(rect, contentOnly: true)) {
      blocking = CellPos(r, c);
      break;
    }
    if (blocking == null) {
      for (final p in placed) {
        final i = p.intersection(rect);
        if (i != null) {
          blocking = CellPos(i.top, i.left);
          break;
        }
      }
    }
    var yielded = false;
    if (blocking == null) {
      // A dynamic array anchored earlier wins the overlap (05 §7.5).
      for (final a in spills) {
        final i = a.rect.intersection(rect)!;
        blocking = CellPos(i.top, i.left);
        yielded = a.rect.contains(row, col);
        break;
      }
    }
    if (blocking != null) {
      return fail(
        PivotProblem.collision,
        'Pivot table results would overwrite data in ${blocking.a1}. '
        'Remove that data or move the pivot table.',
        blocking: blocking,
        want: rect,
        yielded: yielded,
        spills: spillSig,
      );
    }
    return PivotOutput._(
      record: rec,
      spec: spec,
      anchorRow: row,
      anchorCol: col,
      source: source,
      result: result,
      grid: grid,
      sourceHasFormulas: formulas,
      want: rect,
      spillSignature: spillSig,
    );
  }

  /// Dynamic arrays anchored before ([row], [col]) whose area overlaps
  /// [rect]; a `#SPILL!` array that content blocks anyway doesn't count.
  List<SpillArea> _earlierSpills(
    SheetModel s,
    int row,
    int col,
    GridRect rect,
  ) => [
    for (final a in engine.spillAreas(s.id))
      if ((a.row < row || (a.row == row && a.col < col)) &&
          a.rect.intersects(rect) &&
          !(a.blocked && _contentBlocks(s, a)))
        a,
  ];

  static bool _contentBlocks(SheetModel s, SpillArea a) {
    for (final (r, c, _) in s.cellsIn(a.rect, contentOnly: true)) {
      if (r != a.row || c != a.col) return true;
    }
    return false;
  }

  /// Re-places pivots whose overlapping earlier dynamic arrays changed
  /// (an array grew into the output, was removed, or got blocked).
  void _checkSpills() {
    if (_disposed) return;
    final now = <String>{};
    for (final o in _outputs.values) {
      final s = model.sheet(o.sheetId);
      if (s == null) continue;
      final sig = Object.hashAll(
        _earlierSpills(s, o.anchorRow, o.anchorCol, o.wantRect),
      );
      if (sig != o.spillSignature) now.add(o.id);
    }
    if (now.isEmpty) return;
    _dirty.addAll(now);
    flush();
  }

  // ---------------------------------------------------------------------------
  // Change tracking.

  void _onBatch(WorkbookChangeBatch batch) {
    final now = <String>{};
    final later = <String>{};
    final deltas = <String, Set<int>>{};
    for (final e in batch.events) {
      switch (e) {
        case RulesChanged(:final kind, :final ruleIds)
            when kind == RuleKind.pivot:
          now.addAll(ruleIds);
        case RulesChanged(:final sheetId, :final kind, :final ruleIds)
            when kind == RuleKind.object && _touchesSlicers(sheetId, ruleIds):
          // A slicer changed (criteria, range, deleted): pivots on its data.
          later.addAll(_outputs.keys);
        case SheetsChanged():
          now.addAll(_outputs.keys);
          now.addAll(_allRecords().map((r) => r.id));
        case StructureChanged(:final sheetId) when e.order:
          for (final o in _outputs.values) {
            // Anchors move with inserted/deleted rows: place them now.
            if (o.sheetId == sheetId) now.add(o.id);
            if (o.source?.sheetId == sheetId) later.add(o.id);
          }
        case StructureChanged():
          break;
        case CellsChanged(:final sheetId):
          if (e.contentKeys.isEmpty && e.formatKeys.isEmpty) break;
          _cellsChanged(sheetId, e, later, now, deltas);
          _formulasTyped(sheetId, e);
        case SpreadsheetChanged():
          later.addAll(_outputs.keys);
        case NamesChanged():
        case RulesChanged():
        case OtherRowsChanged():
          break;
      }
    }
    // Only pivots whose sole change is source values may refresh
    // incrementally.
    for (final id in {...now, ...later}) {
      if (!deltas.containsKey(id) || now.contains(id)) _full.add(id);
    }
    for (final MapEntry(key: id, value: rows) in deltas.entries) {
      (_deltaRows[id] ??= {}).addAll(rows);
    }
    if (now.isNotEmpty) {
      _dirty.addAll(now);
      flush();
    }
    later.removeAll(now);
    if (later.isNotEmpty) markDirty(later);
  }

  final Map<String, Set<CellPos>> _typedFormulas = {};
  bool _spillCheckScheduled = false;

  /// Formulas typed on a sheet with pivots may spill into an output: they
  /// are evaluated and the earlier-anchor rule re-checked after the batch
  /// (the engine is pull-based; recalc batches only come from drains).
  void _formulasTyped(String sheetId, CellsChanged e) {
    if (e.contentKeys.isEmpty) return;
    if (!_outputs.values.any((o) => o.sheetId == sheetId)) return;
    final s = model.sheet(sheetId);
    if (s == null) return;
    var n = 0;
    for (final k in e.contentKeys) {
      if (++n > 2000) break;
      final r = s.rows.indexOf(k.rowId);
      final c = s.columns.indexOf(k.colId);
      if (r < 0 || c < 0) continue;
      if (s.cellAt(r, c)?.content?.startsWith('=') ?? false) {
        (_typedFormulas[sheetId] ??= {}).add(CellPos(r, c));
      }
    }
    if (_spillCheckScheduled) return;
    _spillCheckScheduled = true;
    scheduleMicrotask(() {
      _spillCheckScheduled = false;
      if (_disposed) return;
      for (final MapEntry(key: sid, value: cells) in _typedFormulas.entries) {
        if (model.sheet(sid) == null) continue;
        for (final p in cells) {
          engine.computedAt(sid, p.row, p.col);
        }
      }
      _typedFormulas.clear();
      _checkSpills();
    });
  }

  final Set<String> _knownSlicers = {};

  /// Whether [ids] are (or were) slicers on [sheetId].
  bool _touchesSlicers(String sheetId, Set<String> ids) {
    final s = model.sheet(sheetId);
    var hit = false;
    for (final id in ids) {
      final o = s?.objects[id];
      if (o == null) {
        if (_knownSlicers.remove(id)) hit = true;
      } else if (o.kind == EmbeddedObjectKind.slicer) {
        _knownSlicers.add(id);
        hit = true;
      }
    }
    return hit;
  }

  void _cellsChanged(
    String sheetId,
    CellsChanged e,
    Set<String> later,
    Set<String> now,
    Map<String, Set<int>> deltas,
  ) {
    final s = model.sheet(sheetId);
    if (s == null) return;
    final keys = e.contentKeys.isEmpty ? e.formatKeys : e.allKeys;
    for (final o in _outputs.values) {
      final src = o.source;
      var hit = false;
      // Content-only edits inside the source are value deltas (07 §7.10).
      final valuesOnly = e.formatKeys.isEmpty && !o.sourceHasFormulas;
      if (src != null && src.sheetId == sheetId) {
        final rect = src.rect;
        for (final k in keys) {
          final r = s.rows.indexOf(k.rowId);
          final c = s.columns.indexOf(k.colId);
          if (rect.contains(r, c)) {
            hit = true;
            if (!valuesOnly) break;
            (deltas[o.id] ??= {}).add(r);
          }
        }
        if (!valuesOnly) deltas.remove(o.id);
      }
      if (!hit && o.sheetId == sheetId && e.contentKeys.isNotEmpty) {
        // Typing where the output is (or would be) changes collisions.
        final blockedHere = o.problem == PivotProblem.collision;
        for (final k in e.contentKeys) {
          final r = s.rows.indexOf(k.rowId);
          final c = s.columns.indexOf(k.colId);
          if (blockedHere || o.rect.contains(r, c)) {
            now.add(o.id);
            break;
          }
        }
      }
      if (!hit && o.sourceHasFormulas && e.contentKeys.isNotEmpty) {
        // Formulas in the source may read the changed cells.
        hit = true;
      }
      if (hit) later.add(o.id);
    }
  }

  void _onRecalc(RecalcBatch batch) {
    if (_outputs.isNotEmpty) scheduleMicrotask(_checkSpills);
    if (batch.cells.isEmpty) return;
    final hits = <String>{};
    for (final o in _outputs.values) {
      final src = o.source;
      if (src == null) continue;
      for (final c in batch.cells) {
        if (c.sheetId == src.sheetId &&
            src.rect.contains(c.row, c.col) &&
            !o.rect.contains(c.row, c.col)) {
          hits.add(o.id);
          // Recalculated source values: a value delta (07 §7.10).
          (_deltaRows[o.id] ??= {}).add(c.row);
        }
      }
    }
    if (hits.isNotEmpty) markDirty(hits);
  }
}

/// A background computation of one pivot.
final class _PivotJob {
  _PivotJob(this.record);

  final PivotTableRecord record;
  final CancellationToken token = CancellationToken();

  /// The source changed while it ran: a new job replaces it.
  bool dirty = false;

  /// Share of the source read so far (sliced snapshots).
  double snapshotProgress = 0;
}

/// A finished background computation waiting to be placed.
final class _Computed {
  _Computed(this.record, this.result, this.grid, this.sourceHasFormulas);

  final PivotTableRecord record;
  final PivotResult result;
  final PivotGrid grid;
  final bool sourceHasFormulas;
}

/// Isolate entry of a background pivot without formula-backed parts.
(PivotResult, PivotGrid) _isolatePivot((PivotSpec, SourceTable, String) a) {
  final (spec, table, locale) = a;
  final display = FormatterDisplayText(locale: locale);
  final r = const PivotEngine().compute(
    spec,
    table,
    PivotContext(locale: locale),
  );
  return (r, PivotLayout.build(r, labelText: display.displayText));
}
