/// Transform math of the canvas (03 §4): resizing a (rotated) frame by a
/// handle, scaling a multi-selection inside its box, rotating about a
/// center, Shift-constrained moves and the mapping of slide-space frames
/// back into an element group's child space (the inverse of
/// `GroupSpace.toParent`, 02 §6.9). Pure Dart.
library;

import 'dart:math' as math;

import '../model/geometry/frame_math.dart';
import '../theme/model/common.dart';

/// The 8 resize handles of a selection box (03 §4.2).
enum ResizeHandle {
  topLeft(-1, -1),
  top(0, -1),
  topRight(1, -1),
  right(1, 0),
  bottomRight(1, 1),
  bottom(0, 1),
  bottomLeft(-1, 1),
  left(-1, 0);

  const ResizeHandle(this.sx, this.sy);

  /// −1 = left edge, 1 = right edge, 0 = neither.
  final int sx;

  /// −1 = top edge, 1 = bottom edge, 0 = neither.
  final int sy;

  /// Whether this is a corner handle.
  bool get isCorner => sx != 0 && sy != 0;

  /// The handle's position on a box (0..1 per axis).
  (double, double) get unit => ((sx + 1) / 2, (sy + 1) / 2);
}

/// Transform math of 03 §4.
abstract final class FrameTransforms {
  static double _clean(double v) => (v * 1e6).roundToDouble() / 1e6;

  static (double, double) _rot(double x, double y, double degrees) {
    if (degrees == 0) return (x, y);
    final a = degrees * math.pi / 180;
    final c = math.cos(a), s = math.sin(a);
    return (x * c - y * s, x * s + y * c);
  }

  /// The slide-space position of [handle] on [f] (rotation applied).
  static (double, double) handlePoint(ElementFrame f, ResizeHandle handle) {
    final (lx, ly) = _rot(
      handle.sx * f.width / 2,
      handle.sy * f.height / 2,
      f.rotation,
    );
    return (f.cx + lx, f.cy + ly);
  }

  /// [start] resized by dragging [handle] to slide point ([px], [py]) (03
  /// §4.2): in the frame's own (rotated) axes, against the opposite handle
  /// — or the center with [fromCenter] (Alt). [keepAspect] (Shift, or the
  /// default of images/icons/groups) keeps `width / height`. Dragging past
  /// the anchor flips the frame (`flipH`/`flipV` toggled, Keynote). Sides
  /// are at least [minSize] su (0 for lines).
  static ElementFrame resize(
    ElementFrame start,
    ResizeHandle handle,
    double px,
    double py, {
    bool keepAspect = false,
    bool fromCenter = false,
    double minSize = 1,
  }) {
    final w0 = start.width, h0 = start.height;
    // Pointer in the frame's local axes, relative to its center.
    final (qx, qy) = _rot(px - start.cx, py - start.cy, -start.rotation);
    // Anchor (fixed point) and signed new extents along each moving axis.
    final ax = fromCenter ? 0.0 : -handle.sx * w0 / 2;
    final ay = fromCenter ? 0.0 : -handle.sy * h0 / 2;
    double sw = w0, sh = h0; // signed sizes (negative = flipped)
    if (handle.sx != 0) {
      sw = fromCenter ? 2 * qx * handle.sx : (qx - ax) * handle.sx;
    }
    if (handle.sy != 0) {
      sh = fromCenter ? 2 * qy * handle.sy : (qy - ay) * handle.sy;
    }
    if (keepAspect && w0 > 0 && h0 > 0) {
      final ratio = w0 / h0;
      if (handle.isCorner) {
        final kx = sw.abs() / w0, ky = sh.abs() / h0;
        final k = math.max(kx, ky);
        sw = (sw < 0 ? -1 : 1) * k * w0;
        sh = (sh < 0 ? -1 : 1) * k * h0;
      } else if (handle.sx != 0) {
        sh = sw.abs() / ratio;
      } else {
        sw = sh.abs() * ratio;
      }
    }
    double atLeast(double v) {
      final m = v.abs() < minSize ? minSize : v.abs();
      return v < 0 ? -m : m;
    }

    sw = atLeast(sw);
    sh = atLeast(sh);
    // New local center: midway between the anchor and the moving edge.
    var lcx = 0.0, lcy = 0.0;
    if (!fromCenter) {
      if (handle.sx != 0) lcx = ax + handle.sx * sw / 2;
      if (handle.sy != 0) lcy = ay + handle.sy * sh / 2;
    }
    final (dx, dy) = _rot(lcx, lcy, start.rotation);
    final cx = start.cx + dx, cy = start.cy + dy;
    final w = sw.abs(), h = sh.abs();
    return ElementFrame(
      _clean(cx - w / 2),
      _clean(cy - h / 2),
      _clean(w),
      _clean(h),
      rotation: start.rotation,
      flipH: sw < 0 ? !start.flipH : start.flipH,
      flipV: sh < 0 ? !start.flipV : start.flipV,
    );
  }

