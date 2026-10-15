import 'dart:math' as math;
import 'dart:typed_data';

/// One path command of an [SPath] (scene coordinates).
sealed class PathCmd {
  const PathCmd();

  /// Stable JSON form (`["M", x, y]`, `["L", x, y]`, `["C", x1, y1, x2, y2, x, y]`, `["Z"]`).
  List<Object> toJson(num Function(double) n);
}

/// Starts a new sub-path at ([x], [y]).
final class PMoveTo extends PathCmd {
  /// Creates the command.
  const PMoveTo(this.x, this.y);
  final double x;
  final double y;

  @override
  List<Object> toJson(num Function(double) n) => ['M', n(x), n(y)];

  @override
  bool operator ==(Object other) =>
      other is PMoveTo && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash('M', x, y);
}

/// Straight line to ([x], [y]).
final class PLineTo extends PathCmd {
  /// Creates the command.
  const PLineTo(this.x, this.y);
  final double x;
  final double y;

  @override
  List<Object> toJson(num Function(double) n) => ['L', n(x), n(y)];

  @override
  bool operator ==(Object other) =>
      other is PLineTo && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash('L', x, y);
}

/// Cubic Bézier to ([x], [y]) with control points 1 and 2.
final class PCubicTo extends PathCmd {
  /// Creates the command.
  const PCubicTo(this.x1, this.y1, this.x2, this.y2, this.x, this.y);
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double x;
  final double y;

  @override
  List<Object> toJson(num Function(double) n) => [
    'C',
    n(x1),
    n(y1),
    n(x2),
    n(y2),
    n(x),
    n(y),
  ];

  @override
  bool operator ==(Object other) =>
      other is PCubicTo &&
      other.x1 == x1 &&
      other.y1 == y1 &&
      other.x2 == x2 &&
      other.y2 == y2 &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash('C', x1, y1, x2, y2, x, y);
}

/// Closes the current sub-path.
final class PClose extends PathCmd {
  /// The command.
  const PClose();

  @override
  List<Object> toJson(num Function(double) n) => const ['Z'];

  @override
  bool operator ==(Object other) => other is PClose;

  @override
  int get hashCode => 'Z'.hashCode;
}

/// Builds a list of [PathCmd]s.
final class PathBuilder {
  final List<PathCmd> _cmds = [];
  double _x = 0;
  double _y = 0;
  bool _open = false;

  /// The commands so far.
  List<PathCmd> get commands => List.unmodifiable(_cmds);

  /// Whether nothing was added.
  bool get isEmpty => _cmds.isEmpty;

  /// Starts a sub-path.
  void moveTo(double x, double y) {
    _cmds.add(PMoveTo(x, y));
    _x = x;
    _y = y;
    _open = true;
  }

  /// Adds a line (starts a sub-path when none is open).
  void lineTo(double x, double y) {
    if (!_open) {
      moveTo(x, y);
      return;
    }
    _cmds.add(PLineTo(x, y));
    _x = x;
    _y = y;
  }

  /// Adds a cubic Bézier.
  void cubicTo(double x1, double y1, double x2, double y2, double x, double y) {
    if (!_open) moveTo(_x, _y);
    _cmds.add(PCubicTo(x1, y1, x2, y2, x, y));
    _x = x;
    _y = y;
  }

  /// Closes the current sub-path.
  void close() {
    if (!_open) return;
    _cmds.add(const PClose());
    _open = false;
  }

  /// Adds a circular arc around ([cx], [cy]) from angle [start] sweeping [sweep] radians
  /// (clockwise on screen for positive sweeps, 0 = 3 o'clock). Connects with a line from the
  /// current point when a sub-path is open, else starts a new one.
  void arc(double cx, double cy, double r, double start, double sweep) {
    final sx = cx + r * math.cos(start);
    final sy = cy + r * math.sin(start);
    if (_open) {
      lineTo(sx, sy);
    } else {
      moveTo(sx, sy);
    }
    if (sweep == 0 || r <= 0) return;
    final segments = (sweep.abs() / (math.pi / 2)).ceil().clamp(1, 16);
    final step = sweep / segments;
    final k = 4 / 3 * math.tan(step / 4);
    var a = start;
    for (var i = 0; i < segments; i++) {
      final b = a + step;
      final ca = math.cos(a), sa = math.sin(a);
      final cb = math.cos(b), sb = math.sin(b);
      cubicTo(
        cx + r * (ca - k * sa),
        cy + r * (sa + k * ca),
        cx + r * (cb + k * sb),
        cy + r * (sb - k * cb),
        cx + r * cb,
        cy + r * sb,
      );
      a = b;
    }
  }

