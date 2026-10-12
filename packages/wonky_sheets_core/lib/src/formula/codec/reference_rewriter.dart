import '../../addressing/grid_geometry.dart';
import '../model/workbook_view.dart';
import '../parser/lexer.dart';
import 'ref_resolver.dart';
import 'ref_token.dart';

/// Token-level rewrites of stored formulas caused by operations on *other* cells
/// (05 §5.1, §5.4, §5.5). Every function returns null when the formula is unchanged.
///
/// User whitespace, literals and function spelling are preserved: only reference tokens and
/// name tokens are replaced.
abstract final class ReferenceRewriter {
  static const FormulaLexer _lexer = FormulaLexer();

  static String _withEq(String s) => s.startsWith('=') ? s : '=$s';

  /// Applies [f] to every stored reference token; [f] returns replacement text or null.
  static String? _mapRefs(String stored, String? Function(StoredRef ref) f) {
    final tokens = _lexer.tokenize(_withEq(stored));
    final b = StringBuffer();
    var changed = false;
    for (final t in tokens) {
      if (t.kind == TokenKind.storedRef) {
        final r = f(t.ref!.stored!);
        if (r != null && r != t.text) {
          b.write(r);
          changed = true;
          continue;
        }
      }
      b.write(t.text);
    }
    return changed ? b.toString() : null;
  }

  static SheetView? _sheetOf(StoredRef ref, WorkbookView wb, String hostSheetId) =>
      wb.sheetById(ref.start.sheetId ?? hostSheetId);

  /// Rename of a named range/function: rewrites name and function-name tokens
  /// (case-insensitive) only (05 §5.5, 07 §8.3).
  static String? renameName(String stored, String oldName, String newName) {
    final tokens = _lexer.tokenize(_withEq(stored));
    final b = StringBuffer();
    var changed = false;
    final old = oldName.toUpperCase();
    for (final t in tokens) {
      if ((t.kind == TokenKind.name || t.kind == TokenKind.functionName) &&
          t.text.toUpperCase() == old) {
        b.write(newName);
        changed = true;
      } else {
        b.write(t.text);
      }
    }
    return changed ? b.toString() : null;
  }

  /// Cut/paste, drag-move, insert/delete cells with shift (05 §5.5): references to cells fully
  /// inside [source] (on [sourceSheetId]) are retargeted to the same relative cells of [dest]
  /// (on [destSheetId]); ranges entirely inside move as a whole; partially overlapping ranges
  /// are unchanged.
  static String? remap(
    String stored, {
    required WorkbookView workbook,
    required String hostSheetId,
    required String sourceSheetId,
    required GridRect source,
    required String destSheetId,
    required GridRect dest,
  }) {
    final src = workbook.sheetById(sourceSheetId);
    final dst = workbook.sheetById(destSheetId);
    if (src == null || dst == null) return null;
    final dRow = dest.top - source.top, dCol = dest.left - source.left;
    return _mapRefs(stored, (ref) {
      if (ref.start.isUnbound) return null;
      final sheet = _sheetOf(ref, workbook, hostSheetId);
      if (sheet == null || sheet.id != sourceSheetId) return null;
      final r = RefResolver.resolve(ref, workbook, sheet);
      if (r is! ResolvedRef) return null;
      final rect = GridRect(
        r.row1 ?? 0,
        r.col1 ?? 0,
        r.row2 ?? sheet.rows.length - 1,
        r.col2 ?? sheet.columns.length - 1,
      );
      if (!source.containsRect(rect)) return null;
      final newSheetId = destSheetId == hostSheetId ? null : destSheetId;
      RefToken move(RefToken t, bool first) {
        String? rowId = t.rowId, colId = t.colId, rowKey = t.rowKey, colKey = t.colKey;
        if (t.rowId != null) {
          final i = RefResolver.endpointIndex(sheet.rows, t.rowId!, t.rowKey, isStart: first) + dRow;
          rowId = dst.rows.idAt(i.clamp(0, dst.rows.length - 1));
          if (rowKey != null) rowKey = dst.rows.sortKeyAt(i.clamp(0, dst.rows.length - 1));
        }
        if (t.colId != null) {
          final i = RefResolver.endpointIndex(sheet.columns, t.colId!, t.colKey, isStart: first) + dCol;
          colId = dst.columns.idAt(i.clamp(0, dst.columns.length - 1));
          if (colKey != null) colKey = dst.columns.sortKeyAt(i.clamp(0, dst.columns.length - 1));
        }
        return t.copyWith(
          sheetId: first ? newSheetId : null,
          rowId: rowId,
          colId: colId,
          rowKey: rowKey,
          colKey: colKey,
        );
      }

      // the moved block must fit the destination grid
      if (dest.bottom >= dst.rows.length || dest.right >= dst.columns.length) return null;
      final a = move(ref.start, true);
      final e = ref.end == null ? null : move(ref.end!, false);
      return StoredRef(a, e).encode();
    });
  }

