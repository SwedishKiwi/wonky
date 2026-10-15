/// Image adjustments (02 §6.4 `adjust`, 03 §6.5.5) as one 4×5 color
/// matrix: applied on screen with a `ColorFilter` and baked into PDF
/// images by the core renderer (same math, 10).
library;

/// Color matrices in the Flutter `ColorFilter.matrix` convention: 20
/// values, row-major RGBA rows, the fifth column an offset in 0..255.
abstract final class ImageAdjust {
  /// The identity matrix.
  static const List<double> identity = [
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  /// The matrix of an `adjust` object, or null when it changes nothing.
  static List<double>? matrix(Map<String, Object?>? adjust) {
    if (adjust == null) return null;
    double v(String k) {
      final x = adjust[k];
      return x is num && x.isFinite ? x.toDouble().clamp(-1.0, 1.0) : 0;
    }

    var m = identity;
    var changed = false;
    void then(List<double> next) {
      m = multiply(next, m);
      changed = true;
    }

    final brightness = v('brightness');
    final contrast = v('contrast');
    final saturation = v('saturation');
    final temperature = v('temperature');
    if (brightness != 0) {
      final o = brightness * 255 * 0.4;
      then([1, 0, 0, 0, o, 0, 1, 0, 0, o, 0, 0, 1, 0, o, 0, 0, 0, 1, 0]);
    }
    if (contrast != 0) {
      final k = 1 + contrast;
      final o = 128 * (1 - k);
      then([k, 0, 0, 0, o, 0, k, 0, 0, o, 0, 0, k, 0, o, 0, 0, 0, 1, 0]);
    }
    if (saturation != 0) then(saturate(1 + saturation));
    if (temperature != 0) {
      final t = temperature * 30;
      then([1, 0, 0, 0, t, 0, 1, 0, 0, 0, 0, 0, 1, 0, -t, 0, 0, 0, 1, 0]);
    }
    if (adjust['grayscale'] == true) then(saturate(0));
    if (adjust['sepia'] == true) {
      then([
        0.393, 0.769, 0.189, 0, 0, //
        0.349, 0.686, 0.168, 0, 0, //
        0.272, 0.534, 0.131, 0, 0, //
        0, 0, 0, 1, 0, //
      ]);
    }
    if (adjust['invert'] == true) {
      then([
        -1, 0, 0, 0, 255, //
        0, -1, 0, 0, 255, //
        0, 0, -1, 0, 255, //
        0, 0, 0, 1, 0, //
      ]);
    }
    return changed ? m : null;
  }

  /// A saturation matrix (0 = grayscale, 1 = identity, 2 = doubled) with
  /// Rec. 709 luminance weights.
  static List<double> saturate(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    return [
      r + (1 - r) * s, g - g * s, b - b * s, 0, 0, //
      r - r * s, g + (1 - g) * s, b - b * s, 0, 0, //
      r - r * s, g - g * s, b + (1 - b) * s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// [a] · [b] (apply [b] first, then [a]).
  static List<double> multiply(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 5; col++) {
        var sum = col == 4 ? a[row * 5 + 4] : 0.0;
        for (var k = 0; k < 4; k++) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        out[row * 5 + col] = sum;
      }
    }
    return out;
  }

  /// Applies [m] to an ARGB color (tests, PDF baking).
  static int apply(List<double> m, int argb) {
    final a = (argb >>> 24) & 0xff, r = (argb >> 16) & 0xff;
    final g = (argb >> 8) & 0xff, b = argb & 0xff;
    int ch(int row) =>
        (m[row * 5] * r +
                m[row * 5 + 1] * g +
                m[row * 5 + 2] * b +
                m[row * 5 + 3] * a +
                m[row * 5 + 4])
            .round()
            .clamp(0, 255);
    return (ch(3) << 24) | (ch(0) << 16) | (ch(1) << 8) | ch(2);
  }
}
