import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:wonky_slides_core/scene.dart';

import '../../stage/flutter_text_layout_engine.dart';

/// Glyph boxes of plain-text ranges in a laid-out text body (06 §12.1:
/// part runs, typewriter reveals, highlight sweeps; the stage's
/// `TextPartGeometryProvider`). Boxes are relative to the text node's
/// origin. Flutter layouts measure with `Paragraph.getBoxesForRange`;
/// other engines' layouts are approximated from their runs.
abstract final class TextRangeGeometry {
  static final Expando<Map<int, List<Rect>>> _cache = Expando('textBoxes');

  /// The line-by-line boxes of `[start, end)` in [layout] (list markers
  /// belong to the range that holds their paragraph's first character).
  static List<Rect> boxes(TextLayoutResult layout, int start, int end) {
    if (end <= start) return const [];
    final cache = _cache[layout.lines] ??= {};
    final key = start * 0x100000 + end;
    final hit = cache[key];
    if (hit != null) return hit;
    if (cache.length > 4096) cache.clear();
    final out = _measure(layout, start, end);
    return cache[key] = out;
  }

  static List<Rect> _measure(TextLayoutResult layout, int start, int end) {
    final paras = FlutterTextLayoutEngine.paragraphsOf(layout);
    final out = <Rect>[];
    if (paras != null) {
      for (final p in paras.paragraphs) {
        if (p.marker) {
          if (p.start >= start && p.start < end) {
            out.add(
              Rect.fromLTWH(
                p.dx,
                p.dy,
                p.paragraph.maxIntrinsicWidth,
                p.paragraph.height,
              ),
            );
          }
          continue;
        }
        final a = math.max(start, p.start);
        final b = math.min(end, p.start + p.length);
        if (b <= a) continue;
        for (final box in p.paragraph.getBoxesForRange(
          a - p.start,
          b - p.start,
          boxHeightStyle: ui.BoxHeightStyle.max,
        )) {
          out.add(box.toRect().shift(Offset(p.dx, p.dy)));
        }
      }
      return _merge(out);
    }
    for (final line in layout.lines) {
      final bullet = line.bullet;
      if (bullet != null && line.start >= start && line.start < end) {
        out.add(
          Rect.fromLTWH(
            line.left + bullet.x,
            line.top,
            bullet.width,
            line.height,
          ),
        );
      }
      for (final r in line.runs) {
        final len = r.text.length;
        final a = math.max(start, r.start);
        final b = math.min(end, r.start + len);
        if (b <= a || len == 0) continue;
        final x0 = line.left + r.x + r.width * (a - r.start) / len;
        final x1 = line.left + r.x + r.width * (b - r.start) / len;
        out.add(Rect.fromLTRB(x0, line.top, x1, line.top + line.height));
      }
    }
    return _merge(out);
  }

  /// Joins boxes that touch on the same line (fewer clip rects).
  static List<Rect> _merge(List<Rect> boxes) {
    if (boxes.length < 2) return boxes;
    final out = <Rect>[boxes.first];
    for (final b in boxes.skip(1)) {
      final last = out.last;
      if ((last.top - b.top).abs() < 0.01 &&
          (last.bottom - b.bottom).abs() < 0.01 &&
          (b.left - last.right).abs() < 0.5) {
        out[out.length - 1] = last.expandToInclude(b);
      } else {
        out.add(b);
      }
    }
    return out;
  }

  /// The bounds of [boxes] (empty → [Rect.zero]).
  static Rect bounds(List<Rect> boxes) {
    if (boxes.isEmpty) return Rect.zero;
    var r = boxes.first;
    for (final b in boxes.skip(1)) {
      r = r.expandToInclude(b);
    }
    return r;
  }

  /// The caret rectangle before plain offset [offset] (after the last
  /// character of the body when it is past the end), or null.
  static Rect? caretAt(TextLayoutResult layout, int offset) {
    if (offset > 0) {
      final before = boxes(layout, offset - 1, offset);
      if (before.isNotEmpty) {
        final b = before.last;
        return Rect.fromLTWH(b.right, b.top, 0, b.height);
      }
    }
    final after = boxes(layout, offset, offset + 1);
    if (after.isNotEmpty) {
      final b = after.first;
      return Rect.fromLTWH(b.left, b.top, 0, b.height);
    }
    if (layout.lines.isEmpty) return null;
    final l = layout.lines.first;
    return Rect.fromLTWH(l.left, l.top, 0, l.height);
  }

  /// The text color at plain [offset] (caret color), or null.
  static int? colorAt(TextLayoutResult layout, int offset) {
    int? last;
    for (final line in layout.lines) {
      for (final r in line.runs) {
        last = r.color;
        if (offset >= r.start && offset <= r.start + r.text.length) {
          return r.color;
        }
      }
    }
    return last;
  }

  /// The plain-text length of [layout].
  static int lengthOf(TextLayoutResult layout) =>
      layout.lines.isEmpty ? 0 : layout.lines.last.end;
}
