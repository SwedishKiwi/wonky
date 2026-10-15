/// Building in parts (06 §2.3): text segmentation into paragraphs,
/// paragraph groups, words and characters (UTF-16 ranges of the body's
/// plain text, the offsets of the text layout), chart parts, and the part
/// order (forward, backward, center, edges, seeded random).
library;

import 'dart:convert';

import '../../scene/nodes/text_layout.dart' show TextBody;
import '../timeline/slide_frame.dart' show ChartPartKey;
import '../util/seeded_random.dart';
import 'build_options.dart';

/// A text part: `[start, end)` of the plain text, in paragraph
/// [paragraph] (index among all paragraphs, as the layout counts them).
final class TextPartRange {
  /// Creates a range.
  const TextPartRange(this.start, this.end, this.paragraph);

  final int start, end, paragraph;

  @override
  bool operator ==(Object other) =>
      other is TextPartRange &&
      other.start == start &&
      other.end == end &&
      other.paragraph == paragraph;

  @override
  int get hashCode => Object.hash(start, end, paragraph);

  @override
  String toString() => '[$start,$end)#$paragraph';
}

/// The text of an element for delivery: plain text and paragraph levels.
final class MotionText {
  /// Creates a text.
  const MotionText(this.plain, [this.levels = const []]);

  /// From a Delta JSON body (`SlideElement.text`): paragraph `indent`
  /// levels from the block attributes.
  factory MotionText.fromDelta(String? deltaJson) {
    final body = TextBody.fromJson(deltaJson);
    final levels = <int>[];
    for (final op in body.ops) {
      final ins = op['insert'];
      if (ins is! String) continue;
      final attrs = op['attributes'];
      final indent = attrs is Map && attrs['indent'] is num
          ? (attrs['indent'] as num).round()
          : 0;
      for (var i = 0; i < ins.length; i++) {
        if (ins.codeUnitAt(i) == 0x0A) levels.add(indent);
      }
    }
    return MotionText(body.plainText, levels);
  }

  /// The plain text (ends with `"\n"` for Delta bodies).
  final String plain;

  /// Indent level per paragraph (missing = 0).
  final List<int> levels;

  /// Characters that are drawn (not whitespace): typewriter length.
  int get visibleLength {
    var n = 0;
    for (final r in plain.runes) {
      if (!_isSpace(r)) n++;
    }
    return n;
  }
}

bool _isSpace(int r) =>
    r == 0x20 ||
    r == 0x09 ||
    r == 0x0A ||
    r == 0x0D ||
    r == 0x2028 ||
    r == 0x00A0 ||
    r == 0x3000 ||
    (r >= 0x2000 && r <= 0x200A);

bool _isWordChar(int r) {
  if (r >= 0x30 && r <= 0x39) return true; // digits
  if (r >= 0x41 && r <= 0x5A) return true;
  if (r >= 0x61 && r <= 0x7A) return true;
  if (r >= 0xC0 && r != 0xD7 && r != 0xF7 && r < 0x2000) return true;
  if (r >= 0x3040) return true; // CJK, emoji, …
  return false;
}

bool _extends(int r) =>
    (r >= 0x0300 && r <= 0x036F) || // combining marks
    (r >= 0x1AB0 && r <= 0x1AFF) ||
    (r >= 0x20D0 && r <= 0x20FF) ||
    (r >= 0xFE00 && r <= 0xFE0F) || // variation selectors
    (r >= 0x1F3FB && r <= 0x1F3FF) || // skin tones
    (r >= 0xE0020 && r <= 0xE007F); // tags

