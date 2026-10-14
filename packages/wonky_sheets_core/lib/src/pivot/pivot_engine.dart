import 'dart:typed_data';

import '../addressing/grid_geometry.dart';
import '../content/cell_content.dart';
import '../data_tools/filter/filter_criteria.dart';
import '../data_tools/filter/filter_engine.dart';
import '../formula/recalc/engine_types.dart';
import '../formula/values/numeric.dart';
import '../rules/conditions/condition_evaluator.dart';
import 'aggregators.dart';
import 'pivot_grouping.dart';
import 'pivot_spec.dart';
import 'source_table.dart';

/// Evaluates calculated fields of pivot values (07 §7.4 step 4). The formula
/// is in stored form with field tokens `⟦F:<colId>⟧` (see [PivotFormula]);
/// the app adapts the formula engine (LET-like bindings of the tokens).
abstract interface class PivotFormulaEvaluator {
  /// *Summarize by* a function other than Custom: evaluates [formula] for one
  /// source row; each field token is bound to that row's value ([field]).
  CellValue evaluateRow(String formula, CellValue Function(String colId) field);

  /// *Custom*: evaluates [formula] for one output cell; each field token is
  /// bound to the array of the values of the source rows of that cell
  /// (`=SUM(Revenue)/COUNTA(Region)`).
  CellValue evaluateGroup(
    String formula,
    List<CellValue> Function(String colId) field,
  );
}

/// Inputs of [PivotEngine.compute] besides the spec and the source.
final class PivotContext {
  /// Creates a context.
  PivotContext({
    this.locale = 'en_US',
    ConditionEvaluator? conditions,
    this.formulas,
    this.maxOutputCells = 1000000,
  }) : conditions = conditions ?? ConditionEvaluator(locale: locale);

  /// Spreadsheet locale (date group labels, condition literals).
  final String locale;

  /// Evaluator of filter conditions (custom formulas through its hooks).
  final ConditionEvaluator conditions;

  /// Calculated field evaluator; without it calculated values are `#NAME?`.
  final PivotFormulaEvaluator? formulas;

  /// Output size limit (07 §7.5): larger pivots render `#REF!`.
  final int maxOutputCells;
}

/// A row or column field of a computed pivot.
final class PivotFieldInfo {
  /// Creates the info.
  const PivotFieldInfo({
    required this.spec,
    required this.specIndex,
    required this.header,
    this.numberFormat,
  });

  /// The group spec.
  final PivotGroupSpec spec;

  /// Index of [spec] in `PivotSpec.rows` / `columns`.
  final int specIndex;

  /// Header text of the source column.
  final String header;

  /// The source column's number format (labels of ungrouped numbers).
  final String? numberFormat;

  /// Header shown in the output: the custom label, else the source header.
  String get label {
    final l = spec.label;
    return l == null || l.isEmpty ? header : l;
  }
}

/// A value field of a computed pivot.
final class PivotValueField {
  /// Creates the field.
  const PivotValueField({
    required this.spec,
    required this.specIndex,
    required this.name,
    required this.header,
    this.numberFormat,
  });

  /// The value spec.
  final PivotValueSpec spec;

  /// Index of [spec] in `PivotSpec.values`.
  final int specIndex;

  /// Display name ("SUM of Revenue", custom name, "Calculated Field 1").
  final String name;

  /// Header of the source column ('' for calculated fields).
  final String header;

  /// Effective number format of the value cells (07 §7.5): the override,
  /// `0.00%` for show-as percentages, the source column's format for
  /// SUM/AVERAGE/MIN/MAX/MEDIAN, else null (Automatic).
  final String? numberFormat;

  /// Summarize function.
  PivotSummarize get summarizeBy => spec.summarizeBy;

  /// Show as.
  PivotShowAs get showAs => spec.showAs;
}

/// A node of the row or column header tree. The root (depth 0) stands for
/// the grand total; nodes at depth *d* are the items of group *d − 1*;
/// leaves are at depth = number of groups of the axis.
final class PivotAxisNode {
  PivotAxisNode._(this.id, this.parent, this.key, this.depth);

  /// Id unique within the axis.
  final int id;

  /// Parent (null for the root).
  final PivotAxisNode? parent;

  /// Group key (null for the root).
  final PivotKey? key;

  /// 0 for the root.
  final int depth;

