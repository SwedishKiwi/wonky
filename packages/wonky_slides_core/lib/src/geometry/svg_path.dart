/// SVG path data → `PathCmd`s (custom shapes, 02 §6.2 `"path"`; pasted SVG
/// paths, 03 §6.3).
library;

import 'dart:math' as math;

import 'package:wonky_charts/wonky_charts.dart' show PathCmd;

import 'path_ops.dart';

/// Parses SVG path data (`M L H V C S Q T A Z`, absolute and relative).
abstract final class SvgPathParser {
  /// The commands of [d]; malformed data stops at the first error (what
  /// was parsed so far is kept), so bad input never throws.
  static List<PathCmd> parse(String d) {
    final t = _Tokens(d);
    final b = ShapePathBuilder();
    var cmd = '';
    var cx = 0.0, cy = 0.0; // current point
    var sx = 0.0, sy = 0.0; // sub-path start
    double? lastCx, lastCy; // last control point (S/T reflection)
    var lastCmd = '';
    while (true) {
      t.skipSeparators();
      if (t.atEnd) break;
      final c = t.peekCommand();
      if (c != null) {
        t.pos++;
        cmd = c;
      } else if (cmd.isEmpty) {
        break;
      } else if (cmd == 'M') {
        cmd = 'L';
      } else if (cmd == 'm') {
        cmd = 'l';
      }
      final rel = cmd == cmd.toLowerCase();
      final up = cmd.toUpperCase();
      double ox() => rel ? cx : 0;
      double oy() => rel ? cy : 0;
      try {
        switch (up) {
          case 'M':
            cx = t.number() + ox();
            cy = t.number() + oy();
            sx = cx;
            sy = cy;
            b.moveTo(cx, cy);
            lastCx = lastCy = null;
          case 'L':
            cx = t.number() + ox();
            cy = t.number() + oy();
            b.lineTo(cx, cy);
            lastCx = lastCy = null;
          case 'H':
            cx = t.number() + (rel ? cx : 0);
            b.lineTo(cx, cy);
            lastCx = lastCy = null;
          case 'V':
            cy = t.number() + (rel ? cy : 0);
            b.lineTo(cx, cy);
            lastCx = lastCy = null;
          case 'C':
            final x1 = t.number() + ox(), y1 = t.number() + oy();
            final x2 = t.number() + ox(), y2 = t.number() + oy();
            final x = t.number() + ox(), y = t.number() + oy();
            b.cubicTo(x1, y1, x2, y2, x, y);
            lastCx = x2;
            lastCy = y2;
            cx = x;
            cy = y;
          case 'S':
            final reflect = lastCmd == 'C' || lastCmd == 'S';
            final x1 = reflect && lastCx != null ? 2 * cx - lastCx : cx;
            final y1 = reflect && lastCy != null ? 2 * cy - lastCy : cy;
            final x2 = t.number() + ox(), y2 = t.number() + oy();
            final x = t.number() + ox(), y = t.number() + oy();
            b.cubicTo(x1, y1, x2, y2, x, y);
            lastCx = x2;
            lastCy = y2;
            cx = x;
            cy = y;
          case 'Q':
            final qx = t.number() + ox(), qy = t.number() + oy();
            final x = t.number() + ox(), y = t.number() + oy();
            b.quadTo(qx, qy, x, y);
            lastCx = qx;
            lastCy = qy;
            cx = x;
            cy = y;
          case 'T':
            final reflect = lastCmd == 'Q' || lastCmd == 'T';
            final qx = reflect && lastCx != null ? 2 * cx - lastCx : cx;
            final qy = reflect && lastCy != null ? 2 * cy - lastCy : cy;
            final x = t.number() + ox(), y = t.number() + oy();
            b.quadTo(qx, qy, x, y);
            lastCx = qx;
            lastCy = qy;
            cx = x;
            cy = y;
          case 'A':
            final rx = t.number().abs(), ry = t.number().abs();
            final rot = t.number();
            final large = t.flag(), sweep = t.flag();
            final x = t.number() + ox(), y = t.number() + oy();
            _arc(b, cx, cy, rx, ry, rot, large, sweep, x, y);
            cx = x;
            cy = y;
            lastCx = lastCy = null;
          case 'Z':
            b.close();
            cx = sx;
            cy = sy;
            lastCx = lastCy = null;
          default:
            return b.commands;
        }
      } on FormatException {
        return b.commands;
      }
      lastCmd = up;
    }
    return b.commands;
  }

