import 'dart:math' as math;

import '../scene/geometry.dart';
import '../scene/path.dart';
import '../scene/scene.dart';

/// Geometry shared by the chart renderers (SVG, PDF, raster), so every output draws markers,
/// rounded rectangles and dashes the same way.
abstract final class RenderGeometry {
  /// Ratio of the inner to the outer radius of [MarkerShape.star].
  static const double starInnerRatio = 0.45;

  /// Miter limit (ratio of miter length to stroke width) used by all renderers; matches the
  /// SVG and Flutter default.
  static const double miterLimit = 4;

  /// Outline of a marker of [shape] centered at ([cx], [cy]) with diameter [size].
  ///
  /// Circles are two half-circle arcs; the triangle is equilateral with side [size] pointing
  /// up; polygon (a pentagon) and star (five points) are inscribed in the marker circle with a
  /// vertex on top; the square and the diamond fill the marker's bounding square.
  static List<PathCmd> markerPath(MarkerShape shape, double cx, double cy, double size) {
    final r = size / 2;
    final b = PathBuilder();
    switch (shape) {
      case MarkerShape.circle:
        b
          ..arc(cx, cy, r, 0, math.pi)
          ..arc(cx, cy, r, math.pi, math.pi)
          ..close();
      case MarkerShape.square:
        b.rect(cx - r, cy - r, size, size);
      case MarkerShape.diamond:
        b.polygon([cx, cy - r, cx + r, cy, cx, cy + r, cx - r, cy]);
      case MarkerShape.triangle:
        // Equilateral, side = size, centered on its bounding box.
        final h = size * math.sqrt(3) / 2;
        b.polygon([cx, cy - h / 2, cx + r, cy + h / 2, cx - r, cy + h / 2]);
      case MarkerShape.polygon:
        b.polygon(_regular(cx, cy, r, 5));
      case MarkerShape.star:
        final xy = <double>[];
        for (var i = 0; i < 10; i++) {
          final rr = i.isEven ? r : r * starInnerRatio;
          final a = -math.pi / 2 + i * math.pi / 5;
          xy
            ..add(cx + rr * math.cos(a))
            ..add(cy + rr * math.sin(a));
        }
        b.polygon(xy);
    }
    return b.commands;
  }

  static List<double> _regular(double cx, double cy, double r, int n) => [
    for (var i = 0; i < n; i++) ...[
      cx + r * math.cos(-math.pi / 2 + i * 2 * math.pi / n),
      cy + r * math.sin(-math.pi / 2 + i * 2 * math.pi / n),
    ],
  ];

  /// The corner radius actually drawn for [rect] (clamped to half the shorter side).
  static double clampRadius(ChartRect rect, double radius) {
    if (!(radius > 0)) return 0;
    return math.min(radius, math.min(rect.width.abs(), rect.height.abs()) / 2);
  }

  /// [rect] normalized to non-negative width and height.
  static ChartRect normalize(ChartRect rect) => rect.width >= 0 && rect.height >= 0
      ? rect
      : ChartRect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom);

  /// Outline of [rect] with corner [radius] (a plain rectangle when the radius is 0).
  static List<PathCmd> roundedRect(ChartRect rect, double radius) {
    final rc = normalize(rect);
    final rr = clampRadius(rc, radius);
    final b = PathBuilder();
    if (rr <= 0) {
      b.rect(rc.left, rc.top, rc.width, rc.height);
      return b.commands;
    }
    final l = rc.left, t = rc.top, r = rc.right, btm = rc.bottom;
    b
      ..moveTo(l + rr, t)
      ..lineTo(r - rr, t)
      ..arc(r - rr, t + rr, rr, -math.pi / 2, math.pi / 2)
      ..arc(r - rr, btm - rr, rr, 0, math.pi / 2)
      ..arc(l + rr, btm - rr, rr, math.pi / 2, math.pi / 2)
      ..arc(l + rr, t + rr, rr, math.pi, math.pi / 2)
      ..close();
    return b.commands;
  }

  /// The dash pattern to draw for [dash], or null for a solid stroke: null, empty, negative,
  /// non-finite or all-zero patterns are solid; odd-length patterns are repeated once (as SVG
  /// and PDF do) so the result always alternates on/off.
  static List<double>? effectiveDash(List<double>? dash) {
    if (dash == null || dash.isEmpty) return null;
    var sum = 0.0;
    for (final d in dash) {
      if (!d.isFinite || d < 0) return null;
      sum += d;
    }
    if (sum <= 0) return null;
    return dash.length.isOdd ? [...dash, ...dash] : dash;
  }

  /// Whether [stroke] paints anything.
  static bool strokeVisible(SStroke? stroke) =>
      stroke != null && stroke.width > 0 && stroke.width.isFinite && Argb.alpha(stroke.color) > 0;

  /// Whether the ARGB [fill] paints anything.
  static bool fillVisible(int? fill) => fill != null && Argb.alpha(fill) > 0;
}