  /// [frame] (inside [from]) scaled into box [to] — the multi-selection
  /// resize of 03 §4.2: positions and sizes scale with the box; a flipped
  /// box mirrors positions and toggles flips.
  static ElementFrame scaleInBox(
    ElementFrame frame,
    SuRect from,
    ElementFrame to,
  ) => GroupSpace.toParent(frame, to, from);

  /// [f] rotated by [degrees] about ([cx], [cy]) (03 §4.3, multi-selection
  /// rotation about the selection center).
  static ElementFrame rotateAbout(
    ElementFrame f,
    double cx,
    double cy,
    double degrees,
  ) {
    final (dx, dy) = _rot(f.cx - cx, f.cy - cy, degrees);
    final ncx = cx + dx, ncy = cy + dy;
    return ElementFrame(
      _clean(ncx - f.width / 2),
      _clean(ncy - f.height / 2),
      f.width,
      f.height,
      rotation: normalizeRotation(f.rotation + degrees),
      flipH: f.flipH,
      flipV: f.flipV,
    );
  }

  /// The angle (degrees clockwise from "up") of slide point ([px], [py])
  /// around ([cx], [cy]) — the rotation handle's pointer angle.
  static double angleOf(double cx, double cy, double px, double py) =>
      math.atan2(px - cx, -(py - cy)) * 180 / math.pi;

  /// A pointer delta constrained to horizontal, vertical or 45° (Shift
  /// while moving, 03 §4.1).
  static (double, double) constrain(double dx, double dy) {
    final ax = dx.abs(), ay = dy.abs();
    if (ax == 0 && ay == 0) return (0, 0);
    final angle = math.atan2(ay, ax) * 180 / math.pi;
    if (angle < 22.5) return (dx, 0);
    if (angle > 67.5) return (0, dy);
    final d = (ax + ay) / 2;
    return (dx.sign * d, dy.sign * d);
  }

  /// The inverse of `GroupSpace.toParent`: frame [f] of the space [group]
  /// lives in, expressed in the group's child space described by
  /// [childBounds]. Used to write frames of elements inside an entered
  /// group (their stored frames are in the group's child space).
  static ElementFrame toChild(
    ElementFrame f,
    ElementFrame group,
    SuRect childBounds,
  ) {
    final sx = childBounds.width == 0 || group.width == 0
        ? 1.0
        : group.width / childBounds.width;
    final sy = childBounds.height == 0 || group.height == 0
        ? 1.0
        : group.height / childBounds.height;
    var px = f.cx, py = f.cy, rot = f.rotation;
    var fh = f.flipH, fv = f.flipV;
    final gr = normalizeRotation(group.rotation);
    if (gr != 0) {
      final (dx, dy) = _rot(px - group.cx, py - group.cy, -gr);
      px = group.cx + dx;
      py = group.cy + dy;
      rot -= gr;
    }
    if (group.flipV) {
      py = group.cy - (py - group.cy);
      rot = -rot;
      fv = !fv;
    }
    if (group.flipH) {
      px = group.cx - (px - group.cx);
      rot = -rot;
      fh = !fh;
    }
    final ccx = (px - group.x) / sx + childBounds.x;
    final ccy = (py - group.y) / sy + childBounds.y;
    final w = f.width / sx, h = f.height / sy;
    return ElementFrame(
      _clean(ccx - w / 2),
      _clean(ccy - h / 2),
      _clean(w),
      _clean(h),
      rotation: normalizeRotation(rot),
      flipH: fh,
      flipV: fv,
    );
  }

  /// A slide-space delta ([dx], [dy]) expressed in [group]'s child space
  /// (moving an element inside an entered group by a pointer delta).
  static (double, double) deltaToChild(
    double dx,
    double dy,
    ElementFrame group,
    SuRect childBounds,
  ) {
    var (x, y) = _rot(dx, dy, -normalizeRotation(group.rotation));
    if (group.flipV) y = -y;
    if (group.flipH) x = -x;
    final sx = childBounds.width == 0 || group.width == 0
        ? 1.0
        : group.width / childBounds.width;
    final sy = childBounds.height == 0 || group.height == 0
        ? 1.0
        : group.height / childBounds.height;
    return (_clean(x / sx), _clean(y / sy));
  }

  /// The union of the rotated bounds of [frames], or null when empty.
  static SuRect? boundsOf(Iterable<ElementFrame> frames) =>
      unionRects(frames.map((f) => f.bounds));
}