  /// Children in output order.
  final List<PivotAxisNode> children = [];
  final Map<Object, PivotAxisNode> _byIdentity = {};
  int _firstLeaf = 0;
  int _lastLeaf = 0;

  /// Whether this is the root (grand total).
  bool get isRoot => parent == null;

  /// Keys from the outermost group to this node.
  List<PivotKey> get path {
    final out = <PivotKey>[];
    for (PivotAxisNode? n = this; n != null && n.key != null; n = n.parent) {
      out.add(n.key!);
    }
    return out.reversed.toList();
  }

  PivotAxisNode? _child(Object identity) => _byIdentity[identity];

  /// The child whose key [matches], or null.
  PivotAxisNode? childWhere(bool Function(PivotKey key) matches) {
    for (final c in children) {
      if (matches(c.key!)) return c;
    }
    return null;
  }

  @override
  String toString() => 'PivotAxisNode(${path.map((k) => k.labelText)})';
}

final class _Cell {
  _Cell(this.aggs);
  final List<Aggregator?> aggs;
  List<int>? rows;
  List<CellValue>? results;
}

/// Output of [PivotEngine.compute]: the sorted row and column trees and the
/// aggregated values of every (row node, column node) pair — items,
/// subtotals and grand totals (07 §7.4).
final class PivotResult {
  PivotResult._({
    required this.spec,
    required this.source,
    required this.rowFields,
    required this.columnFields,
    required this.valueFields,
    required this.rowRoot,
    required this.columnRoot,
    required this._cells,
    required this._rowLeafOf,
    required this._columnLeafOf,
    required this._rowNodes,
    required this._columnNodes,
    required this.maxOutputCells,
    this.cancelled = false,
  });

  /// The spec.
  final PivotSpec spec;

  /// The source snapshot.
  final SourceTable source;

  /// Row fields whose source column exists, outermost first.
  final List<PivotFieldInfo> rowFields;

  /// Column fields whose source column exists, outermost first.
  final List<PivotFieldInfo> columnFields;

  /// Value fields whose source column exists (or calculated), in spec order.
  final List<PivotValueField> valueFields;

  /// Root of the row tree (grand total row).
  final PivotAxisNode rowRoot;

  /// Root of the column tree (grand total column).
  final PivotAxisNode columnRoot;

  /// Output size limit from the context.
  final int maxOutputCells;

  /// Whether the computation was cancelled (the result is empty).
  final bool cancelled;

  final Map<int, _Cell> _cells;
  final Int32List _rowLeafOf;
  final Int32List _columnLeafOf;
  final List<PivotAxisNode> _rowNodes;
  final List<PivotAxisNode> _columnNodes;

  /// Whether the spec has no rows, columns and values (07 §7.5 empty state).
  bool get isEmpty => spec.isEmpty;

  /// Index into [valueFields] of the value at spec index [specIndex], or -1.
  int valueIndexOfSpec(int specIndex) =>
      valueFields.indexWhere((v) => v.specIndex == specIndex);

  static int _pairKey(int r, int c) => r * _colStride + c;
  static const int _colStride = 0x4000000;

  /// The aggregate of value [valueIndex] for ([row], [column]) before
  /// *show as*; empty when no source row falls into the pair.
  CellValue rawValue(PivotAxisNode row, PivotAxisNode column, int valueIndex) {
    final cell = _cells[_pairKey(row.id, column.id)];
    if (cell == null) return CellValue.empty;
    return cell.results![valueIndex];
  }

  /// The displayed value of [valueIndex] for ([row], [column]) after
  /// *show as* (07 §7.4 step 5).
  CellValue value(PivotAxisNode row, PivotAxisNode column, int valueIndex) {
    final raw = rawValue(row, column, valueIndex);
    final showAs = valueFields[valueIndex].showAs;
    if (showAs == PivotShowAs.defaultValue || raw is EmptyValue) return raw;
    if (raw is ErrorValue) return raw;
    if (raw is! NumberValue) return const ErrorValue(CellErrorKind.value);
    final total = switch (showAs) {
      PivotShowAs.percentOfRowTotal => rawValue(row, columnRoot, valueIndex),
      PivotShowAs.percentOfColumnTotal => rawValue(rowRoot, column, valueIndex),
      _ => rawValue(rowRoot, columnRoot, valueIndex),
    };
    if (total is ErrorValue) return total;
    if (total is! NumberValue || total.number == 0) {
      return const ErrorValue(CellErrorKind.div0);
    }
    return NumberValue(raw.number / total.number);
  }

