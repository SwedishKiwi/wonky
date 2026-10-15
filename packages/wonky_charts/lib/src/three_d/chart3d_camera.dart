import 'dart:math' as math;

import '../scene/geometry.dart';
import 'vec3.dart';

/// A projected point: screen position (scene px) and distance from the eye.
final class Projected {
  /// Creates a projected point.
  const Projected(this.x, this.y, this.depth);

  final double x;
  final double y;

  /// Distance along the view direction (larger = farther).
  final double depth;
}

/// The orbit camera of a 3D chart (08 §23.4), shared by the software and GPU backends so both
/// draw the same pixels: a perspective camera looking at the scene center from [azimuth] /
/// [elevation], fitted into the plot rectangle.
///
/// Screen mapping: `X = cx + s·(xv/zf − ox)`, `Y = cy − s·(yv/zf − oy)` where `xv, yv, zf` are
/// view-space coordinates (right, up, forward). A GPU camera with the vertical field of view
/// [gpuFovY] rendering into [gpuViewport] produces exactly this mapping.
final class Chart3DCamera {
  Chart3DCamera._(
    this.azimuth,
    this.elevation,
    this.fov,
    this.target,
    this.eye,
    this._r,
    this._u,
    this._f,
    this._s,
    this._cx,
    this._cy,
    this._ox,
    this._oy,
    this.gpuViewport,
    this.gpuFovY,
  );

  /// Fits a camera looking at [bounds] from [azimuthDeg]/[elevationDeg] with a field of view
  /// of [fovDeg] (0 = almost orthographic) into [viewport] (scene px).
  factory Chart3DCamera.fit({
    required Aabb3 bounds,
    required double azimuthDeg,
    required double elevationDeg,
    required double fovDeg,
    required ChartRect viewport,
    Iterable<Vec3> extraPoints = const [],
  }) {
    final az = azimuthDeg * math.pi / 180;
    final el = elevationDeg.clamp(0.0, 89.0) * math.pi / 180;
    final fov = fovDeg.clamp(1.0, 60.0) * math.pi / 180;
    final target = bounds.center;
    final radius = math.max(bounds.radius, 1e-6);
    final distance = radius / math.sin(fov / 2) * 1.02;
    final dir = Vec3(
      math.sin(az) * math.cos(el),
      math.sin(el),
      math.cos(az) * math.cos(el),
    );
    final eye = target + dir * distance;
    final f = (target - eye).normalized;
    final r = f.cross(Vec3.unitY).normalized;
    final u = r.cross(f);
    // Tangent-space bounds of the corners.
    var x0 = double.infinity, x1 = -double.infinity;
    var y0 = double.infinity, y1 = -double.infinity;
    for (final p in [...bounds.corners, ...extraPoints]) {
      final d = p - eye;
      final zf = math.max(d.dot(f), 1e-9);
      final xt = d.dot(r) / zf, yt = d.dot(u) / zf;
      x0 = math.min(x0, xt);
      x1 = math.max(x1, xt);
      y0 = math.min(y0, yt);
      y1 = math.max(y1, yt);
    }
    final bw = math.max(x1 - x0, 1e-9), bh = math.max(y1 - y0, 1e-9);
    final s = math.min(viewport.width / bw, viewport.height / bh);
    final ox = (x0 + x1) / 2, oy = (y0 + y1) / 2;
    final cx = viewport.left + viewport.width / 2;
    final cy = viewport.top + viewport.height / 2;
    final maxX = math.max(x0.abs(), x1.abs()) * 1.02;
    final maxY = math.max(y0.abs(), y1.abs()) * 1.02;
    final gw = 2 * s * maxX, gh = 2 * s * maxY;
    final gcx = cx - s * ox, gcy = cy + s * oy;
    return Chart3DCamera._(
      azimuthDeg,
      elevationDeg,
      fovDeg,
      target,
      eye,
      r,
      u,
      f,
      s,
      cx,
      cy,
      ox,
      oy,
      ChartRect(gcx - gw / 2, gcy - gh / 2, gw, gh),
      2 * math.atan(maxY),
    );
  }

  /// Degrees as requested.
  final double azimuth;
  final double elevation;
  final double fov;

  /// World point looked at.
  final Vec3 target;

  /// World position of the eye.
  final Vec3 eye;

  final Vec3 _r;
  final Vec3 _u;
  final Vec3 _f;
  final double _s;
  final double _cx;
  final double _cy;
  final double _ox;
  final double _oy;

  /// Screen rectangle (scene px) a GPU perspective camera with [gpuFovY] must render into.
  final ChartRect gpuViewport;

  /// Vertical field of view (radians) of the GPU camera.
  final double gpuFovY;

  /// Unit vector to the right of the view.
  Vec3 get right => _r;

  /// Unit up vector of the view.
  Vec3 get up => _u;

  /// Unit view direction.
  Vec3 get forward => _f;

  /// Projects [p] to the screen.
  Projected project(Vec3 p) {
    final d = p - eye;
    final zf = math.max(d.dot(_f), 1e-9);
    return Projected(
      _cx + _s * (d.dot(_r) / zf - _ox),
      _cy - _s * (d.dot(_u) / zf - _oy),
      zf,
    );
  }

  /// Distance of [p] from the eye.
  double distanceTo(Vec3 p) => (p - eye).length;

  /// The world ray through screen point ([x], [y]): origin and unit direction.
  (Vec3, Vec3) ray(double x, double y) {
    final xt = (x - _cx) / _s + _ox;
    final yt = -(y - _cy) / _s + _oy;
    return (eye, (_f + _r * xt + _u * yt).normalized);
  }

  /// Converts a direction given in view space (x right, y up, z toward the viewer) to world
  /// space; lights are defined relative to the view so the chart is lit the same while it
  /// orbits.
  Vec3 viewToWorld(Vec3 v) => (_r * v.x + _u * v.y - _f * v.z).normalized;
}
