import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

/// The drawing tool of an [InkStroke]. The names are the wire format.
enum InkTool {
  pen,

  /// Wide and translucent; multiplies on light backgrounds and screens on
  /// dark ones ([InkStrokePainter]).
  highlighter;

  static InkTool? fromName(Object? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

/// A freehand ink stroke (Slides 10 §4.3, the board's screenshot editor,
/// specs/16 §5.2), in the caller's units (Slides: slide units).
class InkStroke {
  InkStroke({
    required this.id,
    required this.tool,
    required this.color,
    required this.width,
    required List<Offset> points,
  }) : points = List.unmodifiable(points);

  final String id;

  /// Pen or highlighter.
  final InkTool tool;

  /// ARGB.
  final int color;

  /// The stroke width (Slides: su).
  final double width;
  final List<Offset> points;

  /// A copy with [point] appended.
  InkStroke extend(Offset point) => InkStroke(
    id: id,
    tool: tool,
    color: color,
    width: width,
    points: [...points, point],
  );

  /// The wire format (points quantized to 0.5 units; Slides 10 §6.2).
  Map<String, Object?> toJson() => {
    'id': id,
    'tool': tool.name,
    'color': color,
    'width': width,
    'points': [
      for (final p in points) ...[_q(p.dx), _q(p.dy)],
    ],
  };

  static num _q(double v) {
    final r = (v * 2).round() / 2;
    return r == r.roundToDouble() ? r.toInt() : r;
  }

  String encode() => jsonEncode(toJson());

  /// Parses [toJson] (null when malformed).
  static InkStroke? tryParse(String? json) {
    if (json == null) return null;
    try {
      final j = jsonDecode(json);
      if (j is! Map) return null;
      final tool = InkTool.fromName(j['tool']);
      final raw = j['points'];
      final id = j['id'];
      final color = j['color'];
      final width = j['width'];
      if (tool == null || raw is! List || id is! String) {
        return null;
      }
      if (color is! int || width is! num) return null;
      final pts = <Offset>[];
      for (var i = 0; i + 1 < raw.length; i += 2) {
        final x = raw[i], y = raw[i + 1];
        if (x is! num || y is! num) return null;
        pts.add(Offset(x.toDouble(), y.toDouble()));
      }
      return InkStroke(
        id: id,
        tool: tool,
        color: color,
        width: width.toDouble(),
        points: pts,
      );
    } on FormatException {
      return null;
    }
  }

  /// Whether a circle at [p] with [radius] touches the stroke.
  bool touches(Offset p, double radius) {
    final r = radius + width / 2;
    if (points.length == 1) return (points.single - p).distance <= r;
    for (var i = 0; i + 1 < points.length; i++) {
      if (_segmentDistance(p, points[i], points[i + 1]) <= r) return true;
    }
    return false;
  }

  static double _segmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(
      0.0,
      1.0,
    );
    return (p - (a + ab * t)).distance;
  }

  /// A smooth path through the points (Catmull-Rom → cubic Béziers, Slides 10 §4.3).
  Path path() {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) {
      path.lineTo(points.first.dx + 0.01, points.first.dy);
      return path;
    }
    for (var i = 0; i + 1 < points.length; i++) {
      final p0 = points[math.max(0, i - 1)];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = points[math.min(points.length - 1, i + 2)];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }
}
