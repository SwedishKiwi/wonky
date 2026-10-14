import 'dart:math' as math;

/// An immutable 3D vector (world units of a 3D chart scene; right-handed, y up, +z toward the
/// default viewer).
final class Vec3 {
  /// Creates a vector.
  const Vec3(this.x, this.y, this.z);

  static const Vec3 zero = Vec3(0, 0, 0);
  static const Vec3 unitX = Vec3(1, 0, 0);
  static const Vec3 unitY = Vec3(0, 1, 0);
  static const Vec3 unitZ = Vec3(0, 0, 1);

  final double x;
  final double y;
  final double z;

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
  Vec3 operator -() => Vec3(-x, -y, -z);

  /// Dot product.
  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  /// Cross product (right-handed).
  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  /// Length.
  double get length => math.sqrt(x * x + y * y + z * z);

  /// Unit vector (zero stays zero).
  Vec3 get normalized {
    final l = length;
    return l == 0 ? this : Vec3(x / l, y / l, z / l);
  }

  /// Linear interpolation (t = 0 → this).
  Vec3 lerp(Vec3 o, double t) =>
      Vec3(x + (o.x - x) * t, y + (o.y - y) * t, z + (o.z - z) * t);

  @override
  bool operator ==(Object other) =>
      other is Vec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() =>
      'Vec3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// An axis-aligned box.
final class Aabb3 {
  /// Creates a box from its corners.
  const Aabb3(this.min, this.max);

  /// The bounds of [points] (zero box when empty).
  factory Aabb3.of(Iterable<Vec3> points) {
    var x0 = double.infinity, y0 = double.infinity, z0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity, z1 = -double.infinity;
    for (final p in points) {
      x0 = math.min(x0, p.x);
      y0 = math.min(y0, p.y);
      z0 = math.min(z0, p.z);
      x1 = math.max(x1, p.x);
      y1 = math.max(y1, p.y);
      z1 = math.max(z1, p.z);
    }
    if (x0 > x1) return const Aabb3(Vec3.zero, Vec3.zero);
    return Aabb3(Vec3(x0, y0, z0), Vec3(x1, y1, z1));
  }

  final Vec3 min;
  final Vec3 max;

  Vec3 get center => (min + max) * 0.5;

  /// The 8 corners.
  List<Vec3> get corners => [
    for (final x in [min.x, max.x])
      for (final y in [min.y, max.y])
        for (final z in [min.z, max.z]) Vec3(x, y, z),
  ];

  /// Radius of the bounding sphere around [center].
  double get radius => (max - min).length / 2;
}
