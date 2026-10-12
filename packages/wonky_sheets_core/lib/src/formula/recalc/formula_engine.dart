import 'dart:async';
import 'dart:collection';

import '../../addressing/grid_geometry.dart';
import '../codec/formula_codec.dart';
import '../codec/ref_resolver.dart';
import '../codec/ref_token.dart';
import '../eval/compiler.dart';
import '../eval/eval_context.dart';
import '../eval/lambda.dart';
import '../eval/range_access.dart';
import '../eval/runtime_services.dart';
import '../external/external_data.dart';
import '../functions/registry.dart';
import '../functions/text/number_text_formatter.dart';
import '../graph/range_index.dart';
import '../model/workbook_view.dart';
import '../parser/formula_locale.dart';
import '../values/errors.dart';
import '../values/format_hint.dart';
import '../values/fvalue.dart';
import 'engine_types.dart';

/// Engine version stored with cached values (05 §12). Bump on behavior changes.
const String engineVersion = '1.0.0';

final class _NeedsPrecedent implements EvaluationInterrupt {
  final _Node node;
  _NeedsPrecedent(this.node);
}

final class _Aborted implements EvaluationInterrupt {}

final class _CycleGroup {
  _Node root;
  final Set<_Node> members = {};
  bool iterating = false;
  _CycleGroup(this.root);
}

/// Dependency entry: single cell (by ids) or id-bounded range.
sealed class _Dep {
  const _Dep();
}

final class _CellDep extends _Dep {
  final String sheetId;
  final String rowId;
  final String colId;
  final String key;
  _CellDep(this.sheetId, this.rowId, this.colId) : key = '$sheetId\u0001$rowId\u0001$colId';
  @override
  bool operator ==(Object other) => other is _CellDep && other.key == key;
  @override
  int get hashCode => key.hashCode;
}

final class _RangeDep extends _Dep {
  final IdRange range;
  const _RangeDep(this.range);
  @override
  bool operator ==(Object other) => other is _RangeDep && other.range == range;
  @override
  int get hashCode => range.hashCode;
}

final class _Node {
  final String sheetId;
  final String rowId;
  final String colId;
  final String key;
  CellInput input;
  late String formula;
  late CompiledFormula compiled;
  late List<StoredRef> slots;

  FValue value = FEmpty.instance;
  FValue result = FEmpty.instance;
  FormatHint hint = FormatHint.none;
  bool dirty = true;
  bool evaluating = false;
  bool waiting = false;
  bool cyclic = false;
  bool hasValue = false;
  bool removed = false;
  _CycleGroup? group;

  // spill
  int spillRows = 0;
  int spillCols = 0;
  FArray? spillArray;
  int wantRows = 0;
  int wantCols = 0;

  List<_Dep> staticDeps = const [];
  List<_Dep> dynamicDeps = const [];
  Set<String> nameDeps = const {};
  bool axisDep = false;
  Set<String> axisSheets = const {};
  bool sheetNamesDep = false;
  bool filterDep = false;
  bool volatile = false;
  Set<String> customDeps = const {};

  _Node(this.sheetId, this.rowId, this.colId, this.input)
    : key = '$sheetId\u0001$rowId\u0001$colId';

  bool get onChain => evaluating || waiting;
  bool get spills => spillRows > 0;
}

final class _SpillTable {
  final Set<_Node> hosts = {};
  final Set<_Node> blocked = {};
  List<(GridRect, _Node)>? cache;
}

/// The formula engine facade (05 §7.1): change ingestion, incremental recalculation, value
/// reads, headless evaluation, dependency queries. Implements [CellSource] over computed
/// values.
final class FormulaEngine implements EvalHost, CellSource {
  @override
  final WorkbookView workbook;
  @override
  final FunctionRegistry registry;
  @override
  final EngineClock clock;
  @override
  final ExternalDataProvider? external;
  @override
  final CustomFunctionProvider? customFunctions;
  @override
  PivotDataProvider? pivots;
  @override
  final TimeZoneResolver timeZones;
  @override
  NumberTextFormatter textFormatter;
  final EngineConfig config;
  final FormulaCompiler compiler;

  final Map<String, _Node> _nodes = {};
  final Map<String, Set<_Node>> _nodesBySheet = {};
  final Map<String, Set<_Node>> _cellDeps = {};
  final Map<String, Set<_CellDep>> _cellDepKeysBySheet = {};
  final Map<String, RangeIndex<IdRange, _Node>> _rangeIndexes = {};
  final Map<String, Set<_Node>> _nameDeps = {};
  final Map<String, Set<_Node>> _axisDeps = {};
  final Set<_Node> _sheetNameDeps = {};
  final Map<String, Set<_Node>> _filterDeps = {};
  final Set<_Node> _volatile = {};
  final Map<String, Set<_Node>> _customDeps = {};
  final Map<ExternalKey, Set<_Node>> _externalDeps = {};
  final Map<String, _SpillTable> _spills = {};
  final Map<String, (String, FCallable?)> _namedFunctions = {};
  final Map<String, NamedRangeView>? _namesCache = {};
  bool _namesDirty = true;

  final LinkedHashSet<_Node> _dirty = LinkedHashSet();
  final List<_Node> _evalStack = [];
  final List<_Node> _waitStack = [];
  int _depth = 0;
  bool _loaded = false;
  String? _epochOverride;
  int _changeCounter = 0;
  Viewport? _viewport;

  final List<ChangedCell> _changed = [];
  final Map<String, List<GridRect>> _changedSpills = {};
  final StreamController<RecalcBatch> _changes = StreamController.broadcast(sync: true);
  final List<StreamSubscription<Object?>> _subscriptions = [];
  CalcSettings _settings;
  FormulaLocale _locale;
  bool Function()? _abort;

  FormulaEngine({
    required this.workbook,
    FunctionRegistry? registry,
    EngineClock? clock,
    this.external,
    this.customFunctions,
    this.pivots,
    TimeZoneResolver? timeZones,
    NumberTextFormatter? textFormatter,
    this.config = const EngineConfig(),
  }) : registry = registry ?? FunctionRegistry.standard,
       clock = clock ?? SystemEngineClock(),
       timeZones = timeZones ?? const TzDatabaseResolver(),
       textFormatter = textFormatter ?? const BuiltinNumberTextFormatter(),
       compiler = FormulaCompiler(
         registry ?? FunctionRegistry.standard,
         templateCapacity: config.templateCapacity,
       ),
       _settings = workbook.settings,
       _locale = FormulaLocale.forId(workbook.settings.locale) {
    final ext = external;
    if (ext != null) {
      _subscriptions.add(ext.updates.listen(_onExternalUpdate));
    }
    final cf = customFunctions;
    if (cf != null) {
      _subscriptions.add(cf.updates.listen(_onCustomUpdate));
    }
  }

