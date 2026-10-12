import 'dart:math' as math;
import 'dart:typed_data';

import '../../scene/scene.dart';
import '../render_geometry.dart';
import 'rasterizer.dart';

/// Converts strokes (device px) into positively oriented polygons on a [CoverageRasterizer]:
/// one quad per segment plus join and cap polygons. Filled with the non-zero rule, the parts
/// union without double blending.
final class Stroker {
  /// Creates a stroker feeding [raster].
  Stroker(this.raster);

  /// The rasterizer receiving the polygons.
  final CoverageRasterizer raster;

  final List<double> _poly = [];

  /// Adds the stroke of the polyline [pts] (`x, y` pairs; non-finite points split it) with
  /// half width [hw]. [dash] (device px, even length) splits it into dashes first.
  void addPolyline(
    Float64List pts,
    bool closed,
    double hw,
    SStrokeCap cap,
    SStrokeJoin join, {
    List<double>? dash,
  }) {
    var start = 0;
    final n = pts.length ~/ 2;
    for (var i = 0; i <= n; i++) {
      final end = i == n || !pts[2 * i].isFinite || !pts[2 * i + 1].isFinite;
      if (!end) continue;
      if (i > start) {
        final piece = Float64List.sublistView(pts, 2 * start, 2 * i);
        final isClosed = closed && start == 0 && i == n;
        if (dash == null) {
          _stroke(piece, isClosed, hw, cap, join);
        } else {
          for (final d in _dashes(piece, isClosed, dash)) {
            _stroke(d, false, hw, cap, join);
          }
        }
      }
      start = i + 1;
    }
  }

  /// Splits a polyline into dash pieces following [dash] (on, off, …).
  static List<Float64List> _dashes(Float64List pts, bool closed, List<double> dash) {
    final n = pts.length ~/ 2;
    var total = 0.0;
    final segs = closed ? n : n - 1;
    for (var i = 0; i < segs; i++) {
      final j = (i + 1) % n;
      total += _len(pts[2 * i], pts[2 * i + 1], pts[2 * j], pts[2 * j + 1]);
    }
    var period = 0.0;
    for (final d in dash) {
      period += d;
    }
    // Patterns too fine to resolve (or absurd dash counts) are drawn solid.
    if (period < 0.5 || total / period > 500000) return [pts];
    final out = <Float64List>[];
    var di = 0;
    var left = dash[0];
    var on = true;
    var cur = <double>[pts[0], pts[1]];
    for (var i = 0; i < segs; i++) {
      final j = (i + 1) % n;
      var x0 = pts[2 * i], y0 = pts[2 * i + 1];
      final x1 = pts[2 * j], y1 = pts[2 * j + 1];
      var segLen = _len(x0, y0, x1, y1);
      while (segLen > 0) {
        if (left >= segLen) {
          left -= segLen;
          if (on) {
            cur
              ..add(x1)
              ..add(y1);
          }
          segLen = 0;
        } else {
          final t = left / segLen;
          final mx = x0 + (x1 - x0) * t, my = y0 + (y1 - y0) * t;
          if (on) {
            cur
              ..add(mx)
              ..add(my);
            if (cur.length >= 4) out.add(Float64List.fromList(cur));
            cur = [];
          } else {
            cur = [mx, my];
          }
          on = !on;
          segLen -= left;
          x0 = mx;
          y0 = my;
          di = (di + 1) % dash.length;
          left = dash[di];
        }
      }
    }
    if (on && cur.length >= 4) out.add(Float64List.fromList(cur));
    return out;
  }

  static double _len(double x0, double y0, double x1, double y1) {
    final dx = x1 - x0, dy = y1 - y0;
    return math.sqrt(dx * dx + dy * dy);
  }

