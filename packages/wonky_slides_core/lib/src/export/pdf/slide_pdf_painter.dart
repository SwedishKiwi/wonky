/// Draws a `SlideScene` with the `pdf` package's low-level graphics (10
/// §11.3 step 2–3): vector paths with solid and gradient fills, strokes,
/// dashes, caps and joins; images (crop, mask, pre-applied adjustments);
/// text as embedded-font glyph runs with highlights, decorations and link
/// annotations; charts through the shared `PdfChartRenderer`; code in the
/// mono font; opacity through graphic states; element shadows as offset
/// silhouettes. The same geometry as the Flutter `SlideScenePainter`.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;
import 'package:wonky_charts/wonky_charts.dart'
    show
        ChartPoint,
        PClose,
        PCubicTo,
        PLineTo,
        PMoveTo,
        PdfChartRenderer,
        SStrokeCap,
        SStrokeJoin;

import '../../motion/timeline/slide_frame.dart';
import '../../scene/nodes/code_scene.dart';
import '../../scene/nodes/scene_nodes.dart';
import '../../scene/nodes/text_layout.dart';
import '../../theme/resolve/resolved_theme.dart';
import 'pdf_page_plan.dart';
import 'ttf_text_measurer.dart';

/// A piece of text drawable with one PDF font.
final class PdfTextSegment {
  /// Creates a segment.
  const PdfTextSegment(this.font, this.text, this.advanceEm);

  final PdfFont font;
  final String text;

  /// Advance without letter spacing (em).
  final double advanceEm;
}

/// The embedded fonts of one PDF document: one subset `PdfTtfFont` per
/// loaded face (10 §11.3 step 4), glyph fallbacks per character, and the
/// standard Helvetica when a family could not be loaded.
final class SlidesPdfFonts {
  /// Creates the fonts of [doc] over [faces].
  SlidesPdfFonts(this.doc, this.faces);

  final PdfDocument doc;
  final TtfFaceSet faces;

  final Map<TtfFaceMetrics, PdfFont> _fonts = Map.identity();
  PdfFont? _standard;

  /// Warning codes raised while drawing (`font_fallback`, `glyph_missing`).
  final Set<String> warnings = {};

  /// The embedded font of [face].
  PdfFont fontOf(TtfFaceMetrics face) =>
      _fonts[face] ??= PdfTtfFont(doc, ByteData.sublistView(face.face.bytes));

  /// Helvetica (families that could not be loaded).
  PdfFont get standard => _standard ??= PdfFont.helvetica(doc);

  /// The embedded font of the run face [family]/[weight]/[italic], or null.
  PdfFont? fontFor(String family, int weight, bool italic) {
    final f = faces.faceOf(family, weight, italic);
    return f == null ? null : fontOf(f);
  }

  /// Splits [text] into segments by glyph coverage: the run's face, then
  /// the fallback faces; characters no face has are dropped
  /// (`glyph_missing`).
  List<PdfTextSegment> segments(
    String text,
    String family,
    int weight,
    bool italic,
  ) {
    final face = faces.faceOf(family, weight, italic);
    if (face == null) {
      warnings.add('font_fallback');
      final f = standard;
      final b = StringBuffer();
      for (final r in text.runes) {
        if (r == 0x2028 || r == 0x0a) continue;
        if (f.isRuneSupported(r)) {
          b.writeCharCode(r);
        } else {
          warnings.add('glyph_missing');
        }
      }
      final t = b.toString();
      if (t.isEmpty) return const [];
      return [PdfTextSegment(f, t, f.stringMetrics(t).advanceWidth)];
    }
    final out = <PdfTextSegment>[];
    TtfFaceMetrics? current;
    final b = StringBuffer();
    var adv = 0.0;
    void flush() {
      if (current != null && b.isNotEmpty) {
        out.add(PdfTextSegment(fontOf(current), b.toString(), adv));
      }
      b.clear();
      adv = 0;
    }

    for (final r in text.runes) {
      if (r == 0x2028 || r == 0x0a) continue;
      TtfFaceMetrics? use;
      if (face.hasGlyph(r)) {
        use = face;
      } else {
        for (final f in faces.fallbacks) {
          if (f.hasGlyph(r)) {
            use = f;
            break;
          }
        }
      }
      if (use == null) {
        warnings.add('glyph_missing');
        continue;
      }
      if (!identical(use, current)) {
        flush();
        current = use;
      }
      b.writeCharCode(r);
      adv += use.advance(r) ?? 0;
    }
    flush();
    return out;
  }
}

