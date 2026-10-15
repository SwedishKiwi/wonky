/// Path construction and measuring helpers of the scene layer (SL-10):
/// [ShapePathBuilder] (elliptical arcs, rounded rectangles, quadratic
/// curves on top of the chart engine's `PathCmd`s), path transforms and
/// bounds.
library;

import 'dart:math' as math;

import 'package:wonky_charts/wonky_charts.dart'
    show PathCmd, PMoveTo, PLineTo, PCubicTo, PClose;

import '../scene/nodes/scene_nodes.dart';
import '../theme/model/common.dart';

/// Builds `PathCmd` lists in local coordinates.
final class ShapePathBuilder {
  final List<PathCmd> _cmds = [];
  double _x = 0, _y = 0;
  double _startX = 0, _startY = 0;
  bool _open = false;

  /// The commands so far.
  List<PathCmd> get commands => List.unmodifiable(_cmds);

  /// The current point.
  (double, double) get current => (_x, _y);

  /// Whether a sub-path is open.
  bool get isOpen => _open;

  /// A [ScenePath] of the commands.
  ScenePath build({bool evenOdd = false}) =>
      ScenePath(commands, evenOdd: evenOdd);

  /// Starts a sub-path.
  void moveTo(double x, double y) {
    _cmds.add(PMoveTo(x, y));
    _x = _startX = x;
    _y = _startY = y;
    _open = true;
  }

  /// A straight segment.
  void lineTo(double x, double y) {
    if (!_open) return moveTo(x, y);
    _cmds.add(PLineTo(x, y));
    _x = x;
    _y = y;
  }

  /// A cubic Bézier.
  void cubicTo(double x1, double y1, double x2, double y2, double x, double y) {
    if (!_open) moveTo(_x, _y);
    _cmds.add(PCubicTo(x1, y1, x2, y2, x, y));
    _x = x;
    _y = y;
  }

  /// A quadratic Bézier (as a cubic).
  void quadTo(double cx, double cy, double x, double y) => cubicTo(
    _x + 2 / 3 * (cx - _x),
    _y + 2 / 3 * (cy - _y),
    x + 2 / 3 * (cx - x),
    y + 2 / 3 * (cy - y),
    x,
    y,
  );

  /// Closes the sub-path.
  void close() {
    if (!_open) return;
    _cmds.add(const PClose());
    _x = _startX;
    _y = _startY;
    _open = false;
  }

  /// An elliptical arc around ([cx], [cy]) with radii [rx]/[ry] from angle
  /// [start] sweeping [sweep] (radians, clockwise on screen for positive
  /// sweeps, 0 = 3 o'clock). Continues the open sub-path with a line to the
  /// arc start (or starts one when [connect] is false or none is open).
  void ellipseArc(
    double cx,
    double cy,
    double rx,
    double ry,
    double start,
    double sweep, {
    bool connect = true,
  }) {
    final sx = cx + rx * math.cos(start), sy = cy + ry * math.sin(start);
    if (_open && connect) {
      if ((sx - _x).abs() > 1e-9 || (sy - _y).abs() > 1e-9) lineTo(sx, sy);
    } else {
      moveTo(sx, sy);
    }
    if (sweep == 0) return;
    final segments = (sweep.abs() / (math.pi / 2)).ceil().clamp(1, 32);
    final step = sweep / segments;
    final k = 4 / 3 * math.tan(step / 4);
    var a = start;
    for (var i = 0; i < segments; i++) {
      final b = a + step;
      final ca = math.cos(a), sa = math.sin(a);
      final cb = math.cos(b), sb = math.sin(b);
      cubicTo(
        cx + rx * (ca - k * sa),
        cy + ry * (sa + k * ca),
        cx + rx * (cb + k * sb),
        cy + ry * (sb - k * cb),
        cx + rx * cb,
        cy + ry * sb,
      );
      a = b;
    }
  }

  /// A closed ellipse inscribed in the rectangle.
  void ellipse(double l, double t, double w, double h) {
    ellipseArc(
      l + w / 2,
      t + h / 2,
      w / 2,
      h / 2,
      0,
      2 * math.pi,
      connect: false,
    );
    close();
  }

