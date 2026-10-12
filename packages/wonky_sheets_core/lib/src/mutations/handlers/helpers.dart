import 'dart:convert';

import 'package:wonky_sync_models/ids.dart';

import '../../addressing/grid_geometry.dart';
import '../../format/attributes.dart';
import '../../model/grid_range.dart';
import '../../model/records.dart';
import '../../model/schema.dart';
import '../../model/sheet_model.dart';
import '../plan_builder.dart';

/// Shared helpers of the planner handlers.
extension PlanBuilderHelpers on PlanBuilder {
  /// The sheet or a `not_found` error.
  SheetModel sheetOf(String sheetId) {
    final s = model.sheet(sheetId);
    if (s == null) throw PlanException('not_found', 'Sheet not found', details: {'sheetId': sheetId});
    return s;
  }

  /// Validates that [rect] lies inside the grid of [s].
  void checkRect(SheetModel s, GridRect rect) {
    if (rect.top < 0 ||
        rect.left < 0 ||
        rect.bottom >= s.rows.length ||
        rect.right >= s.columns.length ||
        rect.bottom < rect.top ||
        rect.right < rect.left) {
      throw PlanException('invalid_range', 'Range ${rect.a1} is outside the grid of "${s.name}"');
    }
  }

  /// Writes a `formatJson` column of a row/column/sheet record: sets the given
  /// attributes (null removes the key).
  void writeFormatJson(String table, String id, Map<FormatAttr, Object?> values) {
    final cur = current(table, id);
    if (cur == null) return;
    final f = CellFormat.fromJson(cur[Cols.formatJson] as String?).withValues(values);
    update(table, id, {Cols.formatJson: f.toJson()});
  }

  /// Current `formatJson` of a record as a [CellFormat].
  CellFormat formatJsonOf(String table, String id) =>
      CellFormat.fromJson(current(table, id)?[Cols.formatJson] as String?);

  /// The number of grid cells of all sheets if [sheetId] had [rows] × [cols].
  int gridCellsWith(String sheetId, int rows, int cols) {
    var n = 0;
    for (final s in model.sheets) {
      n += s.id == sheetId ? rows * cols : s.rows.length * s.columns.length;
    }
    if (model.sheet(sheetId) == null) n += rows * cols;
    return n;
  }

  /// Throws `cell_limit_exceeded` when the grid would exceed the limit.
  void checkCellLimit(int newTotal) {
    if (newTotal > ctx.maxCells) {
      throw PlanException(
        'cell_limit_exceeded',
        'This would make the spreadsheet $newTotal cells; the limit is ${ctx.maxCells}.',
        details: {'cells': newTotal, 'limit': ctx.maxCells},
      );
    }
  }

  /// Appends [count] rows (or columns) at the end of [s]; returns the new ids.
  List<String> appendDimension(SheetModel s, Dimension d, int count) {
    if (count <= 0) return const [];
    final axis = s.axis(d);
    final lastKey = axis.length == 0 ? null : axis.sortKeyAt(axis.length - 1);
    final keys = FractionalIndex.nBetween(lastKey, null, count);
    final table = d == Dimension.rows ? SheetsTables.sheetRow : SheetsTables.sheetColumn;
    final ids = <String>[];
    for (final k in keys) {
      final id = ctx.ids.newId();
      ids.add(id);
      insert(table, id, {Cols.sheetId: s.id, Cols.sortKey: k, Cols.hidden: false});
    }
    summary.kinds.add('structure');
    return ids;
  }

  /// GridRange JSON for a rect of [s].
  String rangeJson(SheetModel s, GridRect rect, {bool wholeRows = false, bool wholeColumns = false}) =>
      s.gridRange(rect, wholeRows: wholeRows, wholeColumns: wholeColumns).encode();

  /// GridRange list JSON for rects of [s].
  String rangesJson(SheetModel s, Iterable<GridRect> rects) =>
      GridRange.encodeList(rects.map((r) => s.gridRange(r)));

  /// A sort key before [beforeKey] and after the last key smaller than it, among
  /// [keys] (sorted); null [beforeKey] appends after the last key.
  static String keyBefore(List<String> sortedKeys, String? beforeKey) {
    if (beforeKey == null) {
      return FractionalIndex.after(sortedKeys.isEmpty ? null : sortedKeys.last);
    }
    String? prev;
    for (final k in sortedKeys) {
      if (k.compareTo(beforeKey) < 0) prev = k;
    }
    if (prev == beforeKey) return FractionalIndex.after(prev);
    return FractionalIndex.between(prev, beforeKey);
  }

  /// Iterates the current cell rows (overlay-aware) of [s] inside [rect] as
  /// `(row, col, rowId, colId, columns)`; includes cells written earlier in
  /// the plan.
  Iterable<(int, int, String, String, Map<String, Object?>)> cellsIn(SheetModel s, GridRect rect) sync* {
    final seen = <String>{};
    for (final (r, c, cell) in s.cellsIn(rect)) {
      seen.add(cell.id);
      final cur = current(SheetsTables.cell, cell.id);
      if (cur != null) yield (r, c, cell.rowId, cell.columnId, cur);
    }
    for (final e in touchedRows(SheetsTables.cell).entries) {
      if (seen.contains(e.key) || e.value == null) continue;
      final v = e.value!;
      if (v[Cols.sheetId] != s.id) continue;
      final r = s.rows.indexOf(v[CellCols.rowId] as String);
      final c = s.columns.indexOf(v[CellCols.columnId] as String);
      if (r < 0 || c < 0 || !rect.contains(r, c)) continue;
      yield (r, c, v[CellCols.rowId] as String, v[CellCols.columnId] as String, Map.of(v));
    }
  }

  /// Decodes a JSON string column (map) or returns an empty map.
  static Map<String, Object?> decodeMap(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final v = jsonDecode(json);
      return v is Map ? v.cast<String, Object?>() : {};
    } on FormatException {
      return {};
    }
  }
}

/// All cells of the record types of a sheet that have a row id inside [s].
extension SheetCells on SheetModel {
  /// Cell records of [rowIds].
  Iterable<CellRecord> cellsOfRows(Iterable<String> rowIds) sync* {
    for (final r in rowIds) {
      yield* cells.inRow(r);
    }
  }
}