  /// Whether the pair is shown in the output: items always, subtotals and
  /// grand totals when their group has `showTotals` (07 §7.5).
  bool isDisplayed(PivotAxisNode row, PivotAxisNode column) =>
      _axisDisplayed(row, rowFields) && _axisDisplayed(column, columnFields);

  static bool _axisDisplayed(PivotAxisNode n, List<PivotFieldInfo> fields) {
    if (n.depth == fields.length) return true;
    if (n.depth == 0) return fields.first.spec.showTotals;
    return fields[n.depth - 1].spec.showTotals;
  }

  /// Data row indices of [source] contributing to ([row], [column]) in
  /// source order (drill-down, 07 §7.9).
  List<int> drillDownRows(PivotAxisNode row, PivotAxisNode column) {
    final out = <int>[];
    for (var i = 0; i < _rowLeafOf.length; i++) {
      final rl = _rowLeafOf[i];
      if (rl < 0) continue;
      final r = _rowNodes[rl];
      if (r._firstLeaf < row._firstLeaf || r._firstLeaf > row._lastLeaf) {
        continue;
      }
      final c = _columnNodes[_columnLeafOf[i]];
      if (c._firstLeaf < column._firstLeaf || c._firstLeaf > column._lastLeaf) {
        continue;
      }
      out.add(i);
    }
    return out;
  }

  /// The source rows of a drill-down as values (header row first), ready to
  /// be written to a "Details" sheet (07 §7.9).
  List<List<CellValue>> drillDownTable(
    PivotAxisNode row,
    PivotAxisNode column,
  ) => [
    [for (final c in source.columns) TextValue(c.header)],
    for (final i in drillDownRows(row, column))
      [for (final c in source.columns) c.values[i]],
  ];
}

/// Computes pivot tables (07 §7.4): filter → group keys → aggregation
/// (calculated fields included) → sort. Pure and synchronous; lay the result
/// out with `PivotLayout.build`.
final class PivotEngine {
  /// Creates the engine.
  const PivotEngine();

  /// Computes [spec] over [source]. [cancel] stops the computation
  /// cooperatively ([PivotResult.cancelled]).
  PivotResult compute(
    PivotSpec spec,
    SourceTable source,
    PivotContext ctx, {
    CancellationToken? cancel,
  }) {
    PivotResult? result;
    for (final step in _steps(spec, source, ctx, cancel)) {
      if (step != null) result = step;
    }
    return result!;
  }

  /// Like [compute], time-sliced (07 §7.4, big pivots on the web where no
  /// isolate is available): the aggregation pauses every [slice] and lets
  /// the event loop run (frames, input) before it goes on.
  Future<PivotResult> computeSliced(
    PivotSpec spec,
    SourceTable source,
    PivotContext ctx, {
    CancellationToken? cancel,
    Duration slice = const Duration(milliseconds: 8),
  }) async {
    final sw = Stopwatch()..start();
    PivotResult? result;
    for (final step in _steps(spec, source, ctx, cancel, every: 0x7ff)) {
      if (step != null) {
        result = step;
        continue;
      }
      if (sw.elapsed >= slice) {
        await Future<void>.delayed(Duration.zero);
        sw.reset();
      }
    }
    return result!;
  }

  /// Whether [applyDelta] can update a result of [spec] (07 §7.10, P2):
  /// decomposable aggregates only (SUM, AVERAGE, COUNT, COUNTA, MIN, MAX;
  /// no calculated fields), no pivot filters and no histogram groups.
  static bool supportsDelta(PivotSpec spec) {
    if (spec.filters.any((f) => !f.criteria.isEmpty)) return false;
    for (final v in spec.values) {
      if (v.isCalculated) return false;
      switch (v.summarizeBy) {
        case PivotSummarize.sum ||
            PivotSummarize.average ||
            PivotSummarize.count ||
            PivotSummarize.counta ||
            PivotSummarize.min ||
            PivotSummarize.max:
          break;
        default:
          return false;
      }
    }
    for (final g in [...spec.rows, ...spec.columns]) {
      if (g.group is PivotHistogramGrouping) return false;
    }
    return true;
  }