  /// SVG endpoint arc → center parameterization → cubic segments
  /// (SVG 1.1 implementation notes F.6).
  static void _arc(
    ShapePathBuilder b,
    double x1,
    double y1,
    double rx,
    double ry,
    double rotDeg,
    bool large,
    bool sweep,
    double x2,
    double y2,
  ) {
    if (rx == 0 || ry == 0 || (x1 == x2 && y1 == y2)) {
      b.lineTo(x2, y2);
      return;
    }
    final phi = rotDeg * math.pi / 180;
    final cp = math.cos(phi), sp = math.sin(phi);
    final dx = (x1 - x2) / 2, dy = (y1 - y2) / 2;
    final x1p = cp * dx + sp * dy, y1p = -sp * dx + cp * dy;
    final lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
    if (lambda > 1) {
      final s = math.sqrt(lambda);
      rx *= s;
      ry *= s;
    }
    final num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
    final den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
    var coef = den == 0 ? 0.0 : math.sqrt(math.max(0, num / den));
    if (large == sweep) coef = -coef;
    final cxp = coef * rx * y1p / ry, cyp = -coef * ry * x1p / rx;
    final cx = cp * cxp - sp * cyp + (x1 + x2) / 2;
    final cy = sp * cxp + cp * cyp + (y1 + y2) / 2;
    double angle(double ux, double uy, double vx, double vy) {
      final a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy);
      return a;
    }

    final th1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
    var dth = angle(
      (x1p - cxp) / rx,
      (y1p - cyp) / ry,
      (-x1p - cxp) / rx,
      (-y1p - cyp) / ry,
    );
    if (!sweep && dth > 0) dth -= 2 * math.pi;
    if (sweep && dth < 0) dth += 2 * math.pi;
    final segments = (dth.abs() / (math.pi / 2)).ceil().clamp(1, 32);
    final step = dth / segments;
    final k = 4 / 3 * math.tan(step / 4);
    var a = th1;
    for (var i = 0; i < segments; i++) {
      final bAng = a + step;
      // Control points in the ellipse frame, then rotated.
      final e1x = rx * (math.cos(a) - k * math.sin(a));
      final e1y = ry * (math.sin(a) + k * math.cos(a));
      final e2x = rx * (math.cos(bAng) + k * math.sin(bAng));
      final e2y = ry * (math.sin(bAng) - k * math.cos(bAng));
      final ex = rx * math.cos(bAng), ey = ry * math.sin(bAng);
      (double, double) rot(double x, double y) =>
          (cp * x - sp * y + cx, sp * x + cp * y + cy);
      final (p1x, p1y) = rot(e1x, e1y);
      final (p2x, p2y) = rot(e2x, e2y);
      final (p3x, p3y) = rot(ex, ey);
      b.cubicTo(p1x, p1y, p2x, p2y, p3x, p3y);
      a = bAng;
    }
  }
}

final class _Tokens {
  _Tokens(this.s);

  final String s;
  int pos = 0;

  bool get atEnd => pos >= s.length;

  void skipSeparators() {
    while (pos < s.length) {
      final c = s.codeUnitAt(pos);
      if (c == 0x20 || c == 0x2c || c == 0x09 || c == 0x0a || c == 0x0d) {
        pos++;
      } else {
        break;
      }
    }
  }

  String? peekCommand() {
    final c = s[pos];
    return 'MmLlHhVvCcSsQqTtAaZz'.contains(c) ? c : null;
  }

  bool flag() {
    skipSeparators();
    if (atEnd) throw const FormatException('flag expected');
    final c = s[pos];
    if (c != '0' && c != '1') throw const FormatException('flag expected');
    pos++;
    return c == '1';
  }

  static final _num = RegExp(r'[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?');

  double number() {
    skipSeparators();
    final m = _num.matchAsPrefix(s, pos);
    if (m == null) throw const FormatException('number expected');
    pos = m.end;
    return double.parse(m.group(0)!);
  }
}