/// A decoded image ready to draw.
final class SlidesPdfImage {
  /// Creates an entry.
  const SlidesPdfImage(this.image, this.width, this.height);

  final PdfImage image;

  /// Decoded pixel size.
  final int width;
  final int height;
}

/// The key of an image variant (source + adjustments).
String slidesPdfImageKey(String src, {List<double>? matrix, double blur = 0}) =>
    matrix == null && blur <= 0
    ? src
    : '$src|${matrix?.map((v) => v.toStringAsFixed(4)).join(',')}|$blur';

/// A link found while drawing: [rect] in page space (pt, y up).
typedef SlidesPdfLinkSink = void Function(PdfRect rect, String target);

/// Draws scenes onto one page.
final class SlidePdfPainter {
  /// Creates a painter for [page].
  SlidePdfPainter({
    required this.page,
    required this.fonts,
    required this.images,
    this.onLink,
    this.chartFont,
  }) : g = page.getGraphics();

  final PdfPage page;
  final PdfGraphics g;
  final SlidesPdfFonts fonts;

  /// Prepared images by [slidesPdfImageKey].
  final Map<String, SlidesPdfImage> images;

  /// Receives clickable text runs (null = no link annotations).
  final SlidesPdfLinkSink? onLink;

  /// Fonts of chart text (regular, bold, italic, bold italic), created on
  /// first use (unused faces are not embedded).
  final (PdfFont, PdfFont?, PdfFont?, PdfFont?) Function()? chartFont;

  PdfDocument get doc => page.pdfDocument;

  double _opacity = 1;

  /// A color every fill, stroke and glyph is drawn with (shadow
  /// silhouettes), or null.
  int? _override;

  SlideFrame _frame = SlideFrame.edit;

  /// Draws [scene] into [box] (pt, top-left origin) of a page [pageHeight]
  /// pt high, with the element states of [frame]; [background] false
  /// omits the slide background (*Ink saver*).
  void paintScene(
    SlideScene scene,
    SlidesPdfRect box, {
    required double pageHeight,
    SlideFrame frame = SlideFrame.edit,
    bool background = true,
  }) {
    _frame = frame;
    final s = box.width / scene.width;
    g.saveContext();
    _cm(s, 0, 0, -s, box.x, pageHeight - box.y);
    g
      ..drawRect(0, 0, scene.width, scene.height)
      ..clipPath();
    if (background) {
      final bounds = (0.0, 0.0, scene.width, scene.height);
      void rect() => g.drawRect(0, 0, scene.width, scene.height);
      _fill(rect, scene.background.fill, bounds, false);
      final overlay = scene.background.overlay;
      if (overlay != null) _fill(rect, overlay, bounds, false);
    }
    for (final n in scene.nodes) {
      _node(n);
    }
    g.restoreContext();
  }

  // ---------------------------------------------------------------------
  // Transforms

  void _cm(double a, double b, double c, double d, double e, double f) {
    final m = Matrix4.identity();
    final st = m.storage;
    st[0] = a;
    st[1] = b;
    st[4] = c;
    st[5] = d;
    st[12] = e;
    st[13] = f;
    g.setTransform(m);
  }

  static bool _isIdentity(Matrix4 m) {
    final s = m.storage;
    for (var i = 0; i < 16; i++) {
      if (s[i] != (i % 5 == 0 ? 1.0 : 0.0)) return false;
    }
    return true;
  }

