import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:wonky_slides_core/scene.dart';

/// The Flutter [TextLayoutEngine] (03 §6.3, 12 §5.4): `dart:ui` paragraphs
/// over the shared [TextParagraphs] model, so the static canvas, the
/// editing overlay, thumbnails, presenting and client PDFs get the same
/// line breaks. The laid-out paragraphs are kept with the result for
/// painting ([FlutterTextLayoutEngine.paragraphsOf]).
class FlutterTextLayoutEngine implements TextLayoutEngine {
  /// Creates an engine. [fontGeneration] (the font registry's counter) is
  /// part of the cache key, so layouts made with fallback metrics are
  /// redone once the bundled faces are registered (05 §3.3).
  FlutterTextLayoutEngine({this.cacheSize = 512, this.fontGeneration});

  /// Maximum cached layouts.
  final int cacheSize;

  /// The font registry's generation.
  final ValueListenable<int>? fontGeneration;

  final LinkedHashMap<String, TextLayoutResult> _cache = LinkedHashMap();

  static final Expando<FlutterTextLines> _paragraphs = Expando(
    'flutterTextLines',
  );

  /// The paragraphs [result] was laid out with, or null for results of
  /// another engine.
  static FlutterTextLines? paragraphsOf(TextLayoutResult result) =>
      _paragraphs[result.lines];

  /// How many layouts were computed (tests, benchmarks).
  @visibleForTesting
  int debugLayouts = 0;

  @override
  TextLayoutResult layout(
    TextBody body,
    ResolvedTextStyles styles, {
    required double width,
    double scale = 1,
  }) {
    final key =
        '${body.toJson()}|${textStylesKey(styles)}|$width|$scale|'
        '${fontGeneration?.value ?? 0}';
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    final r = _layout(body, styles, width, scale);
    _cache[key] = r;
    while (_cache.length > cacheSize) {
      _cache.remove(_cache.keys.first);
    }
    return r;
  }

  /// Drops every cached layout.
  void clear() => _cache.clear();

  TextLayoutResult _layout(
    TextBody body,
    ResolvedTextStyles styles,
    double width,
    double scale,
  ) {
    debugLayouts++;
    final paras = TextParagraphs.build(body, styles, scale: scale);
    final lines = <TextLineBox>[];
    final placed = <PlacedParagraph>[];
    var y = 0.0;
    var maxRight = 0.0;
    for (var pi = 0; pi < paras.length; pi++) {
      final p = paras[pi];
      if (pi > 0) y += p.spaceBefore;
      final avail = math.max(1.0, width - p.textIndent);
      final text = p.isEmpty ? '​' : p.text;
      final para = _paragraph(p, text)
        ..layout(ui.ParagraphConstraints(width: avail));
      placed.add(PlacedParagraph(para, p.textIndent, y));
      final metrics = para.computeLineMetrics();
      final ranges = _lineRanges(para, text, metrics.length);
      for (var li = 0; li < metrics.length; li++) {
        final m = metrics[li];
        final range = li < ranges.length
            ? ranges[li]
            : TextRange(start: text.length, end: text.length);
        final runs = p.isEmpty
            ? const <TextRunBox>[]
            : _runsOn(p, para, range, m.left);
        TextRunBox? bullet;
        if (li == 0 && p.marker != null) {
          final mp = _markerParagraph(p.marker!);
          placed.add(
            PlacedParagraph(
              mp,
              p.markerX,
              y + m.baseline - mp.alphabeticBaseline,
            ),
          );
          bullet = p.marker!.box(
            x: p.markerX - (p.textIndent + m.left),
            width: mp.maxIntrinsicWidth,
          );
        }
        final start = p.start + math.min<int>(range.start, p.text.length);
        final end = p.start + math.min<int>(range.end, p.text.length);
        lines.add(
          TextLineBox(
            top: y + m.baseline - m.ascent,
            baseline: y + m.baseline,
            height: m.height,
            left: p.textIndent + m.left,
            width: p.isEmpty ? 0 : m.width,
            start: start,
            end: end,
            runs: runs,
            paragraph: p.index,
            bullet: bullet,
          ),
        );
        maxRight = math.max(maxRight, p.textIndent + m.left + m.width);
      }
      y += para.height;
      if (pi < paras.length - 1) y += p.spaceAfter;
    }
    _paragraphs[lines] = FlutterTextLines(placed);
    return TextLayoutResult(
      width: width,
      height: y,
      lines: lines,
      fitScale: scale,
    );
  }

