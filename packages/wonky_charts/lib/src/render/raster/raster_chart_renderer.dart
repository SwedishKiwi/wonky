import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../scene/path.dart';
import '../../scene/scene.dart';
import '../render_geometry.dart';
import 'bitmap_text.dart';
import 'raster_surface.dart';
import 'rasterizer.dart';
import 'stroker.dart';

/// Renders a [ChartScene] to PNG without Flutter (server-side exports, MCP
/// `sheets.export_chart_png`; 08 §13), with an own anti-aliased scanline rasterizer and the
/// bitmap fonts of `package:image`.
final class RasterChartRenderer {
  /// Creates a renderer.
  const RasterChartRenderer();

  /// PNG bytes of [scene] rendered at [scale] (the image is `scene size × scale` px).
  Uint8List render(ChartScene scene, {double scale = 1}) =>
      img.encodePng(renderImage(scene, scale: scale));

  /// [scene] rendered at [scale] as an RGBA image of `scene size × scale` px.
  img.Image renderImage(ChartScene scene, {double scale = 1}) {
    final s = scale.isFinite && scale > 0 ? scale : 1.0;
    final w = math.max(1, (_finite(scene.width) * s).round());
    final h = math.max(1, (_finite(scene.height) * s).round());
    final ctx = _RasterContext(w, h, s);
    if (RenderGeometry.fillVisible(scene.background)) {
      final bg = scene.background;
      ctx.surface.clear(
        Argb.red(bg) / 255,
        Argb.green(bg) / 255,
        Argb.blue(bg) / 255,
        Argb.alpha(bg) / 255,
      );
    }
    ctx.list(scene.primitives);
    return ctx.surface.toImage();
  }

  static double _finite(double v) => v.isFinite && v > 0 ? v : 0;
}

final class _RasterContext {
  _RasterContext(this.width, this.height, this.scale)
    : surface = RasterSurface(width, height),
      raster = CoverageRasterizer(width, height) {
    stroker = Stroker(raster);
    clipR = width.toDouble();
    clipB = height.toDouble();
  }

  final int width;
  final int height;
  final double scale;
  RasterSurface surface;
  final CoverageRasterizer raster;
  late final Stroker stroker;
  final BitmapTextPainter text = BitmapTextPainter();

  double clipL = 0, clipT = 0;
  late double clipR, clipB;

  // Paint state of the current fill (avoids a closure allocation per primitive).
  double _r = 0, _g = 0, _b = 0, _a = 0;
  late final CoverageSink _sink = _blend;

  void _blend(int y, int x0, int x1, Float32List coverage) =>
      surface.blendRow(y, x0, x1, coverage, _r, _g, _b, _a);

  bool get _clipEmpty => !(clipR > clipL) || !(clipB > clipT);

  void list(List<ScenePrimitive> list) {
    for (final p in list) {
      if (_clipEmpty) return;
      primitive(p);
    }
  }

  void primitive(ScenePrimitive p) {
    switch (p) {
      case SRect(:final rect, :final fill, :final stroke, :final radius):
        if (!RenderGeometry.rectFinite(rect)) return;
        final r = RenderGeometry.normalize(rect);
        final cmds = RenderGeometry.roundedRect(r, radius);
        _shape(cmds, fill, stroke, false);
      case SPath(
        :final cmds,
        :final fill,
        :final stroke,
        :final evenOdd,
        :final gradient,
      ):
        _shape(cmds, fill, stroke, evenOdd, gradient: gradient);
      case SPolyline(:final xy, :final stroke):
        if (!RenderGeometry.strokeVisible(stroke)) return;
        raster.clear();
        final alpha = _strokeSetup(stroke);
        final dash = _dash(stroke);
        for (final run in RenderGeometry.finiteRuns(xy)) {
          stroker.addPolyline(
            _scaled(run),
            false,
            _hw,
            stroke.cap,
            stroke.join,
            dash: dash,
          );
        }
        _paint(stroke.color, alpha, false);
      case SMarkers():
        _markers(p);
      case SArc():
        _shape(
          p.toPath(),
          p.fill,
          p.stroke,
          p.isFullCircle && p.innerRadius > 0,
        );
      case SText():
        text.draw(
          p,
          surface,
          scale,
          cl: clipL,
          ct: clipT,
          cr: clipR,
          cb: clipB,
        );
      case SClip(:final rect, :final children):
        final r = RenderGeometry.normalize(rect);
        final saved = (clipL, clipT, clipR, clipB);
        clipL = math.max(clipL, r.left * scale);
        clipT = math.max(clipT, r.top * scale);
        clipR = math.min(clipR, r.right * scale);
        clipB = math.min(clipB, r.bottom * scale);
        if (!_clipEmpty) list(children);
        clipL = saved.$1;
        clipT = saved.$2;
        clipR = saved.$3;
        clipB = saved.$4;
      case SGroup(:final children, :final opacity):
        if (!(opacity > 0)) return;
        if (opacity >= 1) {
          list(children);
          return;
        }
        final parent = surface;
        surface = RasterSurface(width, height);
        list(children);
        final layer = surface;
        surface = parent;
        parent.compositeLayer(layer, opacity);
    }
  }