  /// Incremental refresh (07 §7.10, P2): updates [previous] **in place**
  /// for changed source data rows — [rows] maps a data row index to its new
  /// `(value, number format)` per source column (in `source.columns`
  /// order) — by taking the old values out of the affected aggregates and
  /// adding the new ones, then re-sorting. Returns [previous], or null
  /// (nothing changed) when the update isn't decomposable: see
  /// [supportsDelta], slicer masks, a changed group key or number format,
  /// errors, or the extreme of a MIN/MAX taken away. Compute anew then.
  PivotResult? applyDelta(
    PivotResult previous,
    Map<int, List<(CellValue, String?)>> rows,
    PivotContext ctx,
  ) {
    final r = previous;
    final source = r.source;
    final n = source.rowCount;
    if (r.cancelled || source.rowMask != null || !supportsDelta(r.spec)) {
      return null;
    }
    if (rows.isEmpty) return r;
    final cols = source.columns;
    final valueCols = [
      for (final v in r.valueFields)
        cols.indexOf(source.column(v.spec.source!)!),
    ];
    final rowGroupers = [
      for (final f in r.rowFields)
        PivotGrouper(f.spec, source.column(f.spec.source)!, locale: ctx.locale),
    ];
    final colGroupers = [
      for (final f in r.columnFields)
        PivotGrouper(f.spec, source.column(f.spec.source)!, locale: ctx.locale),
    ];
    final rowFieldCols = [
      for (final f in r.rowFields) cols.indexOf(source.column(f.spec.source)!),
    ];
    final colFieldCols = [
      for (final f in r.columnFields)
        cols.indexOf(source.column(f.spec.source)!),
    ];
    List<PivotAxisNode> ancestors(PivotAxisNode leaf) => [
      for (PivotAxisNode? x = leaf; x != null; x = x.parent) x,
    ];
    bool sameKeys(
      PivotAxisNode leaf,
      List<PivotGrouper> groupers,
      List<int> fieldCols,
      List<(CellValue, String?)> next,
    ) {
      final path = leaf.path;
      if (path.length != groupers.length) return false;
      for (var d = 0; d < groupers.length; d++) {
        final c = cols[fieldCols[d]];
        final (v, f) = next[fieldCols[d]];
        final k = groupers[d].keyOf(v, c.displayTextOf(v, f));
        if (k.identity != path[d].identity) return false;
      }
      return true;
    }

    // Check everything before changing anything.
    final pairs = <int, List<_Cell>>{};
    for (final MapEntry(key: i, value: next) in rows.entries) {
      if (i < 0 || i >= n || next.length != cols.length) return null;
      for (var c = 0; c < cols.length; c++) {
        if (cols[c].formats[i] != next[c].$2) return null;
      }
      final rl = r._rowLeafOf[i];
      final cl = r._columnLeafOf[i];
      if (rl < 0 || cl < 0) return null;
      final rowLeaf = r._rowNodes[rl];
      final colLeaf = r._columnNodes[cl];
      if (!sameKeys(rowLeaf, rowGroupers, rowFieldCols, next) ||
          !sameKeys(colLeaf, colGroupers, colFieldCols, next)) {
        return null;
      }
      final cells = [
        for (final a in ancestors(rowLeaf))
          for (final b in ancestors(colLeaf))
            if (r._cells[PivotResult._pairKey(a.id, b.id)] case final _Cell x)
              x,
      ];
      for (final cell in cells) {
        for (var j = 0; j < valueCols.length; j++) {
          if (!cell.aggs[j]!.canRemove(cols[valueCols[j]].values[i])) {
            return null;
          }
        }
      }
      pairs[i] = cells;
    }
    // Take the old values out, put the new ones in.
    final touched = <_Cell>{};
    for (final MapEntry(key: i, value: cells) in pairs.entries) {
      for (final cell in cells) {
        for (var j = 0; j < valueCols.length; j++) {
          cell.aggs[j]!.remove(cols[valueCols[j]].values[i]);
        }
        touched.add(cell);
      }
    }
    for (final MapEntry(key: i, value: next) in rows.entries) {
      for (var c = 0; c < cols.length; c++) {
        cols[c].setRow(i, next[c].$1, next[c].$2);
      }
      for (final cell in pairs[i]!) {
        for (var j = 0; j < valueCols.length; j++) {
          cell.aggs[j]!.add(cols[valueCols[j]].values[i]);
        }
      }
    }
    for (final cell in touched) {
      cell.results = [for (final a in cell.aggs) a!.result];
    }
    final byValue = [
      ...r.rowFields,
      ...r.columnFields,
    ].any((f) => f.spec.sortByValueIndex != null);
    if (byValue) {
      _sort(
        r.rowRoot,
        r.rowFields,
        r,
        (child, j) => r.rawValue(child, r.columnRoot, j),
      );
      _sort(
        r.columnRoot,
        r.columnFields,
        r,
        (child, j) => r.rawValue(r.rowRoot, child, j),
      );
      _numberLeaves(r.rowRoot, 0);
      _numberLeaves(r.columnRoot, 0);
    }
    return r;
  }