  /// [x0, y0, x1, y1] of the local box mapped to page space.
  PdfRect _pageRect(double x, double y, double w, double h) {
    final m = g.getTransform();
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final (px, py) in [(x, y), (x + w, y), (x, y + h), (x + w, y + h)]) {
      final v = m.transform3(Vector3(px, py, 0));
      minX = math.min(minX, v.x);
      minY = math.min(minY, v.y);
      maxX = math.max(maxX, v.x);
      maxY = math.max(maxY, v.y);
    }
    return PdfRect(minX, minY, maxX - minX, maxY - minY);
  }

  // ---------------------------------------------------------------------
  // Nodes

  void _node(SceneNode n) {
    final id = n.elementId;
    final state = id == null ? null : _frame.elements[id];
    if (state != null && !state.visible) return;
    switch (n) {
      case GroupNode():
        _group(n, state);
      case PathNode():
        _pathNode(n);
      case ImageNode():
        _image(n);
      case TextNode():
        paintText(n.layout, n.originX, n.originY);
      case ChartNode():
        _chart(n);
      case CodeNode():
        _code(n);
      case PromptNode():
        // Editor only (03 §2.4): never exported.
        break;
    }
  }

  void _group(GroupNode n, ElementVisualState? state) {
    final opacity = (n.opacity * (state?.opacity ?? 1)).clamp(0.0, 1.0);
    if (opacity <= 0) return;
    g.saveContext();
    if (state != null && !_isIdentity(state.transform)) {
      g.setTransform(state.transform);
    }
    if (!_isIdentity(n.transform)) g.setTransform(n.transform);
    final clip = n.clip;
    if (clip != null) {
      if (clip.rect case final r?) {
        g.drawRect(r.x, r.y, r.width, r.height);
      } else if (clip.path case final p?) {
        _path(p);
      }
      g.clipPath(evenOdd: clip.path?.evenOdd ?? false);
    }
    final saved = _opacity;
    // Shadows: the children's silhouette in the shadow color, offset
    // (blurred shadows drawn lighter; soft rasterized shadows are P1).
    for (final s in n.effects.shadows) {
      if ((s.color >>> 24) == 0) continue;
      g.saveContext();
      _cm(1, 0, 0, 1, s.dx, s.dy);
      final prev = _override;
      _override = s.color;
      _opacity = saved * opacity * (s.blur > 0 ? 0.6 : 1);
      for (final c in n.children) {
        _node(c);
      }
      _override = prev;
      g.restoreContext();
    }
    _opacity = saved * opacity;
    for (final c in n.children) {
      _node(c);
    }
    _opacity = saved;
    g.restoreContext();
  }

  // ---------------------------------------------------------------------
  // Paths, fills and strokes

  void _path(ScenePath p) {
    for (final c in p.commands) {
      switch (c) {
        case PMoveTo(:final x, :final y):
          if (x.isFinite && y.isFinite) g.moveTo(x, y);
        case PLineTo(:final x, :final y):
          if (x.isFinite && y.isFinite) g.lineTo(x, y);
        case PCubicTo(
          :final x1,
          :final y1,
          :final x2,
          :final y2,
          :final x,
          :final y,
        ):
          g.curveTo(x1, y1, x2, y2, x, y);
        case PClose():
          g.closePath();
      }
    }
  }

  static (double, double, double, double) _bounds(ScenePath p) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    void add(double x, double y) {
      if (!x.isFinite || !y.isFinite) return;
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }

    for (final c in p.commands) {
      switch (c) {
        case PMoveTo(:final x, :final y) || PLineTo(:final x, :final y):
          add(x, y);
        case PCubicTo():
          add(c.x1, c.y1);
          add(c.x2, c.y2);
          add(c.x, c.y);
        case PClose():
          break;
      }
    }
    if (!minX.isFinite) return (0, 0, 0, 0);
    return (minX, minY, maxX - minX, maxY - minY);
  }

  void _pathNode(PathNode n) {
    if (n.path.commands.isEmpty) return;
    final fill = n.fill;
    if (fill != null) {
      _fill(() => _path(n.path), fill, _bounds(n.path), n.path.evenOdd);
    }
    final s = n.stroke;
    if (s != null && s.width > 0 && (s.color >>> 24) != 0) {
      final color = _override ?? s.color;
      g.saveContext();
      g.setGraphicState(PdfGraphicState(strokeOpacity: _alpha(color)));
      g
        ..setStrokeColor(_color(color))
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
        ..setMiterLimit(10);
      if (s.dash.isNotEmpty && s.dash.any((v) => v > 0)) {
        g.setLineDashPattern([for (final d in s.dash) math.max(0.01, d)]);
      }
      _path(n.path);
      g.strokePath();
      g.restoreContext();
    }
  }

  double _alpha(int argb) =>
      (((argb >>> 24) & 0xff) / 255 * _opacity * 1000).round() / 1000;

  static PdfColor _color(int argb) => PdfColor(
    ((argb >> 16) & 0xff) / 255,
    ((argb >> 8) & 0xff) / 255,
    (argb & 0xff) / 255,
  );

  /// Fills the path built by [build] with [fill] over [bounds] (x, y, w, h).
  void _fill(
    void Function() build,
    ResolvedFill fill,
    (double, double, double, double) bounds,
    bool evenOdd,
  ) {
    final over = _override;
    if (over != null) {
      if (fill is ResolvedNoFill) return;
      _solid(build, over, evenOdd);
      return;
    }
    switch (fill) {
      case ResolvedNoFill():
        return;
      case ResolvedSolidFill(:final color):
        _solid(build, color, evenOdd);
      case ResolvedGradientFill():
        _gradient(build, fill, bounds, evenOdd);
      case ResolvedImageFill(:final fileUuid, :final fit, :final opacity):
        final img = images['${SlideImageRef.fileScheme}$fileUuid'];
        if (img == null) return;
        g.saveContext();
        build();
        g.clipPath(evenOdd: evenOdd);
        final saved = _opacity;
        _opacity *= opacity.clamp(0.0, 1.0);
        _drawFitted(img, bounds, fit);
        _opacity = saved;
        g.restoreContext();
    }
  }

  void _solid(void Function() build, int color, bool evenOdd) {
    if ((color >>> 24) == 0 || _opacity <= 0) return;
    g.saveContext();
    g.setGraphicState(PdfGraphicState(fillOpacity: _alpha(color)));
    g.setFillColor(_color(color));
    build();
    g.fillPath(evenOdd: evenOdd);
    g.restoreContext();
  }

  void _gradient(
    void Function() build,
    ResolvedGradientFill f,
    (double, double, double, double) bounds,
    bool evenOdd,
  ) {
    if (f.stops.isEmpty || _opacity <= 0) return;
    final (bx, by, bw, bh) = bounds;
    var alpha = 0.0;
    for (final (_, c) in f.stops) {
      alpha += ((c >>> 24) & 0xff) / 255;
    }
    alpha /= f.stops.length;
    final colors = [for (final (_, c) in f.stops) _color(c)];
    final stops = [for (final (p, _) in f.stops) p.clamp(0.0, 1.0)];
    final fn = PdfBaseFunction.colorsAndStops(doc, colors, stops);
    final PdfShading shading;
    if (f.kind == 'radial') {
      final c = PdfPoint(bx + f.centerX * bw, by + f.centerY * bh);
      final diag = math.sqrt(bw * bw + bh * bh);
      shading = PdfShading(
        doc,
        shadingType: PdfShadingType.radial,
        function: fn,
        start: c,
        end: c,
        radius0: 0,
        radius1: math.max(1, f.radius * diag),
        extendStart: true,
        extendEnd: true,
      );
    } else {
      final a = f.angle * math.pi / 180;
      final dx = math.cos(a), dy = math.sin(a);
      final half = (bw * dx).abs() / 2 + (bh * dy).abs() / 2;
      final cx = bx + bw / 2, cy = by + bh / 2;
      shading = PdfShading(
        doc,
        shadingType: PdfShadingType.axial,
        function: fn,
        start: PdfPoint(cx - dx * half, cy - dy * half),
        end: PdfPoint(cx + dx * half, cy + dy * half),
        extendStart: true,
        extendEnd: true,
      );
    }
    g.saveContext();
    g.setGraphicState(
      PdfGraphicState(fillOpacity: ((alpha * _opacity) * 1000).round() / 1000),
    );
    build();
    g.clipPath(evenOdd: evenOdd);
    g.applyShader(shading);
    g.restoreContext();
  }

  // ---------------------------------------------------------------------
  // Images

  /// Draws [img] with its full pixel rect mapped onto [x, y, w, h] (local,
  /// y down).
  void _drawImage(SlidesPdfImage img, double x, double y, double w, double h) {
    if (w <= 0 || h <= 0 || _opacity <= 0) return;
    g.saveContext();
    if (_opacity < 1) {
      g.setGraphicState(PdfGraphicState(fillOpacity: _opacity));
    }
    // Images fill the unit square with row 0 at the top in a y-up space:
    // flip back locally.
    g.drawImage(img.image, x, y + h, w, -h);
    g.restoreContext();
  }

  void _drawFitted(
    SlidesPdfImage img,
    (double, double, double, double) dst,
    String fit,
  ) {
    final (x, y, w, h) = dst;
    final iw = img.width.toDouble(), ih = img.height.toDouble();
    switch (fit) {
      case 'stretch':
        _drawImage(img, x, y, w, h);
      case 'contain' || 'cover':
        final s = fit == 'cover'
            ? math.max(w / iw, h / ih)
            : math.min(w / iw, h / ih);
        _drawImage(
          img,
          x + (w - iw * s) / 2,
          y + (h - ih * s) / 2,
          iw * s,
          ih * s,
        );
      default: // tile (1 px = 1 su, like the stage)
        var count = 0;
        for (var ty = y; ty < y + h && count < 400; ty += ih) {
          for (var tx = x; tx < x + w && count < 400; tx += iw) {
            _drawImage(img, tx, ty, iw, ih);
            count++;
          }
        }
    }
  }

  void _image(ImageNode n) {
    final img =
        images[slidesPdfImageKey(
          n.image.src,
          matrix: n.colorMatrix,
          blur: n.blurSigma,
        )];
    g.saveContext();
    if (n.mask case final m?) {
      _path(m);
      g.clipPath(evenOdd: m.evenOdd);
    }
    final d = n.dst;
    g
      ..drawRect(d.x, d.y, d.width, d.height)
      ..clipPath();
    if (_override case final color?) {
      _solid(() => g.drawRect(d.x, d.y, d.width, d.height), color, false);
      g.restoreContext();
      return;
    }
    if (img == null) {
      g.restoreContext();
      return;
    }
    var sx = n.src.x, sy = n.src.y, sw = n.src.width, sh = n.src.height;
    final nw = n.image.naturalWidth, nh = n.image.naturalHeight;
    if (nw == null || nh == null) {
      // Crop fractions of an image of unknown size (02 §6.4).
      sx *= img.width;
      sy *= img.height;
      sw *= img.width;
      sh *= img.height;
    } else if (nw != img.width) {
      final k = img.width / nw;
      sx *= k;
      sy *= k;
      sw *= k;
      sh *= k;
    }
    if (sw > 0 && sh > 0) {
      final kx = d.width / sw, ky = d.height / sh;
      _drawImage(
        img,
        d.x - sx * kx,
        d.y - sy * ky,
        img.width * kx,
        img.height * ky,
      );
    }
    g.restoreContext();
  }

  // ---------------------------------------------------------------------
  // Text

  /// Draws [layout] with its top-left at ([ox], [oy]) (local su, y down).
  void paintText(TextLayoutResult layout, double ox, double oy) {
    for (final line in layout.lines) {
      for (final r in [?line.bullet, ...line.runs]) {
        _run(r, ox + line.left + r.x, oy + line.baseline - r.baselineShift);
      }
    }
  }

  void _run(TextRunBox r, double x, double baseline) {
    if (r.text.isEmpty || r.fontSize <= 0) return;
    final face = fonts.faces.faceOf(r.fontFamily, r.fontWeight, r.italic);
    if (_privateUse(r.text) && !(face?.hasGlyph(r.text.runes.first) ?? false)) {
      // An icon-font glyph (Lucide) whose font isn't embeddable.
      fonts.warnings.add('icon_unavailable');
      return;
    }
    final ascent = (face?.ascent ?? 0.95) * r.fontSize;
    final descent = (face?.descent ?? 0.25) * r.fontSize;
    final color = _override ?? r.color;
    if (r.highlight case final h? when _override == null && (h >>> 24) != 0) {
      _solid(
        () => g.drawRect(x, baseline - ascent, r.width, ascent + descent),
        h,
        false,
      );
    }
    final segments = fonts.segments(
      r.text,
      r.fontFamily,
      r.fontWeight,
      r.italic,
    );
    if ((color >>> 24) != 0 && _opacity > 0 && segments.isNotEmpty) {
      g.saveContext();
      g.setGraphicState(PdfGraphicState(fillOpacity: _alpha(color)));
      g.setFillColor(_color(color));
      var cx = x;
      for (final s in segments) {
        g.saveContext();
        _cm(1, 0, 0, -1, cx, baseline);
        g.drawString(
          s.font,
          r.fontSize,
          s.text,
          0,
          0,
          charSpace: r.letterSpacing == 0 ? null : r.letterSpacing,
        );
        g.restoreContext();
        cx += s.advanceEm * r.fontSize + r.letterSpacing * s.text.runes.length;
      }
      g.restoreContext();
    }
    final thick = math.max(0.5, r.fontSize / 16);
    if (r.underline) {
      _solid(
        () => g.drawRect(x, baseline + r.fontSize * 0.1, r.width, thick),
        color,
        false,
      );
    }
    if (r.strike) {
      _solid(
        () => g.drawRect(x, baseline - r.fontSize * 0.3, r.width, thick),
        color,
        false,
      );
    }
    final link = r.link;
    if (link != null && link.isNotEmpty && onLink != null && r.width > 0) {
      onLink!(_pageRect(x, baseline - ascent, r.width, ascent + descent), link);
    }
  }

  static bool _privateUse(String text) {
    if (text.isEmpty) return false;
    for (final r in text.runes) {
      final pua = (r >= 0xe000 && r <= 0xf8ff) || r >= 0xf0000;
      if (!pua) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------
  // Charts and code

  void _chart(ChartNode n) {
    final s = n.scene;
    if (s.width <= 0 || s.height <= 0 || chartFont == null) return;
    final (regular, bold, italic, boldItalic) = chartFont!();
    g.saveContext();
    if (_opacity < 1) {
      g.setGraphicState(
        PdfGraphicState(fillOpacity: _opacity, strokeOpacity: _opacity),
      );
    }
    // The chart renderer works in a y-up space: flip back locally.
    _cm(1, 0, 0, -1, 0, 0);
    const PdfChartRenderer().draw(
      s,
      g,
      offset: ChartPoint(n.dst.x, -n.dst.y),
      scale: n.dst.width / s.width,
      font: regular,
      boldFont: bold,
      italicFont: italic,
      boldItalicFont: boldItalic,
    );
    g.restoreContext();
  }

  void _code(CodeNode n) {
    final s = n.scene;
    final d = n.dst;
    g.saveContext();
    _cm(1, 0, 0, 1, d.x, d.y);
    void box() => _roundRect(0, 0, d.width, d.height, s.cornerRadius);
    if ((s.background >>> 24) != 0) _solid(box, s.background, false);
    box();
    g.clipPath();
    void line(List<CodeRun> runs, double x, double baseline) {
      var cx = x;
      for (final r in runs) {
        final color = _override ?? r.color;
        final weight = r.bold ? 700 : 400;
        final segs = fonts.segments(r.text, s.fontFamily, weight, r.italic);
        for (final seg in segs) {
          if ((color >>> 24) != 0) {
            g.saveContext();
            g.setGraphicState(PdfGraphicState(fillOpacity: _alpha(color)));
            g.setFillColor(_color(color));
            _cm(1, 0, 0, -1, cx, baseline);
            g.drawString(seg.font, s.fontSize, seg.text, 0, 0);
            g.restoreContext();
          }
          cx += seg.advanceEm * s.fontSize;
        }
      }
    }

    final top = s.chromeHeight;
    if (s.title != null && top > 0) {
      line(
        [CodeRun(s.title!, color: s.titleColor)],
        s.codeLeft,
        top / 2 + s.fontSize * 0.35,
      );
    }
    for (final l in s.lines) {
      final baseline = top + l.y;
      line(l.runs, s.codeLeft, baseline);
      if (s.numbersRight case final right?) {
        final label = '${l.number}';
        final segs = fonts.segments(label, s.fontFamily, 400, false);
        final w = segs.fold(0.0, (a, x) => a + x.advanceEm) * s.fontSize;
        line([CodeRun(label, color: s.lineNumberColor)], right - w, baseline);
      }
    }
    g.restoreContext();
  }

  void _roundRect(double x, double y, double w, double h, double r) {
    final rr = math.min(r, math.min(w, h) / 2);
    if (rr <= 0) {
      g.drawRect(x, y, w, h);
      return;
    }
    const k = 0.5522847498;
    g
      ..moveTo(x + rr, y)
      ..lineTo(x + w - rr, y)
      ..curveTo(x + w - rr + rr * k, y, x + w, y + rr - rr * k, x + w, y + rr)
      ..lineTo(x + w, y + h - rr)
      ..curveTo(
        x + w,
        y + h - rr + rr * k,
        x + w - rr + rr * k,
        y + h,
        x + w - rr,
        y + h,
      )
      ..lineTo(x + rr, y + h)
      ..curveTo(x + rr - rr * k, y + h, x, y + h - rr + rr * k, x, y + h - rr)
      ..lineTo(x, y + rr)
      ..curveTo(x, y + rr - rr * k, x + rr - rr * k, y, x + rr, y)
      ..closePath();
  }
}
