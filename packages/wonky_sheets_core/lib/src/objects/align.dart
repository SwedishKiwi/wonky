import 'dart:math' as math;

import '../charts/scene/geometry.dart';

/// Aligning and distributing several selected objects (08 §9.2
/// multi-selection). Rectangles are sheet px at 100 % zoom; only positions
/// change, never sizes.
abstract final class ObjectAlign {
  /// The operations of `sheets.object.align`.
  static const ops = [
    'left',
    'center',
    'right',
    'top',
    'middle',
    'bottom',
    'distributeHorizontally',
    'distributeVertically',
  ];

  /// New rectangles for [rects] (by object id) after [op]: edges/centers line
  /// up with the selection's bounds (left/right/top/bottom) or its center
  /// (center/middle); *distribute* spaces the objects evenly between the
  /// outermost ones (≥ 3 objects; ordered by position, then id). Unknown
  /// ops return [rects] unchanged.
  static Map<String, ChartRect> apply(Map<String, ChartRect> rects, String op) {
    if (rects.length < 2) return rects;
    final all = rects.values;
    final l = all.map((r) => r.left).reduce(math.min);
    final t = all.map((r) => r.top).reduce(math.min);
    final r = all.map((r) => r.right).reduce(math.max);
    final b = all.map((r) => r.bottom).reduce(math.max);
    ChartRect at(ChartRect x, double left, double top) =>
        ChartRect(left, top, x.width, x.height);
    switch (op) {
      case 'left':
        return rects.map((k, x) => MapEntry(k, at(x, l, x.top)));
      case 'right':
        return rects.map((k, x) => MapEntry(k, at(x, r - x.width, x.top)));
      case 'center':
        final c = (l + r) / 2;
        return rects.map((k, x) => MapEntry(k, at(x, c - x.width / 2, x.top)));
      case 'top':
        return rects.map((k, x) => MapEntry(k, at(x, x.left, t)));
      case 'bottom':
        return rects.map((k, x) => MapEntry(k, at(x, x.left, b - x.height)));
      case 'middle':
        final c = (t + b) / 2;
        return rects.map(
          (k, x) => MapEntry(k, at(x, x.left, c - x.height / 2)),
        );
      case 'distributeHorizontally' || 'distributeVertically':
        if (rects.length < 3) return rects;
        final h = op == 'distributeHorizontally';
        final ids = rects.keys.toList()
          ..sort((a, c) {
            final x = rects[a]!;
            final y = rects[c]!;
            final d = h ? x.left.compareTo(y.left) : x.top.compareTo(y.top);
            return d != 0 ? d : a.compareTo(c);
          });
        final total = ids.fold<double>(
          0,
          (s, id) => s + (h ? rects[id]!.width : rects[id]!.height),
        );
        final span = h ? r - l : b - t;
        final gap = (span - total) / (ids.length - 1);
        var pos = h ? l : t;
        final out = <String, ChartRect>{};
        for (final id in ids) {
          final x = rects[id]!;
          out[id] = h ? at(x, pos, x.top) : at(x, x.left, pos);
          pos += (h ? x.width : x.height) + gap;
        }
        return out;
      default:
        return rects;
    }
  }
}