  void _stroke(Float64List raw, bool closed, double hw, SStrokeCap cap, SStrokeJoin join) {
    // Drop repeated points.
    final pts = <double>[];
    for (var i = 0; i + 1 < raw.length; i += 2) {
      final x = raw[i], y = raw[i + 1];
      if (pts.isNotEmpty) {
        final dx = x - pts[pts.length - 2], dy = y - pts[pts.length - 1];
        if (dx * dx + dy * dy < 1e-12) continue;
      }
      pts
        ..add(x)
        ..add(y);
    }
    var n = pts.length ~/ 2;
    if (closed && n > 1) {
      final dx = pts[0] - pts[2 * n - 2], dy = pts[1] - pts[2 * n - 1];
      if (dx * dx + dy * dy < 1e-12) {
        pts.length -= 2;
        n--;
      }
    }
    if (n == 0) return;
    if (n == 1) {
      final x = pts[0], y = pts[1];
      if (cap == SStrokeCap.round) {
        _circle(x, y, hw);
      } else if (cap == SStrokeCap.square) {
        raster.addPolygon([x - hw, y - hw, x + hw, y - hw, x + hw, y + hw, x - hw, y + hw]);
      }
      return;
    }
    if (n == 2) closed = false;
    final segs = closed ? n : n - 1;
    // Unit directions per segment.
    final ux = Float64List(segs), uy = Float64List(segs);
    for (var i = 0; i < segs; i++) {
      final j = (i + 1) % n;
      final dx = pts[2 * j] - pts[2 * i], dy = pts[2 * j + 1] - pts[2 * i + 1];
      final l = math.sqrt(dx * dx + dy * dy);
      ux[i] = dx / l;
      uy[i] = dy / l;
    }
    for (var i = 0; i < segs; i++) {
      final j = (i + 1) % n;
      final nx = -uy[i] * hw, ny = ux[i] * hw;
      final x0 = pts[2 * i], y0 = pts[2 * i + 1], x1 = pts[2 * j], y1 = pts[2 * j + 1];
      raster.addPolygon([
        x0 + nx,
        y0 + ny,
        x1 + nx,
        y1 + ny,
        x1 - nx,
        y1 - ny,
        x0 - nx,
        y0 - ny,
      ], positive: true);
    }
    // Joins.
    final firstJoin = closed ? 0 : 1;
    final lastJoin = closed ? n - 1 : n - 2;
    for (var v = firstJoin; v <= lastJoin; v++) {
      final a = (v - 1 + segs) % segs, b = v % segs;
      _join(pts[2 * v], pts[2 * v + 1], ux[a], uy[a], ux[b], uy[b], hw, join);
    }
    // Caps.
    if (!closed && cap != SStrokeCap.butt) {
      final last = segs - 1;
      if (cap == SStrokeCap.round) {
        _circle(pts[0], pts[1], hw);
        _circle(pts[2 * n - 2], pts[2 * n - 1], hw);
      } else {
        _squareCap(pts[0], pts[1], -ux[0], -uy[0], hw);
        _squareCap(pts[2 * n - 2], pts[2 * n - 1], ux[last], uy[last], hw);
      }
    }
  }

  void _squareCap(double x, double y, double dx, double dy, double hw) {
    final nx = -dy * hw, ny = dx * hw;
    final ex = dx * hw, ey = dy * hw;
    raster.addPolygon([
      x + nx,
      y + ny,
      x + nx + ex,
      y + ny + ey,
      x - nx + ex,
      y - ny + ey,
      x - nx,
      y - ny,
    ], positive: true);
  }

  void _join(
    double x,
    double y,
    double ax,
    double ay,
    double bx,
    double by,
    double hw,
    SStrokeJoin join,
  ) {
    final cross = ax * by - ay * bx;
    final dot = ax * bx + ay * by;
    if (cross.abs() < 1e-9 && dot > 0) return; // collinear: segments already meet.
    if (join == SStrokeJoin.round) {
      _circle(x, y, hw);
      return;
    }
    if (cross.abs() < 1e-9) return; // full reversal: nothing to bevel or miter.
    final s = cross > 0 ? -1.0 : 1.0; // outer side
    final n0x = -ay * s, n0y = ax * s;
    final n1x = -by * s, n1y = bx * s;
    final p0x = x + n0x * hw, p0y = y + n0y * hw;
    final p1x = x + n1x * hw, p1y = y + n1y * hw;
    if (join == SStrokeJoin.miter) {
      final mx = n0x + n1x, my = n0y + n1y;
      final m2 = mx * mx + my * my;
      if (m2 > 1e-12 && 2 / math.sqrt(m2) <= RenderGeometry.miterLimit) {
        final k = 2 * hw / m2;
        raster.addPolygon([x, y, p0x, p0y, x + mx * k, y + my * k, p1x, p1y], positive: true);
        return;
      }
    }
    raster.addPolygon([x, y, p0x, p0y, p1x, p1y], positive: true);
  }

  void _circle(double cx, double cy, double r) {
    final segs = (r * 2.5).ceil().clamp(8, 128) + 4;
    _poly.clear();
    for (var i = 0; i < segs; i++) {
      final a = i * 2 * math.pi / segs;
      _poly
        ..add(cx + r * math.cos(a))
        ..add(cy + r * math.sin(a));
    }
    raster.addPolygon(_poly, positive: true);
  }
}
