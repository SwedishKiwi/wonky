import 'dart:math' as math;

import 'package:wonky_charts/wonky_charts.dart';

import '../model/axis_index.dart';
import 'anchor.dart';

/// The 8 resize handles of a selected object (08 §9.2).
enum ResizeHandle {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left;

  /// Whether dragging moves the left edge.
  bool get movesLeft => this == topLeft || this == left || this == bottomLeft;

  /// Whether dragging moves the right edge.
  bool get movesRight =>
      this == topRight || this == right || this == bottomRight;

  /// Whether dragging moves the top edge.
  bool get movesTop => this == topLeft || this == top || this == topRight;

  /// Whether dragging moves the bottom edge.
  bool get movesBottom =>
      this == bottomLeft || this == bottom || this == bottomRight;

  /// Whether this is a corner handle (resizes both dimensions).
  bool get isCorner =>
      this == topLeft ||
      this == topRight ||
      this == bottomLeft ||
      this == bottomRight;
}

/// Pure size and rectangle math for embedded objects (08 §9.3).
abstract final class ObjectGeometry {
  /// [width] × [height] clamped to [ObjectAnchor.minSize]..[maxWidth] /
  /// [maxHeight] (both capped to [ObjectAnchor.maxSize]).
  ///
  /// With [aspect] (width / height) the result keeps that ratio: the box
  /// follows the requested dimension that makes it larger, then scales into
  /// the limits. If the ratio is so extreme that both limits can't hold, each
  /// dimension is clamped on its own.
  static ChartSize constrainSize(
    double width,
    double height, {
    double? aspect,
    double maxWidth = ObjectAnchor.maxSize,
    double maxHeight = ObjectAnchor.maxSize,
  }) {
    final maxW = math.max(
      ObjectAnchor.minSize,
      math.min(maxWidth, ObjectAnchor.maxSize),
    );
    final maxH = math.max(
      ObjectAnchor.minSize,
      math.min(maxHeight, ObjectAnchor.maxSize),
    );
    double clampW(double w) =>
        w.isNaN ? ObjectAnchor.minSize : w.clamp(ObjectAnchor.minSize, maxW);
    double clampH(double h) =>
        h.isNaN ? ObjectAnchor.minSize : h.clamp(ObjectAnchor.minSize, maxH);
    if (aspect == null || !aspect.isFinite || aspect <= 0) {
      return ChartSize(clampW(width), clampH(height));
    }
    final w0 = width.isNaN ? 0.0 : width;
    final h0 = height.isNaN ? 0.0 : height;
    var w = w0;
    var h = w0 / aspect;
    if (h < h0) {
      h = h0;
      w = h0 * aspect;
    }
    if (w <= 0 || h <= 0) {
      w = aspect >= 1 ? ObjectAnchor.minSize * aspect : ObjectAnchor.minSize;
      h = w / aspect;
    }
    final lo = math.max(ObjectAnchor.minSize / w, ObjectAnchor.minSize / h);
    final hi = math.min(maxW / w, maxH / h);
    if (lo > hi) return ChartSize(clampW(w), clampH(h));
    final s = 1.0.clamp(lo, hi);
    return ChartSize(w * s, h * s);
  }

  /// The rectangle after dragging [handle] of [start] by ([ddx], [ddy]) px.
  ///
  /// The opposite edge (or corner) stays fixed; the size is limited to
  /// 20–4000 px and the rectangle never crosses the sheet's top/left edge.
  /// [keepAspect] keeps [start]'s ratio for corner handles.
  static ChartRect resizeRect(
    ChartRect start,
    ResizeHandle handle,
    double ddx,
    double ddy, {
    bool keepAspect = false,
  }) {
    var w = start.width;
    var h = start.height;
    if (handle.movesLeft) w -= ddx;
    if (handle.movesRight) w += ddx;
    if (handle.movesTop) h -= ddy;
    if (handle.movesBottom) h += ddy;
    final aspect =
        keepAspect && handle.isCorner && start.width > 0 && start.height > 0
        ? start.width / start.height
        : null;
    final size = constrainSize(
      w,
      h,
      aspect: aspect,
      maxWidth: handle.movesLeft ? start.right : ObjectAnchor.maxSize,
      maxHeight: handle.movesTop ? start.bottom : ObjectAnchor.maxSize,
    );
    final left = handle.movesLeft ? start.right - size.width : start.left;
    final top = handle.movesTop ? start.bottom - size.height : start.top;
    return ChartRect(
      math.max(0, left),
      math.max(0, top),
      size.width,
      size.height,
    );
  }
}

