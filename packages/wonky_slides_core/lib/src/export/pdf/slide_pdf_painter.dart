/// Draws a `SlideScene` with the `pdf` package's low-level graphics (10
/// §11.3 step 2–3): vector paths with solid and gradient fills, strokes,
/// dashes, caps and joins; images (crop, mask, pre-applied adjustments);
/// text as embedded-font glyph runs with highlights, decorations and link
/// annotations; charts through the shared `PdfChartRenderer`; code in the
/// mono font; opacity through graphic states; element shadows as offset
/// silhouettes. The same geometry as the Flutter `SlideScenePainter`.
///
/// Settled timeline frames (06 §9.6, SL-33) apply as on the stage: element
/// visibility, opacity and transforms, fill/stroke/text color changes,
/// fill opacity, text parts (hidden, dimmed, recolored, moved), persistent
/// highlights and the box opacity of text built in parts. Code and chart
/// content of a frame is composed before painting (`SlideFrameScenes`).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;
import 'package:wonky_code/wonky_code.dart' show oklabLerp;
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
import '../../theme/model/common.dart' show SuRect;
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

  /// Draws [n]; [owner] is the frame state of the element the node
  /// belongs to (nodes without an element id inherit it, as on the stage).
  void _node(SceneNode n, [ElementVisualState? owner]) {
    final id = n.elementId;
    final state = id == null ? owner : _frame.elements[id];
    if (state != null && !state.visible) return;
    switch (n) {
      case GroupNode():
        _group(n, state, own: id != null);
      case PathNode():
        _pathNode(n, state);
      case ImageNode():
        _image(n);
      case TextNode():
        if (state != null && _textAnimated(n, state)) {
          _animatedText(n, state);
        } else {
          paintText(n.layout, n.originX, n.originY);
        }
      case ChartNode():
        _chart(n);
      case CodeNode():
        _code(n);
      case PromptNode():
        // Editor only (03 §2.4): never exported.
        break;
    }
  }

  void _group(GroupNode n, ElementVisualState? inherited, {required bool own}) {
    // Only the element's own group applies its transform and opacity;
    // nested anonymous groups pass the state on.
    final state = own ? inherited : null;
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
        _node(c, inherited);
      }
      _override = prev;
      g.restoreContext();
    }
    _opacity = saved * opacity;
    for (final c in n.children) {
      _node(c, inherited);
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

  void _pathNode(PathNode n, [ElementVisualState? state]) {
    if (n.path.commands.isEmpty) return;
    // Text built in parts: the box arrives with the first part.
    final bg = (state?.parts?.backgroundOpacity ?? 1).clamp(0.0, 1.0);
    if (bg <= 0) return;
    final saved = _opacity;
    _opacity *= bg;
    final fill = n.fill;
    final fillOpacity = (state?.fillOpacity ?? 1).clamp(0.0, 1.0);
    if (fill != null && fillOpacity > 0) {
      final o = state?.colors['fill'];
      final before = _opacity;
      _opacity *= fillOpacity;
      _fill(
        () => _path(n.path),
        o == null ? fill : _recolorFill(fill, o),
        _bounds(n.path),
        n.path.evenOdd,
      );
      _opacity = before;
    }
    final s = n.stroke;
    final drawn = (state?.drawProgress ?? 1) > 0;
    if (drawn && s != null && s.width > 0 && (s.color >>> 24) != 0) {
      final so = state?.colors['stroke'];
      final color = _override ?? (so == null ? s.color : _blend(s.color, so));
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
    _opacity = saved;
  }

  /// [authored] blended toward the override (OKLab, as the stage).
  static int _blend(int authored, ColorOverride o) =>
      oklabLerp(o.from ?? authored, o.to, o.mix.clamp(0.0, 1.0));

  /// [fill] recolored by [o]: solid fills blend; gradient stops blend.
  static ResolvedFill _recolorFill(ResolvedFill fill, ColorOverride o) =>
      switch (fill) {
        ResolvedSolidFill(:final color) => ResolvedSolidFill(_blend(color, o)),
        ResolvedGradientFill() => ResolvedGradientFill(
          kind: fill.kind,
          angle: fill.angle,
          centerX: fill.centerX,
          centerY: fill.centerY,
          radius: fill.radius,
          stops: [for (final (p, c) in fill.stops) (p, _blend(c, o))],
        ),
        _ => fill,
      };

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

  /// The advance of [text] in run [r]'s face (su, letter spacing incl.).
  double _advance(TextRunBox r, String text) {
    if (text.isEmpty) return 0;
    final segs = fonts.segments(text, r.fontFamily, r.fontWeight, r.italic);
    var w = 0.0;
    for (final s in segs) {
      w += s.advanceEm * r.fontSize + r.letterSpacing * s.text.runes.length;
    }
    return w;
  }

  /// Draws run [r] (or its characters `[from, to)`, offsets in the run's
  /// text) with the start of the run at [x]; [recolor] maps the run's
  /// colors (frame color changes, dimming).
  void _run(
    TextRunBox r,
    double x,
    double baseline, {
    int from = 0,
    int? to,
    int Function(int color)? recolor,
  }) {
    if (r.text.isEmpty || r.fontSize <= 0) return;
    final end = math.min(to ?? r.text.length, r.text.length);
    if (end <= from) return;
    final whole = from == 0 && end == r.text.length;
    final text = whole ? r.text : r.text.substring(from, end);
    final width = whole ? r.width : _advance(r, text);
    if (from > 0) x += _advance(r, r.text.substring(0, from));
    final face = fonts.faces.faceOf(r.fontFamily, r.fontWeight, r.italic);
    if (_privateUse(text) && !(face?.hasGlyph(text.runes.first) ?? false)) {
      // An icon-font glyph (Lucide) whose font isn't embeddable.
      fonts.warnings.add('icon_unavailable');
      return;
    }
    final ascent = (face?.ascent ?? 0.95) * r.fontSize;
    final descent = (face?.descent ?? 0.25) * r.fontSize;
    final color = _override ?? (recolor?.call(r.color) ?? r.color);
    if (r.highlight case final h? when _override == null && (h >>> 24) != 0) {
      _solid(
        () => g.drawRect(x, baseline - ascent, width, ascent + descent),
        h,
        false,
      );
    }
    final segments = fonts.segments(text, r.fontFamily, r.fontWeight, r.italic);
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
        () => g.drawRect(x, baseline + r.fontSize * 0.1, width, thick),
        color,
        false,
      );
    }
    if (r.strike) {
      _solid(
        () => g.drawRect(x, baseline - r.fontSize * 0.3, width, thick),
        color,
        false,
      );
    }
    final link = r.link;
    if (link != null && link.isNotEmpty && onLink != null && width > 0) {
      onLink!(_pageRect(x, baseline - ascent, width, ascent + descent), link);
    }
  }

  // ---------------------------------------------------------------------
  // Text in a frame (06 §9.6: builds as pages)

  static bool _textAnimated(TextNode n, ElementVisualState st) {
    if (n.partId != null) return st.colors.containsKey('text');
    return (st.parts?.parts.isNotEmpty ?? false) ||
        st.highlights.isNotEmpty ||
        st.colors.containsKey('text') ||
        st.drawProgress <= 0;
  }

  /// Whether part [p] shows nothing.
  static bool _partHidden(TextPartState p) =>
      !p.visible ||
      (p.dimColor == null && p.opacity * p.dim <= 0) ||
      (p.revealEnd != null && p.revealEnd! <= p.start);

  /// Text node [n] with the frame state [st]: parts (hidden, dimmed,
  /// recolored, moved, revealed up to `revealEnd`), the element's text
  /// color change and highlights (marker and box behind the glyphs,
  /// underline over them). Settled frames only: no caret, blur or clips.
  void _animatedText(TextNode n, ElementVisualState st) {
    if (st.drawProgress <= 0) return;
    final layout = n.layout;
    final ox = n.originX, oy = n.originY;
    final textColor = st.colors['text'];
    final parts = n.partId == null
        ? (st.parts?.parts ?? const <TextPartState>[])
        : const <TextPartState>[];
    for (final h in st.highlights) {
      if (h.style != 'underline') _highlight(layout, ox, oy, h);
    }
    TextPartState? partAt(int i) {
      for (final p in parts) {
        if (i >= p.start && i < p.end) return p;
      }
      return null;
    }

    void draw(TextRunBox r, double x, double baseline, int from, int to) {
      final p = partAt(r.start + from);
      if (p != null && _partHidden(p)) return;
      var end = to;
      if (p?.revealEnd case final reveal?) {
        end = math.min(end, reveal - r.start);
        if (end <= from) return;
      }
      int recolor(int c) {
        var out = c;
        if (p?.color case final o?) out = _blend(out, o);
        if (p?.dimColor case final d?) out = d;
        if (textColor != null) out = _blend(out, textColor);
        return out;
      }

      final saved = _opacity;
      if (p != null) {
        _opacity *= (p.dimColor != null ? p.opacity : p.opacity * p.dim).clamp(
          0.0,
          1.0,
        );
      }
      final moved = p != null && !_isIdentity(p.transform);
      if (moved) {
        g.saveContext();
        g.setTransform(p.transform);
      }
      _run(r, x, baseline, from: from, to: end, recolor: recolor);
      if (moved) g.restoreContext();
      _opacity = saved;
    }

    for (final line in layout.lines) {
      final left = ox + line.left;
      final baseline = oy + line.baseline;
      if (line.bullet case final b?) {
        // A list marker belongs to the part of its paragraph's start.
        final p = partAt(line.start);
        if (p == null || !_partHidden(p)) {
          final shifted = TextRunBox(
            text: b.text,
            start: line.start,
            x: b.x,
            width: b.width,
            fontFamily: b.fontFamily,
            fontSize: b.fontSize,
            fontWeight: b.fontWeight,
            italic: b.italic,
            color: b.color,
            baselineShift: b.baselineShift,
          );
          draw(
            shifted,
            left + b.x,
            baseline - b.baselineShift,
            0,
            b.text.length,
          );
        }
      }
      for (final r in line.runs) {
        final x = left + r.x;
        final y = baseline - r.baselineShift;
        final len = r.text.length;
        if (parts.isEmpty) {
          draw(r, x, y, 0, len);
          continue;
        }
        // Split the run at part boundaries.
        final cuts = <int>{0, len};
        for (final p in parts) {
          for (final b in [p.start, p.end, ?p.revealEnd]) {
            final k = b - r.start;
            if (k > 0 && k < len) cuts.add(k);
          }
        }
        final sorted = cuts.toList()..sort();
        for (var i = 0; i + 1 < sorted.length; i++) {
          draw(r, x, y, sorted[i], sorted[i + 1]);
        }
      }
    }
    for (final h in st.highlights) {
      if (h.style == 'underline') _highlight(layout, ox, oy, h);
    }
  }

  /// A highlight sweep over `[h.start, h.end)` (06 §3.3 `highlight`):
  /// marker band, box outline or underline, left to right by progress.
  void _highlight(
    TextLayoutResult layout,
    double ox,
    double oy,
    TextHighlightState h,
  ) {
    final p = h.progress.clamp(0.0, 1.0);
    if (p <= 0 || (h.color >>> 24) == 0) return;
    final boxes = <(double, double, double, double)>[];
    for (final line in layout.lines) {
      for (final r in line.runs) {
        final len = r.text.length;
        final a = math.max(h.start, r.start),
            b = math.min(h.end, r.start + len);
        if (b <= a || len == 0) continue;
        final x0 =
            ox +
            line.left +
            r.x +
            _advance(r, r.text.substring(0, a - r.start));
        final w = _advance(r, r.text.substring(a - r.start, b - r.start));
        boxes.add((x0, oy + line.top, w, line.height));
      }
    }
    if (boxes.isEmpty) return;
    var left = boxes.fold(0.0, (a, b) => a + b.$3) * p;
    for (final (x, y, w0, hgt) in boxes) {
      if (left <= 0) break;
      final w = math.min(w0, left);
      left -= w;
      switch (h.style) {
        case 'underline':
          final t = math.max(2.0, hgt * 0.08);
          _solid(() => g.drawRect(x, y + hgt - t * 1.5, w, t), h.color, false);
        case 'box':
          final sw = math.max(2.0, hgt * 0.06);
          final c = _override ?? h.color;
          if (_opacity <= 0) continue;
          g.saveContext();
          g.setGraphicState(PdfGraphicState(strokeOpacity: _alpha(c)));
          g
            ..setStrokeColor(_color(c))
            ..setLineWidth(sw)
            ..drawRect(x + 1, y + 1, math.max(0, w - 2), math.max(0, hgt - 2))
            ..strokePath()
            ..restoreContext();
        default:
          _solid(
            () => _roundRect(
              x - 2,
              y + hgt * 0.22,
              w + 4,
              hgt * 0.74,
              hgt * 0.08,
            ),
            h.color,
            false,
          );
      }
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

  /// Code elements (07 §3.4, §9): box, border, chrome (tab, window bar,
  /// caption, language badge), highlight bars, selections and gutter
  /// markers, line numbers (active color on highlighted lines), token runs
  /// on the monospace grid with the line opacity (blur is drawn as its
  /// opacity: no blur in vector PDF, 07 §4.2), morph glyphs and gutter
  /// labels, the caret, callouts (bubble, label, pill with inline
  /// Markdown, SL-33) and the crossfade underlay — the fields the stage's
  /// `CodeScenePainter` draws.
  void _code(CodeNode n) {
    final s = n.scene;
    final d = n.dst;
    if (s.width <= 0 || s.height <= 0) return;
    g.saveContext();
    _cm(d.width / s.width, 0, 0, d.height / s.height, d.x, d.y);
    final saved = _opacity;
    final under = s.underlay;
    if (under != null && s.underlayOpacity > 0) {
      _opacity = saved * s.underlayOpacity.clamp(0.0, 1.0);
      if (_opacity > 0) _codeScene(under);
    }
    _opacity = saved * s.opacity.clamp(0.0, 1.0);
    if (_opacity > 0) _codeScene(s);
    _opacity = saved;
    g.restoreContext();
  }

  /// Draws [t] in [family] with its baseline at ([x], [baseline])
  /// (right-aligned at [alignRight] when given); returns the advance.
  double _codeText(
    String t,
    String family,
    double x,
    double baseline, {
    required int color,
    required double size,
    bool bold = false,
    bool italic = false,
    double? alignRight,
  }) {
    final c = _override ?? color;
    final segs = fonts.segments(t, family, bold ? 700 : 400, italic);
    final w = segs.fold(0.0, (a, x) => a + x.advanceEm) * size;
    var cx = alignRight == null ? x : alignRight - w;
    for (final seg in segs) {
      if ((c >>> 24) != 0 && _opacity > 0) {
        g.saveContext();
        g.setGraphicState(PdfGraphicState(fillOpacity: _alpha(c)));
        g.setFillColor(_color(c));
        _cm(1, 0, 0, -1, cx, baseline);
        g.drawString(seg.font, size, seg.text, 0, 0);
        g.restoreContext();
      }
      cx += seg.advanceEm * size;
    }
    return w;
  }

  void _codeScene(CodeScene s) {
    final box = s.box ?? SuRect(0, 0, s.width, s.height);
    final radius = math.min(
      s.cornerRadius,
      math.min(box.width, box.height) / 2,
    );
    void boxPath() => _roundRect(box.x, box.y, box.width, box.height, radius);
    if ((s.background >>> 24) != 0) _solid(boxPath, s.background, false);

    double text(
      String t,
      double x,
      double baseline, {
      required int color,
      required double size,
      bool bold = false,
      bool italic = false,
      double? alignRight,
    }) => _codeText(
      t,
      s.fontFamily,
      x,
      baseline,
      color: color,
      size: size,
      bold: bold,
      italic: italic,
      alignRight: alignRight,
    );

    // Chrome.
    final titleSize = s.gutterFontSize > 0 ? s.gutterFontSize : s.fontSize;
    if (s.chrome == 'caption' && s.title != null && s.captionHeight > 0) {
      text(
        s.title!,
        box.x,
        s.captionHeight / 2 + titleSize * 0.35,
        color: s.titleColor,
        size: titleSize,
      );
    } else if (s.titleHeight > 0 &&
        (s.chrome == 'tab' || s.chrome == 'window')) {
      final h = s.titleHeight;
      final padX = h * 0.45;
      final mid = box.y + h / 2;
      g.saveContext();
      boxPath();
      g.clipPath();
      _solid(
        () => g.drawRect(box.x, box.y, box.width, h),
        s.titleBackground,
        false,
      );
      if (s.chrome == 'window') {
        final r = h * 0.14;
        const lights = [0xffff5f57, 0xfffebc2e, 0xff28c840];
        for (var i = 0; i < lights.length; i++) {
          _solid(
            () => g.drawEllipse(box.x + padX + r + i * r * 3.2, mid, r, r),
            lights[i],
            false,
          );
        }
        if (s.title != null) {
          final segs = fonts.segments(s.title!, s.fontFamily, 400, false);
          final w = segs.fold(0.0, (a, x) => a + x.advanceEm) * titleSize;
          text(
            s.title!,
            box.x + box.width / 2 - w / 2,
            mid + titleSize * 0.35,
            color: s.titleColor,
            size: titleSize,
          );
        }
      } else if (s.title != null) {
        final segs = fonts.segments(s.title!, s.fontFamily, 400, false);
        final w = segs.fold(0.0, (a, x) => a + x.advanceEm) * titleSize;
        final top = box.y + h * 0.22;
        final left = box.x + padX * 0.6;
        _solid(
          () => _roundRect(left, top, w + 2 * padX, h - h * 0.22 + 1, 0),
          s.background,
          false,
        );
        text(
          s.title!,
          left + padX,
          (top + box.y + h) / 2 + titleSize * 0.35,
          color: s.titleColor,
          size: titleSize,
        );
      }
      if (s.language != null) {
        final size = titleSize * 0.9;
        text(
          s.language!,
          0,
          mid + size * 0.35,
          color: s.lineNumberColor,
          size: size,
          alignRight: box.x + box.width - padX,
        );
      }
      g.restoreContext();
    }

    // Code area: bars and selections under the text, gutter markers and
    // box outlines over it, then the caret.
    final area = s.codeArea ?? box;
    g.saveContext();
    boxPath();
    g.clipPath();
    g.drawRect(box.x, area.y, box.width, area.height);
    g.clipPath();
    _codeBars(s, under: true);
    final numberSize = s.gutterFontSize > 0 ? s.gutterFontSize : s.fontSize;
    for (final l in s.lines) {
      final saved = _opacity;
      _opacity *= l.opacity.clamp(0.0, 1.0);
      if (_opacity <= 0) {
        _opacity = saved;
        continue;
      }
      final baseline = s.chromeHeight + l.y;
      if (s.numbersRight case final right?) {
        text(
          l.continuation ? '↪' : '${l.number}',
          0,
          baseline,
          color: l.highlighted ? s.lineNumberActiveColor : s.lineNumberColor,
          size: numberSize,
          alignRight: right,
        );
      }
      for (final r in l.runs) {
        final o = _opacity;
        _opacity *= r.opacity.clamp(0.0, 1.0);
        text(
          r.text,
          s.codeLeft + r.column * s.columnWidth,
          baseline,
          color: r.color,
          size: s.fontSize,
          bold: r.bold,
          italic: r.italic,
        );
        _opacity = o;
      }
      _opacity = saved;
    }
    for (final gl in s.glyphs) {
      if (gl.text.isEmpty || gl.opacity <= 0) continue;
      final o = _opacity;
      _opacity *= gl.opacity.clamp(0.0, 1.0);
      text(
        gl.text,
        gl.x,
        gl.baseline,
        color: gl.color,
        size: gl.fontSize,
        bold: gl.bold,
        italic: gl.italic,
      );
      _opacity = o;
    }
    if (s.numbersRight case final right?) {
      for (final gl in s.gutter) {
        if (gl.opacity <= 0) continue;
        final o = _opacity;
        _opacity *= gl.opacity.clamp(0.0, 1.0);
        text(
          gl.text,
          0,
          gl.baseline,
          color: gl.color,
          size: numberSize,
          alignRight: right,
        );
        _opacity = o;
      }
    }
    _codeBars(s, under: false);
    if (s.caret case final c? when c.opacity > 0) {
      final o = _opacity;
      _opacity *= (c.style == 'block' ? 0.55 : 1) * c.opacity.clamp(0.0, 1.0);
      final r = c.rect;
      _solid(() => g.drawRect(r.x, r.y, r.width, r.height), c.color, false);
      _opacity = o;
    }
    g.restoreContext();

    final border = s.border;
    if (border != null && s.borderWidth > 0) {
      final c = _override ?? border;
      if ((c >>> 24) != 0 && _opacity > 0) {
        g.saveContext();
        g.setGraphicState(PdfGraphicState(strokeOpacity: _alpha(c)));
        g.setStrokeColor(_color(c));
        g.setLineWidth(s.borderWidth);
        final k = s.borderWidth / 2;
        _roundRect(
          box.x + k,
          box.y + k,
          box.width - 2 * k,
          box.height - 2 * k,
          math.max(0, radius - k),
        );
        g.strokePath();
        g.restoreContext();
      }
    }
    for (final c in s.callouts) {
      _callout(s, c);
    }
  }

  void _codeBars(CodeScene s, {required bool under}) {
    for (final b in s.bars) {
      final isUnder =
          b.kind == CodeBarKind.bar || b.kind == CodeBarKind.selection;
      if (isUnder != under) continue;
      final saved = _opacity;
      _opacity *= b.opacity.clamp(0.0, 1.0);
      final r = b.rect;
      if (b.strokeWidth > 0) {
        final c = _override ?? b.color;
        if ((c >>> 24) != 0 && _opacity > 0) {
          g.saveContext();
          g.setGraphicState(PdfGraphicState(strokeOpacity: _alpha(c)));
          g.setStrokeColor(_color(c));
          g.setLineWidth(b.strokeWidth);
          final k = b.strokeWidth / 2;
          _roundRect(
            r.x + k,
            r.y + k,
            r.width - 2 * k,
            r.height - 2 * k,
            b.radius,
          );
          g.strokePath();
          g.restoreContext();
        }
      } else {
        _solid(
          () => _roundRect(r.x, r.y, r.width, r.height, b.radius),
          b.color,
          false,
        );
      }
      _opacity = saved;
    }
  }

  // ---------------------------------------------------------------------
  // Code callouts (07 §4.4)

  /// Gap between a callout and its anchor (su; the stage's
  /// `CodeScenePainter.calloutGap`).
  static const calloutGap = 16.0;

  /// Inline Markdown of callouts (07 §4.4: `**bold**`, `*italic*` /
  /// `_italic_`, `` `code` ``) as styled segments (the stage's
  /// `CodeScenePainter.inlineMarkdown`).
  static List<(String, {bool bold, bool italic, bool code})> calloutMarkdown(
    String text,
  ) {
    final out = <(String, {bool bold, bool italic, bool code})>[];
    final buf = StringBuffer();
    var bold = false, italic = false;
    void flush({bool code = false}) {
      if (buf.isEmpty) return;
      out.add((buf.toString(), bold: bold, italic: italic, code: code));
      buf.clear();
    }

    var i = 0;
    while (i < text.length) {
      final ch = text[i];
      if (ch == '\\' && i + 1 < text.length) {
        buf.write(text[i + 1]);
        i += 2;
        continue;
      }
      if (ch == '`') {
        final end = text.indexOf('`', i + 1);
        if (end > i) {
          flush();
          buf.write(text.substring(i + 1, end));
          flush(code: true);
          i = end + 1;
          continue;
        }
      }
      if (text.startsWith('**', i) || text.startsWith('__', i)) {
        flush();
        bold = !bold;
        i += 2;
        continue;
      }
      if (ch == '*' || ch == '_') {
        flush();
        italic = !italic;
        i++;
        continue;
      }
      buf.write(ch);
      i++;
    }
    flush();
    return out;
  }

  /// A callout: wrapped inline-Markdown text (≤ 8 lines; pills one line
  /// with an ellipsis) in a bubble with a pointer, a pill, or a label with
  /// a leader line and anchor dot — the stage's geometry (no drop shadow).
  void _callout(CodeScene s, CodeCalloutPlacement c) {
    final o = c.opacity.clamp(0.0, 1.0);
    if (o <= 0 || c.text.trim().isEmpty) return;
    final family = c.fontFamily.isEmpty ? s.fontFamily : c.fontFamily;
    final label = c.style == 'label';
    final pill = c.style == 'pill';
    final ink = label ? c.color : c.textColor;
    final size = c.fontSize;
    final padX = size * (pill ? 0.7 : 0.8);
    final padY = size * (pill ? 0.3 : 0.55);
    final maxWidth = math.max(size * 4, c.maxWidth - 2 * padX);
    final lineHeight = size * 1.3;

    // Words with their styles, wrapped greedily.
    final words = <_CalloutWord>[];
    for (final seg in calloutMarkdown(c.text)) {
      final f = seg.code ? s.fontFamily : family;
      final sz = seg.code ? size * 0.92 : size;
      for (final m in RegExp(r'\s+|[^\s]+').allMatches(seg.$1)) {
        final t = m.group(0)!;
        final space = t.trim().isEmpty;
        final w =
            fonts
                .segments(space ? ' ' : t, f, seg.bold ? 700 : 400, seg.italic)
                .fold(0.0, (a, x) => a + x.advanceEm) *
            sz;
        words.add(
          _CalloutWord(
            space ? ' ' : t,
            f,
            sz,
            w,
            bold: seg.bold,
            italic: seg.italic,
            space: space,
          ),
        );
      }
    }
    final lines = <List<_CalloutWord>>[[]];
    var lineW = 0.0;
    for (final w in words) {
      final line = lines.last;
      if (w.space) {
        if (line.isNotEmpty) {
          line.add(w);
          lineW += w.width;
        }
        continue;
      }
      if (!pill && line.isNotEmpty && lineW + w.width > maxWidth) {
        while (line.isNotEmpty && line.last.space) {
          lineW -= line.removeLast().width;
        }
        lines.add([w]);
        lineW = w.width;
      } else {
        line.add(w);
        lineW += w.width;
      }
    }
    for (final l in lines) {
      while (l.isNotEmpty && l.last.space) {
        l.removeLast();
      }
    }
    if (lines.length > 8) lines.removeRange(8, lines.length);
    double widthOf(List<_CalloutWord> l) => l.fold(0.0, (a, w) => a + w.width);
    var textW = 0.0;
    for (final l in lines) {
      textW = math.max(textW, widthOf(l));
    }
    textW = math.min(textW, maxWidth);
    final w = textW + 2 * padX;
    final h = lines.length * lineHeight + 2 * padY;
    final ax = c.anchorX + c.dx, ay = c.anchorY + c.dy + c.rise;
    final gap = label ? calloutGap * 2 : calloutGap;
    final (rx, ry) = switch (c.side) {
      'left' => (ax - gap - w, ay - h / 2),
      'above' => (ax, ay - gap - h),
      'below' => (ax, ay + gap),
      _ => (ax + gap, ay - h / 2),
    };
    final saved = _opacity;
    _opacity *= o;
    if (label) {
      final (ex, ey) = switch (c.side) {
        'left' => (rx + w, ry + h / 2),
        'above' => (rx + padX, ry + h),
        'below' => (rx + padX, ry),
        _ => (rx, ry + h / 2),
      };
      final col = _override ?? c.color;
      if ((col >>> 24) != 0) {
        g.saveContext();
        g.setGraphicState(PdfGraphicState(strokeOpacity: _alpha(col)));
        g
          ..setStrokeColor(_color(col))
          ..setLineWidth(math.max(1, size / 14))
          ..moveTo(ax, ay)
          ..lineTo(ex, ey)
          ..strokePath()
          ..restoreContext();
      }
      final dot = math.max(2.0, size / 7);
      _solid(() => g.drawEllipse(ax, ay, dot, dot), c.color, false);
    } else {
      final radius = pill ? h / 2 : math.min(size * 0.6, 12.0);
      _solid(() => _roundRect(rx, ry, w, h, radius), c.color, false);
      if (!pill) {
        final k = math.min(gap * 0.75, h / 3);
        final pts = switch (c.side) {
          'left' => [
            (rx + w - 1, ry + h / 2 - k / 2),
            (ax - 2, ay),
            (rx + w - 1, ry + h / 2 + k / 2),
          ],
          'above' => [
            (rx + padX, ry + h - 1),
            (ax + padX / 2, ay - 2),
            (rx + padX + k, ry + h - 1),
          ],
          'below' => [
            (rx + padX, ry + 1),
            (ax + padX / 2, ay + 2),
            (rx + padX + k, ry + 1),
          ],
          _ => [
            (rx + 1, ry + h / 2 - k / 2),
            (ax + 2, ay),
            (rx + 1, ry + h / 2 + k / 2),
          ],
        };
        _solid(
          () {
            g.moveTo(pts[0].$1, pts[0].$2);
            g.lineTo(pts[1].$1, pts[1].$2);
            g.lineTo(pts[2].$1, pts[2].$2);
            g.closePath();
          },
          c.color,
          false,
        );
      }
    }
    final face = fonts.faces.faceOf(family, 400, false);
    final ascent = face?.ascent ?? 0.95;
    final descent = face?.descent ?? 0.25;
    for (var i = 0; i < lines.length; i++) {
      final baseline =
          ry +
          padY +
          i * lineHeight +
          (lineHeight - (ascent + descent) * size) / 2 +
          ascent * size;
      var x = rx + padX;
      final right = rx + padX + textW;
      for (final word in lines[i]) {
        if (x >= right - 0.01) break;
        var t = word.text;
        if (x + word.width > right + 0.01) {
          // Pills (one line) and overlong words end in an ellipsis.
          while (t.isNotEmpty &&
              x +
                      fonts
                              .segments(
                                '$t…',
                                word.family,
                                word.bold ? 700 : 400,
                                word.italic,
                              )
                              .fold(0.0, (a, s) => a + s.advanceEm) *
                          word.size >
                  right) {
            t = t.substring(0, t.length - 1);
          }
          t = '$t…';
        }
        x += _codeText(
          t,
          word.family,
          x,
          baseline,
          color: ink,
          size: word.size,
          bold: word.bold,
          italic: word.italic,
        );
      }
    }
    _opacity = saved;
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

/// A word (or space) of a callout line.
final class _CalloutWord {
  const _CalloutWord(
    this.text,
    this.family,
    this.size,
    this.width, {
    required this.bold,
    required this.italic,
    required this.space,
  });

  final String text;
  final String family;
  final double size;
  final double width;
  final bool bold;
  final bool italic;
  final bool space;
}