  /// The computation as checkpoints: `null` every [every] + 1 source rows
  /// (a place to pause), then the result.
  Iterable<PivotResult?> _steps(
    PivotSpec spec,
    SourceTable source,
    PivotContext ctx,
    CancellationToken? cancel, {
    int every = 0x3fff,
  }) sync* {
    final rowFields = _fields(spec.rows, source);
    final columnFields = _fields(spec.columns, source);
    final valueFields = _valueFields(spec, source);
    final n = source.rowCount;
    final excluded = _filter(spec, source, ctx, n);

    final rowGroupers = _groupers(rowFields, source, ctx, excluded);
    final colGroupers = _groupers(columnFields, source, ctx, excluded);

    final rowNodes = <PivotAxisNode>[];
    final colNodes = <PivotAxisNode>[];
    PivotAxisNode newNode(
      List<PivotAxisNode> all,
      PivotAxisNode? parent,
      PivotKey? key,
    ) {
      final node = PivotAxisNode._(
        all.length,
        parent,
        key,
        parent == null ? 0 : parent.depth + 1,
      );
      all.add(node);
      if (parent != null) {
        parent.children.add(node);
        parent._byIdentity[key!.identity] = node;
      }
      return node;
    }

    final rowRoot = newNode(rowNodes, null, null);
    final colRoot = newNode(colNodes, null, null);
    final rowLeafOf = Int32List(n)..fillRange(0, n, -1);
    final colLeafOf = Int32List(n)..fillRange(0, n, -1);

    final cells = <int, _Cell>{};
    final pairCache = <int, List<_Cell>>{};
    final hasCustom = valueFields.any(
      (v) => v.spec.isCalculated && v.summarizeBy == PivotSummarize.custom,
    );
    final rowValue = [
      for (final v in valueFields) _rowValueFn(v.spec, source, ctx),
    ];

    _Cell cellOf(int r, int c) => cells.putIfAbsent(
      PivotResult._pairKey(r, c),
      () => _Cell([
        for (final v in valueFields)
          v.spec.isCalculated && v.summarizeBy == PivotSummarize.custom
              ? null
              : Aggregator.create(v.summarizeBy),
      ])..rows = hasCustom ? <int>[] : null,
    );

    PivotAxisNode leafOf(
      PivotAxisNode root,
      List<PivotAxisNode> all,
      List<PivotGrouper> groupers,
      int i,
    ) {
      var node = root;
      for (final g in groupers) {
        final k = g.keyOfRow(i);
        node = node._child(k.identity) ?? newNode(all, node, k);
      }
      return node;
    }

    List<PivotAxisNode> ancestors(PivotAxisNode leaf) => [
      for (PivotAxisNode? x = leaf; x != null; x = x.parent) x,
    ];

    for (var i = 0; i < n; i++) {
      if ((i & every) == 0) {
        if (cancel?.isCancelled ?? false) {
          yield _cancelled(
            spec,
            source,
            rowFields,
            columnFields,
            valueFields,
            ctx,
          );
          return;
        }
        if (i > 0) yield null;
      }
      if (excluded[i] == 1) continue;
      final rl = leafOf(rowRoot, rowNodes, rowGroupers, i);
      final cl = leafOf(colRoot, colNodes, colGroupers, i);
      rowLeafOf[i] = rl.id;
      colLeafOf[i] = cl.id;
      final pair = pairCache.putIfAbsent(
        PivotResult._pairKey(rl.id, cl.id),
        () {
          final ra = ancestors(rl);
          final ca = ancestors(cl);
          return [
            for (final r in ra)
              for (final c in ca) cellOf(r.id, c.id),
          ];
        },
      );
      if (valueFields.isEmpty) continue;
      final vs = [for (final f in rowValue) f?.call(i)];
      for (final cell in pair) {
        for (var j = 0; j < vs.length; j++) {
          final v = vs[j];
          if (v != null) cell.aggs[j]!.add(v);
        }
        cell.rows?.add(i);
      }
    }

    // `showEmptyGroups` (P2): every item of a group under every item of
    // the enclosing group, with or without data (filtered rows included).
    if (spec.showEmptyGroups) {
      void fill(
        PivotAxisNode root,
        List<PivotAxisNode> all,
        List<PivotGrouper> groupers,
      ) {
        if (groupers.isEmpty) return;
        final levels = [
          for (var d = 0; d < groupers.length; d++) <Object, PivotKey>{},
        ];
        for (var i = 0; i < n; i++) {
          for (var d = 0; d < groupers.length; d++) {
            final k = groupers[d].keyOfRow(i);
            levels[d].putIfAbsent(k.identity, () => k);
          }
        }
        void walk(PivotAxisNode node) {
          if (node.depth >= groupers.length) return;
          for (final k in levels[node.depth].values) {
            if (node._child(k.identity) == null) newNode(all, node, k);
          }
          node.children.forEach(walk);
        }

        walk(root);
      }

      fill(rowRoot, rowNodes, rowGroupers);
      fill(colRoot, colNodes, colGroupers);
    }

    // Results (custom calculated fields per output cell).
    for (final cell in cells.values) {
      cell.results = [
        for (var j = 0; j < valueFields.length; j++)
          cell.aggs[j]?.result ?? _custom(valueFields[j], cell, source, ctx),
      ];
      cell.rows = null;
    }

    final result = PivotResult._(
      spec: spec,
      source: source,
      rowFields: rowFields,
      columnFields: columnFields,
      valueFields: valueFields,
      rowRoot: rowRoot,
      columnRoot: colRoot,
      cells: cells,
      rowLeafOf: rowLeafOf,
      columnLeafOf: colLeafOf,
      rowNodes: rowNodes,
      columnNodes: colNodes,
      maxOutputCells: ctx.maxOutputCells,
    );
    _sort(
      rowRoot,
      rowFields,
      result,
      (child, j) => result.rawValue(child, colRoot, j),
    );
    _sort(
      colRoot,
      columnFields,
      result,
      (child, j) => result.rawValue(rowRoot, child, j),
    );
    _numberLeaves(rowRoot, 0);
    _numberLeaves(colRoot, 0);
    yield result;
  }