  /// Releases stream subscriptions.
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _changes.close();
  }

  // ====================================================================== EvalHost

  @override
  FormulaLocale get locale => _locale;

  @override
  CalcSettings get settings => _settings;

  @override
  String get randomEpoch => _epochOverride ?? '$_changeCounter';

  /// Sets the RAND epoch (id of the newest ChangeLog row + timer bucket, 05 §12).
  void setRandomEpoch(String epoch) {
    if (_epochOverride == epoch) return;
    _epochOverride = epoch;
    _dirtyVolatile();
  }

  @override
  FValue cellValue(SheetView sheet, int row, int col) {
    final input = sheet.inputAt(row, col);
    if (input == null) return _overlayValue(sheet, row, col) ?? FEmpty.instance;
    if (!input.isFormula) return input.value;
    final node = _nodeForInput(sheet, row, col, input);
    return _require(node);
  }

  @override
  FormatHint cellHint(SheetView sheet, int row, int col) {
    final f = sheet.numberFormatAt(row, col);
    if (f != null) return FormatHint.fromCell(f);
    final input = sheet.inputAt(row, col);
    if (input != null && input.isFormula) {
      final node = _nodeForInput(sheet, row, col, input);
      return node.hint;
    }
    if (input == null) {
      final host = _overlayHost(sheet, row, col);
      if (host != null) {
        final v = _overlayElement(sheet, host, row, col);
        if (v is FNumber) return v.hint;
      }
    }
    return FormatHint.none;
  }

  @override
  void forEachValue(SheetView sheet, GridRect rect, void Function(int row, int col, FValue v) visit) {
    var n = 0;
    final abort = _abort;
    sheet.forEachInput(rect, (r, c, input) {
      if (abort != null && (++n & 4095) == 0 && abort()) throw _Aborted();
      if (!input.isFormula) {
        visit(r, c, input.value);
        return;
      }
      final node = _nodeForInput(sheet, r, c, input);
      final v = _require(node);
      if (v is! FEmpty) visit(r, c, v);
    });
    final table = _spills[sheet.id];
    if (table == null || table.hosts.isEmpty) return;
    for (final (hr, host) in _spillRects(sheet, table)) {
      final inter = hr.intersection(rect);
      if (inter == null) continue;
      final arr = host.spillArray;
      if (arr == null) continue;
      final hostRow = hr.top, hostCol = hr.left;
      for (var r = inter.top; r <= inter.bottom; r++) {
        for (var c = inter.left; c <= inter.right; c++) {
          if (r == hostRow && c == hostCol) continue;
          final v = arr.at(r - hostRow, c - hostCol);
          if (v is! FEmpty) visit(r, c, v);
        }
      }
    }
  }

  @override
  int usedRows(SheetView sheet) {
    var u = sheet.usedRowCount;
    final t = _spills[sheet.id];
    if (t != null && t.hosts.isNotEmpty) {
      for (final (r, _) in _spillRects(sheet, t)) {
        if (r.bottom + 1 > u) u = r.bottom + 1;
      }
    }
    return u;
  }

  @override
  int usedColumns(SheetView sheet) {
    var u = sheet.usedColumnCount;
    final t = _spills[sheet.id];
    if (t != null && t.hosts.isNotEmpty) {
      for (final (r, _) in _spillRects(sheet, t)) {
        if (r.right + 1 > u) u = r.right + 1;
      }
    }
    return u;
  }

  @override
  String? formulaAt(SheetView sheet, int row, int col) => sheet.inputAt(row, col)?.formula;

  void _refreshNames() {
    if (!_namesDirty) return;
    _namesCache!.clear();
    // Smaller id wins for duplicate names (07 §8.3).
    final sorted = workbook.namedRanges.toList()..sort((a, b) => a.id.compareTo(b.id));
    for (final n in sorted) {
      _namesCache.putIfAbsent(n.name.toUpperCase(), () => n);
    }
    _namesDirty = false;
  }

  @override
  NamedRangeView? namedRange(String name) {
    _refreshNames();
    return _namesCache![name.toUpperCase()];
  }

  @override
  FCallable? namedFunction(String upperName) {
    final nr = namedRange(upperName);
    if (nr == null || nr.formula == null || nr.range != null) return null;
    final formula = nr.formula!;
    final cached = _namedFunctions[upperName];
    if (cached != null && cached.$1 == formula) return cached.$2;
    FCallable? fn;
    final compiled = compiler.compileText(formula.startsWith('=') ? formula.substring(1) : formula);
    if (workbook.sheets.isNotEmpty) {
      final ctx = EvalContext(host: this, sheet: workbook.sheets.first, row: 0, col: 0);
      final v = compiled.root(ctx);
      if (v is FLambda) {
        final c = v.closure;
        fn = c is LambdaClosure ? LambdaClosure(c.params, c.body, c.captured, name: nr.name) : c;
      }
    }
    _namedFunctions[upperName] = (formula, fn);
    return fn;
  }

  @override
  bool isRowHidden(SheetView sheet, int row, {required bool includeUserHidden}) {
    if (sheet.isRowFilterHidden(row)) return true;
    return includeUserHidden && sheet.rows.isHidden(row);
  }

  // ====================================================================== CellSource

  @override
  FValue valueAt(String sheetId, int row, int col) => computedAt(sheetId, row, col).value;

  @override
  String? numberFormatAt(String sheetId, int row, int col) {
    final s = workbook.sheetById(sheetId);
    if (s == null) return null;
    final f = s.numberFormatAt(row, col);
    if (f != null) return f;
    final h = cellHint(s, row, col);
    return switch (h.kind) {
      FormatHintKind.fromCell => h.detail,
      FormatHintKind.none => null,
      _ => 'preset:${h.code}',
    };
  }

  @override
  bool isHidden(String sheetId, GridDimension dimension, int index, {bool includeFilter = true}) {
    final s = workbook.sheetById(sheetId);
    if (s == null) return false;
    if (dimension == GridDimension.rows) {
      if (includeFilter && s.isRowFilterHidden(index)) return true;
      return s.rows.isHidden(index);
    }
    return s.columns.isHidden(index);
  }

  // ====================================================================== reading

  /// Computed value; dirty formula cells are evaluated on demand (pull).
  ComputedValue computedAt(String sheetId, int row, int col) {
    _ensureLoaded();
    final sheet = workbook.sheetById(sheetId);
    if (sheet == null) return ComputedValue.empty;
    final input = sheet.inputAt(row, col);
    if (input == null) {
      final host = _overlayHost(sheet, row, col);
      if (host == null) return ComputedValue.empty;
      _ensureClean(host);
      final v = _overlayElement(sheet, host, row, col) ?? FEmpty.instance;
      return ComputedValue(v, hint: v is FNumber ? v.hint : FormatHint.none);
    }
    if (!input.isFormula) return ComputedValue(input.value);
    final node = _nodeForInput(sheet, row, col, input);
    _ensureClean(node);
    return _computed(node, sheet);
  }

  ComputedValue _computed(_Node node, SheetView sheet) {
    SpillInfo? spill;
    if (node.spills) {
      final r = sheet.rows.indexOf(node.rowId), c = sheet.columns.indexOf(node.colId);
      spill = SpillInfo(
        node.spillRows,
        node.spillCols,
        GridRect(r, c, r + node.spillRows - 1, c + node.spillCols - 1),
      );
    }
    return ComputedValue(node.value, hint: node.hint, spill: spill, stale: node.dirty);
  }

  /// Like [computedAt] but never evaluates (painting). Null when the cell is dirty and has no
  /// previous value.
  ComputedValue? peekValueAt(String sheetId, int row, int col) {
    final sheet = workbook.sheetById(sheetId);
    if (sheet == null) return null;
    final input = sheet.inputAt(row, col);
    if (input == null) {
      final host = _overlayHost(sheet, row, col);
      if (host == null) return ComputedValue.empty;
      final v = _overlayElement(sheet, host, row, col) ?? FEmpty.instance;
      return ComputedValue(v, stale: host.dirty);
    }
    if (!input.isFormula) return ComputedValue(input.value);
    final node = _nodes['${sheet.id}\u0001${sheet.rows.idAt(row)}\u0001${sheet.columns.idAt(col)}'];
    if (node == null || (!node.hasValue && node.dirty)) return null;
    return _computed(node, sheet);
  }

  /// Spill overlay content at a cell, or null.
  OverlayCell? overlayAt(String sheetId, int row, int col) {
    final sheet = workbook.sheetById(sheetId);
    if (sheet == null || sheet.inputAt(row, col) != null) return null;
    final host = _overlayHost(sheet, row, col);
    if (host == null) return null;
    final hr = sheet.rows.indexOf(host.rowId), hc = sheet.columns.indexOf(host.colId);
    return OverlayCell(sheetId, hr, hc, _overlayElement(sheet, host, row, col) ?? FEmpty.instance);
  }

  /// Whether no recalculation work is pending.
  bool get isIdle {
    _ensureLoaded();
    return _dirty.isEmpty;
  }

  /// Number of dirty formula cells.
  int get pendingCount => _dirty.length;

  /// Number of formula cells known to the engine.
  int get formulaCount {
    _ensureLoaded();
    return _nodes.length;
  }

  /// Changed cells per drain slice.
  Stream<RecalcBatch> get changes => _changes.stream;

  // ====================================================================== control

  /// Sets the priority viewport.
  void setViewport(String sheetId, GridRect visible) => _viewport = Viewport(sheetId, visible);

  /// Evaluates dirty cells until [budget] is exhausted (viewport first, 05 §10).
  RecalcBudgetResult drain(Duration budget, {Viewport? priority}) {
    _ensureLoaded();
    final sw = Stopwatch()..start();
    var evaluated = 0;
    final vp = priority ?? _viewport;
    if (vp != null) {
      final sheet = workbook.sheetById(vp.sheetId);
      if (sheet != null) {
        final inView = <_Node>[];
        for (final n in _dirty) {
          if (n.sheetId != vp.sheetId) continue;
          final r = sheet.rows.indexOf(n.rowId), c = sheet.columns.indexOf(n.colId);
          if (vp.rect.contains(r, c)) inView.add(n);
        }
        for (final n in inView) {
          _ensureClean(n);
          evaluated++;
          if (evaluated % config.budgetCheckInterval == 0 && sw.elapsed > budget) break;
        }
      }
    }
    while (_dirty.isNotEmpty) {
      if (evaluated % config.budgetCheckInterval == 0 && evaluated > 0 && sw.elapsed > budget) {
        break;
      }
      final n = _dirty.first;
      _ensureClean(n);
      evaluated++;
    }
    _emit();
    return RecalcBudgetResult(evaluated, _dirty.length);
  }

  /// Evaluates everything that is dirty (unbounded).
  void settle() => drain(const Duration(days: 1));

  /// Dirties every formula (incl. volatile, custom functions) and recalculates cooperatively.
  Future<void> recalcAll({CancellationToken? cancel}) async {
    _ensureLoaded();
    for (final n in _nodes.values) {
      _markDirty(n);
    }
    while (_dirty.isNotEmpty) {
      if (cancel?.isCancelled ?? false) return;
      drain(const Duration(milliseconds: 16));
      if (_dirty.isNotEmpty) await Future<void>.delayed(Duration.zero);
    }
  }

  /// Dirties all formulas (sync variant of [recalcAll] without draining).
  void invalidateAll() {
    _ensureLoaded();
    for (final n in _nodes.values) {
      _markDirty(n);
    }
  }

  /// Timer tick for NOW/TODAY/RAND (recalc modes, midnight).
  void tick() => _dirtyVolatile();

  void _emit() {
    if (_changed.isEmpty && _changedSpills.isEmpty) return;
    final batch = RecalcBatch(List.of(_changed), Map.of(_changedSpills));
    _changed.clear();
    _changedSpills.clear();
    if (_changes.hasListener) _changes.add(batch);
  }

  // ====================================================================== change ingestion

  void _ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    for (final sheet in workbook.sheets) {
      final rect = GridRect(0, 0, sheet.usedRowCount - 1, sheet.usedColumnCount - 1);
      if (rect.bottom < 0 || rect.right < 0) continue;
      sheet.forEachInput(rect, (r, c, input) {
        if (input.isFormula) _createNode(sheet, r, c, input);
      });
    }
  }

  /// Content of cells changed (local or remote).
  void cellsChanged(String sheetId, Iterable<CellPos> cells) {
    _changeCounter++;
    if (!_loaded) {
      _ensureLoaded();
      _dirtyVolatile();
      return;
    }
    final sheet = workbook.sheetById(sheetId);
    if (sheet == null) return;
    final work = Queue<_Node>();
    for (final p in cells) {
      if (p.row < 0 || p.col < 0 || p.row >= sheet.rows.length || p.col >= sheet.columns.length) {
        continue;
      }
      _cellChanged(sheet, p.row, p.col, work);
    }
    _dirtyVolatile(work);
    _propagate(work);
  }

  /// Bulk variant over a rectangle (paste, import).
  void rectChanged(String sheetId, GridRect rect) {
    final sheet = workbook.sheetById(sheetId);
    if (sheet == null) return;
    if (!_loaded) {
      _ensureLoaded();
      return;
    }
    _changeCounter++;
    final work = Queue<_Node>();
    // Existing nodes in the rect may have been removed.
    final existing = _nodesBySheet[sheetId];
    if (existing != null) {
      for (final n in existing.toList()) {
        final r = sheet.rows.indexOf(n.rowId), c = sheet.columns.indexOf(n.colId);
        if (rect.contains(r, c)) {
          final input = sheet.inputAt(r, c);
          if (input == null || !input.isFormula) _removeNode(n, work);
        }
      }
    }
    sheet.forEachInput(rect, (r, c, input) {
      if (!input.isFormula) return;
      final key = '$sheetId\u0001${sheet.rows.idAt(r)}\u0001${sheet.columns.idAt(c)}';
      final n = _nodes[key];
      if (n == null) {
        _markDirty(_createNode(sheet, r, c, input), work);
      } else if (!identical(n.input, input)) {
        _updateNode(n, input);
        _markDirty(n, work);
      }
    });
    _dirtyRect(sheet, rect, work);
    _dirtyVolatile(work);
    _propagate(work);
  }

  void _cellChanged(SheetView sheet, int row, int col, Queue<_Node> work) {
    final rowId = sheet.rows.idAt(row), colId = sheet.columns.idAt(col);
    final key = '${sheet.id}\u0001$rowId\u0001$colId';
    final input = sheet.inputAt(row, col);
    final existing = _nodes[key];
    if (input != null && input.isFormula) {
      if (existing == null) {
        _markDirty(_createNode(sheet, row, col, input), work);
      } else {
        if (!identical(existing.input, input)) _updateNode(existing, input);
        _markDirty(existing, work);
      }
    } else if (existing != null) {
      _removeNode(existing, work);
    }
    _dirtyCellDependents(sheet, row, col, rowId, colId, work);
    // Typing into (or clearing) a spill area blocks/unblocks the host.
    final t = _spills[sheet.id];
    if (t != null) {
      for (final (r, host) in _spillRects(sheet, t)) {
        if (r.contains(row, col) && host.key != key) _markDirty(host, work);
      }
      for (final b in t.blocked.toList()) {
        final br = sheet.rows.indexOf(b.rowId), bc = sheet.columns.indexOf(b.colId);
        if (br < 0 || bc < 0) continue;
        if (GridRect(br, bc, br + b.wantRows - 1, bc + b.wantCols - 1).contains(row, col)) {
          _markDirty(b, work);
        }
      }
    }
  }

  /// Structural change of an axis (05 §9.1).
  void axisChanged(String sheetId, GridDimension dim, AxisChange change) {
    _changeCounter++;
    if (!_loaded) {
      _ensureLoaded();
      return;
    }
    final sheet = workbook.sheetById(sheetId);
    _rangeIndexes[sheetId]?.invalidate();
    _spills[sheetId]?.cache = null;
    final work = Queue<_Node>();
    if (sheet == null) return;
    if (change.kind == AxisChangeKind.deleted && change.ids.isNotEmpty) {
      final deleted = change.ids.toSet();
      // formula cells in deleted rows/columns disappear
      final nodes = _nodesBySheet[sheetId];
      if (nodes != null) {
        for (final n in nodes.toList()) {
          final id = dim == GridDimension.rows ? n.rowId : n.colId;
          if (deleted.contains(id)) _removeNode(n, work);
        }
      }
      // single-cell references on deleted ids → #REF!
      final keys = _cellDepKeysBySheet[sheetId];
      if (keys != null) {
        for (final d in keys) {
          final id = dim == GridDimension.rows ? d.rowId : d.colId;
          if (deleted.contains(id)) {
            for (final n in _cellDeps[d.key] ?? const <_Node>{}) {
              _markDirty(n, work);
            }
          }
        }
      }
      // ranges whose endpoint was deleted, or spanning the deletion point
      final idx = _rangeIndexes[sheetId];
      if (idx != null) {
        for (final k in idx.keysWhere((r) {
          final ids = dim == GridDimension.rows ? [r.rowStart, r.rowEnd] : [r.colStart, r.colEnd];
          return ids.any((e) => e != null && deleted.contains(e));
        }).toList()) {
          for (final n in idx.nodesOf(k) ?? const <_Node>{}) {
            _markDirty(n, work);
          }
        }
      }
      _dirtyAxisBand(sheet, dim, change.index - 1, change.index, work);
    } else if (change.kind == AxisChangeKind.inserted) {
      _dirtyAxisBand(sheet, dim, change.index - 1, change.index + change.count, work);
    } else if (change.kind == AxisChangeKind.moved) {
      // Coverage of ranges with endpoints among moved ids changes; be conservative.
      _dirtySheetReaders(sheetId, work);
    }
    for (final n in _axisDeps[sheetId] ?? const <_Node>{}) {
      _markDirty(n, work);
    }
    // Spill collisions may change when rows appear/disappear inside spill areas.
    final t = _spills[sheetId];
    if (t != null) {
      for (final h in [...t.hosts, ...t.blocked]) {
        _markDirty(h, work);
      }
    }
    _dirtyVolatile(work);
    _propagate(work);
  }

  void _dirtyAxisBand(SheetView sheet, GridDimension dim, int from, int to, Queue<_Node> work) {
    final rect = dim == GridDimension.rows
        ? GridRect(from < 0 ? 0 : from, 0, to < 0 ? 0 : to, sheet.columns.length)
        : GridRect(0, from < 0 ? 0 : from, sheet.rows.length, to < 0 ? 0 : to);
    _rangeIndexes[sheet.id]?.intersect(rect, (n) => _markDirty(n, work));
  }

  void _dirtySheetReaders(String sheetId, Queue<_Node> work) {
    final idx = _rangeIndexes[sheetId];
    if (idx != null) {
      for (final k in idx.keysWhere((_) => true).toList()) {
        for (final n in idx.nodesOf(k) ?? const <_Node>{}) {
          _markDirty(n, work);
        }
      }
    }
    for (final d in _cellDepKeysBySheet[sheetId] ?? const <_CellDep>{}) {
      for (final n in _cellDeps[d.key] ?? const <_Node>{}) {
        _markDirty(n, work);
      }
    }
  }

  /// Sheets added, removed, renamed or reordered.
  void sheetsChanged() {
    _changeCounter++;
    if (!_loaded) {
      _ensureLoaded();
      return;
    }
    final work = Queue<_Node>();
    final alive = {for (final s in workbook.sheets) s.id};
    for (final n in _nodes.values.toList()) {
      if (!alive.contains(n.sheetId)) _removeNode(n, work);
    }
    // Discover formulas of new sheets.
    for (final sheet in workbook.sheets) {
      if (_nodesBySheet.containsKey(sheet.id)) continue;
      final rect = GridRect(0, 0, sheet.usedRowCount - 1, sheet.usedColumnCount - 1);
      if (rect.bottom < 0 || rect.right < 0) continue;
      sheet.forEachInput(rect, (r, c, input) {
        if (input.isFormula) {
          final key = '${sheet.id}\u0001${sheet.rows.idAt(r)}\u0001${sheet.columns.idAt(c)}';
          if (!_nodes.containsKey(key)) _markDirty(_createNode(sheet, r, c, input), work);
        }
      });
    }
    for (final idx in _rangeIndexes.values) {
      idx.invalidate();
    }
    for (final t in _spills.values) {
      t.cache = null;
    }
    for (final n in _nodes.values) {
      _markDirty(n, work);
    }
    _propagate(work);
  }

  /// Named ranges/functions changed (definition, rename, delete).
  void namesChanged(Set<String> names) {
    _changeCounter++;
    _namesDirty = true;
    final work = Queue<_Node>();
    for (final name in names) {
      final u = name.toUpperCase();
      _namedFunctions.remove(u);
      for (final n in _nameDeps[u] ?? const <_Node>{}) {
        _markDirty(n, work);
      }
    }
    _propagate(work);
  }

  /// Locale, time zone, iterative calculation, recalc mode.
  void settingsChanged(CalcSettings settings) {
    final old = _settings;
    _settings = settings;
    _locale = FormulaLocale.forId(settings.locale);
    final work = Queue<_Node>();
    if (old.locale != settings.locale ||
        old.iterativeCalc != settings.iterativeCalc ||
        old.maxIterations != settings.maxIterations ||
        old.convergenceThreshold != settings.convergenceThreshold) {
      for (final n in _nodes.values) {
        _markDirty(n, work);
      }
    } else {
      _dirtyVolatile(work);
    }
    _propagate(work);
  }

  /// Basic filter / slicer visibility changed (SUBTOTAL, AGGREGATE).
  void filterVisibilityChanged(String sheetId) {
    final work = Queue<_Node>();
    for (final n in _filterDeps[sheetId] ?? const <_Node>{}) {
      _markDirty(n, work);
    }
    _propagate(work);
  }

  void _onExternalUpdate(ExternalKey key) {
    final work = Queue<_Node>();
    for (final n in _externalDeps[key] ?? const <_Node>{}) {
      _markDirty(n, work);
    }
    _propagate(work);
  }

  void _onCustomUpdate(String? name) {
    final work = Queue<_Node>();
    if (name == null) {
      for (final s in _customDeps.values) {
        for (final n in s) {
          _markDirty(n, work);
        }
      }
    } else {
      for (final n in _customDeps[name.toUpperCase()] ?? const <_Node>{}) {
        _markDirty(n, work);
      }
    }
    _propagate(work);
  }

  /// Records an [ExternalDep] for the cell being evaluated (used by IMPORT* functions).
  void _dirtyVolatile([Queue<_Node>? work]) {
    final w = work ?? Queue<_Node>();
    for (final n in _volatile) {
      _markDirty(n, w);
    }
    if (work == null) _propagate(w);
  }

  // ====================================================================== nodes

  _Node _nodeForInput(SheetView sheet, int row, int col, CellInput input) {
    final d = input.engineData;
    if (d is _Node && identical(d.input, input) && !d.removed) return d;
    final key = '${sheet.id}\u0001${sheet.rows.idAt(row)}\u0001${sheet.columns.idAt(col)}';
    final n = _nodes[key];
    if (n != null) {
      if (!identical(n.input, input)) {
        _updateNode(n, input);
        _markDirty(n);
      }
      input.engineData = n;
      return n;
    }
    return _createNode(sheet, row, col, input);
  }

  _Node _createNode(SheetView sheet, int row, int col, CellInput input) {
    final n = _Node(sheet.id, sheet.rows.idAt(row), sheet.columns.idAt(col), input);
    _nodes[n.key] = n;
    (_nodesBySheet[sheet.id] ??= {}).add(n);
    input.engineData = n;
    _compileNode(n);
    _registerStatic(n);
    _dirty.add(n);
    return n;
  }

  void _compileNode(_Node n) {
    n.formula = n.input.formula!;
    final (c, slots) = compiler.compileStored(n.formula);
    n.compiled = c;
    n.slots = slots;
    n.volatile = c.volatile;
    if (c.volatile) _volatile.add(n);
  }

  void _updateNode(_Node n, CellInput input) {
    final oldFormula = n.formula;
    n.input = input;
    input.engineData = n;
    if (input.formula == oldFormula) return;
    _unregisterStatic(n);
    _volatile.remove(n);
    _compileNode(n);
    _registerStatic(n);
  }

  void _removeNode(_Node n, [Queue<_Node>? work]) {
    if (n.removed) return;
    n.removed = true;
    _nodes.remove(n.key);
    _nodesBySheet[n.sheetId]?.remove(n);
    _unregisterStatic(n);
    _setDynamicDeps(n, const [], const {}, const {}, false, false, const {});
    _volatile.remove(n);
    _dirty.remove(n);
    final sheet = workbook.sheetById(n.sheetId);
    final t = _spills[n.sheetId];
    if (t != null) {
      t.blocked.remove(n);
      if (t.hosts.remove(n)) {
        t.cache = null;
        if (sheet != null && work != null) {
          final r = sheet.rows.indexOf(n.rowId), c = sheet.columns.indexOf(n.colId);
          if (r >= 0 && c >= 0) {
            final rect = GridRect(r, c, r + n.spillRows - 1, c + n.spillCols - 1);
            _recordSpillChange(n.sheetId, rect);
            _dirtyRect(sheet, rect, work);
          }
        }
      }
    }
  }

  // ====================================================================== dependencies

  _Dep? _depOfStored(_Node n, StoredRef ref) {
    final s = ref.start;
    if (s.isUnbound) return null;
    final sheetId = s.sheetId ?? n.sheetId;
    final e = ref.end;
    if (e == null) {
      if (s.rowId == null || s.colId == null) return null;
      return _CellDep(sheetId, s.rowId!, s.colId!);
    }
    return _RangeDep(
      IdRange(
        sheetId,
        rowStart: s.rowId,
        rowEnd: e.rowId,
        colStart: s.colId,
        colEnd: e.colId,
        rowStartKey: s.rowKey,
        rowEndKey: e.rowKey,
        colStartKey: s.colKey,
        colEndKey: e.colKey,
      ),
    );
  }

  _Dep? _depOfArea(ResolvedArea a) {
    final sheet = workbook.sheetById(a.sheetId);
    if (sheet == null) return null;
    final rows = sheet.rows, cols = sheet.columns;
    if (a.top < 0 || a.left < 0 || a.bottom >= rows.length || a.right >= cols.length) return null;
    if (a.isSingleCell) return _CellDep(a.sheetId, rows.idAt(a.top), cols.idAt(a.left));
    return _RangeDep(
      IdRange(
        a.sheetId,
        rowStart: a.top == 0 ? null : rows.idAt(a.top),
        rowEnd: a.bottom == rows.length - 1 ? null : rows.idAt(a.bottom),
        colStart: a.left == 0 ? null : cols.idAt(a.left),
        colEnd: a.right == cols.length - 1 ? null : cols.idAt(a.right),
      ),
    );
  }

  RangeIndex<IdRange, _Node> _rangeIndex(String sheetId) =>
      _rangeIndexes.putIfAbsent(sheetId, () => RangeIndex<IdRange, _Node>((r) => _resolveIdRange(r)));

  GridRect? _resolveIdRange(IdRange r) {
    final sheet = workbook.sheetById(r.sheetId);
    if (sheet == null) return null;
    int idx(AxisView axis, String? id, String? key, bool start, int dflt) {
      if (id == null) return dflt;
      return RefResolver.endpointIndex(axis, id, key, isStart: start);
    }

    var r1 = idx(sheet.rows, r.rowStart, r.rowStartKey, true, 0);
    var r2 = idx(sheet.rows, r.rowEnd, r.rowEndKey, false, sheet.rows.length - 1);
    var c1 = idx(sheet.columns, r.colStart, r.colStartKey, true, 0);
    var c2 = idx(sheet.columns, r.colEnd, r.colEndKey, false, sheet.columns.length - 1);
    if (r1 < 0 && r2 < 0) return null;
    if (r1 > r2) {
      final t = r1;
      r1 = r2;
      r2 = t;
    }
    if (c1 > c2) {
      final t = c1;
      c1 = c2;
      c2 = t;
    }
    if (r1 < 0) r1 = 0;
    if (c1 < 0) c1 = 0;
    return GridRect(r1, c1, r2, c2);
  }

  void _addDep(_Node n, _Dep d) {
    switch (d) {
      case _CellDep():
        (_cellDeps[d.key] ??= {}).add(n);
        (_cellDepKeysBySheet[d.sheetId] ??= {}).add(d);
      case _RangeDep(:final range):
        _rangeIndex(range.sheetId).add(range, n);
    }
  }

  void _removeDep(_Node n, _Dep d) {
    switch (d) {
      case _CellDep():
        final s = _cellDeps[d.key];
        if (s != null) {
          s.remove(n);
          if (s.isEmpty) {
            _cellDeps.remove(d.key);
            _cellDepKeysBySheet[d.sheetId]?.remove(d);
          }
        }
      case _RangeDep(:final range):
        _rangeIndexes[range.sheetId]?.remove(range, n);
    }
  }

  void _registerStatic(_Node n) {
    final deps = <_Dep>[];
    for (final s in n.slots) {
      final d = _depOfStored(n, s);
      if (d != null) deps.add(d);
    }
    n.staticDeps = deps;
    for (final d in deps) {
      _addDep(n, d);
    }
    final c = n.compiled;
    for (final name in c.names) {
      (_nameDeps[name] ??= {}).add(n);
    }
    if (c.positionSensitive) {
      n.axisDep = true;
      (_axisDeps[n.sheetId] ??= {}).add(n);
    }
    if (c.usesFilter) {
      n.filterDep = true;
    }
  }

  void _unregisterStatic(_Node n) {
    for (final d in n.staticDeps) {
      _removeDep(n, d);
    }
    n.staticDeps = const [];
    for (final name in n.compiled.names) {
      _nameDeps[name]?.remove(n);
    }
    if (n.axisDep) {
      _axisDeps[n.sheetId]?.remove(n);
      n.axisDep = false;
    }
  }

  void _setDynamicDeps(
    _Node n,
    List<_Dep> deps,
    Set<String> names,
    Set<String> axisSheets,
    bool sheetNames,
    bool filter,
    Set<String> custom,
  ) {
    final old = n.dynamicDeps;
    if (!(old.isEmpty && deps.isEmpty)) {
      final oldSet = old.toSet();
      final newSet = deps.toSet();
      for (final d in oldSet) {
        if (!newSet.contains(d)) _removeDep(n, d);
      }
      for (final d in newSet) {
        if (!oldSet.contains(d)) _addDep(n, d);
      }
      n.dynamicDeps = deps;
    }
    for (final name in n.nameDeps) {
      if (!names.contains(name) && !n.compiled.names.contains(name)) _nameDeps[name]?.remove(n);
    }
    for (final name in names) {
      (_nameDeps[name] ??= {}).add(n);
    }
    n.nameDeps = names.isEmpty ? const {} : Set.of(names);
    for (final s in n.axisSheets) {
      if (!axisSheets.contains(s) && !(n.axisDep && s == n.sheetId)) _axisDeps[s]?.remove(n);
    }
    for (final s in axisSheets) {
      (_axisDeps[s] ??= {}).add(n);
    }
    n.axisSheets = axisSheets.isEmpty ? const {} : Set.of(axisSheets);
    if (sheetNames != n.sheetNamesDep) {
      n.sheetNamesDep = sheetNames;
      if (sheetNames) {
        _sheetNameDeps.add(n);
      } else {
        _sheetNameDeps.remove(n);
      }
    }
    final wantFilter = filter || n.filterDep;
    if (wantFilter) {
      (_filterDeps[n.sheetId] ??= {}).add(n);
    } else {
      _filterDeps[n.sheetId]?.remove(n);
    }
    for (final c in n.customDeps) {
      if (!custom.contains(c)) _customDeps[c]?.remove(n);
    }
    for (final c in custom) {
      (_customDeps[c] ??= {}).add(n);
    }
    n.customDeps = custom.isEmpty ? const {} : Set.of(custom);
  }

  /// Registers an external dependency of the cell currently being evaluated.
  void recordExternal(EvalContext ctx, ExternalKey key) => ctx.deps.external.add(key);

  // ====================================================================== dirty propagation

  void _markDirty(_Node n, [Queue<_Node>? work]) {
    if (n.removed) return;
    if (n.dirty && _dirty.contains(n)) return;
    n.dirty = true;
    n.cyclic = false;
    _dirty.add(n);
    work?.add(n);
  }

  void _propagate(Queue<_Node> work) {
    while (work.isNotEmpty) {
      final n = work.removeFirst();
      final sheet = workbook.sheetById(n.sheetId);
      if (sheet == null) continue;
      final r = sheet.rows.indexOf(n.rowId), c = sheet.columns.indexOf(n.colId);
      if (r < 0 || c < 0) continue;
      _dirtyCellDependents(sheet, r, c, n.rowId, n.colId, work);
      if (n.spills) {
        _dirtyRect(sheet, GridRect(r, c, r + n.spillRows - 1, c + n.spillCols - 1), work);
      }
    }
  }

  void _dirtyCellDependents(
    SheetView sheet,
    int row,
    int col,
    String rowId,
    String colId,
    Queue<_Node> work,
  ) {
    final deps = _cellDeps['${sheet.id}\u0001$rowId\u0001$colId'];
    if (deps != null) {
      for (final d in deps) {
        _markDirty(d, work);
      }
    }
    _rangeIndexes[sheet.id]?.stab(row, col, (d) => _markDirty(d, work));
  }

  void _dirtyRect(SheetView sheet, GridRect rect, Queue<_Node> work) {
    _rangeIndexes[sheet.id]?.intersect(rect, (d) => _markDirty(d, work));
    final keys = _cellDepKeysBySheet[sheet.id];
    if (keys == null || keys.isEmpty) return;
    if (rect.cellCount <= keys.length) {
      final rows = sheet.rows, cols = sheet.columns;
      for (var r = rect.top; r <= rect.bottom && r < rows.length; r++) {
        for (var c = rect.left; c <= rect.right && c < cols.length; c++) {
          final deps = _cellDeps['${sheet.id}\u0001${rows.idAt(r)}\u0001${cols.idAt(c)}'];
          if (deps != null) {
            for (final d in deps) {
              _markDirty(d, work);
            }
          }
        }
      }
    } else {
      for (final k in keys.toList()) {
        final r = sheet.rows.indexOf(k.rowId), c = sheet.columns.indexOf(k.colId);
        if (rect.contains(r, c)) {
          for (final d in _cellDeps[k.key] ?? const <_Node>{}) {
            _markDirty(d, work);
          }
        }
      }
    }
  }

  // ====================================================================== evaluation

  CircularPolicy get _policy =>
      _settings.iterativeCalc ? CircularPolicy.iterate : CircularPolicy.error;

  static const FError _circular = FError(ErrorKind.ref, ErrorMessages.circular);

  /// Value of a formula node for a reader; evaluates when dirty.
  FValue _require(_Node p) {
    if (!p.dirty) return p.value;
    final g = p.group;
    if (g != null && g.iterating) return p.value;
    if (p.onChain) return _cycle(p);
    if (_depth >= config.maxNestedEvaluation) throw _NeedsPrecedent(p);
    _evaluateNode(p);
    return p.value;
  }

  FValue _cycle(_Node p) {
    final members = <_Node>[];
    final wi = _waitStack.indexOf(p);
    if (wi >= 0) {
      members.addAll(_waitStack.sublist(wi));
      members.addAll(_evalStack);
    } else {
      final ei = _evalStack.indexOf(p);
      if (ei >= 0) members.addAll(_evalStack.sublist(ei));
    }
    if (members.isEmpty) members.add(p);
    if (_policy == CircularPolicy.error) {
      for (final m in members) {
        m.cyclic = true;
      }
      return _circular;
    }
    var group = p.group;
    for (final m in members) {
      final mg = m.group;
      if (mg != null && group != null && !identical(mg, group)) {
        // merge into the group whose root is earliest on the chain
        group.members.addAll(mg.members);
        for (final x in mg.members) {
          x.group = group;
        }
      }
      group ??= mg;
    }
    group ??= _CycleGroup(p);
    for (final m in members) {
      m.group = group;
      group.members.add(m);
    }
    if (!group.members.contains(group.root)) group.root = p;
    return p.hasValue ? p.value : FNumber.zero;
  }

  void _ensureClean(_Node root) {
    if (!root.dirty || root.removed) return;
    if (root.onChain) return;
    if (_depth > 0) {
      _require(root);
      return;
    }
    final stackBase = _waitStack.length;
    _waitStack.add(root);
    root.waiting = true;
    try {
      while (_waitStack.length > stackBase) {
        final n = _waitStack.last;
        if (!n.dirty || n.removed) {
          _waitStack.removeLast();
          n.waiting = false;
          continue;
        }
        n.waiting = false;
        try {
          _evaluateNode(n);
          _waitStack.removeLast();
        } on _NeedsPrecedent catch (e) {
          n.waiting = true;
          final p = e.node;
          if (p.onChain) {
            // cycle through the explicit stack
            _cycle(p);
            if (_policy == CircularPolicy.error) {
              p.value = _circular;
              p.result = _circular;
              p.dirty = false;
              _dirty.remove(p);
            }
            continue;
          }
          p.waiting = true;
          _waitStack.add(p);
        }
      }
    } finally {
      for (var i = _waitStack.length - 1; i >= stackBase; i--) {
        _waitStack[i].waiting = false;
      }
      _waitStack.length = stackBase;
    }
  }

  void _evaluateNode(_Node n) {
    final sheet = workbook.sheetById(n.sheetId);
    final row = sheet?.rows.indexOf(n.rowId) ?? -1;
    final col = sheet?.columns.indexOf(n.colId) ?? -1;
    if (sheet == null || row < 0 || col < 0) {
      _removeNode(n);
      return;
    }
    final ctx = EvalContext(
      host: this,
      sheet: sheet,
      row: row,
      col: col,
      rowId: n.rowId,
      colId: n.colId,
      slots: n.slots,
    );
    n.evaluating = true;
    _evalStack.add(n);
    _depth++;
    FValue raw;
    try {
      raw = n.compiled.root(ctx);
    } on FormulaError catch (e) {
      raw = e.error;
    } on StackOverflowError {
      raw = const FError(ErrorKind.calc, ErrorMessages.recursionLimit);
    } finally {
      _depth--;
      _evalStack.removeLast();
      n.evaluating = false;
    }
    final result = _finalize(ctx, n, raw);
    final deps = ctx.deps;
    final dyn = <_Dep>[];
    for (final a in deps.areas) {
      final d = _depOfArea(a);
      if (d != null) dyn.add(d);
    }
    _setDynamicDeps(n, dyn, deps.names, deps.axisSheets, deps.sheetNames, deps.filter, deps.customFunctions);
    for (final k in deps.external) {
      (_externalDeps[k] ??= {}).add(n);
    }
    if (deps.volatile && !_volatile.contains(n)) _volatile.add(n);
    _applyResult(n, sheet, row, col, result);
    if (n.cyclic && _policy == CircularPolicy.error) {
      _setValue(n, sheet, row, col, _circular, FormatHint.none);
      n.result = _circular;
      _clearSpill(n, sheet, row, col);
    }
    n.dirty = false;
    n.hasValue = true;
    _dirty.remove(n);
    final g = n.group;
    if (g != null && identical(g.root, n) && !g.iterating && _policy == CircularPolicy.iterate) {
      _iterate(g);
    }
  }

  void _iterate(_CycleGroup g) {
    g.iterating = true;
    final members = g.members.toList()
      ..sort((a, b) {
        final sa = _sheetOrder(a.sheetId), sb = _sheetOrder(b.sheetId);
        if (sa != sb) return sa - sb;
        final s = workbook.sheetById(a.sheetId)!;
        final ra = s.rows.indexOf(a.rowId), rb = s.rows.indexOf(b.rowId);
        if (ra != rb) return ra - rb;
        return s.columns.indexOf(a.colId) - s.columns.indexOf(b.colId);
      });
    final maxIter = _settings.maxIterations;
    final threshold = _settings.convergenceThreshold;
    try {
      for (var sweep = 1; sweep < maxIter; sweep++) {
        var maxDelta = 0.0;
        for (final m in members) {
          final old = m.value;
          m.dirty = true;
          _dirty.add(m);
          _evaluateNode(m);
          final nv = m.value;
          final d = (old is FNumber && nv is FNumber) ? (nv.v - old.v).abs() : (FValues.sameValue(old, nv) ? 0.0 : double.infinity);
          if (d > maxDelta) maxDelta = d;
        }
        if (maxDelta < threshold) break;
      }
    } finally {
      g.iterating = false;
      for (final m in members) {
        m.group = null;
      }
    }
  }

  int _sheetOrder(String id) {
    final sheets = workbook.sheets;
    for (var i = 0; i < sheets.length; i++) {
      if (sheets[i].id == id) return i;
    }
    return sheets.length;
  }

  FValue _finalize(EvalContext ctx, _Node n, FValue raw) {
    switch (raw) {
      case FRef():
        if (raw.area.isSingleCell) {
          final s = RangeAccess.sheetOf(ctx, raw.area);
          if (s == null) return const FError(ErrorKind.ref, ErrorMessages.referenceDoesNotExist);
          if (raw.dynamic) ctx.deps.areas.add(raw.area);
          return RangeAccess.cellWithHint(ctx, s, raw.area.top, raw.area.left);
        }
        final m = RangeAccess.materialize(ctx, raw);
        return m is FArray && m.length == 1 ? m.at(0, 0) : m;
      case FLambda():
        return const FError(ErrorKind.calc, ErrorMessages.lambdaResult);
      case FOmitted():
        return FEmpty.instance;
      case FArray():
        return raw.length == 1 ? raw.at(0, 0) : raw;
      default:
        return raw;
    }
  }

  void _setValue(_Node n, SheetView sheet, int row, int col, FValue v, FormatHint hint) {
    if ((!n.hasValue || !FValues.sameValue(n.value, v) || n.hint != hint) && _changed.length < 200000) {
      _changed.add(ChangedCell(sheet.id, row, col));
    }
    n.value = v;
    n.hint = hint;
  }

  void _applyResult(_Node n, SheetView sheet, int row, int col, FValue result) {
    n.result = result;
    if (result is! FArray) {
      final hint = result is FNumber ? result.hint : FormatHint.none;
      _setValue(n, sheet, row, col, result, hint);
      _clearSpill(n, sheet, row, col);
      _setBlocked(n, false);
      return;
    }
    final rows = result.rows, cols = result.cols;
    // grid edges
    if (row + rows > sheet.rows.length) {
      _spillError(n, sheet, row, col, FError(ErrorKind.ref, ErrorMessages.spillRows(row + rows - sheet.rows.length)), rows, cols);
      return;
    }
    if (col + cols > sheet.columns.length) {
      _spillError(n, sheet, row, col, FError(ErrorKind.ref, ErrorMessages.spillColumns(col + cols - sheet.columns.length)), rows, cols);
      return;
    }
    final rect = GridRect(row, col, row + rows - 1, col + cols - 1);
    // content blockers
    CellPos? blocker;
    sheet.forEachInput(rect, (r, c, _) {
      if (blocker == null && !(r == row && c == col)) blocker = CellPos(r, c);
    });
    // other overlays
    final t = _spills.putIfAbsent(sheet.id, _SpillTable.new);
    final losers = <_Node>[];
    if (blocker == null) {
      for (final (or, other) in _spillRects(sheet, t)) {
        if (identical(other, n) || !or.intersects(rect)) continue;
        final otherFirst = or.top < row || (or.top == row && or.left < col);
        if (otherFirst) {
          final inter = or.intersection(rect)!;
          blocker = CellPos(inter.top, inter.left);
          break;
        }
        losers.add(other);
      }
    }
    if (blocker != null) {
      _spillError(n, sheet, row, col, FError(ErrorKind.spill, ErrorMessages.spillBlocked(blocker!.a1)), rows, cols);
      return;
    }
    final work = Queue<_Node>();
    for (final l in losers) {
      _clearSpillNode(l, sheet, work);
      _markDirty(l, work);
    }
    final first = result.at(0, 0);
    final hint = first is FNumber ? first.hint : FormatHint.none;
    final oldRect = n.spills ? GridRect(row, col, row + n.spillRows - 1, col + n.spillCols - 1) : null;
    final changedExtent = oldRect != rect;
    final changedContent = !(n.spillArray != null && FValues.sameValue(n.spillArray!, result));
    n.spillRows = rows;
    n.spillCols = cols;
    n.spillArray = result;
    t.hosts.add(n);
    t.cache = null;
    _setBlocked(n, false);
    _setValue(n, sheet, row, col, first, hint);
    if (changedExtent || changedContent) {
      if (oldRect != null) {
        _recordSpillChange(sheet.id, oldRect);
        _dirtyRect(sheet, oldRect, work);
      }
      _recordSpillChange(sheet.id, rect);
      _dirtyRect(sheet, rect, work);
      for (var r = rect.top; r <= rect.bottom && r - rect.top < 200; r++) {
        for (var c = rect.left; c <= rect.right && c - rect.left < 50; c++) {
          if (r != row || c != col) _changed.add(ChangedCell(sheet.id, r, c));
        }
      }
    }
    work.remove(n);
    _propagate(work);
  }

  void _recordSpillChange(String sheetId, GridRect rect) =>
      (_changedSpills[sheetId] ??= []).add(rect);

  void _spillError(_Node n, SheetView sheet, int row, int col, FError e, int rows, int cols) {
    _clearSpill(n, sheet, row, col);
    _setValue(n, sheet, row, col, e, FormatHint.none);
    n.wantRows = rows;
    n.wantCols = cols;
    _setBlocked(n, true);
  }

  void _setBlocked(_Node n, bool blocked) {
    final t = _spills[n.sheetId];
    if (blocked) {
      (_spills[n.sheetId] ??= _SpillTable()).blocked.add(n);
    } else {
      t?.blocked.remove(n);
    }
  }

  void _clearSpill(_Node n, SheetView sheet, int row, int col) {
    if (!n.spills) return;
    final work = Queue<_Node>();
    _clearSpillNode(n, sheet, work);
    work.remove(n);
    _propagate(work);
  }

  void _clearSpillNode(_Node n, SheetView sheet, Queue<_Node> work) {
    if (!n.spills) return;
    final row = sheet.rows.indexOf(n.rowId), col = sheet.columns.indexOf(n.colId);
    final rect = GridRect(row, col, row + n.spillRows - 1, col + n.spillCols - 1);
    n.spillRows = 0;
    n.spillCols = 0;
    n.spillArray = null;
    final t = _spills[n.sheetId];
    if (t != null) {
      t.hosts.remove(n);
      t.cache = null;
    }
    _recordSpillChange(sheet.id, rect);
    _dirtyRect(sheet, rect, work);
  }

  List<(GridRect, _Node)> _spillRects(SheetView sheet, _SpillTable t) {
    final cached = t.cache;
    if (cached != null) return cached;
    final out = <(GridRect, _Node)>[];
    for (final h in t.hosts) {
      final r = sheet.rows.indexOf(h.rowId), c = sheet.columns.indexOf(h.colId);
      if (r < 0 || c < 0) continue;
      out.add((GridRect(r, c, r + h.spillRows - 1, c + h.spillCols - 1), h));
    }
    out.sort((a, b) => a.$1.top != b.$1.top ? a.$1.top - b.$1.top : a.$1.left - b.$1.left);
    t.cache = out;
    return out;
  }

  _Node? _overlayHost(SheetView sheet, int row, int col) {
    final t = _spills[sheet.id];
    if (t == null || t.hosts.isEmpty) return null;
    for (final (r, h) in _spillRects(sheet, t)) {
      if (r.top > row) break;
      if (r.contains(row, col)) return h;
    }
    return null;
  }

  FValue? _overlayElement(SheetView sheet, _Node host, int row, int col) {
    final arr = host.spillArray;
    if (arr == null) return null;
    final hr = sheet.rows.indexOf(host.rowId), hc = sheet.columns.indexOf(host.colId);
    final r = row - hr, c = col - hc;
    if (r < 0 || c < 0 || r >= arr.rows || c >= arr.cols) return null;
    return arr.at(r, c);
  }

  FValue? _overlayValue(SheetView sheet, int row, int col) {
    final host = _overlayHost(sheet, row, col);
    if (host == null) return null;
    if (host.dirty) {
      _require(host);
      // the spill may have moved or been blocked
      final h2 = _overlayHost(sheet, row, col);
      if (h2 == null) return null;
      return _overlayElement(sheet, h2, row, col);
    }
    return _overlayElement(sheet, host, row, col);
  }

  // ====================================================================== headless

  /// Evaluates an A1 formula at a cell without registering it (MCP `sheets.evaluate`, named
  /// function preview). Dirty precedents are evaluated on demand.
  FValue evaluate(String a1Formula, {required String sheetId, int row = 0, int col = 0}) {
    _ensureLoaded();
    final sheet = workbook.sheetById(sheetId);
    if (sheet == null) return const FError(ErrorKind.ref, ErrorMessages.referenceDoesNotExist);
    final stored = FormulaCodec.toStored(
      a1Formula,
      CodecContext(workbook: workbook, hostSheetId: sheetId, hostRow: row, hostCol: col, locale: _locale),
    );
    return evaluateStored(stored, sheetId: sheetId, row: row, col: col);
  }

  /// Evaluates stored formula text at a cell (detached).
  FValue evaluateStored(String stored, {required String sheetId, int row = 0, int col = 0, int rowOffset = 0, int colOffset = 0}) {
    _ensureLoaded();
    final sheet = workbook.sheetById(sheetId);
    if (sheet == null) return const FError(ErrorKind.ref, ErrorMessages.referenceDoesNotExist);
    final (compiled, slots) = compiler.compileStored(stored.startsWith('=') ? stored.substring(1) : stored);
    final ctx = EvalContext(
      host: this,
      sheet: sheet,
      row: row,
      col: col,
      rowId: row < sheet.rows.length ? sheet.rows.idAt(row) : '',
      colId: col < sheet.columns.length ? sheet.columns.idAt(col) : '',
      slots: slots,
    )
      ..rowOffset = rowOffset
      ..colOffset = colOffset;
    FValue raw;
    try {
      raw = _runDetached(() => compiled.root(ctx));
    } on FormulaError catch (e) {
      raw = e.error;
    }
    return _finalizeDetached(ctx, raw);
  }

  FValue _finalizeDetached(EvalContext ctx, FValue raw) {
    switch (raw) {
      case FRef():
        if (raw.area.isSingleCell) {
          final s = RangeAccess.sheetOf(ctx, raw.area);
          if (s == null) return const FError(ErrorKind.ref);
          return RangeAccess.cellWithHint(ctx, s, raw.area.top, raw.area.left);
        }
        final m = RangeAccess.materialize(ctx, raw);
        return m is FArray && m.length == 1 ? m.at(0, 0) : m;
      case FLambda():
        return const FError(ErrorKind.calc, ErrorMessages.lambdaResult);
      case FOmitted():
        return FEmpty.instance;
      case FArray():
        return raw.length == 1 ? raw.at(0, 0) : raw;
      default:
        return raw;
    }
  }

  /// Runs [f] at depth 0 semantics: deep precedent chains are evaluated through the explicit
  /// work stack first.
  FValue _runDetached(FValue Function() f) {
    for (var attempt = 0; attempt < 100000; attempt++) {
      try {
        _depth++;
        try {
          return f();
        } finally {
          _depth--;
        }
      } on _NeedsPrecedent catch (e) {
        _ensureClean(e.node);
      }
    }
    return const FError(ErrorKind.calc, ErrorMessages.recursionLimit);
  }

  /// Live preview while typing (03 §8.7): returns null when [budget] is exceeded.
  ComputedValue? evaluateDetached(
    String a1Formula, {
    required String sheetId,
    required CellPos at,
    Duration budget = const Duration(milliseconds: 50),
  }) {
    final sw = Stopwatch()..start();
    final prev = _abort;
    _abort = () => sw.elapsed > budget;
    try {
      final v = evaluate(a1Formula, sheetId: sheetId, row: at.row, col: at.col);
      return ComputedValue(v, hint: v is FNumber ? v.hint : FormatHint.none);
    } on _Aborted {
      return null;
    } finally {
      _abort = prev;
    }
  }

  /// Rule formulas (CF/DV/filter custom formulas): compiled once relative to [anchor].
  CompiledRelative compileRelative(String stored, {required String sheetId, required CellPos anchor}) =>
      CompiledRelative._(this, stored.startsWith('=') ? stored.substring(1) : stored, sheetId, anchor);

  // ====================================================================== introspection

  /// Precedent areas and dependent formula cells of a cell (05 §7.1).
  DependencyInfo dependencies(String sheetId, int row, int col, {bool transitive = false}) {
    _ensureLoaded();
    final sheet = workbook.sheetById(sheetId);
    if (sheet == null) return const DependencyInfo([], []);
    final precedents = <ResolvedArea>[];
    final input = sheet.inputAt(row, col);
    if (input != null && input.isFormula) {
      final n = _nodeForInput(sheet, row, col, input);
      for (final d in [...n.staticDeps, ...n.dynamicDeps]) {
        final a = _areaOfDep(d);
        if (a != null && !precedents.contains(a)) precedents.add(a);
      }
    }
    final dependents = <FormulaCellRef>[];
    final seen = <_Node>{};
    final work = Queue<(SheetView, int, int)>()..add((sheet, row, col));
    while (work.isNotEmpty) {
      final (s, r, c) = work.removeFirst();
      final found = <_Node>{};
      final deps = _cellDeps['${s.id}\u0001${s.rows.idAt(r)}\u0001${s.columns.idAt(c)}'];
      if (deps != null) found.addAll(deps);
      _rangeIndexes[s.id]?.stab(r, c, found.add);
      for (final d in found) {
        if (!seen.add(d)) continue;
        final ds = workbook.sheetById(d.sheetId);
        if (ds == null) continue;
        final dr = ds.rows.indexOf(d.rowId), dc = ds.columns.indexOf(d.colId);
        dependents.add(FormulaCellRef(d.sheetId, dr, dc, d.formula));
        if (transitive) work.add((ds, dr, dc));
      }
    }
    return DependencyInfo(precedents, dependents);
  }

  ResolvedArea? _areaOfDep(_Dep d) {
    switch (d) {
      case _CellDep():
        final s = workbook.sheetById(d.sheetId);
        if (s == null) return null;
        final r = s.rows.indexOf(d.rowId), c = s.columns.indexOf(d.colId);
        if (r < 0 || c < 0) return null;
        return ResolvedArea.cell(d.sheetId, r, c);
      case _RangeDep(:final range):
        final rect = _resolveIdRange(range);
        if (rect == null) return null;
        return ResolvedArea(range.sheetId, rect.top, rect.left, rect.bottom, rect.right);
    }
  }

  /// Formula cells that reference any cell of [rect] on [sheetId] (cut/move remapping,
  /// boundary repair).
  List<FormulaCellRef> formulasReferencing(String sheetId, GridRect rect) {
    _ensureLoaded();
    final sheet = workbook.sheetById(sheetId);
    if (sheet == null) return const [];
    final found = <_Node>{};
    _rangeIndexes[sheetId]?.intersect(rect, found.add);
    for (final k in _cellDepKeysBySheet[sheetId] ?? const <_CellDep>{}) {
      final r = sheet.rows.indexOf(k.rowId), c = sheet.columns.indexOf(k.colId);
      if (rect.contains(r, c)) found.addAll(_cellDeps[k.key] ?? const {});
    }
    return _refsOf(found);
  }

  /// Formula cells with a range endpoint or single reference on one of the ids.
  List<FormulaCellRef> formulasWithEndpointsOn(String sheetId, GridDimension dim, Set<String> ids) {
    _ensureLoaded();
    final found = <_Node>{};
    final idx = _rangeIndexes[sheetId];
    if (idx != null) {
      for (final k in idx.keysWhere((r) {
        final e = dim == GridDimension.rows ? [r.rowStart, r.rowEnd] : [r.colStart, r.colEnd];
        return e.any((x) => x != null && ids.contains(x));
      }).toList()) {
        found.addAll(idx.nodesOf(k) ?? const {});
      }
    }
    for (final k in _cellDepKeysBySheet[sheetId] ?? const <_CellDep>{}) {
      if (ids.contains(dim == GridDimension.rows ? k.rowId : k.colId)) {
        found.addAll(_cellDeps[k.key] ?? const {});
      }
    }
    return _refsOf(found);
  }

  /// Formula cells using a named range/function.
  List<FormulaCellRef> formulasUsingName(String name) => _refsOf({...?_nameDeps[name.toUpperCase()]});

  /// All formula cells.
  List<FormulaCellRef> allFormulas() {
    _ensureLoaded();
    return _refsOf(_nodes.values.toSet());
  }

  List<FormulaCellRef> _refsOf(Set<_Node> nodes) {
    final out = <FormulaCellRef>[];
    for (final n in nodes) {
      final s = workbook.sheetById(n.sheetId);
      if (s == null) continue;
      final r = s.rows.indexOf(n.rowId), c = s.columns.indexOf(n.colId);
      if (r < 0 || c < 0) continue;
      out.add(FormulaCellRef(n.sheetId, r, c, n.formula));
    }
    out.sort((a, b) {
      final sa = _sheetOrder(a.sheetId), sb = _sheetOrder(b.sheetId);
      if (sa != sb) return sa - sb;
      return a.row != b.row ? a.row - b.row : a.col - b.col;
    });
    return out;
  }

  /// Cells in a circular reference (after evaluation), for "Show circular path".
  List<FormulaCellRef> circularCells() =>
      _refsOf({for (final n in _nodes.values) if (n.cyclic) n});
}

/// Whether cycles error or iterate.
enum CircularPolicy { error, iterate }

/// A rule formula compiled once and evaluated per cell with offsets (06 §15.3, 07 §3.3).
final class CompiledRelative {
  final FormulaEngine _engine;
  final String stored;
  final String sheetId;
  final CellPos anchor;
  CompiledRelative._(this._engine, this.stored, this.sheetId, this.anchor);

  /// Evaluates the formula as if written at ([row], [col]).
  FValue evaluate(int row, int col) => _engine.evaluateStored(
    stored,
    sheetId: sheetId,
    row: row,
    col: col,
    rowOffset: row - anchor.row,
    colOffset: col - anchor.col,
  );

  /// Truthiness for conditions: TRUE or a non-zero number (06 §15.3).
  bool test(int row, int col) {
    var v = evaluate(row, col);
    if (v is FArray) v = v.topLeft;
    return switch (v) {
      FBool(:final v) => v,
      FNumber(:final v) => v != 0,
      _ => false,
    };
  }
}
