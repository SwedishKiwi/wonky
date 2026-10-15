import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show Matrix4;
import 'package:wonky_code_flutter/wonky_code_flutter.dart' show oklabLerp;
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart';

import 'motion_masks.dart';
import '../../stage/flutter_text_layout_engine.dart';
import 'text_range_geometry.dart';

/// Paints a text node with its element's animated state (06 §12.1): part
/// runs (build by paragraph/word/character, typewriter reveals with the
/// caret, after-build dimming, Magic Move glyph runs), highlight sweeps
/// and text color changes — on top of one laid-out paragraph per text
/// paragraph (no relayout per frame).
///
/// Characters outside every animated part are drawn in one pass clipped
/// to their glyph boxes; each animated part is drawn on its own with its
/// transform (element-local), opacity, clip, blur and color, clipped to
/// its glyph boxes. Parts that are fully shown in their resting state
/// join the static pass, so a 2,000-character build draws only the few
/// characters in flight.
abstract final class MotionTextPainter {
  /// Whether [node] needs this painter for [state] (else the plain text
  /// painter draws it).
  static bool handles(TextNode node, ElementVisualState state) {
    if (node.partId != null) return state.colors.containsKey('text');
    return state.parts != null ||
        state.highlights.isNotEmpty ||
        state.colors.containsKey('text') ||
        state.drawProgress < 1;
  }

