import '../addressing/grid_geometry.dart';
import 'axis_index.dart';
import 'cell_store.dart';
import 'events.dart';
import 'grid_range.dart';
import 'records.dart';
import 'rect_index.dart';
import 'schema.dart';

/// In-memory state of one sheet: axes, cells and range rules.
final class SheetModel {
  /// Creates an empty sheet model.
  SheetModel(this.id);

  /// Sheet id.
  final String id;

  /// The `Sheet` row; null while only children have arrived (sync ordering).
  SheetRecord? record;

  /// Rows in order.
  final AxisIndex rows = AxisIndex(defaultSize: 21);

  /// Columns in order.
  final AxisIndex columns = AxisIndex(defaultSize: 100);

  /// `SheetRow` records by id.
  final Map<String, DimensionRecord> rowRecords = {};

  /// `SheetColumn` records by id.
  final Map<String, DimensionRecord> columnRecords = {};

  /// Cells.
  final CellStore cells = CellStore();

  final Map<String, MergedRangeRecord> merges = {};
  final Map<String, DimensionGroupRecord> groups = {};
  final Map<String, ProtectedRangeRecord> protections = {};
  final Map<String, CfRuleRecord> cfRules = {};
  final Map<String, DvRuleRecord> dvRules = {};
  final Map<String, FilterRecord> filterViews = {};
  final Map<String, BandingRecord> bandings = {};
  final Map<String, EmbeddedObjectRecord> objects = {};
  final Map<String, PivotTableRecord> pivots = {};

  /// The basic filter (max one per sheet).
  FilterRecord? basicFilter;

  /// Sheet name ('' while the record is missing).
  String get name => record?.name ?? '';

  /// Axis of [d].
  AxisIndex axis(Dimension d) => d == Dimension.rows ? rows : columns;

  /// Dimension records of [d].
  Map<String, DimensionRecord> dimensionRecords(Dimension d) =>
      d == Dimension.rows ? rowRecords : columnRecords;

  /// Cell at indices.
  CellRecord? cellAt(int row, int col) {
    final r = rows.tryIdAt(row);
    final c = columns.tryIdAt(col);
    if (r == null || c == null) return null;
    return cells.at(r, c);
  }

  /// Cells in an index rectangle (row-major).
  Iterable<(int row, int col, CellRecord cell)> cellsIn(
    GridRect rect, {
    bool contentOnly = false,
  }) => cells.cellsIn(
    rows,
    columns,
    rect.top,
    rect.left,
    rect.bottom,
    rect.right,
    contentOnly: contentOnly,
  );

  /// The whole grid as a rectangle (null when the sheet has no rows/columns).
  GridRect? get gridRect => rows.length == 0 || columns.length == 0
      ? null
      : GridRect(0, 0, rows.length - 1, columns.length - 1);

  /// Bounding box `A1:<last content cell>` (null when empty).
  GridRect? usedRect({bool includeFormatOnly = false}) {
    final e = cells.usedExtent(rows, columns, includeFormatOnly: includeFormatOnly);
    if (e == null) return null;
    return GridRect(0, 0, e.$1, e.$2);
  }

  // ---------------------------------------------------------------------------
  // Range resolution.

  /// Resolves an id-based range to indices (null when it resolves to nothing).
  ///
  /// Deleted endpoints resolve through their sortKey hints: a deleted start
  /// moves to the first surviving entry at or after its position, a deleted end
  /// to the last surviving entry before it (05 §5.4). Without hints a deleted
  /// endpoint makes the range unresolvable.
  ResolvedRange? resolve(GridRange r) {
    final rowSpan = _resolveSpan(rows, r.r1, r.r2, r.r1k, r.r2k);
    final colSpan = _resolveSpan(columns, r.c1, r.c2, r.c1k, r.c2k);
    if (rowSpan == null || colSpan == null) return null;
    return ResolvedRange(
      id,
      GridRect(rowSpan.$1, colSpan.$1, rowSpan.$2, colSpan.$2),
      wholeRows: r.unboundedColumns,
      wholeColumns: r.unboundedRows,
    );
  }

  static (int, int)? _resolveSpan(AxisIndex axis, String? a, String? b, String? ak, String? bk) {
    final n = axis.length;
    if (n == 0) return null;
    int? start;
    int? end;
    if (a == null) {
      start = 0;
    } else {
      final i = axis.indexOf(a);
      if (i >= 0) {
        start = i;
      } else if (ak != null) {
        start = axis.insertionIndex(ak, a);
      }
    }
    if (b == null) {
      end = n - 1;
    } else {
      final i = axis.indexOf(b);
      if (i >= 0) {
        end = i;
      } else if (bk != null) {
        end = axis.insertionIndex(bk, b) - 1;
      }
    }
    if (start == null || end == null) return null;
    if (a != null && b != null && axis.indexOf(a) >= 0 && axis.indexOf(b) >= 0 && start > end) {
      // Endpoints reordered (e.g. moved rows): normalize.
      final t = start;
      start = end;
      end = t;
    }
    if (start > end || start >= n || end < 0) return null;
    return (start, end);
  }

