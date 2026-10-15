/// The geometry of a morphing element (06 §8.4): center, size and rotation,
/// interpolated between two slides, and the slide-space matrices that put
/// an element's authored box onto an interpolated geometry (the
/// `ElementVisualState.transform` of the Magic Move frames).
library;

import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import '../../theme/model/common.dart' show SuRect;

double _r(double v) => (v * 1e6).roundToDouble() / 1e6;

/// Center, size and rotation of an element box (su, degrees clockwise).
final class MorphGeometry {
  /// Creates a geometry.
  const MorphGeometry(this.cx, this.cy, this.width, this.height, this.rotation);

  /// The geometry of [frame] rotated by [rotation] about its center, with a
  /// slide-space [transform] (an `ElementVisualState.transform`) applied:
  /// the transformed center and box axes give the effective center, size
  /// and rotation (shear and perspective are ignored).
  factory MorphGeometry.of(
    SuRect frame,
    double rotation, [
    Matrix4? transform,
  ]) {
    final cx = frame.x + frame.width / 2, cy = frame.y + frame.height / 2;
    final g = MorphGeometry(cx, cy, frame.width, frame.height, rotation);
    if (transform == null || _isIdentity(transform)) return g;
    final a = rotation * math.pi / 180;
    final ca = math.cos(a), sa = math.sin(a);
    Vector3 map(double x, double y) =>
        transform.perspectiveTransform(Vector3(x, y, 0));
    final c = map(cx, cy);
    final ax = map(cx + ca * frame.width / 2, cy + sa * frame.width / 2) - c;
    final ay = map(cx - sa * frame.height / 2, cy + ca * frame.height / 2) - c;
    final w = 2 * math.sqrt(ax.x * ax.x + ax.y * ax.y);
    final h = 2 * math.sqrt(ay.x * ay.x + ay.y * ay.y);
    final rot = frame.width > 1e-9
        ? math.atan2(ax.y, ax.x) * 180 / math.pi
        : math.atan2(ay.y, ay.x) * 180 / math.pi - 90;
    return MorphGeometry(c.x, c.y, w, h, _norm(rot));
  }

  /// Center (su).
  final double cx, cy;

  /// Size (su, ≥ 0).
  final double width, height;

  /// Degrees clockwise.
  final double rotation;

  /// The unrotated box.
  SuRect get frame => SuRect(cx - width / 2, cy - height / 2, width, height);

  /// Element-local (0..width, 0..height) → slide space.
  Matrix4 get local => Matrix4.identity()
    ..translateByDouble(cx, cy, 0, 1)
    ..rotateZ(rotation * math.pi / 180)
    ..translateByDouble(-width / 2, -height / 2, 0, 1);

  /// Slide space → element-local.
  Matrix4 get inverseLocal => Matrix4.identity()
    ..translateByDouble(width / 2, height / 2, 0, 1)
    ..rotateZ(-rotation * math.pi / 180)
    ..translateByDouble(-cx, -cy, 0, 1);

  /// The slide-space matrix that maps the box of [authored] onto this
  /// geometry, scaling it to this size ("stretch": exact at both ends of a
  /// morph, used for shapes, images, charts, code boxes).
  Matrix4 stretchFrom(MorphGeometry authored) {
    final sx = authored.width.abs() < 1e-9 ? 1.0 : width / authored.width;
    final sy = authored.height.abs() < 1e-9 ? 1.0 : height / authored.height;
    return local
      ..scaleByDouble(sx, sy, 1, 1)
      ..multiply(authored.inverseLocal);
  }

  /// The slide-space matrix that moves the box of [authored] rigidly to
  /// this center and rotation, keeping its size (text: glyphs are never
  /// stretched; the box stays centered).
  Matrix4 rigidFrom(MorphGeometry authored) =>
      MorphGeometry(cx, cy, authored.width, authored.height, rotation).local
        ..multiply(authored.inverseLocal);

  /// The geometry between [a] and [b] at [t] (06 §8.4): the center
  /// linearly; the size linearly, or in log space when [logSize] (aspect
  /// kept: no squashing); the rotation along the shortest arc, or by the
  /// literal difference [rotationDelta] when given (`rotation: literal`).
  static MorphGeometry lerp(
    MorphGeometry a,
    MorphGeometry b,
    double t, {
    bool logSize = false,
    double? rotationDelta,
  }) {
    double size(double x, double y) {
      if (logSize && x > 1e-9 && y > 1e-9) {
        return math.exp(math.log(x) + (math.log(y) - math.log(x)) * t);
      }
      return x + (y - x) * t;
    }

    final d = rotationDelta ?? shortestDelta(a.rotation, b.rotation);
    return MorphGeometry(
      a.cx + (b.cx - a.cx) * t,
      a.cy + (b.cy - a.cy) * t,
      size(a.width, b.width),
      size(a.height, b.height),
      a.rotation + d * t,
    );
  }

  /// The signed shortest angular difference from [from] to [to] (degrees,
  /// −180 < d ≤ 180).
  static double shortestDelta(double from, double to) {
    var d = (to - from) % 360;
    if (d > 180) d -= 360;
    if (d <= -180) d += 360;
    return d;
  }

  /// Whether both boxes have the same aspect ratio (within 1 %): the size
  /// then interpolates in log space.
  static bool sameAspect(MorphGeometry a, MorphGeometry b) {
    if (a.width <= 1e-9 || a.height <= 1e-9) return false;
    if (b.width <= 1e-9 || b.height <= 1e-9) return false;
    final ra = a.width / a.height, rb = b.width / b.height;
    return (ra / rb - 1).abs() < 0.01;
  }

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'center': [_r(cx), _r(cy)],
    'size': [_r(width), _r(height)],
    'rotation': _r(rotation),
  };
}

double _norm(double deg) {
  var d = deg % 360;
  if (d < 0) d += 360;
  if ((d - 360).abs() < 1e-9) d = 0;
  return d;
}

bool _isIdentity(Matrix4 m) {
  final s = m.storage;
  for (var i = 0; i < 16; i++) {
    if (s[i] != (i % 5 == 0 ? 1.0 : 0.0)) return false;
  }
  return true;
}