  PivotResult _cancelled(
    PivotSpec spec,
    SourceTable source,
    List<PivotFieldInfo> rowFields,
    List<PivotFieldInfo> columnFields,
    List<PivotValueField> valueFields,
    PivotContext ctx,
  ) {
    final rowRoot = PivotAxisNode._(0, null, null, 0);
    final colRoot = PivotAxisNode._(0, null, null, 0);
    return PivotResult._(
      spec: spec,
      source: source,
      rowFields: rowFields,
      columnFields: columnFields,
      valueFields: valueFields,
      rowRoot: rowRoot,
      columnRoot: colRoot,
      cells: const {},
      rowLeafOf: Int32List(0),
      columnLeafOf: Int32List(0),
      rowNodes: [rowRoot],
      columnNodes: [colRoot],
      maxOutputCells: ctx.maxOutputCells,
      cancelled: true,
    );
  }

  static List<PivotFieldInfo> _fields(
    List<PivotGroupSpec> groups,
    SourceTable source,
  ) => [
    for (var i = 0; i < groups.length; i++)
      if (source.column(groups[i].source) case final SourceColumn col)
        PivotFieldInfo(
          spec: groups[i],
          specIndex: i,
          header: col.header,
          numberFormat: col.numberFormat,
        ),
  ];

  static List<PivotValueField> _valueFields(
    PivotSpec spec,
    SourceTable source,
  ) {
    final out = <PivotValueField>[];
    var calculated = 0;
    for (var i = 0; i < spec.values.length; i++) {
      final v = spec.values[i];
      String? inherited;
      final String header;
      if (v.isCalculated) {
        calculated++;
        header = '';
      } else {
        final col = source.column(v.source ?? '');
        if (col == null) continue;
        header = col.header;
        if (v.summarizeBy.inheritsFormat) inherited = col.numberFormat;
      }
      final custom = v.numberFormat;
      out.add(
        PivotValueField(
          spec: v,
          specIndex: i,
          name: v.displayName(
            v.isCalculated ? null : header,
            calculatedIndex: calculated,
          ),
          header: header,
          numberFormat: custom != null && custom.isNotEmpty
              ? custom
              : (v.showAs != PivotShowAs.defaultValue ? '0.00%' : inherited),
        ),
      );
    }
    return out;
  }

