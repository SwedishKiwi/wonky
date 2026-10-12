import '../scene/scene.dart';

/// Metrics of a single line of text.
final class TextMetrics {
  /// Creates metrics.
  const TextMetrics(this.width, this.height, this.ascent);

  final double width;

  /// Line height (ascent + descent + leading).
  final double height;

  /// Distance from the top of the line box to the baseline.
  final double ascent;

  @override
  String toString() => 'TextMetrics($width × $height, ascent $ascent)';
}

/// Platform text measurement (08 §6.2): Flutter uses `TextPainter`, PDF the embedded font's
/// metrics, the server the bundled font files.
abstract interface class TextMeasurer {
  /// Measures one line of [text] in [style].
  TextMetrics measure(String text, TextStyleSpec style);
}

/// Text helpers on top of a [TextMeasurer].
extension TextMeasurerX on TextMeasurer {
  /// [text] shortened with `…` to fit [maxWidth] (returns '' when even `…` does not fit).
  String ellipsize(String text, TextStyleSpec style, double maxWidth) {
    if (maxWidth <= 0) return '';
    if (measure(text, style).width <= maxWidth) return text;
    const dots = '…';
    if (measure(dots, style).width > maxWidth) return '';
    var lo = 0, hi = text.length;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (measure('${text.substring(0, mid).trimRight()}$dots', style).width <= maxWidth) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return '${text.substring(0, lo).trimRight()}$dots';
  }
}

/// Deterministic measurer from a Helvetica/Arial-like advance-width table (1/1000 em). Used by
/// the server raster path, tests and scene goldens.
final class ApproxTextMeasurer implements TextMeasurer {
  /// Creates the measurer.
  const ApproxTextMeasurer({this.ascentRatio = 0.93, this.lineHeightRatio = 1.17});

  /// Ascent as a fraction of the font size.
  final double ascentRatio;

  /// Line height as a fraction of the font size.
  final double lineHeightRatio;

  // ASCII 0x20..0x7E.
  static const List<int> _ascii = [
    278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278, //
    556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556, //
    1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778, //
    667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556, //
    333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556, //
    556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584,
  ];

  /// Advance of one code point in 1/1000 em.
  static int advance(int cp) {
    if (cp >= 0x20 && cp <= 0x7E) return _ascii[cp - 0x20];
    if (cp == 0x2026) return 1000; // …
    if (cp == 0x00A0) return 278;
    if (cp >= 0x2E80 && cp <= 0x9FFF) return 1000; // CJK
    if (cp >= 0xAC00 && cp <= 0xD7AF) return 1000; // Hangul
    if (cp >= 0xFF00 && cp <= 0xFFEF) return 1000; // full width
    if (cp >= 0x0300 && cp <= 0x036F) return 0; // combining marks
    if (cp == 0x25B2 || cp == 0x25BC) return 700; // ▲ ▼
    return 556;
  }

  @override
  TextMetrics measure(String text, TextStyleSpec style) {
    var units = 0;
    for (final r in text.runes) {
      units += advance(r);
    }
    var w = units * style.size / 1000;
    if (style.bold) w *= 1.06;
    return TextMetrics(w, style.size * lineHeightRatio, style.size * ascentRatio);
  }
}
