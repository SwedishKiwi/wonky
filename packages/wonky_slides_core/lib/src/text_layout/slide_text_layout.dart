/// The pure-Dart `TextLayoutEngine` (12 §5.4 `SlideTextLayout`): greedy
/// line breaking at whitespace/hyphen/CJK opportunities over the shared
/// [TextParagraphs] model, with an injectable [SlideTextMeasurer] (font
/// metrics: the `pdf` package's TTF metrics on the server, an
/// approximation in tests and headless previews).
library;

import 'dart:collection';
import 'dart:math' as math;

import '../scene/nodes/text_layout.dart';
import 'text_paragraphs.dart';

/// Vertical metrics of a face as fractions of the font size.
final class FontVMetrics {
  /// Creates metrics.
  const FontVMetrics(this.ascent, this.descent);

  /// Above the baseline (positive).
  final double ascent;

  /// Below the baseline (positive).
  final double descent;
}

/// Measures text for [SlideTextLayout].
abstract interface class SlideTextMeasurer {
  /// The advance width of [text] in [run]'s face and size (letter spacing
  /// included).
  double width(String text, StyledRun run);

  /// The vertical metrics of [run]'s face.
  FontVMetrics metrics(StyledRun run);
}

/// An approximate measurer: per-character advance classes of a typical
/// sans-serif face. Deterministic; used by tests and as the headless
/// fallback until real font metrics are wired (SL-20).
final class ApproxTextMeasurer implements SlideTextMeasurer {
  /// Creates the measurer.
  const ApproxTextMeasurer({this.ascent = 0.95, this.descent = 0.25});

  final double ascent;
  final double descent;

  /// The advance of [c] in em.
  static double advance(int c) {
    if (c == 0x20 || c == 0xa0) return 0.28;
    if (c >= 0x2e80 && c <= 0x9fff || c >= 0xac00 && c <= 0xd7af) return 1.0;
    if (c >= 0x1f300 && c <= 0x1faff) return 1.2;
    const narrow = 'iljtfr.,;:!|\'"()[]{}`';
    const wide = 'mwMW@%';
    final ch = String.fromCharCode(c);
    if (narrow.contains(ch)) return 0.3;
    if (wide.contains(ch)) return 0.85;
    if (c >= 0x41 && c <= 0x5a) return 0.66;
    if (c >= 0x30 && c <= 0x39) return 0.56;
    return 0.54;
  }

  @override
  double width(String text, StyledRun run) {
    var w = 0.0;
    var n = 0;
    for (final c in text.runes) {
      w += advance(c);
      n++;
    }
    final mono = run.fontFamily.toLowerCase().contains('mono');
    if (mono) w = n * 0.6;
    final bold = run.fontWeight >= 600 ? 1.05 : 1.0;
    return w * run.fontSize * bold + run.letterSpacing * n;
  }

  @override
  FontVMetrics metrics(StyledRun run) => FontVMetrics(ascent, descent);
}

/// Lays out bodies with a [SlideTextMeasurer]. Results are cached (LRU).
///
/// Known differences to the Flutter engine (accepted, 12 R5): `justify`
/// lays out as `left`, right-to-left paragraphs align right without bidi
/// reordering, and small caps render as all caps.
final class SlideTextLayout implements TextLayoutEngine {
  /// Creates an engine.
  SlideTextLayout({
    this.measurer = const ApproxTextMeasurer(),
    this.cacheSize = 256,
  });

  final SlideTextMeasurer measurer;
  final int cacheSize;
  final LinkedHashMap<String, TextLayoutResult> _cache = LinkedHashMap();

  @override
  TextLayoutResult layout(
    TextBody body,
    ResolvedTextStyles styles, {
    required double width,
    double scale = 1,
  }) {
    final key = '${body.toJson()}|${textStylesKey(styles)}|$width|$scale';
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    final r = _layout(body, styles, width, scale);
    _cache[key] = r;
    while (_cache.length > cacheSize) {
      _cache.remove(_cache.keys.first);
    }
    return r;
  }

  TextLayoutResult _layout(
    TextBody body,
    ResolvedTextStyles styles,
    double width,
    double scale,
  ) {
    final paras = TextParagraphs.build(body, styles, scale: scale);
    final lines = <TextLineBox>[];
    var y = 0.0;
    var maxRight = 0.0;
    for (var pi = 0; pi < paras.length; pi++) {
      final p = paras[pi];
      if (pi > 0) y += p.spaceBefore;
      final avail = math.max(1.0, width - p.textIndent);
      final broken = _breakLines(p, avail);
      for (var li = 0; li < broken.length; li++) {
        final segs = broken[li];
        final runsOnLine = segs.isEmpty ? [p.mark] : segs.map((s) => s.$1);
        var asc = 0.0, desc = 0.0, size = 0.0;
        for (final r in runsOnLine) {
          final m = measurer.metrics(r);
          asc = math.max(asc, m.ascent * r.fontSize);
          desc = math.max(desc, m.descent * r.fontSize);
          size = math.max(size, r.fontSize);
        }
        if (li == 0 && p.marker != null) {
          final m = measurer.metrics(p.marker!);
          asc = math.max(asc, m.ascent * p.marker!.fontSize);
          desc = math.max(desc, m.descent * p.marker!.fontSize);
        }
        final height = size * p.lineHeight;
        final leading = height - (asc + desc);
        final baseline = y + leading / 2 + asc;
        // Content width without trailing spaces.
        var x = 0.0;
        final boxes = <TextRunBox>[];
        for (final (run, text) in segs) {
          final w = measurer.width(text, run);
          boxes.add(run.box(x: x, width: w));
          x += w;
        }
        final trimmed = _trimmedWidth(segs, x);
        final align = p.rtl && p.align == 'left' ? 'right' : p.align;
        final free = math.max(0.0, avail - trimmed);
        final dx = switch (align) {
          'center' => free / 2,
          'right' => free,
          _ => 0.0,
        };
        final start = segs.isEmpty ? p.start : segs.first.$1.start;
        final end = segs.isEmpty ? p.start : segs.last.$1.end;
        TextRunBox? bullet;
        if (li == 0 && p.marker != null) {
          final mw = measurer.width(p.marker!.text, p.marker!);
          bullet = p.marker!.box(x: p.markerX - (p.textIndent + dx), width: mw);
        }
        lines.add(
          TextLineBox(
            top: y,
            baseline: baseline,
            height: height,
            left: p.textIndent + dx,
            width: trimmed,
            start: start,
            end: end,
            runs: boxes,
            paragraph: p.index,
            bullet: bullet,
          ),
        );
        maxRight = math.max(maxRight, p.textIndent + dx + trimmed);
        y += height;
      }
      if (pi < paras.length - 1) y += p.spaceAfter;
    }
    return TextLayoutResult(
      width: width.isFinite ? width : maxRight,
      height: y,
      lines: lines,
      fitScale: scale,
    );
  }