/// Text segmentation for delivery.
abstract final class TextParts {
  /// Paragraphs (separated by `"\n"`; U+2028 soft breaks stay inside),
  /// without the newline; blank paragraphs are skipped (06 §2.3).
  static List<TextPartRange> paragraphs(String text) {
    final out = <TextPartRange>[];
    var start = 0, p = 0;
    for (var i = 0; i <= text.length; i++) {
      if (i == text.length || text.codeUnitAt(i) == 0x0A) {
        if (i > start && text.substring(start, i).trim().isNotEmpty) {
          out.add(TextPartRange(start, i, p));
        }
        if (i == text.length) break;
        p++;
        start = i + 1;
      }
    }
    return out;
  }

  /// Top-level paragraphs with their nested sub-paragraphs (levels from
  /// [levels]; a paragraph whose level is greater than the group's first
  /// paragraph joins the group).
  static List<TextPartRange> paragraphGroups(String text, List<int> levels) {
    final paras = paragraphs(text);
    final out = <TextPartRange>[];
    int? level;
    for (final r in paras) {
      final l = r.paragraph < levels.length ? levels[r.paragraph] : 0;
      if (out.isNotEmpty && level != null && l > level) {
        final g = out.removeLast();
        out.add(TextPartRange(g.start, r.end, g.paragraph));
      } else {
        out.add(r);
        level = l;
      }
    }
    return out;
  }

  /// Words: maximal runs of non-space characters; runs without letters or
  /// digits (punctuation) join the preceding word.
  static List<TextPartRange> words(String text) {
    final out = <TextPartRange>[];
    var p = 0;
    var i = 0;
    while (i < text.length) {
      final c = text.codeUnitAt(i);
      if (c == 0x0A) p++;
      final r = _runeAt(text, i);
      if (_isSpace(r)) {
        i += r > 0xFFFF ? 2 : 1;
        continue;
      }
      final start = i;
      var word = false;
      while (i < text.length) {
        final r2 = _runeAt(text, i);
        if (_isSpace(r2)) break;
        if (_isWordChar(r2)) word = true;
        i += r2 > 0xFFFF ? 2 : 1;
      }
      if (!word && out.isNotEmpty && out.last.paragraph == p) {
        final prev = out.removeLast();
        out.add(TextPartRange(prev.start, i, p));
      } else {
        out.add(TextPartRange(start, i, p));
      }
    }
    return out;
  }

  /// Grapheme clusters (approximation: a code point plus following
  /// combining marks, variation selectors, skin tones and ZWJ sequences),
  /// without whitespace.
  static List<TextPartRange> characters(String text) {
    final out = <TextPartRange>[];
    var p = 0;
    var i = 0;
    while (i < text.length) {
      final r = _runeAt(text, i);
      final len = r > 0xFFFF ? 2 : 1;
      if (r == 0x0A) p++;
      if (_isSpace(r)) {
        i += len;
        continue;
      }
      final start = i;
      i += len;
      while (i < text.length) {
        final n = _runeAt(text, i);
        if (_extends(n)) {
          i += n > 0xFFFF ? 2 : 1;
        } else if (n == 0x200D && i + 1 < text.length) {
          i += 1;
          final j = _runeAt(text, i);
          i += j > 0xFFFF ? 2 : 1;
        } else {
          break;
        }
      }
      out.add(TextPartRange(start, i, p));
    }
    return out;
  }

  static int _runeAt(String s, int i) {
    final c = s.codeUnitAt(i);
    if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) {
      final d = s.codeUnitAt(i + 1);
      if (d >= 0xDC00 && d <= 0xDFFF) {
        return 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00);
      }
    }
    return c;
  }

  /// The parts of [text] for delivery [by] (`line` without layout = by
  /// paragraph; non-text deliveries = empty).
  static List<TextPartRange> of(MotionText text, DeliveryBy by) => switch (by) {
    DeliveryBy.paragraph || DeliveryBy.line => paragraphs(text.plain),
    DeliveryBy.paragraphGroup => paragraphGroups(text.plain, text.levels),
    DeliveryBy.word => words(text.plain),
    DeliveryBy.character => characters(text.plain),
    _ => const [],
  };
}

