import 'dart:math' as math;

/// A point in scene coordinates (logical px, origin top-left, y down).
final class ChartPoint {
  /// Creates a point.
  const ChartPoint(this.x, this.y);

  /// The origin.
  static const zero = ChartPoint(0, 0);

  final double x;
  final double y;

  /// Euclidean distance to [o].
  double distanceTo(ChartPoint o) {
    final dx = o.x - x;
    final dy = o.y - y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Translated copy.
  ChartPoint translate(double dx, double dy) => ChartPoint(x + dx, y + dy);

  @override
  bool operator ==(Object other) =>
      other is ChartPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'ChartPoint($x, $y)';
}

/// An axis-aligned rectangle in scene coordinates.
final class ChartRect {
  /// Creates a rectangle from its top-left corner and size.
  const ChartRect(this.left, this.top, this.width, this.height);

  /// Creates a rectangle from its edges (normalized so width/height ≥ 0).
  factory ChartRect.fromLTRB(double l, double t, double r, double b) =>
      ChartRect(math.min(l, r), math.min(t, b), (r - l).abs(), (b - t).abs());

  /// The empty rectangle at the origin.
  static const zero = ChartRect(0, 0, 0, 0);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
  ChartPoint get center => ChartPoint(centerX, centerY);

  /// Whether the rectangle has no area.
  bool get isEmpty => width <= 0 || height <= 0;

  /// Whether ([x], [y]) lies inside (edges inclusive).
  bool contains(double x, double y) =>
      x >= left && x <= right && y >= top && y <= bottom;

  /// Grown by [d] on every side (shrunk for negative [d], never below zero size).
  ChartRect inflate(double d) {
    final w = math.max(0.0, width + 2 * d);
    final h = math.max(0.0, height + 2 * d);
    return ChartRect(centerX - w / 2, centerY - h / 2, w, h);
  }

  /// Shrunk by the given insets.
  ChartRect deflate({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) => ChartRect(
    this.left + left,
    this.top + top,
    math.max(0.0, width - left - right),
    math.max(0.0, height - top - bottom),
  );

  /// Translated copy.
  ChartRect translate(double dx, double dy) =>
      ChartRect(left + dx, top + dy, width, height);

  /// Whether the rectangles overlap (touching edges do not count).
  bool overlaps(ChartRect o) =>
      o.left < right && o.right > left && o.top < bottom && o.bottom > top;

  /// The intersection or null.
  ChartRect? intersect(ChartRect o) {
    final l = math.max(left, o.left);
    final t = math.max(top, o.top);
    final r = math.min(right, o.right);
    final b = math.min(bottom, o.bottom);
    if (r < l || b < t) return null;
    return ChartRect(l, t, r - l, b - t);
  }

  /// Distance from ([x], [y]) to the rectangle (0 inside).
  double distanceTo(double x, double y) {
    final dx = x < left ? left - x : (x > right ? x - right : 0.0);
    final dy = y < top ? top - y : (y > bottom ? y - bottom : 0.0);
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool operator ==(Object other) =>
      other is ChartRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'ChartRect($left, $top, $width × $height)';
}

/// A width/height pair in logical px.
final class ChartSize {
  /// Creates a size.
  const ChartSize(this.width, this.height);

  final double width;
  final double height;

  @override
  bool operator ==(Object other) =>
      other is ChartSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'ChartSize($width × $height)';
}
