import 'dart:typed_data';

import '../../addressing/grid_geometry.dart';
import '../../formula/model/workbook_view.dart' show CellSource;
import '../../model/axis_index.dart';
import '../../model/sheet_model.dart';
import '../sort/sort_permutation.dart';
import '../sort/sort_spec.dart';

/// View-only display order of a filter view's data rows (07 §4.4): a
/// permutation within the contiguous rows `top..top+length-1`; rows outside
/// map to themselves (`RowDisplayMap` of 03).
final class ViewRowOrder {
  ViewRowOrder._(this.top, this._toModel, this._toDisplay);

  /// The identity order.
  factory ViewRowOrder.identity(int top, int length) {
    final p = Int32List(length);
    for (var i = 0; i < length; i++) {
      p[i] = i;
    }
    return ViewRowOrder._(top, p, Int32List.fromList(p));
  }

  /// Computes the order of [table] (the data rows starting at [top]) by
  /// [specs] with the sort comparator (07 §2.3).
  factory ViewRowOrder.compute(
    SortTable table,
    List<SortSpec> specs, {
    required int top,
  }) {
    final perm = SortPermutation.compute(table, specs);
    return ViewRowOrder._(top, perm, SortPermutation.inverse(perm));
  }

  /// The display order of the data rows [rows] of [sheet] sorted by
  /// [sort] (`(colId, ascending)` keys, computed [values]), or null when
  /// there is nothing to sort or the rows can't be permuted (a vertical
  /// merge inside them).
  static ViewRowOrder? forRows(
    SheetModel sheet,
    CellSource values,
    GridRect rows,
    List<(String, bool)> sort,
  ) {
    if (rows.rowCount < 2) return null;
    final specs = <SortSpec>[
      for (final (colId, asc) in sort)
        if (sheet.columns.indexOf(colId) >= 0)
          ValueSortSpec(colId, ascending: asc),
    ];
    if (specs.isEmpty) return null;
    for (final (_, m) in sheet.mergesIntersecting(rows)) {
      if (m.rowCount > 1) return null;
    }
    final table = SortTable.fromSheet(sheet, values, rows, specs);
    final order = ViewRowOrder.compute(table, specs, top: rows.top);
    return order.isIdentity ? null : order;
  }

  /// First data row.
  final int top;

  /// Last permuted row.
  int get bottom => top + _toModel.length - 1;

  /// Whether [row] is inside the permuted block.
  bool contains(int row) => row >= top && row <= bottom;

  /// The model rows of display rows [d1]..[d2] (inclusive, d1 ≤ d2) as
  /// runs `(first, last)` that are contiguous in both orders, in display
  /// order: a display rectangle as model ranges (selection, copy, paste).
  List<(int, int)> modelRuns(int d1, int d2) {
    final out = <(int, int)>[];
    var d = d1;
    while (d <= d2) {
      final start = modelRow(d);
      var end = start;
      while (d + 1 <= d2 && modelRow(d + 1) == end + 1) {
        d++;
        end++;
      }
      out.add((start, end));
      d++;
    }
    return out;
  }

  Float64List? _prefix;
  AxisIndex? _prefixAxis;
  (int, double, double)? _prefixKey;

  /// Clears the cached display offsets.
  void invalidateOffsets() => _prefix = null;

  /// Prefix sums of the display rows' sizes, cached while the axis looks
  /// unchanged (generation, block extent and total size).
  Float64List _prefixOf(AxisIndex rows) {
    final key = (
      rows.generation,
      rows.offsetOf(bottom + 1) - rows.offsetOf(top),
      rows.totalSize,
    );
    final cached = _prefix;
    if (cached != null && identical(_prefixAxis, rows) && _prefixKey == key) {
      return cached;
    }
    final p = Float64List(_toModel.length + 1);
    for (var i = 0; i < _toModel.length; i++) {
      final m = top + _toModel[i];
      p[i + 1] = p[i] + (m < rows.length ? rows.sizeAt(m) : 0);
    }
    _prefixAxis = rows;
    _prefixKey = key;
    return _prefix = p;
  }

  /// Pixel offset of the start of display row [d] on [rows] (unzoomed).
  double displayOffset(AxisIndex rows, int d) {
    if (d <= top || d > bottom) return rows.offsetOf(d);
    return rows.offsetOf(top) + _prefixOf(rows)[d - top];
  }

  /// The display row whose span contains [px] on [rows] (hidden rows
  /// skipped, like `AxisIndex.indexAtOffset`).
  int displayAtOffset(AxisIndex rows, double px) {
    final y0 = rows.offsetOf(top);
    final y1 = rows.offsetOf(bottom + 1);
    if (px < y0 || px >= y1) return rows.indexAtOffset(px);
    final p = _prefixOf(rows);
    final rel = px - y0;
    // Largest k with p[k] <= rel and a visible row k.
    var lo = 0;
    var hi = _toModel.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (p[mid] <= rel) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    var k = lo;
    while (k < _toModel.length - 1 && p[k + 1] - p[k] <= 0) {
      k++;
    }
    while (k > 0 && p[k + 1] - p[k] <= 0) {
      k--;
    }
    return top + k;
  }

  /// The next visible display row after (dir 1) / before (dir −1) display
  /// row [d] on [rows], or null.
  int? nextVisibleDisplay(AxisIndex rows, int d, int dir) {
    var x = d + dir;
    while (x >= 0 && x < rows.length) {
      if (!rows.isHidden(modelRow(x))) return x;
      x += dir;
    }
    return null;
  }

  final Int32List _toModel;
  final Int32List _toDisplay;

  /// Number of permuted rows.
  int get length => _toModel.length;

  /// Whether the order is the identity.
  bool get isIdentity => SortPermutation.isIdentity(_toModel);

  /// The model row shown at [displayRow].
  int modelRow(int displayRow) {
    final i = displayRow - top;
    return i >= 0 && i < _toModel.length ? top + _toModel[i] : displayRow;
  }

  /// The display row of [modelRow].
  int displayRow(int modelRow) {
    final i = modelRow - top;
    return i >= 0 && i < _toDisplay.length ? top + _toDisplay[i] : modelRow;
  }
}
