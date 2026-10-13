import 'dart:math' as math;
import 'dart:ui';

/// Natural (logical pixel) sizes of images the editor has loaded, keyed by
/// the embed `src` (Write 04 §17.3). The image placeholder takes the cached
/// size, so a known image doesn't jump in height when it (re)loads, and the
/// page breaks computed while it loads stay right.
class ImageSizeCache {
  ImageSizeCache({this.capacity = 512});

  /// The cache shared by every editor in the app.
  static final instance = ImageSizeCache();

  /// Most entries kept; the least recently used ones are dropped first.
  final int capacity;

  final _sizes = <String, Size>{}; // insertion-ordered: LRU first

  Size? operator [](String src) {
    final size = _sizes.remove(src);
    if (size != null) _sizes[src] = size;
    return size;
  }

  void operator []=(String src, Size size) {
    if (size.isEmpty) return;
    _sizes
      ..remove(src)
      ..[src] = size;
    while (_sizes.length > capacity) {
      _sizes.remove(_sizes.keys.first);
    }
  }

  void clear() => _sizes.clear();

  /// [natural] scaled down (never up), preserving the aspect ratio, to fit in
  /// [maxWidth] × [maxHeight] (`null` height: unbounded).
  static Size fit(Size natural, double maxWidth, double? maxHeight) {
    if (natural.isEmpty) return natural;
    var scale = math.min(1.0, maxWidth / natural.width);
    if (maxHeight != null) {
      scale = math.min(scale, maxHeight / natural.height);
    }
    return natural * scale;
  }
}
