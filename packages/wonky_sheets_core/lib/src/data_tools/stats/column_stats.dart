import 'dart:math' as math;
import 'dart:typed_data';

import '../../content/cell_content.dart';
import '../../formula/values/dates.dart';
import '../../formula/values/format_hint.dart';
import '../../rules/conditions/display_text.dart';
import '../sort/sort_keys.dart';

/// Dominant value type of a column.
enum ColumnKind { empty, number, date, text, boolean, mixed }

/// One row of the frequency table.
final class FrequencyEntry {
  /// Creates an entry.
  const FrequencyEntry(this.text, this.count, this.share);

  /// Display text.
  final String text;
  final int count;

  /// Share of non-empty values (0..1).
  final double share;

  @override
  bool operator ==(Object other) =>
      other is FrequencyEntry && other.text == text && other.count == count && other.share == share;

  @override
  int get hashCode => Object.hash(text, count, share);

  @override
  String toString() => 'FrequencyEntry($text, $count)';
}

/// One histogram bucket `[start, end)` (the last bucket includes its end).
final class HistogramBucket {
  /// Creates a bucket.
  const HistogramBucket(this.start, this.end, this.count, {this.label});

  final double start;
  final double end;
  final int count;

  /// Label for date buckets (`2026-01`, `2026`), else null.
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is HistogramBucket && other.start == start && other.end == end && other.count == count && other.label == label;

  @override
  int get hashCode => Object.hash(start, end, count, label);

  @override
  String toString() => 'HistogramBucket(${label ?? '$start–$end'}: $count)';
}

/// Numeric summary.
final class NumericSummary {
  /// Creates a summary.
  const NumericSummary({
    required this.count,
    required this.sum,
    required this.average,
    required this.median,
    required this.min,
    required this.max,
  });

  final int count;
  final double sum;
  final double average;
  final double median;
  final double min;
  final double max;
}

/// Result of [ColumnStats.compute] (07 §15).
final class ColumnStatsResult {
  /// Creates a result.
  const ColumnStatsResult({
    required this.kind,
    required this.valueCount,
    required this.emptyCount,
    required this.uniqueCount,
    required this.frequencies,
    this.numeric,
    this.histogram = const [],
    this.minTextLength,
    this.maxTextLength,
  });

  final ColumnKind kind;

  /// Non-empty cells.
  final int valueCount;

  /// Empty cells.
  final int emptyCount;

  /// Distinct non-empty display values.
  final int uniqueCount;

  /// Frequency table sorted by count (desc), then value order.
  final List<FrequencyEntry> frequencies;

  /// Summary of numeric values (numbers and dates), or null.
  final NumericSummary? numeric;

  /// Histogram (numbers: ≤ 20 Freedman–Diaconis buckets; dates: by month or year).
  final List<HistogramBucket> histogram;

  /// Text lengths (text columns).
  final int? minTextLength;
  final int? maxTextLength;

  /// The top values for the text bar chart.
  List<FrequencyEntry> top([int n = 10]) => frequencies.take(n).toList();
}

/// Column statistics (07 §15).
abstract final class ColumnStats {
  /// Maximum histogram buckets.
  static const int maxBuckets = 20;