  /// A closed polygon through [xy] (`x0, y0, x1, y1, …`).
  void polygon(List<double> xy) {
    if (xy.length < 4) return;
    moveTo(xy[0], xy[1]);
    for (var i = 2; i + 1 < xy.length; i += 2) {
      lineTo(xy[i], xy[i + 1]);
    }
    close();
  }

  /// An open polyline through [xy].
  void polyline(List<double> xy) {
    if (xy.length < 4) return;
    moveTo(xy[0], xy[1]);
    for (var i = 2; i + 1 < xy.length; i += 2) {
      lineTo(xy[i], xy[i + 1]);
    }
  }

  /// A closed rectangle.
  void rect(double l, double t, double w, double h) =>
      polygon([l, t, l + w, t, l + w, t + h, l, t + h]);

  /// A closed rectangle with corner radius [r] (clamped to half the
  /// smaller side).
  void roundRect(double l, double t, double w, double h, double r) {
    final rr = math.max(0.0, math.min(r, math.min(w, h) / 2));
    if (rr <= 0) return rect(l, t, w, h);
    const q = math.pi / 2;
    moveTo(l + rr, t);
    lineTo(l + w - rr, t);
    ellipseArc(l + w - rr, t + rr, rr, rr, -q, q);
    lineTo(l + w, t + h - rr);
    ellipseArc(l + w - rr, t + h - rr, rr, rr, 0, q);
    lineTo(l + rr, t + h);
    ellipseArc(l + rr, t + h - rr, rr, rr, q, q);
    lineTo(l, t + rr);
    ellipseArc(l + rr, t + rr, rr, rr, math.pi, q);
    close();
  }

  /// Appends [cmds] unchanged.
  void addAll(Iterable<PathCmd> cmds) {
    for (final c in cmds) {
      switch (c) {
        case PMoveTo(:final x, :final y):
          moveTo(x, y);
        case PLineTo(:final x, :final y):
          lineTo(x, y);
        case PCubicTo(
          :final x1,
          :final y1,
          :final x2,
          :final y2,
          :final x,
          :final y,
        ):
          cubicTo(x1, y1, x2, y2, x, y);
        case PClose():
          close();
      }
    }
  }
}

/// Affine helpers over `PathCmd` lists.
abstract final class PathOps {
  /// [cmds] with every point mapped through [f].
  static List<PathCmd> map(
    List<PathCmd> cmds,
    (double, double) Function(double x, double y) f,
  ) => [
    for (final c in cmds)
      switch (c) {
        PMoveTo(:final x, :final y) => () {
          final (a, b) = f(x, y);
          return PMoveTo(a, b);
        }(),
        PLineTo(:final x, :final y) => () {
          final (a, b) = f(x, y);
          return PLineTo(a, b);
        }(),
        PCubicTo(
          :final x1,
          :final y1,
          :final x2,
          :final y2,
          :final x,
          :final y,
        ) =>
          () {
            final (a1, b1) = f(x1, y1);
            final (a2, b2) = f(x2, y2);
            final (a, b) = f(x, y);
            return PCubicTo(a1, b1, a2, b2, a, b);
          }(),
        PClose() => c,
      },
  ];

  /// [cmds] scaled by ([sx], [sy]) then translated by ([dx], [dy]).
  static List<PathCmd> scale(
    List<PathCmd> cmds,
    double sx,
    double sy, {
    double dx = 0,
    double dy = 0,
  }) => map(cmds, (x, y) => (x * sx + dx, y * sy + dy));

  /// The control-point bounds of [cmds] (a superset of the exact bounds),
  /// or null for an empty path.
  static SuRect? bounds(List<PathCmd> cmds) {
    double? l, t, r, b;
    void add(double x, double y) {
      l = l == null ? x : math.min(l!, x);
      t = t == null ? y : math.min(t!, y);
      r = r == null ? x : math.max(r!, x);
      b = b == null ? y : math.max(b!, y);
    }

    for (final c in cmds) {
      switch (c) {
        case PMoveTo(:final x, :final y) || PLineTo(:final x, :final y):
          add(x, y);
        case PCubicTo(
          :final x1,
          :final y1,
          :final x2,
          :final y2,
          :final x,
          :final y,
        ):
          add(x1, y1);
          add(x2, y2);
          add(x, y);
        case PClose():
          break;
      }
    }
    if (l == null) return null;
    return SuRect(l!, t!, r! - l!, b! - t!);
  }