  /// Row/column delete (05 §5.4): range endpoints on deleted ids move inward to the nearest
  /// surviving row/column inside the range (empty ranges → `#REF!`); single references on
  /// deleted ids become `#REF!`. Works before the delete is applied (ids still present) and
  /// after it (sort-key fallback).
  static String? repairBoundaries(
    String stored, {
    required WorkbookView workbook,
    required Set<String> deletedRowIds,
    required Set<String> deletedColIds,
    String? hostSheetId,
  }) {
    return _mapRefs(stored, (ref) {
      final s = ref.start;
      if (s.isUnbound) return null;
      final e = ref.end;
      bool hit(RefToken t) =>
          (t.rowId != null && deletedRowIds.contains(t.rowId)) ||
          (t.colId != null && deletedColIds.contains(t.colId));
      if (e == null) return hit(s) ? '#REF!' : null;
      if (!hit(s) && !hit(e)) return null;
      final sheet = _findSheet(ref, workbook, hostSheetId);
      if (sheet == null) return null;
      RefToken? fixStart(RefToken t, RefToken other) => _inward(t, other, sheet, deletedRowIds, deletedColIds, start: true);
      RefToken? fixEnd(RefToken t, RefToken other) => _inward(t, other, sheet, deletedRowIds, deletedColIds, start: false);
      final ns = fixStart(s, e);
      final ne = fixEnd(e, s);
      if (ns == null || ne == null) return '#REF!';
      // collapsed?
      final r1 = ns.rowId == null ? null : sheet.rows.indexOf(ns.rowId!);
      final r2 = ne.rowId == null ? null : sheet.rows.indexOf(ne.rowId!);
      final c1 = ns.colId == null ? null : sheet.columns.indexOf(ns.colId!);
      final c2 = ne.colId == null ? null : sheet.columns.indexOf(ne.colId!);
      if ((r1 != null && r2 != null && r1 > r2) || (c1 != null && c2 != null && c1 > c2)) {
        return '#REF!';
      }
      return StoredRef(ns, ne).encode();
    });
  }

  static SheetView? _findSheet(StoredRef ref, WorkbookView wb, String? hostSheetId) {
    if (ref.start.sheetId != null) return wb.sheetById(ref.start.sheetId!);
    if (hostSheetId != null) return wb.sheetById(hostSheetId);
    final ids = [ref.start.rowId, ref.start.colId, ref.end?.rowId, ref.end?.colId];
    for (final sheet in wb.sheets) {
      for (var i = 0; i < ids.length; i++) {
        final id = ids[i];
        if (id == null) continue;
        final axis = i.isEven ? sheet.rows : sheet.columns;
        if (axis.indexOf(id) >= 0) return sheet;
      }
    }
    return null;
  }

