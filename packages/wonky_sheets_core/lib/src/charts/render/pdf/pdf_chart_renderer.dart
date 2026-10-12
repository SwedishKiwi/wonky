import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';

import '../../scene/geometry.dart';
import '../../scene/path.dart';
import '../../scene/scene.dart';
import '../render_geometry.dart';

/// Draws a [ChartScene] with the `pdf` package's [PdfGraphics] (print and PDF export,
/// 08 §13). One scene px is one PDF point at `scale = 1`.
final class PdfChartRenderer {
  /// Creates a renderer.
  const PdfChartRenderer();

  /// Draws [scene] onto [g]. [offset] is the position of the chart's top-left corner in PDF
  /// user space (y axis up), so scene (x, y) maps to `(offset.x + x·scale, offset.y − y·scale)`.
  ///
  /// Text uses [font] (default: the document's default font, Helvetica) and the bold/italic
  /// variants; when [font] is not given, missing variants are the standard Helvetica-Bold,
  /// Helvetica-Oblique and Helvetica-BoldOblique fonts of the page's document, otherwise
  /// [font] itself. The chart is clipped to its own bounds and its background is drawn first.
  void draw(
    ChartScene scene,
    PdfGraphics g, {
    ChartPoint offset = ChartPoint.zero,
    double scale = 1,
    PdfFont? font,
    PdfFont? boldFont,
    PdfFont? italicFont,
    PdfFont? boldItalicFont,
  }) {
    final regular = font ?? g.defaultFont;
    if (regular == null) {
      throw StateError('PdfChartRenderer.draw: no font available');
    }
    final fonts = _Fonts(
      regular,
      font == null,
      bold: boldFont,
      italic: italicFont,
      boldItalic: boldItalicFont,
    );
    final painter = _PdfPainter(g, fonts);
    g.saveContext();
    painter.transform(scale, 0, 0, -scale, offset.x, offset.y);
    g
      ..drawRect(0, 0, scene.width, scene.height)
      ..clipPath();
    if (RenderGeometry.fillVisible(scene.background)) {
      painter.paint(
        () => g.drawRect(0, 0, scene.width, scene.height),
        fill: scene.background,
        stroke: null,
        evenOdd: false,
        opacity: 1,
      );
    }
    painter.list(scene.primitives, 1);
    g.restoreContext();
  }

  /// A one-page PDF document with [scene] centered on a page of the chart's size plus
  /// [margin] points on every side (08 §13: 0.5 in = 36 pt).
  Future<Uint8List> renderDocument(
    ChartScene scene, {
    double margin = 36,
    bool compress = true,
  }) async {
    final doc = PdfDocument(compress: compress);
    final m = margin.isFinite && margin > 0 ? margin : 0.0;
    final w = math.max(1.0, _finite(scene.width) + 2 * m);
    final h = math.max(1.0, _finite(scene.height) + 2 * m);
    final page = PdfPage(doc, pageFormat: PdfPageFormat(w, h));
    final g = page.getGraphics();
    draw(scene, g, offset: ChartPoint(m, h - m));
    return doc.save();
  }

  static double _finite(double v) => v.isFinite && v > 0 ? v : 0;
}

final class _Fonts {
  _Fonts(this.regular, this.useStandard, {this.bold, this.italic, this.boldItalic});

  final PdfFont regular;
  final bool useStandard;
  PdfFont? bold;
  PdfFont? italic;
  PdfFont? boldItalic;

  PdfFont pick(bool isBold, bool isItalic) {
    if (isBold && isItalic) {
      return boldItalic ??= _standard('Helvetica-BoldOblique', PdfFont.helveticaBoldOblique);
    }
    if (isBold) return bold ??= _standard('Helvetica-Bold', PdfFont.helveticaBold);
    if (isItalic) return italic ??= _standard('Helvetica-Oblique', PdfFont.helveticaOblique);
    return regular;
  }

  PdfFont _standard(String name, PdfFont Function(PdfDocument) create) {
    if (!useStandard) return regular;
    final doc = regular.pdfDocument;
    for (final f in doc.fonts) {
      if (f.fontName == name) return f;
    }
    return create(doc);
  }
}