  /// Rows excluded by slicers ([SourceTable.rowMask]) or pivot filters.
  static Uint8List _filter(
    PivotSpec spec,
    SourceTable source,
    PivotContext ctx,
    int n,
  ) {
    final excluded = Uint8List(n);
    final mask = source.rowMask;
    if (mask != null) {
      for (var i = 0; i < n && i < mask.length; i++) {
        excluded[i] = mask[i] == 0 ? 0 : 1;
      }
    }
    final criteria = <int, ColumnCriteria>{};
    final data = _SourceFilterData(source);
    for (final f in spec.filters) {
      final col = source.column(f.source);
      if (col == null || f.criteria.isEmpty) continue;
      final x = data.colOf(col);
      final prev = criteria[x];
      criteria[x] = prev == null ? f.criteria : _and(prev, f.criteria);
    }
    if (criteria.isEmpty) return excluded;
    final visibility = FilterEngine.compute(
      FilterInput(
        sheetId: source.sheetId,
        range: data.range,
        criteria: criteria,
        source: data,
        conditions: ctx.conditions,
      ),
    );
    for (var i = 0; i < n && i < visibility.hidden.length; i++) {
      if (visibility.hidden[i] == 1) excluded[i] = 1;
    }
    return excluded;
  }

  /// Two filters on the same column: hidden values are combined; the
  /// later condition wins (the editor allows one filter per field).
  static ColumnCriteria _and(ColumnCriteria a, ColumnCriteria b) =>
      ColumnCriteria(
        hiddenValues: {...a.hiddenValues, ...b.hiddenValues},
        condition: b.condition ?? a.condition,
        visibleBackgroundColor:
            b.visibleBackgroundColor ?? a.visibleBackgroundColor,
        visibleForegroundColor:
            b.visibleForegroundColor ?? a.visibleForegroundColor,
      );

  static List<PivotGrouper> _groupers(
    List<PivotFieldInfo> fields,
    SourceTable source,
    PivotContext ctx,
    Uint8List excluded,
  ) {
    final out = <PivotGrouper>[];
    for (final f in fields) {
      final col = source.column(f.spec.source)!;
      double? lo;
      double? hi;
      if (f.spec.group is PivotHistogramGrouping) {
        for (var i = 0; i < col.values.length; i++) {
          if (excluded[i] == 1) continue;
          final v = col.values[i];
          if (v is! NumberValue) continue;
          final x = v.number;
          if (lo == null || x < lo) lo = x;
          if (hi == null || x > hi) hi = x;
        }
      }
      out.add(
        PivotGrouper(
          f.spec,
          col,
          locale: ctx.locale,
          histogramMin: lo,
          histogramMax: hi,
        ),
      );
    }
    return out;
  }

  /// The per-row input of a value field (null: custom calculated fields,
  /// evaluated per output cell instead).
  static CellValue Function(int i)? _rowValueFn(
    PivotValueSpec v,
    SourceTable source,
    PivotContext ctx,
  ) {
    if (!v.isCalculated) {
      final col = source.column(v.source ?? '')!;
      return (i) => col.values[i];
    }
    if (v.summarizeBy == PivotSummarize.custom) return null;
    final formulas = ctx.formulas;
    final formula = v.formula!;
    if (formulas == null) return (_) => _noEvaluator;
    return (i) => formulas.evaluateRow(
      formula,
      (colId) => source.column(colId)?.values[i] ?? _missingField,
    );
  }

  static const CellValue _noEvaluator = ErrorValue(
    CellErrorKind.name,
    'Calculated fields need the formula engine.',
  );
  static const CellValue _missingField = ErrorValue(CellErrorKind.ref);

  static CellValue _custom(
    PivotValueField v,
    _Cell cell,
    SourceTable source,
    PivotContext ctx,
  ) {
    final formulas = ctx.formulas;
    if (formulas == null) return _noEvaluator;
    final rows = cell.rows ?? const <int>[];
    return formulas.evaluateGroup(v.spec.formula!, (colId) {
      final col = source.column(colId);
      if (col == null) return const [_missingField];
      return [for (final i in rows) col.values[i]];
    });
  }