  /// Computes the stats of a column snapshot: [values] (computed values),
  /// [displayTexts] (same length) and the column's [numberFormat] (dates are
  /// detected from it).
  static ColumnStatsResult compute(List<CellValue> values, List<String> displayTexts, {String? numberFormat}) {
    var empty = 0;
    final counts = <String, int>{};
    final repr = <String, CellValue>{};
    final numbers = <double>[];
    final kinds = List<int>.filled(4, 0);
    int? minLen;
    int? maxLen;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v.isBlank()) {
        empty++;
        continue;
      }
      final t = displayTexts[i];
      counts[t] = (counts[t] ?? 0) + 1;
      repr.putIfAbsent(t, () => v);
      kinds[SortKeys.groupOf(v).clamp(0, 3)]++;
      if (v is NumberValue) numbers.add(v.number);
      if (v is TextValue) {
        final l = v.text.length;
        if (minLen == null || l < minLen) minLen = l;
        if (maxLen == null || l > maxLen) maxLen = l;
      }
    }
    final nonEmpty = values.length - empty;
    final freq = [
      for (final e in counts.entries) FrequencyEntry(e.key, e.value, nonEmpty == 0 ? 0 : e.value / nonEmpty),
    ]..sort((a, b) {
        final c = b.count.compareTo(a.count);
        if (c != 0) return c;
        final s = SortKeys.compare(repr[a.text]!, repr[b.text]!);
        return s != 0 ? s : a.text.compareTo(b.text);
      });

    final isDate = numberFormat != null && FormatHint.looksLikeDatePattern(numberFormat);
    var kind = ColumnKind.empty;
    if (nonEmpty > 0) {
      var best = 0;
      for (var g = 1; g < 4; g++) {
        if (kinds[g] > kinds[best]) best = g;
      }
      kind = kinds[best] * 2 < nonEmpty && kinds.where((k) => k > 0).length > 1
          ? ColumnKind.mixed
          : switch (best) {
              SortKeys.number => isDate ? ColumnKind.date : ColumnKind.number,
              SortKeys.text => ColumnKind.text,
              SortKeys.boolean => ColumnKind.boolean,
              _ => ColumnKind.mixed,
            };
    }
    NumericSummary? summary;
    var histogram = const <HistogramBucket>[];
    if (numbers.isNotEmpty) {
      final sorted = Float64List.fromList(numbers)..sort();
      var sum = 0.0;
      for (final x in sorted) {
        sum += x;
      }
      summary = NumericSummary(
        count: sorted.length,
        sum: sum,
        average: sum / sorted.length,
        median: _quantile(sorted, 0.5),
        min: sorted.first,
        max: sorted.last,
      );
      histogram = kind == ColumnKind.date ? dateHistogram(sorted) : numericHistogram(sorted);
    }
    return ColumnStatsResult(
      kind: kind,
      valueCount: nonEmpty,
      emptyCount: empty,
      uniqueCount: counts.length,
      frequencies: freq,
      numeric: summary,
      histogram: histogram,
      minTextLength: minLen,
      maxTextLength: maxLen,
    );
  }

  /// Computes the stats of column [col], rows [top]..[bottom] of [sheetId]
  /// (all rows, hidden included). The column format is the first non-empty
  /// cell's number format.
  static ColumnStatsResult fromSheet(CellTextReader reader, String sheetId, int col, int top, int bottom) {
    final values = <CellValue>[];
    final texts = <String>[];
    String? format;
    for (var r = top; r <= bottom; r++) {
      final v = reader.valueAt(sheetId, r, col);
      final f = reader.numberFormatAt(sheetId, r, col);
      values.add(v);
      texts.add(v.isBlank() ? '' : reader.display.displayText(v, f));
      if (format == null && !v.isBlank()) format = f;
    }
    return compute(values, texts, numberFormat: format);
  }

  static double _quantile(Float64List sorted, double p) {
    if (sorted.isEmpty) return 0;
    final rank = p * (sorted.length - 1);
    final lo = rank.floor();
    final hi = rank.ceil();
    return sorted[lo] + (sorted[hi] - sorted[lo]) * (rank - lo);
  }

  /// Freedman–Diaconis histogram (bin width `2·IQR/n^(1/3)`), clamped to
  /// 1..[maxBuckets] buckets. [sorted] must be ascending.
  static List<HistogramBucket> numericHistogram(Float64List sorted) {
    if (sorted.isEmpty) return const [];
    final min = sorted.first;
    final max = sorted.last;
    if (max == min) return [HistogramBucket(min, max, sorted.length)];
    final iqr = _quantile(sorted, 0.75) - _quantile(sorted, 0.25);
    final width = 2 * iqr / math.pow(sorted.length, 1 / 3);
    var buckets = width <= 0 ? maxBuckets : ((max - min) / width).ceil();
    buckets = buckets.clamp(1, maxBuckets);
    final w = (max - min) / buckets;
    final counts = List<int>.filled(buckets, 0);
    for (final x in sorted) {
      var b = ((x - min) / w).floor();
      if (b >= buckets) b = buckets - 1;
      counts[b]++;
    }
    return [
      for (var i = 0; i < buckets; i++)
        HistogramBucket(min + i * w, i == buckets - 1 ? max : min + (i + 1) * w, counts[i]),
    ];
  }

  /// Date histogram by month (span ≤ 24 months) or by year.
  static List<HistogramBucket> dateHistogram(Float64List sorted) {
    if (sorted.isEmpty) return const [];
    final a = DateSerial.toYmd(sorted.first);
    final z = DateSerial.toYmd(sorted.last);
    final months = (z.year - a.year) * 12 + (z.month - a.month) + 1;
    final byMonth = months <= 24;
    final out = <HistogramBucket>[];
    if (byMonth) {
      var y = a.year, m = a.month;
      var i = 0;
      for (var k = 0; k < months; k++) {
        final start = DateSerial.fromYmd(y, m, 1).toDouble();
        final end = DateSerial.fromYmd(y, m + 1, 1).toDouble();
        var c = 0;
        while (i < sorted.length && sorted[i] < end) {
          c++;
          i++;
        }
        out.add(HistogramBucket(start, end, c, label: '$y-${m.toString().padLeft(2, '0')}'));
        m++;
        if (m > 12) {
          m = 1;
          y++;
        }
      }
    } else {
      var i = 0;
      for (var y = a.year; y <= z.year; y++) {
        final start = DateSerial.fromYmd(y, 1, 1).toDouble();
        final end = DateSerial.fromYmd(y + 1, 1, 1).toDouble();
        var c = 0;
        while (i < sorted.length && sorted[i] < end) {
          c++;
          i++;
        }
        out.add(HistogramBucket(start, end, c, label: '$y'));
      }
    }
    return out;
  }
}
