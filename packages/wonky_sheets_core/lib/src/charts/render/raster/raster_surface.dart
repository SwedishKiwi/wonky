import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A premultiplied RGBA float buffer (0..1 per channel) with source-over compositing.
final class RasterSurface {
  /// Creates a transparent surface.
  RasterSurface(this.width, this.height)
    : data = Float32List(width * height * 4);

  /// Width in px.
  final int width;

  /// Height in px.
  final int height;

  /// Premultiplied RGBA, row-major.
  final Float32List data;

  int _dirtyL = 1 << 30, _dirtyT = 1 << 30, _dirtyR = -1, _dirtyB = -1;

  /// Whether nothing was painted yet.
  bool get isClean => _dirtyR < 0;

  void _touch(int y, int x0, int x1) {
    if (x0 < _dirtyL) _dirtyL = x0;
    if (x1 > _dirtyR) _dirtyR = x1;
    if (y < _dirtyT) _dirtyT = y;
    if (y + 1 > _dirtyB) _dirtyB = y + 1;
  }

  /// Fills the whole surface with the straight color ([r], [g], [b], [a]) (0..1).
  void clear(double r, double g, double b, double a) {
    for (var i = 0; i < data.length; i += 4) {
      data[i] = r * a;
      data[i + 1] = g * a;
      data[i + 2] = b * a;
      data[i + 3] = a;
    }
    if (a > 0) {
      _dirtyL = 0;
      _dirtyT = 0;
      _dirtyR = width;
      _dirtyB = height;
    }
  }

  /// Composites the straight color ([r], [g], [b], [a]) over row [y] for `x0 <= x < x1`, with
  /// per-pixel coverage `coverage[x]`.
  void blendRow(
    int y,
    int x0,
    int x1,
    Float32List coverage,
    double r,
    double g,
    double b,
    double a,
  ) {
    if (y < 0 || y >= height) return;
    if (x0 < 0) x0 = 0;
    if (x1 > width) x1 = width;
    if (x1 <= x0) return;
    _touch(y, x0, x1);
    final d = data;
    var i = (y * width + x0) * 4;
    for (var x = x0; x < x1; x++, i += 4) {
      final c = coverage[x];
      if (c <= 0) continue;
      final sa = a * c;
      if (sa >= 1) {
        d[i] = r;
        d[i + 1] = g;
        d[i + 2] = b;
        d[i + 3] = 1;
      } else {
        final inv = 1 - sa;
        d[i] = r * sa + d[i] * inv;
        d[i + 1] = g * sa + d[i + 1] * inv;
        d[i + 2] = b * sa + d[i + 2] * inv;
        d[i + 3] = sa + d[i + 3] * inv;
      }
    }
  }

  /// Composites one pixel of straight color with alpha [sa] (already multiplied by coverage).
  void blendPixel(int x, int y, double r, double g, double b, double sa) {
    if (sa <= 0 || x < 0 || y < 0 || x >= width || y >= height) return;
    _touch(y, x, x + 1);
    final d = data;
    final i = (y * width + x) * 4;
    final inv = 1 - (sa > 1 ? 1 : sa);
    final s = sa > 1 ? 1.0 : sa;
    d[i] = r * s + d[i] * inv;
    d[i + 1] = g * s + d[i + 1] * inv;
    d[i + 2] = b * s + d[i + 2] * inv;
    d[i + 3] = s + d[i + 3] * inv;
  }

  /// Composites [layer] (same size) over this surface with [opacity].
  void compositeLayer(RasterSurface layer, double opacity) {
    if (layer.isClean || opacity <= 0) return;
    final o = opacity > 1 ? 1.0 : opacity;
    final x0 = layer._dirtyL,
        x1 = layer._dirtyR,
        y0 = layer._dirtyT,
        y1 = layer._dirtyB;
    for (var y = y0; y < y1; y++) {
      _touch(y, x0, x1);
      var i = (y * width + x0) * 4;
      for (var x = x0; x < x1; x++, i += 4) {
        final sa = layer.data[i + 3] * o;
        if (sa <= 0) continue;
        final inv = 1 - sa;
        data[i] = layer.data[i] * o + data[i] * inv;
        data[i + 1] = layer.data[i + 1] * o + data[i + 1] * inv;
        data[i + 2] = layer.data[i + 2] * o + data[i + 2] * inv;
        data[i + 3] = sa + data[i + 3] * inv;
      }
    }
  }

  /// The surface as an 8-bit straight-alpha RGBA image.
  img.Image toImage() {
    final bytes = Uint8List(width * height * 4);
    for (var i = 0; i < data.length; i += 4) {
      final a = data[i + 3];
      if (a <= 0) continue;
      final inv = a >= 1 ? 1.0 : 1 / a;
      bytes[i] = _byte(data[i] * inv);
      bytes[i + 1] = _byte(data[i + 1] * inv);
      bytes[i + 2] = _byte(data[i + 2] * inv);
      bytes[i + 3] = _byte(a);
    }
    return img.Image.fromBytes(
      width: width,
      height: height,
      bytes: bytes.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  }

  static int _byte(double v) {
    final b = (v * 255).round();
    return b < 0 ? 0 : (b > 255 ? 255 : b);
  }
}
