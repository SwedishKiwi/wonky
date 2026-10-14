import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:wonky_sheets_core/model.dart';

/// Font used for chart text when the spec names none (or one that isn't
/// bundled): the app UI font shipped with `shad`.
const String kChartDefaultFont = 'packages/shad/Inter';

const List<String> _fallbackFonts = [
  'packages/shad/Inter',
  'packages/shad/Geist',
];

/// Families the app can render (bundled fonts); others fall back to
/// [kChartDefaultFont] so layout and paint use the same metrics.
const Set<String> _bundled = {
  'packages/shad/Inter',
  'packages/shad/Geist',
  'packages/shad/GeistMono',
};

String _family(String? f) {
  if (f == null || f.isEmpty) return kChartDefaultFont;
  if (_bundled.contains(f)) return f;
  return switch (f.toLowerCase()) {
    'inter' => 'packages/shad/Inter',
    'geist' => 'packages/shad/Geist',
    'geist mono' || 'geistmono' => 'packages/shad/GeistMono',
    _ => kChartDefaultFont,
  };
}

/// The Flutter text style of a scene text style.
TextStyle chartTextStyle(TextStyleSpec s) => TextStyle(
  fontFamily: _family(s.family),
  fontFamilyFallback: _fallbackFonts,
  fontSize: s.size,
  fontWeight: s.bold ? FontWeight.w600 : FontWeight.w400,
  fontStyle: s.italic ? FontStyle.italic : FontStyle.normal,
  color: Color(s.color),
  height: 1.0,
);

/// `TextPainter`-backed [TextMeasurer] (08 §6.2) with an LRU cache of laid
/// out painters, shared by layout and painting so both agree on metrics.
class FlutterTextMeasurer implements TextMeasurer {
  FlutterTextMeasurer({this.capacity = 2000});

  /// Shared instance of the editor.
  static final FlutterTextMeasurer instance = FlutterTextMeasurer();

  final int capacity;
  final LinkedHashMap<(String, TextStyleSpec), TextPainter> _cache =
      LinkedHashMap();

  /// A laid-out painter for one line of [text].
  TextPainter painter(String text, TextStyleSpec style) {
    final key = (text, style);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }
    final tp = TextPainter(
      text: TextSpan(text: text, style: chartTextStyle(style)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    _cache[key] = tp;
    if (_cache.length > capacity) {
      final old = _cache.keys.first;
      _cache.remove(old)?.dispose();
    }
    return tp;
  }

  @override
  TextMetrics measure(String text, TextStyleSpec style) {
    final tp = painter(text, style);
    final ascent = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    return TextMetrics(tp.width, tp.height, ascent);
  }
}

/// Paints a [ChartScene] (08 §6.3 painting contract) on a Flutter canvas.
/// Coordinates are scene px; scale the canvas for zoom.
void paintChartScene(
  Canvas canvas,
  ChartScene scene, {
  FlutterTextMeasurer? text,
}) {
  final t = text ?? FlutterTextMeasurer.instance;
  if (RenderGeometry.fillVisible(scene.background)) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, scene.width, scene.height),
      Paint()..color = Color(scene.background),
    );
  }
  _paintList(canvas, scene.primitives, t);
}

void _paintList(
  Canvas canvas,
  List<ScenePrimitive> list,
  FlutterTextMeasurer t,
) {
  for (final p in list) {
    _paint(canvas, p, t);
  }
}

Rect _rect(ChartRect r) => Rect.fromLTWH(r.left, r.top, r.width, r.height);

Paint _fill(int argb) => Paint()
  ..color = Color(argb)
  ..style = PaintingStyle.fill
  ..isAntiAlias = true;

Paint _stroke(SStroke s) => Paint()
  ..color = Color(s.color)
  ..style = PaintingStyle.stroke
  ..strokeWidth = s.width
  ..strokeMiterLimit = RenderGeometry.miterLimit
  ..strokeCap = switch (s.cap) {
    SStrokeCap.butt => StrokeCap.butt,
    SStrokeCap.round => StrokeCap.round,
    SStrokeCap.square => StrokeCap.square,
  }
  ..strokeJoin = switch (s.join) {
    SStrokeJoin.miter => StrokeJoin.miter,
    SStrokeJoin.round => StrokeJoin.round,
    SStrokeJoin.bevel => StrokeJoin.bevel,
  }
  ..isAntiAlias = true;

Path _path(List<PathCmd> cmds, {bool evenOdd = false}) {
  final path = Path()
    ..fillType = evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
  for (final c in RenderGeometry.finiteCommands(cmds)) {
    switch (c) {
      case PMoveTo(:final x, :final y):
        path.moveTo(x, y);
      case PLineTo(:final x, :final y):
        path.lineTo(x, y);
      case PCubicTo(
        :final x1,
        :final y1,
        :final x2,
        :final y2,
        :final x,
        :final y,
      ):
        path.cubicTo(x1, y1, x2, y2, x, y);
      case PClose():
        path.close();
    }
  }
  return path;
}

/// [path] cut into dashes of [pattern] (on, off, …).
Path _dashed(Path path, List<double> pattern) {
  final out = Path();
  for (final m in path.computeMetrics()) {
    var d = 0.0;
    var i = 0;
    var on = true;
    while (d < m.length) {
      final len = pattern[i % pattern.length];
      final next = math.min(m.length, d + len);
      if (on && next > d) out.addPath(m.extractPath(d, next), Offset.zero);
      d = next;
      on = !on;
      i++;
      if (len <= 0 && i > pattern.length * 2) break;
    }
  }
  return out;
}

void _strokePath(Canvas canvas, Path path, SStroke? s) {
  if (!RenderGeometry.strokeVisible(s)) return;
  final dash = RenderGeometry.effectiveDash(s!.dash);
  canvas.drawPath(dash == null ? path : _dashed(path, dash), _stroke(s));
}