  /// Moves an endpoint off deleted rows/columns toward [other]. Null when no surviving
  /// position remains inside the range.
  static RefToken? _inward(
    RefToken t,
    RefToken other,
    SheetView sheet,
    Set<String> delRows,
    Set<String> delCols,
    {required bool start}
  ) {
    var out = t;
    String? fix(AxisView axis, String id, String? key, String? otherId, String? otherKey, Set<String> deleted, void Function(String id, String key) set) {
      if (!deleted.contains(id)) return id;
      var i = axis.indexOf(id);
      final j = otherId == null ? (start ? axis.length - 1 : 0) : RefResolver.endpointIndex(axis, otherId, otherKey, isStart: !start);
      if (i >= 0) {
        // before the delete: scan inward past deleted entries
        while (i >= 0 && i < axis.length && deleted.contains(axis.idAt(i))) {
          i += start ? 1 : -1;
        }
      } else {
        if (key == null) return null;
        final lb = axis.lowerBound(key, id);
        i = start ? lb : lb - 1;
      }
      if (i < 0 || i >= axis.length) return null;
      if (start ? i > j : i < j) return null;
      final nid = axis.idAt(i);
      set(nid, axis.sortKeyAt(i));
      return nid;
    }

    if (t.rowId != null) {
      final r = fix(sheet.rows, t.rowId!, t.rowKey, other.rowId, other.rowKey, delRows, (id, key) {
        out = out.copyWith(rowId: id, rowKey: key);
      });
      if (r == null) return null;
    }
    if (t.colId != null) {
      final c = fix(sheet.columns, t.colId!, t.colKey, other.colId, other.colKey, delCols, (id, key) {
        out = out.copyWith(colId: id, colKey: key);
      });
      if (c == null) return null;
    }
    return out;
  }

  /// Full-row sort / randomize (07 §2.2): references and range endpoints pointing into rows
  /// [blockTop]..[blockBottom] of [sheetId] are re-pinned to the ids now at the same positions.
  /// [newRowIdAt] gives the id at a position after the sort, [oldIndexOf] a row id's position
  /// before the sort.
  static String? repinRows(
    String stored, {
    required WorkbookView workbook,
    required String hostSheetId,
    required String sheetId,
    required int blockTop,
    required int blockBottom,
    required String Function(int position) newRowIdAt,
    required int Function(String rowId) oldIndexOf,
  }) {
    final sheet = workbook.sheetById(sheetId);
    return _mapRefs(stored, (ref) {
      if (ref.start.isUnbound) return null;
      if ((ref.start.sheetId ?? hostSheetId) != sheetId) return null;
      RefToken pin(RefToken t) {
        if (t.rowId == null) return t;
        final old = oldIndexOf(t.rowId!);
        if (old < blockTop || old > blockBottom) return t;
        final id = newRowIdAt(old);
        String? key = t.rowKey;
        if (key != null && sheet != null) {
          final i = sheet.rows.indexOf(id);
          if (i >= 0) key = sheet.rows.sortKeyAt(i);
        }
        return t.copyWith(rowId: id, rowKey: key);
      }

      final a = pin(ref.start);
      final e = ref.end == null ? null : pin(ref.end!);
      final out = StoredRef(a, e);
      return out == ref ? null : out.encode();
    });
  }

  /// Whether [stored] references (cell or range) any cell of [rect] on [sheetId].
  static bool references(
    String stored, {
    required WorkbookView workbook,
    required String hostSheetId,
    required String sheetId,
    required GridRect rect,
  }) {
    final sheet = workbook.sheetById(sheetId);
    if (sheet == null) return false;
    var hit = false;
    _mapRefs(stored, (ref) {
      if (hit || ref.start.isUnbound) return null;
      if ((ref.start.sheetId ?? hostSheetId) != sheetId) return null;
      final r = RefResolver.resolve(ref, workbook, sheet);
      if (r is! ResolvedRef) return null;
      final rr = GridRect(
        r.row1 ?? 0,
        r.col1 ?? 0,
        r.row2 ?? sheet.rows.length - 1,
        r.col2 ?? sheet.columns.length - 1,
      );
      if (rr.intersects(rect)) hit = true;
      return null;
    });
    return hit;
  }
}
