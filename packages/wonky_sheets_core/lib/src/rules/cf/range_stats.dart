import 'dart:typed_data';

import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../engine_bridge/value_bridge.dart';
import '../../formula/model/workbook_view.dart';
import '../../model/sheet_model.dart';

/// Statistics of the numeric values in all ranges of a rule (06 §15.5,
/// §15.10): count, min, max and the sorted values for percentiles.
final class RangeStats {
  RangeStats._(this.sorted);

  /// Builds stats from raw numbers (any order).
  factory RangeStats.fromValues(Iterable<double> values) {
    final list = Float64List.fromList(values.where((v) => v.isFinite).toList())..sort();
    return RangeStats._(list);
  }

  /// Empty stats.
  static final RangeStats empty = RangeStats._(Float64List(0));

  /// Collects numeric computed values in [rects] of [sheet]. Cells covered by
  /// several rectangles count once. Small rectangles are scanned densely (spill
  /// overlays included); large ones iterate stored cells only.
  factory RangeStats.collect(
    SheetModel sheet,
    CellSource values,
    List<GridRect> rects, {
    int denseLimit = 200000,
  }) {
    final out = <double>[];
    final seen = rects.length > 1 ? <int>{} : null;
    void add(int r, int c) {
      if (seen != null && !seen.add(r * 0x100000 + c)) return;
      final v = values.valueAt(sheet.id, r, c).toCellValue();
      if (v is NumberValue) out.add(v.number);
    }

    for (final rect in rects) {
      if (rect.cellCount <= denseLimit) {
        for (var r = rect.top; r <= rect.bottom; r++) {
          for (var c = rect.left; c <= rect.right; c++) {
            add(r, c);
          }
        }
      } else {
        for (final (r, c, _) in sheet.cellsIn(rect, contentOnly: true)) {
          add(r, c);
        }
      }
    }
    return RangeStats.fromValues(out);
  }

  /// Sorted numeric values.
  final Float64List sorted;

  /// Number of numeric values.
  int get count => sorted.length;

  /// Whether there are no numeric values.
  bool get isEmpty => sorted.isEmpty;

  /// Smallest value (0 when empty).
  double get min => sorted.isEmpty ? 0 : sorted.first;

  /// Largest value (0 when empty).
  double get max => sorted.isEmpty ? 0 : sorted.last;

  /// Linear-interpolated percentile for [p] in 0..1 (`PERCENTILE.INC`).
  double percentile(double p) {
    if (sorted.isEmpty) return 0;
    final pp = p.clamp(0.0, 1.0);
    final rank = pp * (sorted.length - 1);
    final lo = rank.floor();
    final hi = rank.ceil();
    if (lo == hi) return sorted[lo];
    return sorted[lo] + (sorted[hi] - sorted[lo]) * (rank - lo);
  }
}
