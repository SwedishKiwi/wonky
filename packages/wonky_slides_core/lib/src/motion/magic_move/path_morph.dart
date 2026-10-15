/// Shape outline morphs of Magic Move (06 §8.4 "Shape geometry"): both
/// outlines are flattened, resampled to [PathMorph.samples] points by arc
/// length (in box-relative coordinates), the start index of closed outlines
/// is aligned by the minimal squared distance (orientation matched first),
/// and the points are lerped. Multi-subpath shapes (donut, frame) don't
/// morph: they crossfade (null plan).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:wonky_charts/wonky_charts.dart'
    show PathCmd, PMoveTo, PLineTo, PClose;

import '../../geometry/path_ops.dart';
import '../../scene/nodes/scene_nodes.dart' show ScenePath;

double _r(double v) => (v * 1e6).roundToDouble() / 1e6;

/// A precomputed outline morph between two shapes.
final class PathMorph {
  PathMorph._(this.from, this.to, this.closed);

  /// Points per outline (06 §8.4).
  static const samples = 128;

  /// Box-relative points (`x0, y0, x1, y1, …`, 0..1 of the box) of the
  /// outgoing outline, aligned with [to].
  final Float64List from;

  /// Box-relative points of the incoming outline.
  final Float64List to;

  /// Whether the outlines are closed.
  final bool closed;

  /// Plans the morph from [a] (in a [wa] × [ha] box) to [b] (in a [wb] ×
  /// [hb] box); null when either path is empty or has several sub-paths,
  /// or one is open and the other closed (crossfade).
  static PathMorph? build(
    ScenePath a,
    double wa,
    double ha,
    ScenePath b,
    double wb,
    double hb,
  ) {
    final fa = PathOps.flatten(a.commands);
    final fb = PathOps.flatten(b.commands);
    if (fa.length != 1 || fb.length != 1) return null;
    final (pa, ca) = fa.single;
    final (pb, cb) = fb.single;
    if (ca != cb) return null;
    final ra = _resample(pa, ca, wa, ha);
    final rb = _resample(pb, cb, wb, hb);
    if (ra == null || rb == null) return null;
    final aligned = ca ? _alignClosed(ra, rb) : _alignOpen(ra, rb);
    return PathMorph._(ra, aligned, ca);
  }

  /// Element-local points at [t] for a [width] × [height] box.
  Float64List pointsAt(double t, double width, double height) {
    final out = Float64List(samples * 2);
    for (var i = 0; i < samples; i++) {
      final x = from[2 * i] + (to[2 * i] - from[2 * i]) * t;
      final y = from[2 * i + 1] + (to[2 * i + 1] - from[2 * i + 1]) * t;
      out[2 * i] = x * width;
      out[2 * i + 1] = y * height;
    }
    return out;
  }

  /// The outline at [t] as a path in a [width] × [height] box.
  ScenePath pathAt(double t, double width, double height) {
    final p = pointsAt(t, width, height);
    final cmds = <PathCmd>[PMoveTo(p[0], p[1])];
    for (var i = 1; i < samples; i++) {
      cmds.add(PLineTo(p[2 * i], p[2 * i + 1]));
    }
    if (closed) cmds.add(const PClose());
    return ScenePath(cmds);
  }

  /// Canonical JSON (summary: endpoints of the first point).
  Map<String, Object?> toJson() => {
    'samples': samples,
    'closed': closed,
    'from0': [_r(from[0]), _r(from[1])],
    'to0': [_r(to[0]), _r(to[1])],
  };

  static Float64List? _resample(List<double> pts, bool closed, num w, num h) {
    final sx = w.abs() < 1e-9 ? 1.0 : 1 / w, sy = h.abs() < 1e-9 ? 1.0 : 1 / h;
    final n = pts.length ~/ 2;
    // Box-relative points, the closing segment appended for closed paths.
    final xs = <double>[], ys = <double>[];
    for (var i = 0; i < n; i++) {
      xs.add(pts[2 * i] * sx);
      ys.add(pts[2 * i + 1] * sy);
    }
    if (closed && (xs.first != xs.last || ys.first != ys.last)) {
      xs.add(xs.first);
      ys.add(ys.first);
    }
    final cum = List<double>.filled(xs.length, 0);
    for (var i = 1; i < xs.length; i++) {
      final dx = xs[i] - xs[i - 1], dy = ys[i] - ys[i - 1];
      cum[i] = cum[i - 1] + math.sqrt(dx * dx + dy * dy);
    }
    final total = cum.last;
    if (total <= 1e-12) return null;
    final out = Float64List(samples * 2);
    var seg = 1;
    for (var k = 0; k < samples; k++) {
      final d = closed ? total * k / samples : total * k / (samples - 1);
      while (seg < cum.length - 1 && cum[seg] < d) {
        seg++;
      }
      final l0 = cum[seg - 1], l1 = cum[seg];
      final u = l1 - l0 <= 1e-12 ? 0.0 : ((d - l0) / (l1 - l0)).clamp(0, 1);
      out[2 * k] = xs[seg - 1] + (xs[seg] - xs[seg - 1]) * u;
      out[2 * k + 1] = ys[seg - 1] + (ys[seg] - ys[seg - 1]) * u;
    }
    return out;
  }

  static double _area(Float64List p) {
    var a = 0.0;
    for (var i = 0; i < samples; i++) {
      final j = (i + 1) % samples;
      a += p[2 * i] * p[2 * j + 1] - p[2 * j] * p[2 * i + 1];
    }
    return a / 2;
  }

  static Float64List _reversed(Float64List p) {
    final out = Float64List(p.length);
    for (var i = 0; i < samples; i++) {
      out[2 * i] = p[2 * (samples - 1 - i)];
      out[2 * i + 1] = p[2 * (samples - 1 - i) + 1];
    }
    return out;
  }

  /// [b] with the orientation of [a] and the start index of minimal summed
  /// squared distance (ties: the lowest shift).
  static Float64List _alignClosed(Float64List a, Float64List b) {
    final aa = _area(a), ab = _area(b);
    final bb = (aa < 0) != (ab < 0) && aa.abs() > 1e-12 && ab.abs() > 1e-12
        ? _reversed(b)
        : b;
    var best = 0;
    var bestD = double.infinity;
    for (var s = 0; s < samples; s++) {
      var d = 0.0;
      for (var i = 0; i < samples && d < bestD; i++) {
        final j = (i + s) % samples;
        final dx = a[2 * i] - bb[2 * j], dy = a[2 * i + 1] - bb[2 * j + 1];
        d += dx * dx + dy * dy;
      }
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    final out = Float64List(samples * 2);
    for (var i = 0; i < samples; i++) {
      final j = (i + best) % samples;
      out[2 * i] = bb[2 * j];
      out[2 * i + 1] = bb[2 * j + 1];
    }
    return out;
  }

  /// [b] or its reversal, whichever is nearer to [a].
  static Float64List _alignOpen(Float64List a, Float64List b) {
    final r = _reversed(b);
    var d0 = 0.0, d1 = 0.0;
    for (var i = 0; i < samples * 2; i++) {
      d0 += (a[i] - b[i]) * (a[i] - b[i]);
      d1 += (a[i] - r[i]) * (a[i] - r[i]);
    }
    return d1 < d0 ? r : b;
  }
}
