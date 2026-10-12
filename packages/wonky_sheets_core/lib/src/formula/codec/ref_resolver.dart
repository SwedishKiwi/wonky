import '../../addressing/a1.dart';
import '../model/workbook_view.dart';
import 'ref_token.dart';

/// Resolution of id-based references to current indices.
///
/// Returned rectangles may be open (null bound = to the end of the axis). Missing range
/// endpoints use the `K:`/`KC:` fallback (05 §5.4).
final class ResolvedRef {
  final SheetView sheet;
  final A1Kind kind;
  final int? row1;
  final int? col1;
  final int? row2;
  final int? col2;
  const ResolvedRef(this.sheet, this.kind, this.row1, this.col1, this.row2, this.col2);
}

/// Why a reference could not be resolved.
enum RefFailure { sheetMissing, rowOrColumnMissing, emptyRange, unresolvedSheetName, outOfBounds }

abstract final class RefResolver {
  /// Index of an endpoint id on [axis]; when missing and [key] is set, the fallback position.
  /// [isStart] selects the first surviving index at/after the slot; otherwise the last before.
  static int endpointIndex(AxisView axis, String id, String? key, {required bool isStart}) {
    final i = axis.indexOf(id);
    if (i >= 0) return i;
    if (key == null) return -1;
    final lb = axis.lowerBound(key, id);
    return isStart ? lb : lb - 1;
  }

  /// Resolves a stored reference relative to [hostSheet]. Returns either a [ResolvedRef] or a
  /// [RefFailure]. Unbound tokens are resolved positionally from their A1 text.
  static Object resolve(StoredRef ref, WorkbookView wb, SheetView hostSheet) {
    final s = ref.start;
    SheetView? sheet;
    if (s.sheetId != null) {
      sheet = wb.sheetById(s.sheetId!);
      if (sheet == null && !s.isUnbound) return RefFailure.sheetMissing;
    } else {
      sheet = hostSheet;
    }
    if (s.isUnbound) {
      final area = A1Area.tryParse(s.unbound!);
      if (area == null) return RefFailure.outOfBounds;
      SheetView? target = sheet;
      if (area.sheet != null) {
        target = wb.sheetByName(area.sheet!);
        if (target == null) return RefFailure.unresolvedSheetName;
      }
      if (target == null) return RefFailure.sheetMissing;
      final maxRow = area.row1 ?? 0;
      final maxRow2 = area.row2 ?? maxRow;
      final maxCol = area.col1 ?? 0;
      final maxCol2 = area.col2 ?? maxCol;
      if ((maxRow > maxRow2 ? maxRow : maxRow2) >= target.rows.length ||
          (maxCol > maxCol2 ? maxCol : maxCol2) >= target.columns.length) {
        return RefFailure.outOfBounds;
      }
      return ResolvedRef(target, area.kind, area.row1, area.col1, area.row2, area.col2);
    }
    final sh = sheet!;
    final e = ref.end;
    if (e == null) {
      if (s.rowId == null || s.colId == null) return RefFailure.rowOrColumnMissing;
      final r = sh.rows.indexOf(s.rowId!);
      final c = sh.columns.indexOf(s.colId!);
      if (r < 0 || c < 0) return RefFailure.rowOrColumnMissing;
      return ResolvedRef(sh, A1Kind.cell, r, c, r, c);
    }
    int? r1, c1, r2, c2;
    if (s.rowId != null) {
      r1 = endpointIndex(sh.rows, s.rowId!, s.rowKey, isStart: true);
      if (r1 < 0 && s.rowKey == null) return RefFailure.rowOrColumnMissing;
    }
    if (s.colId != null) {
      c1 = endpointIndex(sh.columns, s.colId!, s.colKey, isStart: true);
      if (c1 < 0 && s.colKey == null) return RefFailure.rowOrColumnMissing;
    }
    if (e.rowId != null) {
      r2 = endpointIndex(sh.rows, e.rowId!, e.rowKey, isStart: false);
      if (r2 < 0 && e.rowKey == null) return RefFailure.rowOrColumnMissing;
    }
    if (e.colId != null) {
      c2 = endpointIndex(sh.columns, e.colId!, e.colKey, isStart: false);
      if (c2 < 0 && e.colKey == null) return RefFailure.rowOrColumnMissing;
    }
    final kind = switch (ref.kind) {
      StoredRefKind.rect => A1Kind.rect,
      StoredRefKind.columns => A1Kind.columns,
      StoredRefKind.rows => A1Kind.rows,
      StoredRefKind.openRows => A1Kind.openRows,
      StoredRefKind.openColumns => A1Kind.openColumns,
      _ => A1Kind.rect,
    };
    // Endpoint fallback: when start and end are both present, keep start <= end ordering; a
    // range whose surviving coverage is empty is #REF!.
    final startRowMissing = s.rowId != null && sh.rows.indexOf(s.rowId!) < 0;
    final endRowMissing = e.rowId != null && sh.rows.indexOf(e.rowId!) < 0;
    final startColMissing = s.colId != null && sh.columns.indexOf(s.colId!) < 0;
    final endColMissing = e.colId != null && sh.columns.indexOf(e.colId!) < 0;
    if (kind == A1Kind.rows || kind == A1Kind.rect || kind == A1Kind.openColumns) {
      if (r1 != null && r2 != null && (startRowMissing || endRowMissing) && r1 > r2) {
        return RefFailure.emptyRange;
      }
    }
    if (kind == A1Kind.columns || kind == A1Kind.rect || kind == A1Kind.openRows) {
      if (c1 != null && c2 != null && (startColMissing || endColMissing) && c1 > c2) {
        return RefFailure.emptyRange;
      }
    }
    if ((r1 != null && (r1 < 0 || r1 >= sh.rows.length) && startRowMissing) ||
        (c1 != null && (c1 < 0 || c1 >= sh.columns.length) && startColMissing)) {
      return RefFailure.emptyRange;
    }
    if ((r2 != null && r2 < 0) || (c2 != null && c2 < 0)) return RefFailure.emptyRange;
    // Normalize order for rectangles typed bottom-up (B5:A1).
    if (r1 != null && r2 != null && r1 > r2 && !startRowMissing && !endRowMissing) {
      final t = r1;
      r1 = r2;
      r2 = t;
    }
    if (c1 != null && c2 != null && c1 > c2 && !startColMissing && !endColMissing) {
      final t = c1;
      c1 = c2;
      c2 = t;
    }
    return ResolvedRef(sh, kind, r1, c1, r2, c2);
  }
}
