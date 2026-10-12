import 'dart:typed_data';

import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';

/// Result of [Dedupe.findDuplicates].
final class DedupeResult {
  /// Creates a result.
  const DedupeResult(this.keptRows, this.duplicateRows, {required this.dataRowCount});

  /// Rows kept (first occurrences), ascending sheet row indices.
  final Int32List keptRows;

  /// Rows removed as duplicates, ascending.
  final Int32List duplicateRows;

  /// Number of data rows examined (header excluded).
  final int dataRowCount;

  int get duplicateCount => duplicateRows.length;
  int get uniqueCount => keptRows.length;

  /// Result dialog text (07 §12.1).
  String get message => duplicateCount == 0
      ? 'No duplicate rows found.'
      : '$duplicateCount duplicate row${duplicateCount == 1 ? '' : 's'} found and removed. '
            '$uniqueCount unique row${uniqueCount == 1 ? '' : 's'} remain.';
}

/// Remove duplicates (07 §12.1): rows are duplicates when all selected
/// columns have equal values — numbers numerically, text exact and
/// case-sensitive, booleans, errors by type, blanks equal blanks (`""`
/// included), formulas by result. The first occurrence is kept.
abstract final class Dedupe {
  /// Value equality of 07 §12.1.
  static bool sameValue(CellValue a, CellValue b) {
    final ba = a.isBlank();
    final bb = b.isBlank();
    if (ba || bb) return ba && bb;
    return switch ((a, b)) {
      (NumberValue(number: final x), NumberValue(number: final y)) => x == y,
      (TextValue(text: final x), TextValue(text: final y)) => x == y,
      (BoolValue(value: final x), BoolValue(value: final y)) => x == y,
      (ErrorValue(kind: final x), ErrorValue(kind: final y)) => x == y,
      _ => false,
    };
  }

  static int _hash(CellValue v) {
    if (v.isBlank()) return 0x9e3779b9;
    return switch (v) {
      NumberValue(:final number) => Object.hash(1, number == 0 ? 0.0 : number),
      TextValue(:final text) => Object.hash(2, text),
      BoolValue(:final value) => Object.hash(3, value),
      ErrorValue(:final kind) => Object.hash(4, kind),
      EmptyValue() => 0,
    };
  }

  /// Finds duplicates among the rows of [rect] (minus the first row when
  /// [hasHeader]) comparing columns [cols] (sheet column indices; empty = all
  /// columns of the range). [value] reads computed values.
  static DedupeResult findDuplicates(
    CellValue Function(int row, int col) value,
    GridRect rect, {
    List<int> cols = const [],
    bool hasHeader = false,
    bool Function()? isCancelled,
  }) {
    final keyCols = cols.isEmpty ? [for (var c = rect.left; c <= rect.right; c++) c] : cols;
    final top = hasHeader ? rect.top + 1 : rect.top;
    final n = rect.bottom - top + 1 < 0 ? 0 : rect.bottom - top + 1;
    final buckets = <int, List<int>>{};
    final kept = <int>[];
    final dups = <int>[];
    final rowValues = <int, List<CellValue>>{};
    for (var i = 0; i < n; i++) {
      if ((i & 0x3fff) == 0 && (isCancelled?.call() ?? false)) break;
      final r = top + i;
      final vs = [for (final c in keyCols) value(r, c)];
      var h = 17;
      for (final v in vs) {
        h = Object.hash(h, _hash(v));
      }
      final bucket = buckets[h];
      var dup = false;
      if (bucket != null) {
        for (final k in bucket) {
          final kv = rowValues[k]!;
          var same = true;
          for (var j = 0; j < vs.length; j++) {
            if (!sameValue(kv[j], vs[j])) {
              same = false;
              break;
            }
          }
          if (same) {
            dup = true;
            break;
          }
        }
      }
      if (dup) {
        dups.add(r);
      } else {
        (buckets[h] ??= []).add(r);
        rowValues[r] = vs;
        kept.add(r);
      }
    }
    return DedupeResult(Int32List.fromList(kept), Int32List.fromList(dups), dataRowCount: n);
  }

  /// The row-move permutation compacting [result]'s kept rows to the top of
  /// the data area: `perm[i]` is the source row offset (relative to the first
  /// data row) placed at position `i`; positions ≥ `uniqueCount` hold the
  /// duplicates (to be cleared).
  static Int32List compactPermutation(DedupeResult result, int firstDataRow) {
    final out = Int32List(result.dataRowCount);
    var k = 0;
    for (final r in result.keptRows) {
      out[k++] = r - firstDataRow;
    }
    for (final r in result.duplicateRows) {
      out[k++] = r - firstDataRow;
    }
    return out;
  }
}