/// Snapping to cell gridlines while Alt-dragging (08 §9.3).
abstract final class GridSnap {
  /// The gridline of [axis] nearest to [px] (ties snap to the lower one).
  /// Gridlines are the cell edges `offsetOf(0..length)`; hidden entries
  /// collapse onto their neighbors. Values outside the sheet snap to its
  /// start/end.
  static double snapOffset(double px, AxisIndex axis) {
    if (axis.length == 0 || px.isNaN || px <= 0) return 0;
    final total = axis.totalSize;
    if (px >= total) return total;
    final i = axis.indexAtOffset(px);
    final start = axis.offsetOf(i);
    if (px <= start) return start;
    final end = start + axis.sizeAt(i);
    return px - start <= end - px ? start : end;
  }

  /// [rect] translated so that the edge nearer to a gridline lies on it,
  /// horizontally and vertically (moving both edges keeps the size).
  static ChartRect snapMove(ChartRect rect, AxisIndex rows, AxisIndex columns) {
    final ddx = _edgeDelta(rect.left, rect.right, columns);
    final ddy = _edgeDelta(rect.top, rect.bottom, rows);
    return rect.translate(ddx, ddy);
  }

  /// [rect] with the edges moved by [handle] snapped to gridlines. An edge
  /// stays unsnapped when snapping would make the object smaller than
  /// [ObjectAnchor.minSize] or larger than [ObjectAnchor.maxSize].
  static ChartRect snapResize(
    ChartRect rect,
    ResizeHandle handle,
    AxisIndex rows,
    AxisIndex columns,
  ) {
    var l = rect.left;
    var r = rect.right;
    var t = rect.top;
    var b = rect.bottom;
    bool ok(double a, double z) =>
        z - a >= ObjectAnchor.minSize && z - a <= ObjectAnchor.maxSize;
    if (handle.movesLeft && ok(snapOffset(l, columns), r)) {
      l = snapOffset(l, columns);
    }
    if (handle.movesRight && ok(l, snapOffset(r, columns))) {
      r = snapOffset(r, columns);
    }
    if (handle.movesTop && ok(snapOffset(t, rows), b)) t = snapOffset(t, rows);
    if (handle.movesBottom && ok(t, snapOffset(b, rows))) {
      b = snapOffset(b, rows);
    }
    return ChartRect(l, t, r - l, b - t);
  }

  static double _edgeDelta(double start, double end, AxisIndex axis) {
    final a = snapOffset(start, axis) - start;
    final b = snapOffset(end, axis) - end;
    if (start + b < 0) return a;
    return a.abs() <= b.abs() ? a : b;
  }
}

/// A dashed alignment guide shown while moving or resizing an object (08 §9.3 smart guides),
/// in sheet px at 100 % zoom.
final class SnapGuide {
  /// Creates a guide: a vertical line at x = [position] from [start] to [end] (y), or a
  /// horizontal one at y = [position] from [start] to [end] (x).
  const SnapGuide({
    required this.vertical,
    required this.position,
    required this.start,
    required this.end,
  });

  /// Whether the guide is a vertical line (it aligns x positions).
  final bool vertical;

  /// x of a vertical guide, y of a horizontal one.
  final double position;

  /// Extent along the line.
  final double start;
  final double end;

  @override
  bool operator ==(Object other) =>
      other is SnapGuide &&
      other.vertical == vertical &&
      other.position == position &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(vertical, position, start, end);

  @override
  String toString() =>
      'SnapGuide(${vertical ? 'x' : 'y'} = $position, $start..$end)';
}

/// Result of a smart-guide snap: the snapped rectangle and the guides to draw.
final class SmartSnap {
  /// Creates a result.
  const SmartSnap(this.rect, this.guides);

  /// The rectangle after snapping.
  final ChartRect rect;

  /// Guides through every aligned edge or center (empty when nothing snapped).
  final List<SnapGuide> guides;
}

/// Smart guides (08 §9.3, P1): while dragging, an edge or center of the object that comes
/// within [tolerance] px of another object's edge or center snaps to it, and a guide is shown.
abstract final class SmartGuides {
  /// Snap distance in px at 100 % zoom.
  static const double tolerance = 4;

