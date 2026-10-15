/// Frame geometry shared by the resolver and the planner (02 §2.2, §6.9):
/// element frames, rotated bounds and the mapping of an element group's
/// child space into its parent space.
library;

import 'dart:math' as math;

import '../../theme/model/common.dart';

/// A frame with rotation and flips (02 §2.2): `x, y` = top-left of the
/// unrotated box, rotation in degrees clockwise about the center.
final class ElementFrame {
  /// Creates a frame.
  const ElementFrame(
    this.x,
    this.y,
    this.width,
    this.height, {
    this.rotation = 0,
    this.flipH = false,
    this.flipV = false,
  });

  /// A frame from a rectangle.
  ElementFrame.of(
    SuRect r, {
    double rotation = 0,
    bool flipH = false,
    bool flipV = false,
  }) : this(
         r.x,
         r.y,
         r.width,
         r.height,
         rotation: rotation,
         flipH: flipH,
         flipV: flipV,
       );

  final double x;
  final double y;
  final double width;
  final double height;

  /// Degrees clockwise, `[0, 360)`.
  final double rotation;
  final bool flipH;
  final bool flipV;

  /// The unrotated box.
  SuRect get rect => SuRect(x, y, width, height);

  /// Center x.
  double get cx => x + width / 2;

  /// Center y.
  double get cy => y + height / 2;

  /// The axis-aligned bounds of the rotated box.
  SuRect get bounds {
    final r = normalizeRotation(rotation);
    if (r == 0) return rect;
    final a = r * math.pi / 180;
    final c = math.cos(a).abs(), s = math.sin(a).abs();
    final w = width * c + height * s;
    final h = width * s + height * c;
    return SuRect(cx - w / 2, cy - h / 2, w, h);
  }

  @override
  bool operator ==(Object other) =>
      other is ElementFrame &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height &&
      other.rotation == rotation &&
      other.flipH == flipH &&
      other.flipV == flipV;

  @override
  int get hashCode => Object.hash(x, y, width, height, rotation, flipH, flipV);

  @override
  String toString() =>
      'ElementFrame($x, $y, $width × $height, $rotation°'
      '${flipH ? ', flipH' : ''}${flipV ? ', flipV' : ''})';
}

/// Normalizes degrees to `[0, 360)` (rounded to 1e-6 to keep values stable).
double normalizeRotation(double degrees) {
  if (!degrees.isFinite) return 0;
  var r = degrees % 360;
  if (r < 0) r += 360;
  r = (r * 1e6).roundToDouble() / 1e6;
  return r >= 360 ? 0 : r;
}

/// The union of [rects], or null when empty.
SuRect? unionRects(Iterable<SuRect> rects) {
  double? l, t, r, b;
  for (final x in rects) {
    l = l == null ? x.x : math.min(l, x.x);
    t = t == null ? x.y : math.min(t, x.y);
    r = r == null ? x.right : math.max(r, x.right);
    b = b == null ? x.bottom : math.max(b, x.bottom);
  }
  if (l == null) return null;
  return SuRect(l, t!, r! - l, b! - t);
}

/// Whether two rectangles overlap (touching edges don't).
bool rectsOverlap(SuRect a, SuRect b) =>
    a.x < b.right && b.x < a.right && a.y < b.bottom && b.y < a.bottom;

/// The child space of an element group (02 §6.9): `childBounds` mapped onto
/// the group's frame (scale, flips, rotation about the group center).
abstract final class GroupSpace {
  /// Maps [child] (in the child space described by [childBounds]) into the
  /// space [group]'s frame lives in. Non-uniform scaling of a rotated child
  /// is approximated by scaling its box.
  static ElementFrame toParent(
    ElementFrame child,
    ElementFrame group,
    SuRect childBounds,
  ) {
    final sx = childBounds.width == 0 ? 1.0 : group.width / childBounds.width;
    final sy = childBounds.height == 0
        ? 1.0
        : group.height / childBounds.height;
    var px = group.x + (child.cx - childBounds.x) * sx;
    var py = group.y + (child.cy - childBounds.y) * sy;
    var rot = child.rotation;
    var fh = child.flipH, fv = child.flipV;
    if (group.flipH) {
      px = group.cx - (px - group.cx);
      rot = -rot;
      fh = !fh;
    }
    if (group.flipV) {
      py = group.cy - (py - group.cy);
      rot = -rot;
      fv = !fv;
    }
    final gr = normalizeRotation(group.rotation);
    if (gr != 0) {
      final a = gr * math.pi / 180;
      final dx = px - group.cx, dy = py - group.cy;
      px = group.cx + dx * math.cos(a) - dy * math.sin(a);
      py = group.cy + dx * math.sin(a) + dy * math.cos(a);
      rot += gr;
    }
    final w = child.width * sx, h = child.height * sy;
    return ElementFrame(
      _clean(px - w / 2),
      _clean(py - h / 2),
      _clean(w),
      _clean(h),
      rotation: normalizeRotation(rot),
      flipH: fh,
      flipV: fv,
    );
  }

  /// The inverse of [toParent] (SL-34, moving an element into a group from
  /// the Layers panel): maps [frame] (in the space [group]'s frame lives
  /// in) into the group's child space described by [childBounds].
  static ElementFrame toChild(
    ElementFrame frame,
    ElementFrame group,
    SuRect childBounds,
  ) {
    final sx = childBounds.width == 0 ? 1.0 : group.width / childBounds.width;
    final sy = childBounds.height == 0
        ? 1.0
        : group.height / childBounds.height;
    var px = frame.cx, py = frame.cy;
    var rot = frame.rotation;
    var fh = frame.flipH, fv = frame.flipV;
    final gr = normalizeRotation(group.rotation);
    if (gr != 0) {
      final a = -gr * math.pi / 180;
      final dx = px - group.cx, dy = py - group.cy;
      px = group.cx + dx * math.cos(a) - dy * math.sin(a);
      py = group.cy + dx * math.sin(a) + dy * math.cos(a);
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
    final cx = childBounds.x + (px - group.x) / sx;
    final cy = childBounds.y + (py - group.y) / sy;
    final w = frame.width / sx, h = frame.height / sy;
    return ElementFrame(
      _clean(cx - w / 2),
      _clean(cy - h / 2),
      _clean(w),
      _clean(h),
      rotation: normalizeRotation(rot),
      flipH: fh,
      flipV: fv,
    );
  }

  /// Rounds float noise (1e-6 su) so baked frames are stable.
  static double _clean(double v) => (v * 1e6).roundToDouble() / 1e6;
}