  void _markers(SMarkers p) {
    final strokeOn = RenderGeometry.strokeVisible(p.stroke);
    for (var k = 0; k < p.length; k++) {
      final x = p.xy[2 * k], y = p.xy[2 * k + 1];
      final size = p.sizeOf(k);
      if (!(size > 0) || !x.isFinite || !y.isFinite) continue;
      final fill = p.fillOf(k);
      if (!RenderGeometry.fillVisible(fill) && !strokeOn) continue;
      // Skip markers entirely outside the clip.
      final ext = (size / 2 + (strokeOn ? p.stroke!.width : 0)) * scale + 1;
      final dx = x * scale, dy = y * scale;
      if (dx + ext < clipL ||
          dx - ext > clipR ||
          dy + ext < clipT ||
          dy - ext > clipB) {
        continue;
      }
      _shape(
        RenderGeometry.markerPath(p.shape, x, y, size),
        fill,
        p.stroke,
        false,
      );
    }
  }

  /// Fills and strokes the path [cmds] (scene coordinates).
  void _shape(
    List<PathCmd> cmds,
    int? fill,
    SStroke? stroke,
    bool evenOdd, {
    SGradient? gradient,
  }) {
    final doFill = RenderGeometry.fillVisible(fill);
    final doStroke = RenderGeometry.strokeVisible(stroke);
    if ((!doFill && !doStroke) || cmds.isEmpty) return;
    final polys = PathGeometry.flatten(
      RenderGeometry.finiteCommands(cmds),
      tolerance: 0.2 / scale,
    );
    if (polys.isEmpty) return;
    final scaled = [for (final (p, closed) in polys) (_scaled(p), closed)];
    if (doFill) {
      raster.clear();
      for (final (p, _) in scaled) {
        raster.addPolygon(p);
      }
      if (gradient != null) {
        _paintGradient(gradient, Argb.alpha(fill!) / 255, evenOdd);
      } else {
        _paint(fill!, 1, evenOdd);
      }
    }
    if (doStroke) {
      final s = stroke!;
      raster.clear();
      final alpha = _strokeSetup(s);
      final dash = _dash(s);
      for (final (p, closed) in scaled) {
        stroker.addPolyline(p, closed, _hw, s.cap, s.join, dash: dash);
      }
      _paint(s.color, alpha, false);
    }
  }

  double _hw = 0.5;

  /// Sets [_hw] for [s] and returns the alpha factor: strokes thinner than one device px are
  /// drawn 1 px wide with proportionally lower alpha so hairlines stay visible.
  double _strokeSetup(SStroke s) {
    final w = s.width * scale;
    if (w < 1) {
      _hw = 0.5;
      return w;
    }
    _hw = w / 2;
    return 1;
  }

  List<double>? _dash(SStroke s) {
    final d = RenderGeometry.effectiveDash(s.dash);
    if (d == null) return null;
    return [for (final v in d) v * scale];
  }

  Float64List _scaled(Float64List p) {
    final out = Float64List(p.length);
    for (var i = 0; i < p.length; i++) {
      out[i] = p[i] * scale;
    }
    return out;
  }

  // Linear gradient of the current fill (3D chart faces, 08 §23.5).
  double _gx = 0, _gy = 0, _gdx = 0, _gdy = 0, _ginv = 0;
  double _r0 = 0, _g0 = 0, _b0 = 0, _a0 = 0;
  double _r1 = 0, _g1 = 0, _b1 = 0, _a1 = 0;
  late final CoverageSink _gradientSink = _blendGradient;

  void _blendGradient(int y, int x0, int x1, Float32List coverage) {
    if (x0 < 0) x0 = 0;
    if (x1 > width) x1 = width;
    final py = y + 0.5 - _gy;
    for (var x = x0; x < x1; x++) {
      final c = coverage[x];
      if (c <= 0) continue;
      var t = ((x + 0.5 - _gx) * _gdx + py * _gdy) * _ginv;
      if (t < 0) t = 0;
      if (t > 1) t = 1;
      final a = (_a0 + (_a1 - _a0) * t) * _a;
      surface.blendPixel(
        x,
        y,
        _r0 + (_r1 - _r0) * t,
        _g0 + (_g1 - _g0) * t,
        _b0 + (_b1 - _b0) * t,
        a * c,
      );
    }
  }

  void _paintGradient(SGradient g, double alphaFactor, bool evenOdd) {
    _gx = g.x0 * scale;
    _gy = g.y0 * scale;
    _gdx = (g.x1 - g.x0) * scale;
    _gdy = (g.y1 - g.y0) * scale;
    final len2 = _gdx * _gdx + _gdy * _gdy;
    _ginv = len2 <= 1e-12 ? 0 : 1 / len2;
    _r0 = Argb.red(g.color0) / 255;
    _g0 = Argb.green(g.color0) / 255;
    _b0 = Argb.blue(g.color0) / 255;
    _a0 = Argb.alpha(g.color0) / 255;
    _r1 = Argb.red(g.color1) / 255;
    _g1 = Argb.green(g.color1) / 255;
    _b1 = Argb.blue(g.color1) / 255;
    _a1 = Argb.alpha(g.color1) / 255;
    _a = alphaFactor;
    if (_a <= 0) return;
    raster.fill(
      _gradientSink,
      evenOdd: evenOdd,
      clipLeft: clipL,
      clipTop: clipT,
      clipRight: clipR,
      clipBottom: clipB,
    );
  }

  void _paint(int argb, double alphaFactor, bool evenOdd) {
    _r = Argb.red(argb) / 255;
    _g = Argb.green(argb) / 255;
    _b = Argb.blue(argb) / 255;
    _a = Argb.alpha(argb) / 255 * alphaFactor;
    if (_a <= 0) return;
    raster.fill(
      _sink,
      evenOdd: evenOdd,
      clipLeft: clipL,
      clipTop: clipT,
      clipRight: clipR,
      clipBottom: clipB,
    );
  }
}
