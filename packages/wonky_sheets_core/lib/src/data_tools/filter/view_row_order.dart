import 'dart:typed_data';

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
  factory ViewRowOrder.compute(SortTable table, List<SortSpec> specs, {required int top}) {
    final perm = SortPermutation.compute(table, specs);
    return ViewRowOrder._(top, perm, SortPermutation.inverse(perm));
  }

  /// First data row.
  final int top;
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
