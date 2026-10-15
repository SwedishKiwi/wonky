import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../scene/scene.dart';
import 'raster_surface.dart';
import 'rasterizer.dart';
import 'stroker.dart';

/// Draws [SText] with the bitmap Arial fonts bundled in `package:image` (14, 24 and 48 px),
/// scaled to the requested size with supersampled bilinear filtering, rotated by inverse
/// mapping, with faux bold (horizontal dilation) and faux italic (shear).
final class BitmapTextPainter {
  /// Creates a painter.
  BitmapTextPainter();

  static final Map<img.BitmapFont, Map<int, _GlyphBitmap?>> _glyphCache = {};
  static const double _italicShear = 0.2;

  /// The font used for text of [px] device pixels: the smallest font at least about that
  /// large (downscaling looks better than upscaling), else the largest.
  static img.BitmapFont fontFor(double px) {
    final fonts = [img.arial14, img.arial24, img.arial48];
    for (final f in fonts) {
      if (f.size >= px * 0.9) return f;
    }
    return fonts.last;
  }

  /// The text's advance width in px at [px] size, measured with the bitmap font's metrics.
  static double measure(String text, double px) {
    final f = fontFor(px);
    return _layout(f, text).advance * px / f.size;
  }

  /// Advance width, line height and ascent in px of [text] at [px] size, as [draw] anchors it.
  static (double width, double height, double ascent) metrics(
    String text,
    double px,
  ) {
    final f = fontFor(px);
    final k = px / f.size;
    return (_layout(f, text).advance * k, f.lineHeight * k, f.base * k);
  }

  /// Draws [t] at [scale] onto [surface], clipped to the device rectangle
  /// ([cl], [ct], [cr], [cb]).
  void draw(
    SText t,
    RasterSurface surface,
    double scale, {
    required double cl,
    required double ct,
    required double cr,
    required double cb,
  }) {
    final style = t.style;
    final px = style.size * scale;
    final alpha = Argb.alpha(style.color) / 255;
    if (!(px > 0) || alpha <= 0 || !px.isFinite) return;
    if (!t.at.x.isFinite || !t.at.y.isFinite) return;
    final font = fontFor(px);
    final layout = _layout(font, t.text);
    if (layout.glyphs.isEmpty) return;
    final k = px / font.size; // device px per font px
    final boldShift = style.bold ? math.max(1, (font.size / 16).round()) : 0;
    final italicPad = style.italic ? (font.base * _italicShear).ceil() + 1 : 0;

    // Line bitmap in font px: x = pen position + pad, y = 0 at the line top.
    const pad = 2;
    var maxBottom = font.lineHeight;
    for (final g in layout.glyphs) {
      maxBottom = math.max(maxBottom, g.bmp.yOffset + g.bmp.height);
    }
    final bw = (layout.right).ceil() + 2 * pad + boldShift + italicPad;
    final bh = maxBottom + 1;
    final bmp = Float32List(bw * bh);
    for (final g in layout.glyphs) {
      final gb = g.bmp;
      final a = gb.alpha;
      final ox = (g.x + gb.xOffset).round() + pad;
      final oy = gb.yOffset;
      for (var s = 0; s <= boldShift; s++) {
        for (var gy = 0; gy < gb.height; gy++) {
          final by = oy + gy;
          if (by < 0 || by >= bh) continue;
          for (var gx = 0; gx < gb.width; gx++) {
            final bx = ox + gx + s;
            if (bx < 0 || bx >= bw) continue;
            final v = a[gy * gb.width + gx];
            final idx = by * bw + bx;
            if (v > bmp[idx]) bmp[idx] = v;
          }
        }
      }
    }

    // Anchor using the bitmap font's metrics (device px).
    final width = layout.advance * k;
    final ascent = font.base * k;
    final height = font.lineHeight * k;
    final (dx, dy) = t.anchor.baselineOrigin(width, height, ascent);
    final angle = t.angle.isFinite ? t.angle : 0.0;
    final c = math.cos(angle), s = math.sin(angle);
    final ax = t.at.x * scale, ay = t.at.y * scale;

    // Device bounds of the rotated bitmap.
    final l0 = dx - pad * k, r0 = dx + (bw - pad) * k;
    final t0 = dy - font.base * k, b0 = dy + (bh - font.base) * k;
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final (lx, ly) in [(l0, t0), (r0, t0), (r0, b0), (l0, b0)]) {
      final x = ax + c * lx - s * ly, y = ay + s * lx + c * ly;
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    final x0 = math.max(minX.floor(), cl.floor()).clamp(0, surface.width);
    final x1 = math.min(maxX.ceil(), cr.ceil()).clamp(0, surface.width);
    final y0 = math.max(minY.floor(), ct.floor()).clamp(0, surface.height);
    final y1 = math.min(maxY.ceil(), cb.ceil()).clamp(0, surface.height);
    if (x1 <= x0 || y1 <= y0) return;

    final ss = k < 0.75 ? 3 : 2;
    final inv = 1 / (ss * ss);
    final r = Argb.red(style.color) / 255;
    final gr = Argb.green(style.color) / 255;
    final b = Argb.blue(style.color) / 255;
    final shear = style.italic ? _italicShear : 0.0;
    final base = font.base.toDouble();
    for (var py = y0; py < y1; py++) {
      final clipY = _overlap(py.toDouble(), ct, cb);
      if (clipY <= 0) continue;
      for (var pxi = x0; pxi < x1; pxi++) {
        final clipX = _overlap(pxi.toDouble(), cl, cr);
        if (clipX <= 0) continue;
        var acc = 0.0;
        for (var sy = 0; sy < ss; sy++) {
          final qy = py + (sy + 0.5) / ss - ay;
          for (var sx = 0; sx < ss; sx++) {
            final qx = pxi + (sx + 0.5) / ss - ax;
            // Unrotate into the text frame (device px, relative to the anchor point).
            final lx = c * qx + s * qy, ly = -s * qx + c * qy;
            final v = (ly - dy) / k + base;
            final u = (lx - dx) / k - shear * (base - v);
            acc += _sample(bmp, bw, bh, u + pad - 0.5, v - 0.5);
          }
        }
        final cov = acc * inv * clipX * clipY;
        if (cov > 0) surface.blendPixel(pxi, py, r, gr, b, cov * alpha);
      }
    }
  }