  /// Sorts children recursively: by label (07 §2.3 type order, blanks last)
  /// or by a value's total (`sortByValue`).
  static void _sort(
    PivotAxisNode node,
    List<PivotFieldInfo> fields,
    PivotResult result,
    CellValue Function(PivotAxisNode child, int valueIndex) total,
  ) {
    if (node.children.isEmpty) return;
    final field = fields[node.depth];
    final asc = field.spec.ascending;
    final sbv = field.spec.sortByValueIndex;
    final vi = sbv == null ? -1 : result.valueIndexOfSpec(sbv);
    int byLabel(PivotAxisNode a, PivotAxisNode b) =>
        PivotKey.compare(a.key!, b.key!, ascending: asc);
    if (vi < 0) {
      node.children.sort(byLabel);
    } else {
      final totals = {for (final c in node.children) c.id: total(c, vi)};
      node.children.sort((a, b) {
        final c = _compareTotals(totals[a.id]!, totals[b.id]!, asc);
        return c != 0 ? c : byLabel(a, b);
      });
    }
    for (final c in node.children) {
      _sort(c, fields, result, total);
    }
  }

  /// Numbers first (in [ascending] order), then other values; blanks last.
  static int _compareTotals(CellValue a, CellValue b, bool ascending) {
    int rank(CellValue v) => switch (v) {
      NumberValue() => 0,
      EmptyValue() => 2,
      _ => 1,
    };
    final ra = rank(a);
    final rb = rank(b);
    if (ra != rb) return ra - rb;
    if (a is NumberValue && b is NumberValue) {
      final c = Numeric.compare(a.number, b.number);
      return ascending ? c : -c;
    }
    return 0;
  }

  static int _numberLeaves(PivotAxisNode node, int next) {
    node._firstLeaf = next;
    if (node.children.isEmpty) {
      node._lastLeaf = next;
      return next + 1;
    }
    var n = next;
    for (final c in node.children) {
      n = _numberLeaves(c, n);
    }
    node._lastLeaf = n - 1;
    return n;
  }
}

/// Pivot source rows as a [FilterDataSource]: sheet coordinates when the
/// columns carry distinct sheet columns, else virtual coordinates.
final class _SourceFilterData implements FilterDataSource {
  _SourceFilterData(this.source) {
    final sheetCols = {for (final c in source.columns) c.sheetCol};
    _sheetCoords =
        sheetCols.length == source.columns.length && source.columns.isNotEmpty;
    for (var i = 0; i < source.columns.length; i++) {
      final c = source.columns[i];
      _byCol[_sheetCoords ? c.sheetCol : i] = c;
    }
  }

  final SourceTable source;
  late final bool _sheetCoords;
  final Map<int, SourceColumn> _byCol = {};

  int get _top => _sheetCoords ? source.range.top : 0;

  /// The filter range (header row first).
  GridRect get range {
    if (_sheetCoords) {
      final cols = [for (final c in source.columns) c.sheetCol]..sort();
      return GridRect(_top, cols.first, _top + source.rowCount, cols.last);
    }
    final last = source.columns.isEmpty ? 0 : source.columns.length - 1;
    return GridRect(0, 0, source.rowCount, last);
  }

  int colOf(SourceColumn c) =>
      _sheetCoords ? c.sheetCol : source.columns.indexOf(c);

  int _index(int row) => row - _top - 1;

  @override
  CellValue valueAt(int row, int col) {
    final c = _byCol[col];
    final i = _index(row);
    if (c == null || i < 0 || i >= c.values.length) return CellValue.empty;
    return c.values[i];
  }

  @override
  String displayTextAt(int row, int col) {
    final c = _byCol[col];
    final i = _index(row);
    if (c == null || i < 0 || i >= c.values.length) return '';
    return c.displayText(i);
  }

  @override
  String? numberFormatAt(int row, int col) {
    final c = _byCol[col];
    final i = _index(row);
    if (c == null || i < 0 || i >= c.formats.length) return null;
    return c.formats[i];
  }

  @override
  String? fillColorAt(int row, int col) {
    final c = _byCol[col];
    final i = _index(row);
    final colors = c?.fillColors;
    if (colors == null || i < 0 || i >= colors.length) return null;
    return colors[i];
  }

  @override
  String? textColorAt(int row, int col) {
    final c = _byCol[col];
    final i = _index(row);
    final colors = c?.textColors;
    if (colors == null || i < 0 || i >= colors.length) return null;
    return colors[i];
  }
}