final class _PdfPainter {
  _PdfPainter(this.g, this.fonts);

  final PdfGraphics g;
  final _Fonts fonts;

  /// Concatenates the affine matrix `[a b c d e f]` to the current transform.
  void transform(double a, double b, double c, double d, double e, double f) {
    final m = g.getTransform();
    final s = m.storage;
    for (var i = 0; i < 16; i++) {
      s[i] = 0;
    }
    s[0] = _snap(a);
    s[1] = _snap(b);
    s[4] = _snap(c);
    s[5] = _snap(d);
    s[10] = 1;
    s[12] = _snap(e);
    s[13] = _snap(f);
    s[15] = 1;
    g.setTransform(m);
  }

  /// Rounds floating-point noise (e.g. cos(π/2)) to zero so matrices stay clean.
  static double _snap(double v) => v.abs() < 1e-9 ? 0 : v;

  void list(List<ScenePrimitive> list, double opacity) {
    for (final p in list) {
      primitive(p, opacity);
    }
  }

  void primitive(ScenePrimitive p, double opacity) {
    switch (p) {
      case SRect(:final rect, :final fill, :final stroke, :final radius):
        final r = RenderGeometry.normalize(rect);
        final rr = RenderGeometry.clampRadius(r, radius);
        paint(
          () => rr > 0
              ? _path(RenderGeometry.roundedRect(r, rr))
              : g.drawRect(r.left, r.top, r.width, r.height),
          fill: fill,
          stroke: stroke,
          evenOdd: false,
          opacity: opacity,
        );
      case SPath(:final cmds, :final fill, :final stroke, :final evenOdd):
        if (cmds.isEmpty) return;
        paint(() => _path(cmds), fill: fill, stroke: stroke, evenOdd: evenOdd, opacity: opacity);
      case SPolyline(:final xy, :final stroke):
        if (xy.length < 4) return;
        paint(
          () {
            var open = false;
            for (var i = 0; i + 1 < xy.length; i += 2) {
              final x = xy[i], y = xy[i + 1];
              if (!x.isFinite || !y.isFinite) {
                open = false;
              } else if (open) {
                g.lineTo(x, y);
              } else {
                g.moveTo(x, y);
                open = true;
              }
            }
          },
          fill: null,
          stroke: stroke,
          evenOdd: false,
          opacity: opacity,
        );
      case SMarkers():
        _markers(p, opacity);
      case SArc():
        paint(
          () => _path(p.toPath()),
          fill: p.fill,
          stroke: p.stroke,
          evenOdd: p.isFullCircle && p.innerRadius > 0,
          opacity: opacity,
        );
      case SText():
        _text(p, opacity);
      case SClip(:final rect, :final children):
        final r = RenderGeometry.normalize(rect);
        g
          ..saveContext()
          ..drawRect(r.left, r.top, r.width, r.height)
          ..clipPath();
        list(children, opacity);
        g.restoreContext();
      case SGroup(:final children, opacity: final o):
        if (!(o > 0)) return;
        list(children, opacity * math.min(1, o));
    }
  }

  void _markers(SMarkers p, double opacity) {
    for (var k = 0; k < p.length; k++) {
      final x = p.xy[2 * k], y = p.xy[2 * k + 1];
      final size = p.sizeOf(k);
      if (!(size > 0) || !x.isFinite || !y.isFinite) continue;
      paint(
        () => p.shape == MarkerShape.circle
            ? g.drawEllipse(x, y, size / 2, size / 2)
            : _path(RenderGeometry.markerPath(p.shape, x, y, size)),
        fill: p.fillOf(k),
        stroke: p.stroke,
        evenOdd: false,
        opacity: opacity,
      );
    }
  }

  void _path(List<PathCmd> cmds) {
    for (final c in cmds) {
      switch (c) {
        case PMoveTo(:final x, :final y):
          g.moveTo(x, y);
        case PLineTo(:final x, :final y):
          g.lineTo(x, y);
        case PCubicTo(:final x1, :final y1, :final x2, :final y2, :final x, :final y):
          g.curveTo(x1, y1, x2, y2, x, y);
        case PClose():
          g.closePath();
      }
    }
  }