  static double _overlap(double p, double lo, double hi) {
    final a = p < lo ? lo : p;
    final b = p + 1 > hi ? hi : p + 1;
    return b > a ? b - a : 0;
  }

  static double _sample(Float32List bmp, int w, int h, double x, double y) {
    final fx = x.floorToDouble(), fy = y.floorToDouble();
    final ix = fx.toInt(), iy = fy.toInt();
    if (ix < -1 || iy < -1 || ix >= w || iy >= h) return 0;
    final tx = x - fx, ty = y - fy;
    double at(int xx, int yy) =>
        (xx < 0 || yy < 0 || xx >= w || yy >= h) ? 0 : bmp[yy * w + xx];
    final top = at(ix, iy) * (1 - tx) + at(ix + 1, iy) * tx;
    final bot = at(ix, iy + 1) * (1 - tx) + at(ix + 1, iy + 1) * tx;
    return top * (1 - ty) + bot * ty;
  }

  /// The glyph of [rune] in [font]: the font's own bitmap, a synthesized vector glyph for the
  /// few ASCII characters the bundled fonts lack, or null.
  static _GlyphBitmap? _glyph(img.BitmapFont font, int rune) {
    final cache = _glyphCache.putIfAbsent(font, () => {});
    if (cache.containsKey(rune)) return cache[rune];
    final ch = font.characters[rune];
    final _GlyphBitmap? g;
    if (ch != null) {
      final out = Float32List(ch.width * ch.height);
      for (var y = 0; y < ch.height; y++) {
        for (var x = 0; x < ch.width; x++) {
          // Glyph coverage is stored in the alpha channel (color channels are white).
          out[y * ch.width + x] = ch.image
              .getPixel(x, y)
              .aNormalized
              .toDouble();
        }
      }
      g = _GlyphBitmap(
        rune,
        out,
        ch.width,
        ch.height,
        ch.xOffset,
        ch.yOffset,
        ch.xAdvance,
      );
    } else {
      g = _synthesize(font, rune);
    }
    cache[rune] = g;
    return g;
  }