  /// Builds an id-based range for an index rectangle. [wholeRows] /
  /// [wholeColumns] leave the column / row bounds open.
  GridRange gridRange(GridRect rect, {bool wholeRows = false, bool wholeColumns = false}) {
    String? rid(int i) => rows.tryIdAt(i);
    String? cid(int i) => columns.tryIdAt(i);
    final r1 = wholeColumns ? null : rid(rect.top);
    final r2 = wholeColumns ? null : rid(rect.bottom);
    final c1 = wholeRows ? null : cid(rect.left);
    final c2 = wholeRows ? null : cid(rect.right);
    return GridRange(
      sheetId: id,
      r1: r1,
      r2: r2,
      c1: c1,
      c2: c2,
      r1k: r1 == null ? null : rows.sortKeyOf(r1),
      r2k: r2 == null ? null : rows.sortKeyOf(r2),
      c1k: c1 == null ? null : columns.sortKeyOf(c1),
      c2k: c2 == null ? null : columns.sortKeyOf(c2),
    );
  }

  // ---------------------------------------------------------------------------
  // Rule index.

  final Map<RuleKind, RectIndex<String>> _ruleIndexes = {};
  final Map<RuleKind, (int, int)> _ruleIndexGen = {};

  /// Invalidates the rule index of [kind] (after rule changes).
  void invalidateRules(RuleKind kind) => _ruleIndexes.remove(kind);

  /// The rectangles of a rule's ranges (resolved now).
  List<GridRect> ruleRects(RuleKind kind, String ruleId) {
    final ranges = _rangesOf(kind, ruleId);
    return [
      for (final r in ranges)
        if (resolve(r) case final ResolvedRange rr) rr.rect,
    ];
  }

  /// Rule ids of [kind] covering (row, col), in insertion order.
  List<String> rulesAt(RuleKind kind, int row, int col) =>
      ruleIndex(kind).at(row, col).toSet().toList();

  /// Rule ids of [kind] intersecting [rect].
  List<String> rulesIntersecting(RuleKind kind, GridRect rect) =>
      ruleIndex(kind).intersecting(rect).toSet().toList();

  /// The (lazily rebuilt) rectangle index of [kind].
  RectIndex<String> ruleIndex(RuleKind kind) {
    final gen = (rows.generation, columns.generation);
    final cached = _ruleIndexes[kind];
    if (cached != null && _ruleIndexGen[kind] == gen) return cached;
    final entries = <(GridRect, String)>[];
    for (final ruleId in _ruleIds(kind)) {
      for (final r in _rangesOf(kind, ruleId)) {
        final rr = resolve(r);
        if (rr != null) entries.add((rr.rect, ruleId));
      }
    }
    final idx = RectIndex<String>(entries);
    _ruleIndexes[kind] = idx;
    _ruleIndexGen[kind] = gen;
    return idx;
  }

  Iterable<String> _ruleIds(RuleKind kind) => switch (kind) {
    RuleKind.merge => merges.keys,
    RuleKind.conditionalFormat => cfRules.keys,
    RuleKind.dataValidation => dvRules.keys,
    RuleKind.protection => protections.keys,
    RuleKind.basicFilter => [?basicFilter?.id],
    RuleKind.filterView => filterViews.keys,
    RuleKind.banding => bandings.keys,
    RuleKind.object => objects.keys,
    RuleKind.pivot => pivots.keys,
    RuleKind.group => groups.keys,
  };

  /// The id-based ranges of a rule.
  List<GridRange> _rangesOf(RuleKind kind, String ruleId) {
    GridRange? one(String? json) => GridRange.tryParse(json);
    switch (kind) {
      case RuleKind.merge:
        return [?one(merges[ruleId]?.rangeJson)];
      case RuleKind.conditionalFormat:
        return GridRange.parseList(cfRules[ruleId]?.rangesJson);
      case RuleKind.dataValidation:
        return GridRange.parseList(dvRules[ruleId]?.rangesJson);
      case RuleKind.protection:
        final p = protections[ruleId];
        if (p == null) return const [];
        return p.rangeJson == null ? [GridRange.sheet(id)] : [?one(p.rangeJson)];
      case RuleKind.basicFilter:
        return basicFilter?.id == ruleId ? [?one(basicFilter!.rangeJson)] : const [];
      case RuleKind.filterView:
        return [?one(filterViews[ruleId]?.rangeJson)];
      case RuleKind.banding:
        return [?one(bandings[ruleId]?.rangeJson)];
      case RuleKind.object:
        return const [];
      case RuleKind.pivot:
        return const [];
      case RuleKind.group:
        final g = groups[ruleId];
        if (g == null) return const [];
        return g.dimension == Dimension.rows
            ? [GridRange(sheetId: id, r1: g.startId, r2: g.endId)]
            : [GridRange(sheetId: id, c1: g.startId, c2: g.endId)];
    }
  }

  /// The id-based ranges of a rule (public).
  List<GridRange> rangesOf(RuleKind kind, String ruleId) => _rangesOf(kind, ruleId);

  /// The merge covering (row, col) as a rectangle, or null.
  GridRect? mergeAt(int row, int col) {
    final ids = rulesAt(RuleKind.merge, row, col);
    if (ids.isEmpty) return null;
    // Overlapping merges (concurrent edits): the smaller id wins (02 §8).
    ids.sort();
    final rects = ruleRects(RuleKind.merge, ids.first);
    return rects.isEmpty ? null : rects.first;
  }

  /// All merge rectangles intersecting [rect].
  List<(String id, GridRect rect)> mergesIntersecting(GridRect rect) => [
    for (final id in rulesIntersecting(RuleKind.merge, rect))
      for (final r in ruleRects(RuleKind.merge, id)) (id, r),
  ];
}
