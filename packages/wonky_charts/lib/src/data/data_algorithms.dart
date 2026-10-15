import 'dart:math' as math;
import 'dart:typed_data';

import '../spec/chart_type.dart';
import 'chart_data.dart';

/// Aggregation functions (08 §3.2 `aggregate`).
abstract final class ChartAggregation {
  /// Applies [fn] to [values] (NaN ignored). Count counts non-NaN values; the others return
  /// NaN when there is no value.
  static double apply(ChartAggregate fn, List<double> values) {
    var n = 0;
    var sum = 0.0;
    var mn = double.infinity;
    var mx = -double.infinity;
    for (final v in values) {
      if (v.isNaN) continue;
      n++;
      sum += v;
      if (v < mn) mn = v;
      if (v > mx) mx = v;
    }
    switch (fn) {
      case ChartAggregate.count:
        return n.toDouble();
      case ChartAggregate.sum:
        return n == 0 ? double.nan : sum;
      case ChartAggregate.average:
        return n == 0 ? double.nan : sum / n;
      case ChartAggregate.max:
        return n == 0 ? double.nan : mx;
      case ChartAggregate.min:
        return n == 0 ? double.nan : mn;
      case ChartAggregate.median:
        if (n == 0) return double.nan;
        final s = [
          for (final v in values)
            if (!v.isNaN) v,
        ]..sort();
        return s.length.isOdd
            ? s[s.length ~/ 2]
            : (s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2;
    }
  }

  /// Groups points by domain value and aggregates every series (08 §4.1 step 7): stable order
  /// of first appearance for categorical domains, ascending for numeric/date domains.
  static (ChartDomain, List<ChartSeries>) aggregate(
    ChartDomain domain,
    List<ChartSeries> series,
    ChartAggregate fn,
  ) {
    final n = domain.length;
    final groupOf = Int32List(n);
    final firstIndex = <int>[];
    if (domain.kind == DomainKind.categorical) {
      final byLabel = <String, int>{};
      for (var i = 0; i < n; i++) {
        groupOf[i] = byLabel.putIfAbsent(domain.labels[i], () {
          firstIndex.add(i);
          return firstIndex.length - 1;
        });
      }
    } else {
      final byValue = <double, int>{};
      for (var i = 0; i < n; i++) {
        final v = domain.values[i];
        final key = v.isNaN ? double.negativeInfinity : v;
        groupOf[i] = byValue.putIfAbsent(key, () {
          firstIndex.add(i);
          return firstIndex.length - 1;
        });
      }
    }
    final g = firstIndex.length;
    final order = List<int>.generate(g, (i) => i);
    if (domain.kind != DomainKind.categorical) {
      order.sort((a, b) {
        final va = domain.values[firstIndex[a]],
            vb = domain.values[firstIndex[b]];
        if (va.isNaN) return vb.isNaN ? 0 : 1;
        if (vb.isNaN) return -1;
        return va.compareTo(vb);
      });
    }
    final rank = Int32List(g);
    for (var i = 0; i < g; i++) {
      rank[order[i]] = i;
    }
    final newDomain = ChartDomain(
      kind: domain.kind,
      values: Float64List.fromList([
        for (final o in order) domain.values[firstIndex[o]],
      ]),
      labels: [for (final o in order) domain.labels[firstIndex[o]]],
      name: domain.name,
      key: domain.key,
      numberFormat: domain.numberFormat,
    );
    final buckets = List<List<double>>.generate(g, (_) => <double>[]);
    final newSeries = <ChartSeries>[];
    for (final s in series) {
      for (final b in buckets) {
        b.clear();
      }
      for (var i = 0; i < n; i++) {
        buckets[rank[groupOf[i]]].add(s.values[i]);
      }
      final out = Float64List(g);
      for (var k = 0; k < g; k++) {
        out[k] = apply(fn, buckets[k]);
      }
      newSeries.add(s.withValues(out));
    }
    return (newDomain, newSeries);
  }
}

/// Largest-Triangle-Three-Buckets downsampling (08 §12).
abstract final class Lttb {
  /// Indices of the points to keep (ascending) when reducing ([xs], [ys]) to [threshold]
  /// points. Points with a NaN coordinate are dropped first. Returns all valid indices when
  /// their count is ≤ [threshold] or [threshold] < 3.
  static Int32List downsample(Float64List xs, Float64List ys, int threshold) {
    final valid = <int>[];
    for (var i = 0; i < ys.length; i++) {
      if (!xs[i].isNaN && !ys[i].isNaN) valid.add(i);
    }
    final n = valid.length;
    if (threshold >= n || threshold < 3) return Int32List.fromList(valid);
    final out = Int32List(threshold);
    var o = 0;
    out[o++] = valid[0];
    final every = (n - 2) / (threshold - 2);
    var a = 0;
    for (var i = 0; i < threshold - 2; i++) {
      // Average of the next bucket.
      var avgStart = ((i + 1) * every).floor() + 1;
      var avgEnd = ((i + 2) * every).floor() + 1;
      if (avgEnd > n) avgEnd = n;
      if (avgStart >= avgEnd) avgStart = avgEnd - 1;
      var avgX = 0.0, avgY = 0.0;
      for (var j = avgStart; j < avgEnd; j++) {
        avgX += xs[valid[j]];
        avgY += ys[valid[j]];
      }
      final len = avgEnd - avgStart;
      avgX /= len;
      avgY /= len;
      // Current bucket.
      final start = (i * every).floor() + 1;
      final end = ((i + 1) * every).floor() + 1;
      final ax = xs[valid[a]], ay = ys[valid[a]];
      var maxArea = -1.0;
      var next = start;
      for (var j = start; j < end && j < n - 1; j++) {
        final area =
            ((ax - avgX) * (ys[valid[j]] - ay) -
                    (ax - xs[valid[j]]) * (avgY - ay))
                .abs();
        if (area > maxArea) {
          maxArea = area;
          next = j;
        }
      }
      out[o++] = valid[next];
      a = next;
    }
    out[o++] = valid[n - 1];
    return out;
  }