  /// Paints [node] with [state]; [paintPlain] draws text at an origin
  /// (the stage's `paintText`).
  static void paint(
    Canvas canvas,
    TextNode node,
    ElementVisualState state, {
    required void Function(Canvas, TextLayoutResult, double, double) paintPlain,
    int? fillColorOverride,
  }) {
    final layout = node.layout;
    final ox = node.originX, oy = node.originY;
    final origin = Offset(ox, oy);
    final textColor = state.colors['text'];
    final bounds = _bounds(layout).shift(origin).inflate(4);

    // `lineDraw` on glyph elements (icons): a left-to-right reveal.
    if (state.drawProgress < 1) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          bounds.left,
          bounds.top,
          bounds.width * state.drawProgress.clamp(0.0, 1.0),
          bounds.height,
        ),
      );
    }

    // Highlight sweeps behind the glyphs (marker, box) and under them.
    for (final h in state.highlights) {
      _highlight(canvas, layout, origin, h, behind: true);
    }

    final parts = node.partId == null ? state.parts : null;
    void body() {
      if (parts == null || parts.parts.isEmpty) {
        paintPlain(canvas, layout, ox, oy);
      } else {
        _paintParts(canvas, node, parts.parts, paintPlain);
      }
    }

    if (textColor != null || fillColorOverride != null) {
      final o = textColor ?? ColorOverride(to: fillColorOverride!);
      _tinted(canvas, bounds, o, body);
    } else {
      body();
    }

    for (final h in state.highlights) {
      _highlight(canvas, layout, origin, h, behind: false);
    }
    if (state.drawProgress < 1) canvas.restore();
  }

  static Rect _bounds(TextLayoutResult layout) {
    var w = layout.width;
    for (final l in layout.lines) {
      w = math.max(w, l.left + l.width);
    }
    return Rect.fromLTWH(0, 0, w, math.max(layout.height, 1));
  }

  /// Draws [body] recolored toward [o] (OKLab blend from `from`, or a
  /// tint of the laid-out colors by `mix` when `from` is unknown).
  static void _tinted(
    Canvas canvas,
    Rect bounds,
    ColorOverride o,
    void Function() body,
  ) {
    final mix = o.mix.clamp(0.0, 1.0);
    if (mix <= 0) {
      body();
      return;
    }
    final from = o.from;
    final Color tint;
    double amount;
    if (from != null) {
      tint = Color(oklabLerp(from, o.to, mix));
      amount = 1;
    } else {
      tint = Color(o.to);
      amount = mix;
    }
    canvas.saveLayer(bounds, Paint());
    body();
    canvas.drawRect(
      bounds,
      Paint()
        ..color = tint.withValues(alpha: tint.a * amount)
        ..blendMode = BlendMode.srcATop,
    );
    canvas.restore();
  }

  static void _highlight(
    Canvas canvas,
    TextLayoutResult layout,
    Offset origin,
    TextHighlightState h, {
    required bool behind,
  }) {
    final underline = h.style == 'underline';
    if (behind == underline) return;
    final p = h.progress.clamp(0.0, 1.0);
    if (p <= 0) return;
    final boxes = TextRangeGeometry.boxes(layout, h.start, h.end);
    if (boxes.isEmpty) return;
    // The sweep runs left to right over the boxes in reading order.
    final total = boxes.fold<double>(0, (a, b) => a + b.width);
    var left = total * p;
    final paint = Paint()..color = Color(h.color);
    for (final b0 in boxes) {
      if (left <= 0) break;
      final w = math.min(b0.width, left);
      left -= w;
      final b = Rect.fromLTWH(b0.left, b0.top, w, b0.height).shift(origin);
      switch (h.style) {
        case 'underline':
          final t = math.max(2.0, b.height * 0.08);
          canvas.drawRect(
            Rect.fromLTWH(b.left, b.bottom - t * 1.5, b.width, t),
            paint,
          );
        case 'box':
          canvas.drawRect(
            b.deflate(1),
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2.0, b.height * 0.06),
          );
        default:
          // Marker: a band over the lower ~70 % of the line.
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(
                b.left - 2,
                b.top + b.height * 0.22,
                b.right + 2,
                b.bottom - b.height * 0.04,
              ),
              Radius.circular(b.height * 0.08),
            ),
            paint,
          );
      }
    }
  }

  // ------------------------------------------------------------------
  // Part runs

  static bool _resting(TextPartState s) =>
      s.visible &&
      s.opacity >= 1 &&
      s.dim >= 1 &&
      s.dimColor == null &&
      s.clip == null &&
      s.blurSigma <= 0 &&
      s.revealEnd == null &&
      !s.caret &&
      s.color == null &&
      _isIdentity(s.transform);

  static bool _hidden(TextPartState s) =>
      !s.visible ||
      (s.dimColor == null && s.opacity * s.dim <= 0) ||
      (s.revealEnd != null && s.revealEnd! <= s.start && !s.caret);

  static void _paintParts(
    Canvas canvas,
    TextNode node,
    List<TextPartState> parts,
    void Function(Canvas, TextLayoutResult, double, double) paintPlain,
  ) {
    final layout = node.layout;
    final origin = Offset(node.originX, node.originY);
    final length = TextRangeGeometry.lengthOf(layout);
    // The static pass: everything outside non-resting parts.
    final special = [
      for (final p in parts)
        if (!_resting(p)) p,
    ]..sort((a, b) => a.start.compareTo(b.start));
    if (special.isEmpty) {
      paintPlain(canvas, layout, node.originX, node.originY);
      return;
    }
    final staticBoxes = <Rect>[];
    var at = 0;
    for (final p in special) {
      if (p.start > at) {
        staticBoxes.addAll(TextRangeGeometry.boxes(layout, at, p.start));
      }
      at = math.max(at, p.end);
    }
    if (at < length) {
      staticBoxes.addAll(TextRangeGeometry.boxes(layout, at, length));
    }
    if (staticBoxes.isNotEmpty) {
      canvas.save();
      canvas.clipPath(_pathOf(staticBoxes, origin));
      paintPlain(canvas, layout, node.originX, node.originY);
      canvas.restore();
    }
    for (final p in special) {
      if (_hidden(p)) continue;
      _paintPart(canvas, node, p, origin, paintPlain);
    }
  }

  static void _paintPart(
    Canvas canvas,
    TextNode node,
    TextPartState p,
    Offset origin,
    void Function(Canvas, TextLayoutResult, double, double) paintPlain,
  ) {
    final layout = node.layout;
    final revealEnd = p.revealEnd;
    final end = revealEnd == null ? p.end : math.min(p.end, revealEnd);
    final boxes = end > p.start
        ? TextRangeGeometry.boxes(layout, p.start, end)
        : const <Rect>[];
    final caret = p.caret && revealEnd != null
        ? TextRangeGeometry.caretAt(layout, revealEnd)
        : null;
    if (boxes.isEmpty && caret == null) return;
    final all = TextRangeGeometry.boxes(layout, p.start, p.end);
    final box = TextRangeGeometry.bounds(
      all.isEmpty ? boxes : all,
    ).shift(origin);
    canvas.save();
    if (!_isIdentity(p.transform)) canvas.transform(p.transform.storage);
    final mask = p.clip == null ? null : MotionMask.of(box, clip: p.clip);
    if (mask != null && mask.hidesAll) {
      canvas.restore();
      return;
    }
    mask?.clip(canvas);
    final opacity = p.dimColor != null
        ? p.opacity
        : (p.opacity * p.dim).clamp(0.0, 1.0);
    final blur = p.blurSigma;
    final layered =
        opacity < 1 || blur > 0 || p.dimColor != null || p.color != null;
    final layerBounds = box.inflate(4 + blur * 3);
    if (boxes.isNotEmpty) {
      if (layered) {
        canvas.saveLayer(
          layerBounds,
          Paint()
            ..color = Color.fromRGBO(0, 0, 0, opacity)
            ..imageFilter = blur > 0
                ? ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur)
                : null,
        );
      }
      // Whole parts draw their own glyph runs (cheap for words and
      // characters); typewriter reveals clip the laid-out paragraphs.
      final runs = revealEnd == null
          ? _glyphRuns(layout, p.start, p.end)
          : null;
      void glyphs() {
        if (runs != null) {
          for (final (para, at) in runs) {
            canvas.drawParagraph(para, at + origin);
          }
        } else {
          canvas.save();
          canvas.clipPath(_pathOf(boxes, origin));
          paintPlain(canvas, layout, node.originX, node.originY);
          canvas.restore();
        }
      }

      if (p.color != null) {
        _tinted(canvas, layerBounds, p.color!, glyphs);
      } else {
        glyphs();
      }
      if (p.dimColor != null) {
        canvas.drawRect(
          layerBounds,
          Paint()
            ..color = Color(p.dimColor!)
            ..blendMode = BlendMode.srcATop,
        );
      }
      if (layered) canvas.restore();
    }
    if (caret != null) {
      final color = TextRangeGeometry.colorAt(layout, revealEnd!) ?? 0xff000000;
      final w = math.max(2.0, caret.height * 0.06);
      canvas.drawRect(
        Rect.fromLTWH(
          caret.left + origin.dx,
          caret.top + origin.dy + caret.height * 0.1,
          w,
          caret.height * 0.8,
        ),
        Paint()..color = Color(color).withValues(alpha: opacity),
      );
    }
    canvas.restore();
  }

  static final Expando<Map<int, List<(ui.Paragraph, Offset)>>> _runs = Expando(
    'partGlyphRuns',
  );

  /// The glyphs of `[start, end)` as one-line paragraphs per style run at
  /// their laid-out positions (relative to the text origin), or null for
  /// layouts of other engines. Cached per layout and range.
  static List<(ui.Paragraph, Offset)>? _glyphRuns(
    TextLayoutResult layout,
    int start,
    int end,
  ) {
    if (FlutterTextLayoutEngine.paragraphsOf(layout) == null) return null;
    final cache = _runs[layout.lines] ??= {};
    final key = start * 0x100000 + end;
    final hit = cache[key];
    if (hit != null) return hit;
    if (cache.length > 8192) cache.clear();
    final out = <(ui.Paragraph, Offset)>[];
    for (final line in layout.lines) {
      final bullet = line.bullet;
      if (bullet != null && line.start >= start && line.start < end) {
        final para = _paragraph(bullet, bullet.text);
        out.add((
          para,
          Offset(
            line.left + bullet.x,
            line.baseline - para.alphabeticBaseline - bullet.baselineShift,
          ),
        ));
      }
      if (line.end <= start || line.start >= end) continue;
      for (final r in line.runs) {
        final a = math.max(start, r.start);
        final b = math.min(end, r.start + r.text.length);
        if (b <= a) continue;
        final boxes = TextRangeGeometry.boxes(layout, a, b);
        if (boxes.isEmpty) continue;
        final para = _paragraph(r, r.text.substring(a - r.start, b - r.start));
        out.add((
          para,
          Offset(
            boxes.first.left,
            line.baseline - para.alphabeticBaseline - r.baselineShift,
          ),
        ));
      }
    }
    return cache[key] = out;
  }

  static ui.Paragraph _paragraph(TextRunBox r, String text) {
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(maxLines: 1))
      ..pushStyle(
        ui.TextStyle(
          color: Color(r.color),
          fontFamily: r.fontFamily.isEmpty ? null : r.fontFamily,
          fontSize: r.fontSize,
          fontWeight:
              FontWeight.values[((r.fontWeight ~/ 100) - 1).clamp(0, 8)],
          fontStyle: r.italic ? FontStyle.italic : FontStyle.normal,
          letterSpacing: r.letterSpacing,
          decoration: TextDecoration.combine([
            if (r.underline) TextDecoration.underline,
            if (r.strike) TextDecoration.lineThrough,
          ]),
          decorationColor: Color(r.color),
          background: r.highlight == null
              ? null
              : (Paint()..color = Color(r.highlight!)),
        ),
      )
      ..addText(text);
    return b.build()..layout(const ui.ParagraphConstraints(width: 1e6));
  }

  static Path _pathOf(List<Rect> boxes, Offset origin) {
    final path = Path();
    for (final b in boxes) {
      // A little vertical room for glyphs that overhang their line box.
      path.addRect(
        Rect.fromLTRB(
          b.left,
          b.top - b.height * 0.04,
          b.right,
          b.bottom + b.height * 0.04,
        ).shift(origin),
      );
    }
    return path;
  }

  static bool _isIdentity(Matrix4 m) {
    final s = m.storage;
    for (var i = 0; i < 16; i++) {
      if (s[i] != (i % 5 == 0 ? 1.0 : 0.0)) return false;
    }
    return true;
  }
}