  /// Stroke outlines (em units, x right, y up from the baseline) and advances of characters
  /// missing from the bundled bitmap fonts.
  static final Map<int, (double, List<List<double>>)> _synthetic = {
    0x3C: (
      0.584,
      [
        [0.49, 0.6, 0.1, 0.355, 0.49, 0.11],
      ],
    ), // <
    0x3E: (
      0.584,
      [
        [0.095, 0.6, 0.485, 0.355, 0.095, 0.11],
      ],
    ), // >
    0x5C: (
      0.278,
      [
        [0.02, 0.72, 0.26, -0.01],
      ],
    ), // backslash
    0x60: (
      0.333,
      [
        [0.09, 0.73, 0.2, 0.6],
      ],
    ), // `
    0x7E: (
      0.584,
      [
        [
          0.07,
          0.31,
          0.13,
          0.37,
          0.2,
          0.39,
          0.29,
          0.36,
          0.38,
          0.32,
          0.45,
          0.31,
          0.51,
          0.37,
        ],
      ],
    ), // ~
    0xB2: (
      0.333,
      [
        [
          0.04,
          0.63,
          0.09,
          0.69,
          0.17,
          0.71,
          0.25,
          0.68,
          0.28,
          0.62,
          0.25,
          0.56,
        ],
        [0.25, 0.56, 0.04, 0.41, 0.3, 0.41],
      ],
    ), // ²
    0x2026: (
      1.0,
      [
        [0.15, 0.0, 0.15, 0.07],
        [0.5, 0.0, 0.5, 0.07],
        [0.85, 0.0, 0.85, 0.07],
      ],
    ), // …
    0x2212: (
      0.584,
      [
        [0.07, 0.31, 0.51, 0.31],
      ],
    ), // − (minus)
    0x2014: (
      1.0,
      [
        [0.0, 0.31, 1.0, 0.31],
      ],
    ), // — (em dash)
    0x25B2: (0.7, _triangle(up: true)), // ▲
    0x25BC: (0.7, _triangle(up: false)), // ▼
  };

  /// Horizontal strokes filling a triangle of width 0.6 em and height 0.55 em, pointing up
  /// or down.
  static List<List<double>> _triangle({required bool up}) => [
    for (var i = 0; i <= 13; i++)
      () {
        final f = i / 13;
        final y = 0.02 + f * 0.53;
        final half = 0.3 * (up ? 1 - f : f);
        return [0.35 - half, y, 0.35 + half, y];
      }(),
  ];

  static _GlyphBitmap? _synthesize(img.BitmapFont font, int rune) {
    final spec = _synthetic[rune];
    if (spec == null) return null;
    final (advance, strokes) = spec;
    final em = font.size.toDouble();
    final w = (advance * em).ceil() + 2;
    final h = font.lineHeight;
    final raster = CoverageRasterizer(w, h);
    final stroker = Stroker(raster);
    final hw = math.max(0.6, em * 0.042);
    for (final pts in strokes) {
      final xy = Float64List(pts.length);
      for (var i = 0; i + 1 < pts.length; i += 2) {
        xy[i] = 1 + pts[i] * em;
        xy[i + 1] = font.base - pts[i + 1] * em;
      }
      stroker.addPolyline(xy, false, hw, SStrokeCap.butt, SStrokeJoin.miter);
    }
    final out = Float32List(w * h);
    raster.fill((y, x0, x1, cov) {
      for (var x = x0; x < x1; x++) {
        out[y * w + x] = cov[x];
      }
    });
    return _GlyphBitmap(rune, out, w, h, -1, 0, (advance * em).round());
  }

  static _Layout _layout(img.BitmapFont font, String text) {
    final glyphs = <_Glyph>[];
    var pen = 0.0;
    var right = 0.0;
    int? prev;
    for (var rune in text.runes) {
      if (rune == 0x09 || rune == 0x0A || rune == 0x0D || rune == 0xA0) {
        rune = 0x20;
      }
      if (rune < 0x20 || rune == 0x7F) continue;
      var g = _glyph(font, rune);
      if (g == null && rune == 0x20) {
        pen += font.base / 3;
        prev = null;
        continue;
      }
      g ??= _glyph(font, 0x3F); // '?'
      if (g == null) continue;
      if (prev != null) pen += font.kernings[prev]?[g.id] ?? 0;
      glyphs.add(_Glyph(g, pen));
      right = math.max(right, pen + g.xOffset + g.width);
      pen += g.xAdvance;
      prev = g.id;
    }
    return _Layout(glyphs, pen, math.max(right, pen));
  }
}

final class _GlyphBitmap {
  const _GlyphBitmap(
    this.id,
    this.alpha,
    this.width,
    this.height,
    this.xOffset,
    this.yOffset,
    this.xAdvance,
  );
  final int id;
  final Float32List alpha;
  final int width;
  final int height;
  final int xOffset;
  final int yOffset;
  final int xAdvance;
}

final class _Glyph {
  const _Glyph(this.bmp, this.x);
  final _GlyphBitmap bmp;
  final double x;
}

final class _Layout {
  const _Layout(this.glyphs, this.advance, this.right);
  final List<_Glyph> glyphs;
  final double advance;
  final double right;
}
