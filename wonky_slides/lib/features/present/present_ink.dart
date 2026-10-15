import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

/// A present tool (Slides 10 §2.1, §4): the arrow (navigation clicks), the
/// laser pointer, pen, highlighter and eraser.
enum PresentTool {
  arrow,
  laser,
  pen,
  highlighter,
  eraser;

  static PresentTool? fromName(Object? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }

  bool get draws => this == pen || this == highlighter;
}

/// The ink colors (§4.3: red, blue, green, amber, white, black).
abstract final class InkColors {
  static const Map<String, int> all = {
    'red': 0xffef4444,
    'blue': 0xff3b82f6,
    'green': 0xff22c55e,
    'amber': 0xfff59e0b,
    'white': 0xffffffff,
    'black': 0xff111111,
  };

  /// Pen widths in slide units (§4.3: thin, medium, thick).
  static const Map<String, double> penWidths = {
    'thin': 4,
    'medium': 8,
    'thick': 14,
  };

  /// The highlighter's width (su) and opacity (§4.3).
  static const highlighterWidth = 28.0;
  static const highlighterOpacity = 0.4;
}

/// One ephemeral ink stroke in slide units (§4.3).
class InkStroke {
  InkStroke({
    required this.id,
    required this.tool,
    required this.color,
    required this.width,
    required List<Offset> points,
  }) : points = List.unmodifiable(points);

  final String id;

  /// [PresentTool.pen] or [PresentTool.highlighter].
  final PresentTool tool;

  /// ARGB.
  final int color;

  /// su.
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

  /// The session wire format (points quantized to 0.5 su, §6.2).
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
      final tool = PresentTool.fromName(j['tool']);
      final raw = j['points'];
      final id = j['id'];
      final color = j['color'];
      final width = j['width'];
      if (tool == null || !tool.draws || raw is! List || id is! String) {
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

  /// Whether a circle at [p] with [radius] (su) touches the stroke.
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

  /// A smooth path through the points (Catmull-Rom → cubic Béziers, §4.3).
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

/// A one-euro filter for pointer input (§4.3): smooths jitter at low
/// speeds and keeps up at high speeds.
class OneEuroFilter {
  OneEuroFilter({this.minCutoff = 1.0, this.beta = 0.02, this.dCutoff = 1.0});

  final double minCutoff;
  final double beta;
  final double dCutoff;

  Offset? _x;
  Offset _dx = Offset.zero;
  int? _t;

  static double _alpha(double cutoff, double dt) {
    final tau = 1 / (2 * math.pi * cutoff);
    return 1 / (1 + tau / dt);
  }

  /// Filters [p] sampled at [ms].
  Offset filter(Offset p, int ms) {
    final x = _x;
    final t = _t;
    if (x == null || t == null) {
      _x = p;
      _t = ms;
      return p;
    }
    final dt = math.max(1, ms - t) / 1000.0;
    final dx = (p - x) / dt;
    final ad = _alpha(dCutoff, dt);
    _dx = _dx + (dx - _dx) * ad;
    final cutoff = minCutoff + beta * _dx.distance;
    final a = _alpha(cutoff, dt);
    final out = x + (p - x) * a;
    _x = out;
    _t = ms;
    return out;
  }
}

/// The ink of a presentation (§4.3): strokes per slide, in memory only —
/// kept while navigating, discarded when presenting ends. [undo] removes
/// the last stroke of a slide (a local stack, not the document undo).
class InkModel {
  final Map<String, List<InkStroke>> _bySlide = {};

  List<InkStroke> strokesOf(String slideId) =>
      List.unmodifiable(_bySlide[slideId] ?? const <InkStroke>[]);

  bool hasInk(String slideId) => _bySlide[slideId]?.isNotEmpty ?? false;

  /// Adds or replaces (same id) a stroke.
  void put(String slideId, InkStroke stroke) {
    final list = _bySlide.putIfAbsent(slideId, () => []);
    final i = list.indexWhere((s) => s.id == stroke.id);
    if (i >= 0) {
      list[i] = stroke;
    } else {
      list.add(stroke);
    }
  }

  bool remove(String slideId, String strokeId) {
    final list = _bySlide[slideId];
    if (list == null) return false;
    final before = list.length;
    list.removeWhere((s) => s.id == strokeId);
    return list.length != before;
  }

  /// Removes every stroke [p] touches; returns their ids.
  List<String> eraseAt(String slideId, Offset p, double radius) {
    final list = _bySlide[slideId];
    if (list == null) return const [];
    final hit = [
      for (final s in list)
        if (s.touches(p, radius)) s.id,
    ];
    list.removeWhere((s) => hit.contains(s.id));
    return hit;
  }

  /// Removes the last stroke of [slideId]; returns its id.
  String? undo(String slideId) {
    final list = _bySlide[slideId];
    if (list == null || list.isEmpty) return null;
    return list.removeLast().id;
  }

  void clear(String slideId) => _bySlide.remove(slideId);

  void clearAll() => _bySlide.clear();
}