  /// Adds a closed polygon through [xy] (`x0, y0, x1, y1, …`).
  void polygon(List<double> xy) {
    if (xy.length < 4) return;
    moveTo(xy[0], xy[1]);
    for (var i = 2; i + 1 < xy.length; i += 2) {
      lineTo(xy[i], xy[i + 1]);
    }
    close();
  }

  /// Adds a closed rectangle.
  void rect(double l, double t, double w, double h) =>
      polygon([l, t, l + w, t, l + w, t + h, l, t + h]);
}

/// Path utilities shared by renderers and hit-testing.
abstract final class PathGeometry {
  /// Flattens [cmds] into polylines (one per sub-path, `x, y` pairs) with curves subdivided so
  /// the chord error stays below [tolerance] px. The bool marks closed sub-paths.
  static List<(Float64List, bool)> flatten(
    List<PathCmd> cmds, {
    double tolerance = 0.25,
  }) {
    final out = <(Float64List, bool)>[];
    var cur = <double>[];
    var cx = 0.0, cy = 0.0;
    var sx = 0.0, sy = 0.0;
    void flush(bool closed) {
      if (cur.length >= 4 || (cur.length >= 2 && closed)) {
        out.add((Float64List.fromList(cur), closed));
      }
      cur = <double>[];
    }

    for (final c in cmds) {
      switch (c) {
        case PMoveTo(:final x, :final y):
          flush(false);
          cur
            ..add(x)
            ..add(y);
          cx = sx = x;
          cy = sy = y;
        case PLineTo(:final x, :final y):
          if (cur.isEmpty) {
            cur
              ..add(cx)
              ..add(cy);
          }
          cur
            ..add(x)
            ..add(y);
          cx = x;
          cy = y;
        case PCubicTo(
          :final x1,
          :final y1,
          :final x2,
          :final y2,
          :final x,
          :final y,
        ):
          if (cur.isEmpty) {
            cur
              ..add(cx)
              ..add(cy);
          }
          final len =
              _dist(cx, cy, x1, y1) +
              _dist(x1, y1, x2, y2) +
              _dist(x2, y2, x, y);
          final dd = len.isFinite ? math.max(len, 1e-9) : 1e-9;
          final n = math
              .sqrt(dd / math.max(tolerance, 1e-3))
              .ceil()
              .clamp(1, 256);
          for (var i = 1; i <= n; i++) {
            final t = i / n;
            final mt = 1 - t;
            final a = mt * mt * mt,
                b = 3 * mt * mt * t,
                cc = 3 * mt * t * t,
                d = t * t * t;
            cur
              ..add(a * cx + b * x1 + cc * x2 + d * x)
              ..add(a * cy + b * y1 + cc * y2 + d * y);
          }
          cx = x;
          cy = y;
        case PClose():
          flush(true);
          cx = sx;
          cy = sy;
      }
    }
    flush(false);
    return out;
  }

  static double _dist(double ax, double ay, double bx, double by) {
    final dx = bx - ax, dy = by - ay;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Non-zero winding test of ([x], [y]) against flattened sub-paths (all treated as closed).
  static bool containsPoint(
    List<(Float64List, bool)> polys,
    double x,
    double y,
  ) {
    var winding = 0;
    for (final (p, _) in polys) {
      final n = p.length ~/ 2;
      for (var i = 0; i < n; i++) {
        final x0 = p[2 * i], y0 = p[2 * i + 1];
        final j = (i + 1) % n;
        final x1 = p[2 * j], y1 = p[2 * j + 1];
        if (y0 <= y) {
          if (y1 > y && _cross(x0, y0, x1, y1, x, y) > 0) winding++;
        } else if (y1 <= y && _cross(x0, y0, x1, y1, x, y) < 0) {
          winding--;
        }
      }
    }
    return winding != 0;
  }

  static double _cross(
    double x0,
    double y0,
    double x1,
    double y1,
    double x,
    double y,
  ) => (x1 - x0) * (y - y0) - (x - x0) * (y1 - y0);

  /// Distance from ([px], [py]) to the segment (a, b).
  static double segmentDistance(
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
    final qx = ax + t * dx - px, qy = ay + t * dy - py;
    return math.sqrt(qx * qx + qy * qy);
  }
}