  /// Target point count for a plot [plotWidth] px wide (08 §12: `max(2 × width, 2000)`).
  static int targetFor(double plotWidth) =>
      math.max((2 * plotWidth).ceil(), 2000);

  /// Min/max per bucket downsampling for sparklines (05 §17): keeps the first, min, max and
  /// last index of each of [buckets] equal-count buckets (ascending, deduplicated).
  static Int32List minMax(Float64List ys, int buckets) {
    final n = ys.length;
    if (n <= buckets * 2 || buckets < 1) {
      return Int32List.fromList([for (var i = 0; i < n; i++) i]);
    }
    final keep = <int>[];
    for (var b = 0; b < buckets; b++) {
      final s = (b * n / buckets).floor();
      final e = ((b + 1) * n / buckets).floor();
      var mn = -1, mx = -1;
      for (var i = s; i < e; i++) {
        final v = ys[i];
        if (v.isNaN) continue;
        if (mn < 0 || v < ys[mn]) mn = i;
        if (mx < 0 || v > ys[mx]) mx = i;
      }
      final set = <int>{
        s,
        ?(mn < 0 ? null : mn),
        ?(mx < 0 ? null : mx),
        e - 1,
      }.toList()..sort();
      keep.addAll(set);
    }
    return Int32List.fromList(keep);
  }
}

/// Histogram bucketing (08 §3.7).
abstract final class HistogramBuckets {
  /// Maximum number of automatic buckets.
  static const maxBuckets = 100;

