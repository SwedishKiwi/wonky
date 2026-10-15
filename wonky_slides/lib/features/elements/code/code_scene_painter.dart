import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;

/// Paints a code element's [CodeScene] (Slides 07 §3.3–§5) on a canvas in
/// element-local slide units: box (background, border, corner radius),
/// chrome (tab, window bar with traffic lights, caption, language badge),
/// highlight bars/boxes, selections and gutter markers, line numbers
/// (active color on highlighted lines, `↪` on wrapped rows), token runs on
/// the monospace grid with per-line opacity and blur, morph glyphs and
/// gutter labels, the type-in caret, callouts (bubble, label, pill with
/// inline Markdown) and the crossfade underlay. The shadow is the scene
/// group's effect (scene builder).
///
/// Used by the stage (`SlideScenePainter`) for every surface: canvas,
/// thumbnails, presenting and previews (SL-31).
abstract final class CodeScenePainter {
  /// Traffic lights of the window chrome (macOS colors).
  static const trafficLights = [0xffff5f57, 0xfffebc2e, 0xff28c840];

  /// Gap between a callout and its anchor (su).
  static const calloutGap = 16.0;

  /// Paints [s] into [dst] (element-local su; scaled when the scene's
  /// size differs).
  static void paint(Canvas canvas, CodeScene s, SuRect dst) {
    if (s.width <= 0 || s.height <= 0) return;
    canvas.save();
    canvas.translate(dst.x, dst.y);
    if (dst.width != s.width || dst.height != s.height) {
      canvas.scale(dst.width / s.width, dst.height / s.height);
    }
    final under = s.underlay;
    if (under != null && s.underlayOpacity > 0) {
      _layer(canvas, s.underlayOpacity, () => _scene(canvas, under));
    }
    _layer(canvas, s.opacity, () => _scene(canvas, s));
    canvas.restore();
  }

