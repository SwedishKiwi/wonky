import '../../layout/text_measurer.dart';
import '../../scene/scene.dart';
import 'bitmap_text.dart';

/// [TextMeasurer] with the metrics of the bitmap fonts `RasterChartRenderer` draws text with,
/// so PNG exports made without Flutter lay out labels for the glyphs they actually show
/// (08 §6.2, §13).
final class RasterTextMeasurer implements TextMeasurer {
  /// Creates the measurer.
  const RasterTextMeasurer();

  @override
  TextMetrics measure(String text, TextStyleSpec style) {
    if (!(style.size > 0)) return const TextMetrics(0, 0, 0);
    final (width, height, ascent) = BitmapTextPainter.metrics(text, style.size);
    return TextMetrics(width, height, ascent);
  }
}