  /// The bounds of the flattened outline (tight up to the flattening
  /// error), or null for an empty path.
  static SuRect? flatBounds(List<PathCmd> cmds) {
    double? l, t, r, b;
    for (final (pts, _) in flatten(cmds)) {
      for (var i = 0; i + 1 < pts.length; i += 2) {
        final x = pts[i], y = pts[i + 1];
        l = l == null ? x : math.min(l, x);
        t = t == null ? y : math.min(t, y);
        r = r == null ? x : math.max(r, x);
        b = b == null ? y : math.max(b, y);
      }
    }
    if (l == null) return null;
    return SuRect(l, t!, r! - l, b! - t);
  }

  /// Flattens [cmds] into polylines (`[x0, y0, x1, y1, …]` per sub-path,
  /// with a flag for closed sub-paths); curves are subdivided into
  /// [curveSteps] segments.
  static List<(List<double>, bool)> flatten(
    List<PathCmd> cmds, {
    int curveSteps = 16,
  }) {
    final out = <(List<double>, bool)>[];
    var pts = <double>[];
    var x = 0.0, y = 0.0;
    void flush(bool closed) {
      if (pts.length >= 4) out.add((pts, closed));
      pts = <double>[];
    }

    for (final c in cmds) {
      switch (c) {
        case PMoveTo(x: final nx, y: final ny):
          flush(false);
          pts.addAll([nx, ny]);
          x = nx;
          y = ny;
        case PLineTo(x: final nx, y: final ny):
          if (pts.isEmpty) pts.addAll([x, y]);
          pts.addAll([nx, ny]);
          x = nx;
          y = ny;
        case PCubicTo(
          :final x1,
          :final y1,
          :final x2,
          :final y2,
          x: final nx,
          y: final ny,
        ):
          if (pts.isEmpty) pts.addAll([x, y]);
          for (var i = 1; i <= curveSteps; i++) {
            final t = i / curveSteps, u = 1 - t;
            pts.add(
              u * u * u * x +
                  3 * u * u * t * x1 +
                  3 * u * t * t * x2 +
                  t * t * t * nx,
            );
            pts.add(
              u * u * u * y +
                  3 * u * u * t * y1 +
                  3 * u * t * t * y2 +
                  t * t * t * ny,
            );
          }
          x = nx;
          y = ny;
        case PClose():
          flush(true);
      }
    }
    flush(false);
    return out;
  }

  /// Whether ([px], [py]) is inside the filled area of [path] (flattened;
  /// non-zero or even-odd per the path).
  static bool contains(ScenePath path, double px, double py) {
    var winding = 0;
    var crossings = 0;
    for (final (pts, _) in flatten(path.commands)) {
      final n = pts.length ~/ 2;
      for (var i = 0; i < n; i++) {
        final x0 = pts[2 * i], y0 = pts[2 * i + 1];
        final j = (i + 1) % n;
        final x1 = pts[2 * j], y1 = pts[2 * j + 1];
        if ((y0 <= py) != (y1 <= py)) {
          final xi = x0 + (py - y0) / (y1 - y0) * (x1 - x0);
          if (xi > px) {
            crossings++;
            winding += y1 > y0 ? 1 : -1;
          }
        }
      }
    }
    return path.evenOdd ? crossings.isOdd : winding != 0;
  }

  /// The shortest distance from ([px], [py]) to the outline of [cmds].
  static double distanceToOutline(List<PathCmd> cmds, double px, double py) {
    var best = double.infinity;
    for (final (pts, closed) in flatten(cmds)) {
      final n = pts.length ~/ 2;
      final segs = closed ? n : n - 1;
      for (var i = 0; i < segs; i++) {
        final j = (i + 1) % n;
        best = math.min(
          best,
          _segDist(
            px,
            py,
            pts[2 * i],
            pts[2 * i + 1],
            pts[2 * j],
            pts[2 * j + 1],
          ),
        );
      }
    }
    return best;
  }

  static double _segDist(
    double px,
    double py,
    double ax,
    double ay,
    double bx,
    double by,
  ) {
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx - px, cy = ay + t * dy - py;
    return math.sqrt(cx * cx + cy * cy);
  }
}