  /// Buckets every series' values with a shared bucket size: [bucketSize] or automatic
  /// (Freedman–Diaconis rounded to a nice number, ≤ 100 buckets). [outlierPercentile] (0..25)
  /// folds values outside the [p, 100 − p] percentiles into the first/last bucket.
  static HistogramData compute(
    List<ChartSeries> series, {
    double? bucketSize,
    double outlierPercentile = 0,
  }) {
    final all = <double>[
      for (final s in series)
        for (final v in s.values)
          if (v.isFinite) v,
    ]..sort();
    if (all.isEmpty) {
      return HistogramData(
        start: 0,
        bucketSize: 1,
        counts: const [],
        seriesKeys: const [],
      );
    }
    final p = outlierPercentile.clamp(0.0, 25.0);
    final lo = p > 0 ? percentile(all, p / 100) : all.first;
    final hi = p > 0 ? percentile(all, 1 - p / 100) : all.last;
    var h = bucketSize ?? 0;
    final range = hi - lo;
    if (h <= 0) {
      final iqr = percentile(all, 0.75) - percentile(all, 0.25);
      h = iqr > 0
          ? 2 * iqr / math.pow(all.length, 1 / 3)
          : (range > 0 ? range / math.sqrt(all.length) : 1);
      if (range > 0 && range / h > maxBuckets) h = range / maxBuckets;
      h = niceStep(h);
    }
    final start = (lo / h).floor() * h;
    var count = range <= 0 ? 1 : ((hi - start) / h).floor() + 1;
    if (count < 1) count = 1;
    if (count > 10000) count = 10000;
    final counts = <Int32List>[];
    for (final s in series) {
      final c = Int32List(count);
      for (final v in s.values) {
        if (!v.isFinite) continue;
        var i = ((v - start) / h).floor();
        if (i < 0) i = 0;
        if (i >= count) i = count - 1;
        c[i]++;
      }
      counts.add(c);
    }
    return HistogramData(
      start: start,
      bucketSize: h,
      counts: counts,
      seriesKeys: [for (final s in series) s.key],
    );
  }

  /// PERCENTILE.INC of sorted [sorted] at [q] (0..1).
  static double percentile(List<double> sorted, double q) {
    if (sorted.isEmpty) return double.nan;
    final pos = q.clamp(0.0, 1.0) * (sorted.length - 1);
    final i = pos.floor();
    final f = pos - i;
    if (i + 1 >= sorted.length) return sorted.last;
    return sorted[i] + (sorted[i + 1] - sorted[i]) * f;
  }

  /// Smallest 1/2/2.5/5 × 10ᵏ step ≥ [raw].
  static double niceStep(double raw) {
    if (!(raw > 0) || !raw.isFinite) return 1;
    final e = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (m * e >= raw * (1 - 1e-12)) return m * e;
    }
    return 10 * e;
  }
}

/// Pie "Other" grouping (08 §12).
abstract final class PieGrouping {
  /// Keeps the largest `threshold − 1` slices (in original order) and sums the rest into a
  /// final "Other" slice when there are more than [threshold] slices with a positive value.
  /// Returns null when no grouping is needed.
  static (ChartDomain, ChartSeries)? group(
    ChartDomain domain,
    ChartSeries series, {
    int threshold = 50,
    String otherLabel = 'Other',
  }) {
    final idx = <int>[
      for (var i = 0; i < series.length; i++)
        if (series.values[i] > 0) i,
    ];
    if (idx.length <= threshold || threshold < 2) return null;
    final sorted = [...idx]
      ..sort((a, b) {
        final c = series.values[b].compareTo(series.values[a]);
        return c != 0 ? c : a.compareTo(b);
      });
    final keep = sorted.take(threshold - 1).toList()..sort();
    final keepSet = keep.toSet();
    var other = 0.0;
    for (final i in idx) {
      if (!keepSet.contains(i)) other += series.values[i];
    }
    final values = Float64List(keep.length + 1);
    for (var k = 0; k < keep.length; k++) {
      values[k] = series.values[keep[k]];
    }
    values[keep.length] = other;
    final d = ChartDomain(
      kind: DomainKind.categorical,
      values: Float64List.fromList([
        ...keep.map((i) => domain.values[i]),
        double.nan,
      ]),
      labels: [...keep.map((i) => domain.labels[i]), otherLabel],
      name: domain.name,
      key: domain.key,
      numberFormat: domain.numberFormat,
    );
    return (d, series.withValues(values));
  }
}
