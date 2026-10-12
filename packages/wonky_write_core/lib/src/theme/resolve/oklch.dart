/// sRGB ↔ OKLab ↔ OKLCH conversion and WCAG 2.x contrast (06 §4, §10.6).
///
/// Implemented without Flutter (Björn Ottosson's OKLab matrices).
library;

import 'dart:math' as math;

/// A color in OKLCH: lightness [l] 0–1, chroma [c] ≥ 0, hue [h] in degrees.
final class Oklch {
  /// Creates an OKLCH color with [alpha] 0–1.
  const Oklch(this.l, this.c, this.h, [this.alpha = 1]);

  /// Perceptual lightness 0–1.
  final double l;

  /// Chroma (≥ 0, sRGB colors stay below ≈ 0.37).
  final double c;

  /// Hue in degrees 0–360.
  final double h;

  /// Alpha 0–1.
  final double alpha;

  /// Converts 32-bit ARGB to OKLCH.
  factory Oklch.fromArgb(int argb) {
    final lab = Oklab.fromArgb(argb);
    final c = math.sqrt(lab.a * lab.a + lab.b * lab.b);
    var h = math.atan2(lab.b, lab.a) * 180 / math.pi;
    if (h < 0) h += 360;
    return Oklch(lab.l, c, c < 1e-7 ? 0 : h, lab.alpha);
  }

  /// A copy with the given components replaced.
  Oklch copyWith({double? l, double? c, double? h, double? alpha}) =>
      Oklch(l ?? this.l, c ?? this.c, h ?? this.h, alpha ?? this.alpha);

  /// This color in OKLab.
  Oklab toOklab() {
    final r = h * math.pi / 180;
    return Oklab(l, c * math.cos(r), c * math.sin(r), alpha);
  }

  /// Converts to 32-bit ARGB, gamut-mapping by reducing chroma (keeping
  /// lightness and hue) until the color fits in sRGB.
  int toArgb() {
    final lc = l.clamp(0.0, 1.0);
    if (Oklch(lc, c, h, alpha).toOklab()._inGamut()) {
      return Oklch(lc, c, h, alpha).toOklab().toArgb();
    }
    var lo = 0.0;
    var hi = c;
    for (var i = 0; i < 24; i++) {
      final mid = (lo + hi) / 2;
      if (Oklch(lc, mid, h, alpha).toOklab()._inGamut()) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return Oklch(lc, lo, h, alpha).toOklab().toArgb();
  }

  @override
  String toString() =>
      'Oklch(${l.toStringAsFixed(4)}, ${c.toStringAsFixed(4)}, '
      '${h.toStringAsFixed(2)})';
}

/// A color in OKLab.
final class Oklab {
  /// Creates an OKLab color.
  const Oklab(this.l, this.a, this.b, [this.alpha = 1]);

  /// Lightness.
  final double l;

  /// Green–red axis.
  final double a;

  /// Blue–yellow axis.
  final double b;

  /// Alpha 0–1.
  final double alpha;

  /// Converts 32-bit ARGB to OKLab.
  factory Oklab.fromArgb(int argb) {
    final r = srgbToLinear(((argb >> 16) & 0xff) / 255);
    final g = srgbToLinear(((argb >> 8) & 0xff) / 255);
    final bl = srgbToLinear((argb & 0xff) / 255);
    final l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * bl;
    final m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * bl;
    final s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * bl;
    final l_ = _cbrt(l), m_ = _cbrt(m), s_ = _cbrt(s);
    return Oklab(
      0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
      1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
      0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
      ((argb >>> 24) & 0xff) / 255,
    );
  }

  (double, double, double) _linear() {
    final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = l - 0.0894841775 * a - 1.2914855480 * b;
    final ll = l_ * l_ * l_, mm = m_ * m_ * m_, ss = s_ * s_ * s_;
    return (
      4.0767416621 * ll - 3.3077115913 * mm + 0.2309699292 * ss,
      -1.2684380046 * ll + 2.6097574011 * mm - 0.3413193965 * ss,
      -0.0041960863 * ll - 0.7034186147 * mm + 1.7076147010 * ss,
    );
  }

  bool _inGamut() {
    const eps = 1e-6;
    final (r, g, bl) = _linear();
    return r >= -eps &&
        r <= 1 + eps &&
        g >= -eps &&
        g <= 1 + eps &&
        bl >= -eps &&
        bl <= 1 + eps;
  }

  /// Converts to 32-bit ARGB (channels clamped).
  int toArgb() {
    final (r, g, bl) = _linear();
    int ch(double v) => (linearToSrgb(v.clamp(0.0, 1.0)) * 255).round().clamp(
      0,
      255,
    );
    final al = (alpha.clamp(0.0, 1.0) * 255).round();
    return (al << 24) | (ch(r) << 16) | (ch(g) << 8) | ch(bl);
  }
}

double _cbrt(double x) =>
    x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

/// sRGB transfer function: gamma-encoded 0–1 → linear 0–1.
double srgbToLinear(double v) =>
    v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

/// Inverse sRGB transfer function: linear 0–1 → gamma-encoded 0–1.
double linearToSrgb(double v) => v <= 0.0031308
    ? v * 12.92
    : 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;

/// WCAG 2.x relative luminance of the RGB part of [argb].
double relativeLuminance(int argb) {
  final r = srgbToLinear(((argb >> 16) & 0xff) / 255);
  final g = srgbToLinear(((argb >> 8) & 0xff) / 255);
  final b = srgbToLinear((argb & 0xff) / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Composites [foreground] (with its alpha) over [background] (alpha
/// ignored, treated as opaque). Returns an opaque ARGB color.
int compositeOver(int foreground, int background) {
  final a = ((foreground >>> 24) & 0xff) / 255;
  int mix(int shift) {
    final f = (foreground >> shift) & 0xff;
    final b = (background >> shift) & 0xff;
    return (f * a + b * (1 - a)).round().clamp(0, 255);
  }

  return 0xff000000 | (mix(16) << 16) | (mix(8) << 8) | mix(0);
}

/// WCAG 2.x contrast ratio (1–21) of opaque colors [a] and [b].
double contrastRatio(int a, int b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Multiplies the alpha of [argb] by [opacity] 0–1.
int withOpacity(int argb, double opacity) {
  final a = ((argb >>> 24) & 0xff) * opacity.clamp(0.0, 1.0);
  return (a.round() << 24) | (argb & 0xffffff);
}