  static ui.TextStyle _style(StyledRun r, double lineHeight) => ui.TextStyle(
    color: Color(r.color),
    fontFamily: r.fontFamily,
    fontSize: r.fontSize,
    fontWeight: FontWeight.values[((r.fontWeight ~/ 100) - 1).clamp(0, 8)],
    fontStyle: r.italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: r.letterSpacing,
    height: lineHeight,
    leadingDistribution: TextLeadingDistribution.even,
    decoration: TextDecoration.combine([
      if (r.underline) TextDecoration.underline,
      if (r.strike) TextDecoration.lineThrough,
    ]),
    decorationColor: Color(r.color),
    background: r.highlight == null
        ? null
        : (Paint()..color = Color(r.highlight!)),
  );

  static ui.Paragraph _paragraph(StyledParagraph p, String text) {
    final b = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: switch (p.align) {
          'center' => TextAlign.center,
          'right' => TextAlign.right,
          'justify' => TextAlign.justify,
          _ => p.rtl ? TextAlign.right : TextAlign.left,
        },
        textDirection: p.rtl ? TextDirection.rtl : TextDirection.ltr,
        fontFamily: p.mark.fontFamily,
        fontSize: p.mark.fontSize,
        height: p.lineHeight,
        textHeightBehavior: const ui.TextHeightBehavior(
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
    );
    if (p.isEmpty) {
      b
        ..pushStyle(_style(p.mark, p.lineHeight))
        ..addText(text);
    } else {
      for (final r in p.runs) {
        b
          ..pushStyle(_style(r, p.lineHeight))
          ..addText(r.text)
          ..pop();
      }
    }
    return b.build();
  }

  static ui.Paragraph _markerParagraph(StyledRun marker) {
    final b = ui.ParagraphBuilder(ui.ParagraphStyle())
      ..pushStyle(_style(marker, 1))
      ..addText(marker.text);
    return b.build()..layout(const ui.ParagraphConstraints(width: 10000));
  }

  /// The character range of each line (line boundaries; a hard soft-break
  /// separator is skipped).
  static List<TextRange> _lineRanges(ui.Paragraph p, String text, int count) {
    final out = <TextRange>[];
    var offset = 0;
    while (out.length < count && offset <= text.length) {
      final r = p.getLineBoundary(TextPosition(offset: offset));
      out.add(r);
      var next = r.end;
      if (next < text.length &&
          (text.codeUnitAt(next) == 0x2028 || text.codeUnitAt(next) == 0x0a)) {
        next++;
      }
      if (next <= offset) next = offset + 1;
      offset = next;
    }
    return out;
  }

  /// The runs of [p] on the line [range] with positions relative to the
  /// line's left edge [lineLeft].
  static List<TextRunBox> _runsOn(
    StyledParagraph p,
    ui.Paragraph para,
    TextRange range,
    double lineLeft,
  ) {
    final out = <TextRunBox>[];
    var local = 0;
    for (final r in p.runs) {
      final from = math.max(local, range.start);
      final to = math.min(local + r.text.length, range.end);
      if (to > from) {
        final boxes = para.getBoxesForRange(from, to);
        if (boxes.isNotEmpty) {
          final left = boxes.map((b) => b.left).reduce(math.min);
          final right = boxes.map((b) => b.right).reduce(math.max);
          out.add(
            r
                .slice(
                  r.text.substring(from - local, to - local),
                  r.start + from - local,
                )
                .box(x: left - lineLeft, width: right - left),
          );
        }
      }
      local += r.text.length;
    }
    return out;
  }
}

/// A paragraph placed in a text layout (element-local su, relative to the
/// text node's origin).
class PlacedParagraph {
  PlacedParagraph(this.paragraph, this.dx, this.dy);

  final ui.Paragraph paragraph;
  final double dx;
  final double dy;
}

/// The paragraphs (and list markers) of a Flutter text layout.
class FlutterTextLines {
  FlutterTextLines(this.paragraphs);

  final List<PlacedParagraph> paragraphs;
}