  double _trimmedWidth(List<(StyledRun, String)> segs, double total) {
    if (segs.isEmpty) return 0;
    final (run, text) = segs.last;
    final t = text.trimRight();
    if (t.length == text.length) return total;
    return total - measurer.width(text, run) + measurer.width(t, run);
  }

  /// Greedy line breaking: clusters end after a space, a hyphen, a CJK
  /// character or a soft break (U+2028, forced).
  List<List<(StyledRun, String)>> _breakLines(StyledParagraph p, double avail) {
    // Build clusters of (run, text) segments.
    final clusters = <(List<(StyledRun, String)>, bool forced)>[];
    var current = <(StyledRun, String)>[];
    for (final run in p.runs) {
      var from = 0;
      final t = run.text;
      for (var i = 0; i < t.length; i++) {
        final c = t.codeUnitAt(i);
        final next = i + 1 < t.length ? t.codeUnitAt(i + 1) : -1;
        final isSpace = c == 0x20;
        final forced = c == 0x2028;
        final opportunity =
            forced ||
            (isSpace && next != 0x20) ||
            c == 0x2d ||
            (c >= 0x2e80 && c <= 0x9fff);
        if (opportunity) {
          final end = forced ? i : i + 1;
          if (end > from) {
            current.add((
              run.slice(t.substring(from, end), run.start + from),
              t.substring(from, end),
            ));
          }
          clusters.add((current, forced));
          current = [];
          from = i + 1;
        }
      }
      if (from < t.length) {
        current.add((
          run.slice(t.substring(from), run.start + from),
          t.substring(from),
        ));
      }
    }
    if (current.isNotEmpty) clusters.add((current, false));

    final lines = <List<(StyledRun, String)>>[];
    var line = <(StyledRun, String)>[];
    var lineWidth = 0.0;
    double widthOf(List<(StyledRun, String)> segs, {bool trim = false}) {
      var w = 0.0;
      for (var i = 0; i < segs.length; i++) {
        final (r, t) = segs[i];
        w += measurer.width(
          trim && i == segs.length - 1 ? t.trimRight() : t,
          r,
        );
      }
      return w;
    }

    for (final (cluster, forced) in clusters) {
      final w = widthOf(cluster);
      final wTrim = widthOf(cluster, trim: true);
      if (line.isNotEmpty && lineWidth + wTrim > avail + 1e-6) {
        lines.add(line);
        line = [];
        lineWidth = 0;
      }
      if (line.isEmpty && wTrim > avail + 1e-6) {
        // Break inside the cluster by characters.
        for (final (r, t) in cluster) {
          var from = 0;
          for (var i = 1; i <= t.length; i++) {
            final piece = t.substring(from, i);
            final pw = measurer.width(piece, r);
            if (lineWidth + pw > avail + 1e-6 &&
                (line.isNotEmpty || i - from > 1)) {
              if (i - 1 > from) {
                line.add((
                  r.slice(t.substring(from, i - 1), r.start + from),
                  t.substring(from, i - 1),
                ));
                from = i - 1;
              }
              lines.add(line);
              line = [];
              lineWidth = 0;
            }
          }
          if (from < t.length) {
            final rest = t.substring(from);
            line.add((r.slice(rest, r.start + from), rest));
            lineWidth += measurer.width(rest, r);
          }
        }
      } else {
        line.addAll(cluster);
        lineWidth += w;
      }
      if (forced) {
        lines.add(line);
        line = [];
        lineWidth = 0;
      }
    }
    if (line.isNotEmpty || lines.isEmpty) lines.add(line);
    return lines;
  }
}

final Expando<String> _stylesKeys = Expando('textStylesKey');

/// A content key of [styles] (theme hash, appearance, default style, box)
/// for layout caches.
String textStylesKey(ResolvedTextStyles styles) => _stylesKeys[styles] ??= [
  styles.theme?.contentHash ?? identityHashCode(styles.styles),
  styles.theme?.appearance.name ?? '',
  styles.defaultStyle,
  styles.box == null ? '' : styles.box!.toJson().toString(),
].join('/');