void _paint(Canvas canvas, ScenePrimitive p, FlutterTextMeasurer t) {
  switch (p) {
    case SRect(:final rect, :final fill, :final stroke, :final radius):
      if (!RenderGeometry.rectFinite(rect)) return;
      final r = _rect(RenderGeometry.normalize(rect));
      final rr = RenderGeometry.clampRadius(rect, radius);
      if (RenderGeometry.fillVisible(fill)) {
        if (rr > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, Radius.circular(rr)),
            _fill(fill!),
          );
        } else {
          canvas.drawRect(r, _fill(fill!));
        }
      }
      if (RenderGeometry.strokeVisible(stroke)) {
        final path = Path();
        if (rr > 0) {
          path.addRRect(RRect.fromRectAndRadius(r, Radius.circular(rr)));
        } else {
          path.addRect(r);
        }
        _strokePath(canvas, path, stroke);
      }
    case SPath(:final cmds, :final fill, :final stroke, :final evenOdd):
      final path = _path(cmds, evenOdd: evenOdd);
      if (RenderGeometry.fillVisible(fill)) canvas.drawPath(path, _fill(fill!));
      _strokePath(canvas, path, stroke);
    case SPolyline(:final xy, :final stroke):
      if (!RenderGeometry.strokeVisible(stroke)) return;
      final path = Path();
      for (final run in RenderGeometry.finiteRuns(xy)) {
        if (run.length < 4) continue;
        path.moveTo(run[0], run[1]);
        for (var i = 2; i + 1 < run.length; i += 2) {
          path.lineTo(run[i], run[i + 1]);
        }
      }
      _strokePath(canvas, path, stroke);
    case SMarkers(:final xy, :final shape, :final stroke):
      _markers(canvas, p, xy, shape, stroke);
    case SArc(:final fill, :final stroke):
      final hollowFull = p.isFullCircle && p.innerRadius > 0;
      final path = _path(p.toPath(), evenOdd: hollowFull);
      if (RenderGeometry.fillVisible(fill)) canvas.drawPath(path, _fill(fill!));
      _strokePath(canvas, path, stroke);
    case SText():
      _text(canvas, p, t);
    case SClip(:final rect, :final children):
      canvas.save();
      canvas.clipRect(_rect(rect));
      _paintList(canvas, children, t);
      canvas.restore();
    case SGroup(:final children, :final opacity):
      if (opacity <= 0) return;
      if (opacity < 1) {
        canvas.saveLayer(
          null,
          Paint()..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)),
        );
        _paintList(canvas, children, t);
        canvas.restore();
      } else {
        _paintList(canvas, children, t);
      }
  }
}

void _markers(
  Canvas canvas,
  SMarkers m,
  Float64List xy,
  MarkerShape shape,
  SStroke? stroke,
) {
  final strokePaint = RenderGeometry.strokeVisible(stroke)
      ? _stroke(stroke!)
      : null;
  final fills = <int, Paint>{};
  for (var k = 0; k < m.length; k++) {
    final x = xy[2 * k], y = xy[2 * k + 1];
    if (!x.isFinite || !y.isFinite) continue;
    final size = m.sizeOf(k);
    if (!(size > 0)) continue;
    final fill = m.fillOf(k);
    final fp = RenderGeometry.fillVisible(fill)
        ? fills.putIfAbsent(fill, () => _fill(fill))
        : null;
    if (shape == MarkerShape.circle) {
      if (fp != null) canvas.drawCircle(Offset(x, y), size / 2, fp);
      if (strokePaint != null) {
        canvas.drawCircle(Offset(x, y), size / 2, strokePaint);
      }
      continue;
    }
    final path = _path(RenderGeometry.markerPath(shape, x, y, size));
    if (fp != null) canvas.drawPath(path, fp);
    if (strokePaint != null) canvas.drawPath(path, strokePaint);
  }
}

void _text(Canvas canvas, SText s, FlutterTextMeasurer t) {
  if (s.text.isEmpty || !s.at.x.isFinite || !s.at.y.isFinite) return;
  final tp = t.painter(s.text, s.style);
  final ascent = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  final (dx, dy) = s.anchor.baselineOrigin(tp.width, tp.height, ascent);
  // Top-left of the text box relative to the anchor point.
  final origin = Offset(dx, dy - ascent);
  if (s.angle == 0) {
    tp.paint(canvas, Offset(s.at.x, s.at.y) + origin);
    return;
  }
  canvas.save();
  canvas.translate(s.at.x, s.at.y);
  canvas.rotate(s.angle);
  tp.paint(canvas, origin);
  canvas.restore();
}

/// Paints a scene laid out at logical size, scaled by [scale] (zoom), so
/// text and lines stay crisp at every zoom level (08 §9.1).
class ChartScenePainter extends CustomPainter {
  ChartScenePainter(this.scene, {this.scale = 1, super.repaint});

  final ChartScene? scene;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final s = scene;
    if (s == null) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (scale != 1) canvas.scale(scale);
    paintChartScene(canvas, s);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ChartScenePainter old) =>
      !identical(old.scene, scene) || old.scale != scale;
}

/// Renders [scene] to PNG bytes at [pixelRatio] (download, copy as image,
/// 08 §13).
Future<Uint8List?> chartSceneToPng(
  ChartScene scene, {
  double pixelRatio = 2,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(pixelRatio);
  paintChartScene(canvas, scene);
  final picture = recorder.endRecording();
  final w = math.max(1, (scene.width * pixelRatio).ceil());
  final h = math.max(1, (scene.height * pixelRatio).ceil());
  final image = await picture.toImage(w, h);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data?.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