  static void _layer(Canvas canvas, double opacity, void Function() paint) {
    final o = opacity.clamp(0.0, 1.0);
    if (o <= 0) return;
    if (o >= 1) {
      paint();
      return;
    }
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, o));
    paint();
    canvas.restore();
  }

  static Rect _rect(SuRect r) => Rect.fromLTWH(r.x, r.y, r.width, r.height);

  static void _scene(Canvas canvas, CodeScene s) {
    final box = s.box == null
        ? Rect.fromLTWH(0, 0, s.width, s.height)
        : _rect(s.box!);
    final radius = math.min(s.cornerRadius, box.shortestSide / 2);
    final rrect = RRect.fromRectAndRadius(box, Radius.circular(radius));
    if ((s.background >>> 24) != 0) {
      canvas.drawRRect(rrect, Paint()..color = Color(s.background));
    }
    _chrome(canvas, s, box, rrect);

    // Code area (clipped vertically; the gutter is inside the box).
    final area = s.codeArea == null ? box : _rect(s.codeArea!);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.clipRect(Rect.fromLTRB(box.left, area.top, box.right, area.bottom));
    _bars(canvas, s, area, under: true);
    _lines(canvas, s, area);
    _glyphs(canvas, s);
    _bars(canvas, s, area, under: false);
    _caret(canvas, s);
    canvas.restore();

    if (s.border != null && s.borderWidth > 0 && (s.border! >>> 24) != 0) {
      canvas.drawRRect(
        rrect.deflate(s.borderWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.borderWidth
          ..color = Color(s.border!),
      );
    }
    for (final c in s.callouts) {
      _callout(canvas, s, c);
    }
  }

  // ---------------------------------------------------------------- chrome

  static void _chrome(Canvas canvas, CodeScene s, Rect box, RRect rrect) {
    final titleFont = s.gutterFontSize > 0 ? s.gutterFontSize : s.fontSize;
    if (s.chrome == 'caption' && s.title != null && s.captionHeight > 0) {
      final p = _paragraph(
        s.title!,
        color: s.titleColor,
        family: s.fontFamily,
        size: titleFont,
        ligatures: s.ligatures,
      );
      canvas.drawParagraph(
        p,
        Offset(box.left, (s.captionHeight - p.height) / 2),
      );
      return;
    }
    final h = s.titleHeight;
    if (h <= 0 || (s.chrome != 'tab' && s.chrome != 'window')) return;
    final strip = Rect.fromLTWH(box.left, box.top, box.width, h);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(strip, Paint()..color = Color(s.titleBackground));
    final title = s.title;
    final badge = s.language;
    final padX = h * 0.45;
    if (s.chrome == 'window') {
      final r = h * 0.14;
      for (final (i, c) in trafficLights.indexed) {
        canvas.drawCircle(
          Offset(box.left + padX + r + i * r * 3.2, strip.center.dy),
          r,
          Paint()..color = Color(c),
        );
      }
      if (title != null) {
        final p = _paragraph(
          title,
          color: s.titleColor,
          family: s.fontFamily,
          size: titleFont,
          ligatures: s.ligatures,
          maxWidth: math.max(10, box.width - 2 * (padX + 10 * r)),
          ellipsis: true,
        );
        canvas.drawParagraph(
          p,
          Offset(
            strip.center.dx - p.maxIntrinsicWidth.clamp(0, p.width) / 2,
            strip.center.dy - p.height / 2,
          ),
        );
      }
    } else if (title != null) {
      // A rounded tab in the code background at the top left.
      final p = _paragraph(
        title,
        color: s.titleColor,
        family: s.fontFamily,
        size: titleFont,
        ligatures: s.ligatures,
        maxWidth: math.max(10, box.width * 0.7),
        ellipsis: true,
      );
      final tabTop = box.top + h * 0.22;
      final tab = Rect.fromLTRB(
        box.left + padX * 0.6,
        tabTop,
        box.left +
            padX * 0.6 +
            math.min(p.maxIntrinsicWidth, p.width) +
            2 * padX,
        box.top + h,
      );
      final tr = math.min(h * 0.25, 12.0);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          tab,
          topLeft: Radius.circular(tr),
          topRight: Radius.circular(tr),
        ),
        Paint()..color = Color(s.background),
      );
      canvas.drawParagraph(
        p,
        Offset(tab.left + padX, tab.center.dy - p.height / 2),
      );
    }
    if (badge != null) {
      final p = _paragraph(
        badge,
        color: s.lineNumberColor,
        family: s.fontFamily,
        size: titleFont * 0.9,
        ligatures: s.ligatures,
      );
      canvas.drawParagraph(
        p,
        Offset(
          box.right - padX - p.maxIntrinsicWidth,
          strip.center.dy - p.height / 2,
        ),
      );
    }
    canvas.restore();
  }

  // ------------------------------------------------------------------ bars

  static void _bars(
    Canvas canvas,
    CodeScene s,
    Rect area, {
    required bool under,
  }) {
    for (final b in s.bars) {
      // Highlight bars, boxes and selections go under the text; gutter
      // markers and box outlines over it.
      final isUnder =
          b.kind == CodeBarKind.bar || b.kind == CodeBarKind.selection;
      if (isUnder != under) continue;
      final o = b.opacity.clamp(0.0, 1.0);
      if (o <= 0) continue;
      final c = Color(b.color);
      final paint = Paint()
        ..color = c.withValues(alpha: c.a * o)
        ..isAntiAlias = true;
      final r = RRect.fromRectAndRadius(
        _rect(b.rect),
        Radius.circular(b.radius),
      );
      if (b.strokeWidth > 0) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = b.strokeWidth;
        canvas.drawRRect(r.deflate(b.strokeWidth / 2), paint);
      } else {
        canvas.drawRRect(r, paint);
      }
    }
  }

  // ----------------------------------------------------------------- lines

  static void _lines(Canvas canvas, CodeScene s, Rect area) {
    final numberSize = s.gutterFontSize > 0 ? s.gutterFontSize : s.fontSize;
    for (final l in s.lines) {
      final baseline = s.chromeHeight + l.y;
      final o = l.opacity.clamp(0.0, 1.0);
      if (o <= 0) continue;
      final blur = l.blurSigma;
      final layered = o < 1 || blur > 0;
      if (layered) {
        final pad = blur * 3 + s.lineHeight;
        canvas.saveLayer(
          Rect.fromLTRB(
            -pad,
            baseline - s.lineHeight - pad,
            s.width + pad,
            baseline + s.lineHeight + pad,
          ),
          Paint()
            ..color = Color.fromRGBO(0, 0, 0, o)
            ..imageFilter = blur > 0
                ? ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur)
                : null,
        );
      }
      if (s.numbersRight case final right?) {
        final label = l.continuation ? '↪' : '${l.number}';
        final p = _paragraph(
          label,
          color: l.highlighted ? s.lineNumberActiveColor : s.lineNumberColor,
          family: s.fontFamily,
          size: numberSize,
          ligatures: false,
        );
        canvas.drawParagraph(
          p,
          Offset(right - p.maxIntrinsicWidth, baseline - p.alphabeticBaseline),
        );
      }
      for (final r in l.runs) {
        if (r.text.isEmpty) continue;
        final c = Color(r.color);
        final color = r.opacity < 1
            ? (c.withValues(alpha: c.a * r.opacity.clamp(0.0, 1.0)))
            : c;
        final p = _paragraph(
          r.text,
          color: color.toARGB32(),
          family: s.fontFamily,
          size: s.fontSize,
          bold: r.bold,
          italic: r.italic,
          ligatures: s.ligatures,
        );
        canvas.drawParagraph(
          p,
          Offset(
            s.codeLeft + r.column * s.columnWidth,
            baseline - p.alphabeticBaseline,
          ),
        );
      }
      if (layered) canvas.restore();
    }
  }

  static void _glyphs(Canvas canvas, CodeScene s) {
    for (final g in s.glyphs) {
      final o = g.opacity.clamp(0.0, 1.0);
      if (o <= 0 || g.text.isEmpty) continue;
      final c = Color(g.color);
      final p = _paragraph(
        g.text,
        color: c.withValues(alpha: c.a * o).toARGB32(),
        family: s.fontFamily,
        size: g.fontSize,
        bold: g.bold,
        italic: g.italic,
        ligatures: false,
      );
      canvas.drawParagraph(p, Offset(g.x, g.baseline - p.alphabeticBaseline));
    }
    final right = s.numbersRight;
    if (right == null) return;
    final size = s.gutterFontSize > 0 ? s.gutterFontSize : s.fontSize;
    for (final g in s.gutter) {
      final o = g.opacity.clamp(0.0, 1.0);
      if (o <= 0) continue;
      final c = Color(g.color);
      final p = _paragraph(
        g.text,
        color: c.withValues(alpha: c.a * o).toARGB32(),
        family: s.fontFamily,
        size: size,
        ligatures: false,
      );
      canvas.drawParagraph(
        p,
        Offset(right - p.maxIntrinsicWidth, g.baseline - p.alphabeticBaseline),
      );
    }
  }

  static void _caret(Canvas canvas, CodeScene s) {
    final c = s.caret;
    if (c == null || c.opacity <= 0) return;
    final color = Color(c.color);
    final alpha = c.style == 'block' ? 0.55 : 1.0;
    canvas.drawRect(
      _rect(c.rect),
      Paint()
        ..color = color.withValues(
          alpha: color.a * alpha * c.opacity.clamp(0.0, 1.0),
        ),
    );
  }

  // -------------------------------------------------------------- callouts

  static void _callout(Canvas canvas, CodeScene s, CodeCalloutPlacement c) {
    final o = c.opacity.clamp(0.0, 1.0);
    if (o <= 0 || c.text.trim().isEmpty) return;
    final family = c.fontFamily.isEmpty ? s.fontFamily : c.fontFamily;
    final label = c.style == 'label';
    final pill = c.style == 'pill';
    final ink = label ? c.color : c.textColor;
    final padX = c.fontSize * (pill ? 0.7 : 0.8);
    final padY = c.fontSize * (pill ? 0.3 : 0.55);
    final p = _calloutParagraph(
      c.text,
      color: ink,
      family: family,
      codeFamily: s.fontFamily,
      size: c.fontSize,
      maxWidth: math.max(c.fontSize * 4, c.maxWidth - 2 * padX),
      singleLine: pill,
    );
    final w = math.min(p.maxIntrinsicWidth, p.width) + 2 * padX;
    final h = p.height + 2 * padY;
    final ax = c.anchorX + c.dx, ay = c.anchorY + c.dy + c.rise;
    final gap = label ? calloutGap * 2 : calloutGap;
    final rect = switch (c.side) {
      'left' => Rect.fromLTWH(ax - gap - w, ay - h / 2, w, h),
      'above' => Rect.fromLTWH(ax, ay - gap - h, w, h),
      'below' => Rect.fromLTWH(ax, ay + gap, w, h),
      _ => Rect.fromLTWH(ax + gap, ay - h / 2, w, h),
    };
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, o));
    final fill = Paint()..color = Color(c.color);
    if (label) {
      // Text with a thin leader line from the anchor.
      final end = switch (c.side) {
        'left' => Offset(rect.right, rect.center.dy),
        'above' => Offset(rect.left + padX, rect.bottom),
        'below' => Offset(rect.left + padX, rect.top),
        _ => Offset(rect.left, rect.center.dy),
      };
      canvas.drawLine(
        Offset(ax, ay),
        end,
        Paint()
          ..color = Color(c.color)
          ..strokeWidth = math.max(1, c.fontSize / 14),
      );
      canvas.drawCircle(Offset(ax, ay), math.max(2, c.fontSize / 7), fill);
    } else {
      final radius = pill ? h / 2 : math.min(c.fontSize * 0.6, 12.0);
      final path = Path()
        ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
      if (!pill) {
        // Pointer toward the anchor.
        final k = math.min(gap * 0.75, h / 3);
        final pointer = switch (c.side) {
          'left' => [
            Offset(rect.right - 1, rect.center.dy - k / 2),
            Offset(ax - 2, ay),
            Offset(rect.right - 1, rect.center.dy + k / 2),
          ],
          'above' => [
            Offset(rect.left + padX, rect.bottom - 1),
            Offset(ax + padX / 2, ay - 2),
            Offset(rect.left + padX + k, rect.bottom - 1),
          ],
          'below' => [
            Offset(rect.left + padX, rect.top + 1),
            Offset(ax + padX / 2, ay + 2),
            Offset(rect.left + padX + k, rect.top + 1),
          ],
          _ => [
            Offset(rect.left + 1, rect.center.dy - k / 2),
            Offset(ax + 2, ay),
            Offset(rect.left + 1, rect.center.dy + k / 2),
          ],
        };
        path.addPolygon(pointer, true);
      }
      canvas.drawShadow(path, const Color(0xff000000), 4, false);
      canvas.drawPath(path, fill);
    }
    canvas.drawParagraph(p, Offset(rect.left + padX, rect.top + padY));
    canvas.restore();
  }

  /// Inline Markdown of callouts (07 §4.4: `**bold**`, `*italic*` /
  /// `_italic_`, `` `code` ``) as styled segments.
  static List<(String, {bool bold, bool italic, bool code})> inlineMarkdown(
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

  static ui.Paragraph _calloutParagraph(
    String text, {
    required int color,
    required String family,
    required String codeFamily,
    required double size,
    required double maxWidth,
    bool singleLine = false,
  }) {
    final b = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        maxLines: singleLine ? 1 : 8,
        ellipsis: '…',
        fontFamily: family,
        fontSize: size,
        height: 1.3,
      ),
    );
    for (final seg in inlineMarkdown(text)) {
      b
        ..pushStyle(
          ui.TextStyle(
            color: Color(color),
            fontFamily: seg.code ? codeFamily : family,
            fontSize: seg.code ? size * 0.92 : size,
            fontWeight: seg.bold ? FontWeight.w700 : FontWeight.w400,
            fontStyle: seg.italic ? FontStyle.italic : FontStyle.normal,
          ),
        )
        ..addText(seg.$1)
        ..pop();
    }
    return b.build()..layout(ui.ParagraphConstraints(width: maxWidth));
  }

  // ------------------------------------------------------------ paragraphs

  static final LinkedHashMap<String, ui.Paragraph> _cache = LinkedHashMap();
  static const _cacheSize = 4000;
  static bool _watchingFonts = false;

  /// Drops the cached paragraphs when the engine's fonts change: bundled
  /// families load on demand (web), and a paragraph laid out before its
  /// family arrived keeps the fallback font (proportional code with gaps
  /// between the grid-placed runs — SL-36).
  static void _watchFonts() {
    if (_watchingFonts) return;
    _watchingFonts = true;
    PaintingBinding.instance.systemFonts.addListener(_cache.clear);
  }

  /// A cached one-line code paragraph (tests).
  @visibleForTesting
  static ui.Paragraph debugParagraph(String text, {required String family}) =>
      _paragraph(
        text,
        color: 0xff000000,
        family: family,
        size: 20,
        ligatures: false,
      );

  /// A one-line paragraph of [text] (cached by text and style).
  static ui.Paragraph _paragraph(
    String text, {
    required int color,
    required String family,
    required double size,
    bool bold = false,
    bool italic = false,
    required bool ligatures,
    double? maxWidth,
    bool ellipsis = false,
  }) {
    _watchFonts();
    final key =
        '$color|$family|$size|$bold|$italic|$ligatures|$maxWidth|$ellipsis|$text';
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }
    final b =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(maxLines: 1, ellipsis: ellipsis ? '…' : null),
          )
          ..pushStyle(
            ui.TextStyle(
              color: Color(color),
              fontFamily: family,
              fontSize: size,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              fontFeatures: ligatures
                  ? null
                  : const [
                      FontFeature.disable('calt'),
                      FontFeature.disable('liga'),
                    ],
            ),
          )
          ..addText(text);
    final p = b.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth ?? 1e6));
    _cache[key] = p;
    if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first);
    return p;
  }
}
