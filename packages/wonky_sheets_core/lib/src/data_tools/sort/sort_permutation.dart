import 'dart:typed_data';

import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../engine_bridge/value_bridge.dart';
import '../../formula/model/workbook_view.dart';
import '../../model/sheet_model.dart';
import 'sort_keys.dart';
import 'sort_spec.dart';

/// Effective colors of a cell for sort/filter by color.
typedef CellColorResolver = ({String? fill, String? text}) Function(int row, int col);

/// An immutable snapshot of the key columns of a range (07 §2.7): one
/// [SortKeyColumn] per column id, plus effective colors for color keys.
final class SortTable {
  /// Creates a snapshot of [rowCount] rows.
  SortTable(this.rowCount, this.columns, {Map<String, List<String?>>? fills, Map<String, List<String?>>? textColors})
    : fills = fills ?? const {},
      textColors = textColors ?? const {};

  /// Builds the snapshot of the key columns of [specs] over the rows of
  /// [rect] (data rows only) from computed values. Color keys use [colors].
  factory SortTable.fromSheet(
    SheetModel sheet,
    CellSource values,
    GridRect rect,
    List<SortSpec> specs, {
    CellColorResolver? colors,
  }) {
    final n = rect.rowCount;
    final cols = <String, SortKeyColumn>{};
    final fills = <String, List<String?>>{};
    final texts = <String, List<String?>>{};
    for (final s in specs) {
      final c = sheet.columns.indexOf(s.colId);
      if (c < 0) continue;
      switch (s) {
        case ValueSortSpec():
          cols.putIfAbsent(s.colId, () {
            final vs = List<CellValue>.generate(
              n,
              (i) => values.valueAt(sheet.id, rect.top + i, c).toCellValue(),
              growable: false,
            );
            return SortKeyColumn.fromValues(vs);
          });
        case ColorSortSpec():
          if (colors == null) continue;
          if (s.fillColor != null) {
            fills.putIfAbsent(s.colId, () => [for (var i = 0; i < n; i++) colors(rect.top + i, c).fill]);
          } else {
            texts.putIfAbsent(s.colId, () => [for (var i = 0; i < n; i++) colors(rect.top + i, c).text]);
          }
      }
    }
    return SortTable(n, cols, fills: fills, textColors: texts);
  }

  /// Number of rows.
  final int rowCount;

  /// Value columns by column id.
  final Map<String, SortKeyColumn> columns;

  /// Effective fill colors by column id.
  final Map<String, List<String?>> fills;

  /// Effective text colors by column id.
  final Map<String, List<String?>> textColors;
}

/// Stable sort permutations (07 §2.7 step 2).
abstract final class SortPermutation {
  /// The stable permutation of [table] rows by [specs]: `result[i]` is the
  /// source row (offset in the range) placed at position `i`. Keys whose
  /// column is missing are ignored. [isCancelled] is polled between merge passes.
  static Int32List compute(SortTable table, List<SortSpec> specs, {bool Function()? isCancelled}) {
    final cmps = <int Function(int, int)>[];
    for (final s in specs) {
      switch (s) {
        case ValueSortSpec(:final colId, :final ascending):
          final col = table.columns[colId];
          if (col != null) cmps.add((i, j) => col.compare(i, j, ascending: ascending));
        case ColorSortSpec(:final colId, :final fillColor, :final textColor):
          final list = fillColor != null ? table.fills[colId] : table.textColors[colId];
          final target = (fillColor ?? textColor)?.toUpperCase();
          if (list == null || target == null) continue;
          final has = Uint8List(table.rowCount);
          for (var i = 0; i < list.length; i++) {
            has[i] = list[i]?.toUpperCase() == target ? 1 : 0;
          }
          cmps.add((i, j) => has[j] - has[i]);
      }
    }
    int compare(int i, int j) {
      for (final c in cmps) {
        final r = c(i, j);
        if (r != 0) return r;
      }
      return 0;
    }

    return StableSort.indices(table.rowCount, compare, isCancelled: isCancelled);
  }

  /// The inverse permutation (`inverse[perm[i]] = i`).
  static Int32List inverse(Int32List perm) {
    final out = Int32List(perm.length);
    for (var i = 0; i < perm.length; i++) {
      out[perm[i]] = i;
    }
    return out;
  }

  /// Whether [perm] is the identity.
  static bool isIdentity(Int32List perm) {
    for (var i = 0; i < perm.length; i++) {
      if (perm[i] != i) return false;
    }
    return true;
  }
}

/// Thrown when a cancellable computation is cancelled.
final class DataJobCancelled implements Exception {
  /// Creates the exception.
  const DataJobCancelled();

  @override
  String toString() => 'DataJobCancelled';
}

/// Stable merge sort over indices (ties keep index order).
abstract final class StableSort {
  /// Sorts `0..n-1` by [compare]; equal elements keep ascending index order.
  static Int32List indices(int n, int Function(int a, int b) compare, {bool Function()? isCancelled}) {
    var a = Int32List(n);
    for (var i = 0; i < n; i++) {
      a[i] = i;
    }
    if (n < 2) return a;
    const run = 32;
    // Insertion sort small runs.
    for (var lo = 0; lo < n; lo += run) {
      final hi = lo + run < n ? lo + run : n;
      for (var i = lo + 1; i < hi; i++) {
        final x = a[i];
        var j = i - 1;
        while (j >= lo && compare(a[j], x) > 0) {
          a[j + 1] = a[j];
          j--;
        }
        a[j + 1] = x;
      }
    }
    var b = Int32List(n);
    for (var width = run; width < n; width *= 2) {
      if (isCancelled?.call() ?? false) throw const DataJobCancelled();
      for (var lo = 0; lo < n; lo += 2 * width) {
        final mid = lo + width < n ? lo + width : n;
        final hi = lo + 2 * width < n ? lo + 2 * width : n;
        var i = lo, j = mid, k = lo;
        if (mid >= hi || compare(a[mid - 1], a[mid]) <= 0) {
          // Already ordered: copy.
          for (var t = lo; t < hi; t++) {
            b[t] = a[t];
          }
          continue;
        }
        while (i < mid && j < hi) {
          if (compare(a[j], a[i]) < 0) {
            b[k++] = a[j++];
          } else {
            b[k++] = a[i++];
          }
        }
        while (i < mid) {
          b[k++] = a[i++];
        }
        while (j < hi) {
          b[k++] = a[j++];
        }
      }
      final t = a;
      a = b;
      b = t;
    }
    return a;
  }
}
