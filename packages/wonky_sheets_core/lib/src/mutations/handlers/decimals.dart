import '../../content/cell_content.dart';
import '../../engine_bridge/value_bridge.dart';
import '../../format/attributes.dart';
import '../../format/number_format/decimals.dart';
import '../../format/number_format/presets.dart';
import '../../model/grid_range.dart';
import '../../model/schema.dart';
import '../../model/sheet_model.dart';
import '../operations.dart';
import '../plan_builder.dart';
import '../row_change.dart';
import 'format.dart';
import 'helpers.dart';
import 'row_tools.dart';
import 'values.dart';

/// [AdjustDecimals] (06 §5.10): every distinct effective number format in
/// the selection gets one more (or one fewer) decimal with
/// [DecimalsAdjuster]; Automatic cells derive their decimals from the active
/// cell's value. Bounded ranges write `numberFormat` per cell; whole rows,
/// columns or sheets adjust the row/column/sheet defaults and the explicit
/// formats underneath, each level from its own pattern.
///
/// Result: `cells` (cell formats written) and `formats` (distinct new
/// patterns).
MutationPlan planAdjustDecimals(PlanBuilder b, AdjustDecimals op) {
  final label = op.delta >= 0 ? 'Increase decimals' : 'Decrease decimals';
  if (op.delta == 0 || op.ranges.isEmpty) return b.build(label);
  final active = _activeValue(b, op);
  final cache = <String?, String>{};
  String adjust(String? pattern) {
    final key = _key(pattern);
    return cache[key] ??= DecimalsAdjuster.adjust(
      key,
      op.delta,
      activeValue: active,
      locale: b.locale,
    );
  }

  var cells = 0;
  for (final range in op.ranges) {
    final s = b.sheetOf(range.sheetId);
    final rect = range.rect;
    b.checkRect(s, rect);
    b.addResolvedRange(range);
    if (range.wholeRows || range.wholeColumns) {
      cells += _adjustDefaults(b, s, range, adjust);
      continue;
    }
    final values = planValues(b);
    for (var r = rect.top; r <= rect.bottom; r++) {
      final rowId = s.rows.idAt(r);
      for (var c = rect.left; c <= rect.right; c++) {
        final colId = s.columns.idAt(c);
        var pattern = effectiveNumberFormat(b, s, rowId, colId);
        if (NumberFormatPresets.isAutomatic(pattern)) {
          pattern = values.numberFormatAt(s.id, r, c) ?? pattern;
        }
        final next = adjust(pattern);
        if (next == pattern) continue;
        writeCellFormat(b, s, rowId, colId, {FormatAttr.numberFormat: next});
        cells++;
      }
    }
  }
  b.result['cells'] = cells;
  b.result['formats'] = cache.values.toSet().toList();
  return b.build(label, kinds: [ChangeKinds.format]);
}

/// Automatic spellings normalized to null (cache key).
String? _key(String? pattern) =>
    NumberFormatPresets.isAutomatic(pattern) ? null : pattern;

int _adjustDefaults(
  PlanBuilder b,
  SheetModel s,
  ResolvedRange range,
  String Function(String?) adjust,
) {
  final rect = range.rect;
  String? fmtOf(String table, String id) =>
      b.formatJsonOf(table, id)[FormatAttr.numberFormat] as String?;
  final sheetPattern = s.record?.format[FormatAttr.numberFormat] as String?;
  var cells = 0;
  void cell(String rowId, String colId, String? pattern) {
    final next = adjust(pattern);
    writeCellFormat(b, s, rowId, colId, {FormatAttr.numberFormat: next});
    cells++;
  }

  final rowsWithFormat = <String>{
    for (final rec in s.rowRecords.values)
      if (fmtOf(SheetsTables.sheetRow, rec.id) != null) rec.id,
  };
  final colsWithFormat = <String>{
    for (final rec in s.columnRecords.values)
      if (fmtOf(SheetsTables.sheetColumn, rec.id) != null) rec.id,
  };
  // Explicit cell formats keep their own pattern.
  final explicit = <(String, String)>{};
  for (final (_, _, rowId, colId, cur) in b.cellsIn(s, rect).toList()) {
    final p = cur[CellCols.numberFormat] as String?;
    if (p == null) continue;
    explicit.add((rowId, colId));
    cell(rowId, colId, p);
  }
  if (range.wholeSheet) {
    b.writeFormatJson(SheetsTables.sheet, s.id, {
      FormatAttr.numberFormat: adjust(sheetPattern),
    });
    for (final id in rowsWithFormat) {
      b.writeFormatJson(SheetsTables.sheetRow, id, {
        FormatAttr.numberFormat: adjust(fmtOf(SheetsTables.sheetRow, id)),
      });
    }
    for (final id in colsWithFormat) {
      b.writeFormatJson(SheetsTables.sheetColumn, id, {
        FormatAttr.numberFormat: adjust(fmtOf(SheetsTables.sheetColumn, id)),
      });
    }
    return cells;
  }
  if (range.wholeColumns) {
    for (var c = rect.left; c <= rect.right; c++) {
      final colId = s.columns.idAt(c);
      final own = fmtOf(SheetsTables.sheetColumn, colId) ?? sheetPattern;
      b.writeFormatJson(SheetsTables.sheetColumn, colId, {
        FormatAttr.numberFormat: adjust(own),
      });
      // Row defaults out-rank the column default: adjust the intersections
      // from the row's pattern.
      for (final rowId in rowsWithFormat) {
        if (explicit.contains((rowId, colId))) continue;
        cell(rowId, colId, fmtOf(SheetsTables.sheetRow, rowId));
      }
    }
    return cells;
  }
  for (var r = rect.top; r <= rect.bottom; r++) {
    final rowId = s.rows.idAt(r);
    final own = fmtOf(SheetsTables.sheetRow, rowId);
    b.writeFormatJson(SheetsTables.sheetRow, rowId, {
      FormatAttr.numberFormat: adjust(own ?? sheetPattern),
    });
    // Without a row default, columns with their own pattern showed that
    // pattern: keep it (adjusted) at the intersections.
    if (own != null) continue;
    for (final colId in colsWithFormat) {
      if (explicit.contains((rowId, colId))) continue;
      cell(rowId, colId, fmtOf(SheetsTables.sheetColumn, colId));
    }
  }
  return cells;
}

CellValue? _activeValue(PlanBuilder b, AdjustDecimals op) {
  final values = planValues(b);
  final a = op.active;
  if (a != null) {
    final v = values.valueAt(a.$1, a.$2, a.$3).toCellValue();
    if (v is NumberValue) return v;
  }
  for (final range in op.ranges) {
    final s = b.model.sheet(range.sheetId);
    if (s == null) continue;
    for (final (r, c, _) in s.cellsIn(range.rect, contentOnly: true)) {
      final v = values.valueAt(s.id, r, c).toCellValue();
      if (v is NumberValue) return v;
    }
  }
  return null;
}
