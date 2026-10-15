import 'dart:math' as math;

import '../../formula/values/fvalue.dart';

/// Header auto-detection (08 §4.2).
abstract final class HeaderDetection {
  /// Returns 1 when the first entry of the [lines] (columns; rows when switched) is a header,
  /// else 0. Rule: the first row contains a text cell and every non-empty cell below it in
  /// that column (first [sample] rows) is a number; or the first row is all text and the
  /// second row has a number.
  static int detect(List<List<FValue>> lines, {int sample = 50}) {
    if (lines.isEmpty) return 0;
    var anyLong = false;
    for (final l in lines) {
      if (l.length >= 2) anyLong = true;
    }
    if (!anyLong) return 0;
    // Rule 1.
    for (final l in lines) {
      if (l.isEmpty || _scalar(l[0]) is! FText) continue;
      var numbers = 0;
      var others = 0;
      final end = math.min(l.length, sample + 1);
      for (var i = 1; i < end; i++) {
        final v = _scalar(l[i]);
        if (v is FNumber) {
          numbers++;
        } else if (v is! FEmpty) {
          others++;
        }
      }
      if (numbers > 0 && others == 0) return 1;
    }
    // Rule 2.
    var allText = true;
    var anyFirst = false;
    for (final l in lines) {
      if (l.isEmpty) continue;
      final v = _scalar(l[0]);
      if (v is FEmpty) continue;
      anyFirst = true;
      if (v is! FText) {
        allText = false;
        break;
      }
    }
    if (allText && anyFirst) {
      for (final l in lines) {
        if (l.length > 1 && _scalar(l[1]) is FNumber) return 1;
      }
    }
    return 0;
  }

  static FValue _scalar(FValue v) => v is FRich ? v.scalar : v;
}