  /// Builds the path with [build] and fills and/or strokes it.
  void paint(
    void Function() build, {
    required int? fill,
    required SStroke? stroke,
    required bool evenOdd,
    required double opacity,
  }) {
    final doFill = RenderGeometry.fillVisible(fill) && opacity > 0;
    final doStroke = RenderGeometry.strokeVisible(stroke) && opacity > 0;
    if (!doFill && !doStroke) return;
    g.setGraphicState(
      PdfGraphicState(
        fillOpacity: doFill ? _opacity(fill!, opacity) : null,
        strokeOpacity: doStroke ? _opacity(stroke!.color, opacity) : null,
      ),
    );
    if (doFill) g.setFillColor(_color(fill!));
    if (doStroke) {
      final s = stroke!;
      g
        ..setStrokeColor(_color(s.color))
        ..setLineWidth(s.width)
        ..setLineCap(switch (s.cap) {
          SStrokeCap.butt => PdfLineCap.butt,
          SStrokeCap.round => PdfLineCap.round,
          SStrokeCap.square => PdfLineCap.square,
        })
        ..setLineJoin(switch (s.join) {
          SStrokeJoin.miter => PdfLineJoin.miter,
          SStrokeJoin.round => PdfLineJoin.round,
          SStrokeJoin.bevel => PdfLineJoin.bevel,
        })
        ..setMiterLimit(RenderGeometry.miterLimit)
        ..setLineDashPattern(RenderGeometry.effectiveDash(s.dash) ?? const <num>[]);
    }
    build();
    if (doFill && doStroke) {
      g.fillAndStrokePath(evenOdd: evenOdd);
    } else if (doFill) {
      g.fillPath(evenOdd: evenOdd);
    } else {
      g.strokePath();
    }
  }

  void _text(SText p, double opacity) {
    final style = p.style;
    if (!(style.size > 0) || !RenderGeometry.fillVisible(style.color) || !(opacity > 0)) return;
    if (!p.at.x.isFinite || !p.at.y.isFinite) return;
    final font = fonts.pick(style.bold, style.italic);
    final text = _encodable(p.text, font);
    if (text.trim().isEmpty) return;
    final size = style.size;
    final width = font.stringMetrics(text).advanceWidth * size;
    final ascent = font.ascent * size;
    final height = (font.ascent - font.descent) * size;
    final (dx, dy) = p.anchor.baselineOrigin(width, height, ascent);
    final angle = p.angle.isFinite ? p.angle : 0.0;
    final c = math.cos(angle), s = math.sin(angle);
    g.saveContext();
    // Glyph space (u, v up) → scene space (y down): at + R(angle)·(dx + u, dy − v).
    transform(c, s, s, -c, p.at.x + c * dx - s * dy, p.at.y + s * dx + c * dy);
    g
      ..setGraphicState(PdfGraphicState(fillOpacity: _opacity(style.color, opacity)))
      ..setFillColor(_color(style.color))
      ..drawString(font, size, text, 0, 0)
      ..restoreContext();
  }

  /// [text] as a single line with characters the font cannot show replaced by `?`.
  static String _encodable(String text, PdfFont font) {
    final b = StringBuffer();
    for (final r in text.runes) {
      if (r == 0x0A || r == 0x0D || r == 0x09) {
        b.write(' ');
      } else if (r < 0x20 || r == 0x7F) {
        continue;
      } else if (font.isRuneSupported(r)) {
        b.writeCharCode(r);
      } else {
        b.write('?');
      }
    }
    return b.toString();
  }

  static PdfColor _color(int argb) =>
      PdfColor(Argb.red(argb) / 255, Argb.green(argb) / 255, Argb.blue(argb) / 255);

  static double _opacity(int argb, double opacity) =>
      ((Argb.alpha(argb) / 255) * opacity.clamp(0.0, 1.0) * 1000).round() / 1000;
}
