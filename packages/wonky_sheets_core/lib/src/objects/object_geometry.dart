import 'dart:math' as math;

import '../charts/scene/geometry.dart';
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
  bool get movesRight => this == topRight || this == right || this == bottomRight;

  /// Whether dragging moves the top edge.
  bool get movesTop => this == topLeft || this == top || this == topRight;

  /// Whether dragging moves the bottom edge.
  bool get movesBottom => this == bottomLeft || this == bottom || this == bottomRight;

  /// Whether this is a corner handle (resizes both dimensions).
  bool get isCorner =>
      this == topLeft || this == topRight || this == bottomLeft || this == bottomRight;
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
    final maxW = math.max(ObjectAnchor.minSize, math.min(maxWidth, ObjectAnchor.maxSize));
    final maxH = math.max(ObjectAnchor.minSize, math.min(maxHeight, ObjectAnchor.maxSize));
    double clampW(double w) => w.isNaN ? ObjectAnchor.minSize : w.clamp(ObjectAnchor.minSize, maxW);
    double clampH(double h) => h.isNaN ? ObjectAnchor.minSize : h.clamp(ObjectAnchor.minSize, maxH);
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
    final aspect = keepAspect && handle.isCorner && start.width > 0 && start.height > 0
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
    return ChartRect(math.max(0, left), math.max(0, top), size.width, size.height);
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
    bool ok(double a, double z) => z - a >= ObjectAnchor.minSize && z - a <= ObjectAnchor.maxSize;
    if (handle.movesLeft && ok(snapOffset(l, columns), r)) l = snapOffset(l, columns);
    if (handle.movesRight && ok(l, snapOffset(r, columns))) r = snapOffset(r, columns);
    if (handle.movesTop && ok(snapOffset(t, rows), b)) t = snapOffset(t, rows);
    if (handle.movesBottom && ok(t, snapOffset(b, rows))) b = snapOffset(b, rows);
    return ChartRect(l, t, r - l, b - t);
  }

  static double _edgeDelta(double start, double end, AxisIndex axis) {
    final a = snapOffset(start, axis) - start;
    final b = snapOffset(end, axis) - end;
    if (start + b < 0) return a;
    return a.abs() <= b.abs() ? a : b;
  }
}