/// The data shape of a chart for chart deliveries (from the chart's
/// snapshot / native table; supplied by the chart layer, 08).
final class ChartShape {
  /// Creates a shape.
  const ChartShape({
    required this.seriesKeys,
    required this.categoryCount,
    this.pie = false,
    this.is3d = false,
  });

  /// Visible series in legend order.
  final List<String> seriesKeys;

  /// Number of categories (domain points).
  final int categoryCount;

  /// Pie/doughnut: category delivery = each slice.
  final bool pie;

  /// A 3D chart (camera effects).
  final bool is3d;

  /// Reads the `ChartData` JSON shape (`{"series":[{"key":…}],
  /// "domain":{"length"|"values"}}`) from a snapshot or a native table; null
  /// when the layout isn't recognized.
  static ChartShape? tryParse(String? json, {bool is3d = false}) {
    if (json == null) return null;
    Object? raw;
    try {
      raw = jsonDecode(json);
    } on FormatException {
      return null;
    }
    final data = _findSeries(raw, 0);
    if (data == null) return null;
    final series = data['series'] as List;
    final keys = <String>[];
    var points = 0;
    for (final (i, s) in series.indexed) {
      if (s is! Map) continue;
      keys.add('${s['key'] ?? i}');
      final v = s['values'];
      if (v is List && v.length > points) points = v.length;
    }
    final domain = data['domain'];
    if (domain is Map) {
      final values = domain['values'] ?? domain['labels'];
      if (values is List && values.length > points) points = values.length;
      final len = domain['length'];
      if (len is num && len > points) points = len.round();
    }
    return ChartShape(seriesKeys: keys, categoryCount: points, is3d: is3d);
  }

  /// The first object holding a `series` list ([raw] itself, `data`,
  /// `snapshot.dataSnapshot.data`, …), searched 4 levels deep.
  static Map<String, Object?>? _findSeries(Object? raw, int depth) {
    if (raw is! Map<String, Object?> || depth > 4) return null;
    if (raw['series'] is List) return raw;
    for (final v in raw.values) {
      final f = _findSeries(v, depth + 1);
      if (f != null) return f;
    }
    return null;
  }

  /// The parts of delivery [by] (background excluded), or null when [by]
  /// is not a chart delivery. `point` falls back to `series` beyond 500
  /// points (06 §2.3; the caller reports it).
  List<ChartPartKey>? partsOf(DeliveryBy by) => switch (by) {
    DeliveryBy.series || DeliveryBy.chartElement => [
      for (final k in seriesKeys) ChartPartKey('series', series: k),
      if (by == DeliveryBy.chartElement) const ChartPartKey('labels'),
    ],
    DeliveryBy.category => [
      for (var i = 0; i < categoryCount; i++)
        ChartPartKey('category', index: i),
    ],
    DeliveryBy.point => [
      for (final k in seriesKeys)
        for (var i = 0; i < categoryCount; i++)
          ChartPartKey('point', series: k, index: i),
    ],
    _ => null,
  };
}

/// Part order (06 §2.3).
abstract final class PartOrdering {
  /// The order in which parts `0 … count−1` build: forward, backward,
  /// center (middle out), edges (outside in) or random (Fisher–Yates with
  /// a generator seeded by [seed]).
  static List<int> order(int count, PartOrder order, int seed) {
    final idx = [for (var i = 0; i < count; i++) i];
    switch (order) {
      case PartOrder.forward:
        return idx;
      case PartOrder.backward:
        return idx.reversed.toList();
      case PartOrder.center:
      case PartOrder.edges:
        final mid = (count - 1) / 2;
        idx.sort((a, b) {
          final da = (a - mid).abs(), db = (b - mid).abs();
          final c = order == PartOrder.center
              ? da.compareTo(db)
              : db.compareTo(da);
          return c != 0 ? c : a.compareTo(b);
        });
        return idx;
      case PartOrder.random:
        SeededRandom(seed).shuffle(idx);
        return idx;
    }
  }
}