  /// [moving] (the dragged object's rectangle) translated so its nearest edge or center lines
  /// up with an edge or center of one of [others], separately on each axis.
  static SmartSnap snapMove(
    ChartRect moving,
    Iterable<ChartRect> others, {
    double tolerance = SmartGuides.tolerance,
  }) {
    final list = others.toList();
    final dx = _bestDelta(
      [moving.left, moving.centerX, moving.right],
      [
        for (final o in list) ...[o.left, o.centerX, o.right],
      ],
      tolerance,
    );
    final dy = _bestDelta(
      [moving.top, moving.centerY, moving.bottom],
      [
        for (final o in list) ...[o.top, o.centerY, o.bottom],
      ],
      tolerance,
    );
    final rect = moving.translate(dx ?? 0, dy ?? 0);
    return SmartSnap(rect, guidesFor(rect, list));
  }

  /// [rect] (being resized with [handle]) with its moving edges snapped to the edges and
  /// centers of [others]. An edge stays unsnapped when snapping would break the size limits
  /// (20–4000 px).
  static SmartSnap snapResize(
    ChartRect rect,
    ResizeHandle handle,
    Iterable<ChartRect> others, {
    double tolerance = SmartGuides.tolerance,
  }) {
    final list = others.toList();
    final xs = [
      for (final o in list) ...[o.left, o.centerX, o.right],
    ];
    final ys = [
      for (final o in list) ...[o.top, o.centerY, o.bottom],
    ];
    var l = rect.left, r = rect.right, t = rect.top, b = rect.bottom;
    bool ok(double a, double z) =>
        z - a >= ObjectAnchor.minSize && z - a <= ObjectAnchor.maxSize;
    if (handle.movesLeft) {
      final d = _bestDelta([l], xs, tolerance);
      if (d != null && ok(l + d, r)) l += d;
    }
    if (handle.movesRight) {
      final d = _bestDelta([r], xs, tolerance);
      if (d != null && ok(l, r + d)) r += d;
    }
    if (handle.movesTop) {
      final d = _bestDelta([t], ys, tolerance);
      if (d != null && ok(t + d, b)) t += d;
    }
    if (handle.movesBottom) {
      final d = _bestDelta([b], ys, tolerance);
      if (d != null && ok(t, b + d)) b += d;
    }
    final out = ChartRect(l, t, r - l, b - t);
    return SmartSnap(out, guidesFor(out, list));
  }

  /// Guides through every edge or center of [rect] that coincides (within 0.5 px) with an
  /// edge or center of one of [others]; each spans both rectangles. Sorted: vertical first,
  /// then by position.
  static List<SnapGuide> guidesFor(ChartRect rect, Iterable<ChartRect> others) {
    const eps = 0.5;
    final byKey = <(bool, double), (double, double)>{};
    void add(bool vertical, double pos, double s, double e) {
      final k = (vertical, pos);
      final cur = byKey[k];
      byKey[k] = cur == null
          ? (s, e)
          : (math.min(cur.$1, s), math.max(cur.$2, e));
    }

    for (final o in others) {
      for (final x in [rect.left, rect.centerX, rect.right]) {
        for (final ox in [o.left, o.centerX, o.right]) {
          if ((x - ox).abs() <= eps) {
            add(
              true,
              x,
              math.min(rect.top, o.top),
              math.max(rect.bottom, o.bottom),
            );
          }
        }
      }
      for (final y in [rect.top, rect.centerY, rect.bottom]) {
        for (final oy in [o.top, o.centerY, o.bottom]) {
          if ((y - oy).abs() <= eps) {
            add(
              false,
              y,
              math.min(rect.left, o.left),
              math.max(rect.right, o.right),
            );
          }
        }
      }
    }
    final keys = byKey.keys.toList()
      ..sort((a, b) {
        if (a.$1 != b.$1) return a.$1 ? -1 : 1;
        return a.$2.compareTo(b.$2);
      });
    return [
      for (final k in keys)
        SnapGuide(
          vertical: k.$1,
          position: k.$2,
          start: byKey[k]!.$1,
          end: byKey[k]!.$2,
        ),
    ];
  }

  /// The smallest move (by magnitude, ties: the earlier source) that puts one of [sources]
  /// on one of [targets] within [tolerance], or null.
  static double? _bestDelta(
    List<double> sources,
    List<double> targets,
    double tolerance,
  ) {
    double? best;
    for (final s in sources) {
      for (final t in targets) {
        final d = t - s;
        if (d.abs() > tolerance) continue;
        if (best == null || d.abs() < best.abs()) best = d;
      }
    }
    return best;
  }
}
