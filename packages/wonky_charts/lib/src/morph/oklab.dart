import 'dart:math' as math;

/// Color interpolation in OKLab (Slides 08 §9.4: chart morphs blend colors perceptually; the
/// same space as the code token morphs of `wonky_code`).
abstract final class OkLab {
  /// [a] → [b] (ARGB) at [t] (0..1); alpha is interpolated linearly.
  static int lerp(int a, int b, double t) {
    if (a == b || t <= 0) return a;
    if (t >= 1) return b;
    final la = _toLab(a), lb = _toLab(b);
    final l = la.$1 + (lb.$1 - la.$1) * t;
    final m = la.$2 + (lb.$2 - la.$2) * t;
    final s = la.$3 + (lb.$3 - la.$3) * t;
    final alpha = ((a >>> 24) + (((b >>> 24) - (a >>> 24)) * t)).round();
    return (alpha.clamp(0, 255) << 24) | _fromLab(l, m, s);
  }

  static double _lin(int c) {
    final v = c / 255.0;
    return v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  static int _gamma(double v) {
    final c = v <= 0.0031308
        ? 12.92 * v
        : 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;
    return (c * 255).round().clamp(0, 255);
  }

  static double _cbrt(double v) =>
      v < 0 ? -math.pow(-v, 1 / 3).toDouble() : math.pow(v, 1 / 3).toDouble();

  static (double, double, double) _toLab(int argb) {
    final r = _lin((argb >> 16) & 0xFF);
    final g = _lin((argb >> 8) & 0xFF);
    final b = _lin(argb & 0xFF);
    final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return (
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    );
  }

  static int _fromLab(double lL, double a, double b) {
    final l = math.pow(lL + 0.3963377774 * a + 0.2158037573 * b, 3).toDouble();
    final m = math.pow(lL - 0.1055613458 * a - 0.0638541728 * b, 3).toDouble();
    final s = math.pow(lL - 0.0894841775 * a - 1.2914855480 * b, 3).toDouble();
    final r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
    final g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
    final bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;
    return (_gamma(r) << 16) | (_gamma(g) << 8) | _gamma(bl);
  }
}
