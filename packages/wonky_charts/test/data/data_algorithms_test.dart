import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';

ChartSeries series(List<double> values, {String key = 'k'}) =>
    ChartSeries(key: key, name: key, values: Float64List.fromList(values));

void main() {
  group('Given aggregation functions', () {
    const values = [3.0, double.nan, 1.0, 2.0, 10.0];
    for (final (fn, expected) in [
      (ChartAggregate.sum, 16.0),
      (ChartAggregate.count, 4.0),
      (ChartAggregate.average, 4.0),
      (ChartAggregate.max, 10.0),
      (ChartAggregate.min, 1.0),
      (ChartAggregate.median, 2.5),
    ]) {
      test(
        'when applying ${fn.name} then NaN is ignored and the result is $expected',
        () {
          expect(ChartAggregation.apply(fn, values), expected);
        },
      );
    }

    test('when applying sum to no values then the result is NaN', () {
      expect(ChartAggregation.apply(ChartAggregate.sum, [double.nan]), isNaN);
    });

    test(
      'when aggregating a numeric domain then groups are sorted ascending',
      () {
        final domain = ChartDomain(
          kind: DomainKind.numeric,
          values: Float64List.fromList([3, 1, 3, 2]),
          labels: ['3', '1', '3', '2'],
        );

        final (d, s) = ChartAggregation.aggregate(domain, [
          series([1, 2, 3, 4]),
        ], ChartAggregate.sum);

        expect(d.values, [1, 2, 3]);
        expect(s.single.values, [2, 4, 4]);
      },
    );
  });

  group('Given LTTB downsampling (08 §12)', () {
    final n = 1000;
    final xs = Float64List.fromList([for (var i = 0; i < n; i++) i.toDouble()]);
    final ys = Float64List.fromList([
      for (var i = 0; i < n; i++) i == 500 ? 100.0 : math.sin(i / 50),
    ]);

    test('when reducing to 100 points then first and last are kept', () {
      final idx = Lttb.downsample(xs, ys, 100);

      expect(idx, hasLength(100));
      expect(idx.first, 0);
      expect(idx.last, n - 1);
    });

    test('when reducing then indices ascend and the spike survives', () {
      final idx = Lttb.downsample(xs, ys, 100);

      for (var k = 1; k < idx.length; k++) {
        expect(idx[k], greaterThan(idx[k - 1]));
      }
      expect(idx, contains(500));
    });

    test(
      'when the threshold exceeds the points then every valid index is kept',
      () {
        final idx = Lttb.downsample(
          Float64List.fromList([0, 1, 2]),
          Float64List.fromList([1, double.nan, 3]),
          10,
        );

        expect(idx, [0, 2]);
      },
    );

    test('when computing the target then it is max(2 × width, 2000)', () {
      expect(Lttb.targetFor(500), 2000);
      expect(Lttb.targetFor(1500), 3000);
    });

    test('when min/max bucketing then each bucket keeps its extremes', () {
      final v = Float64List.fromList([
        for (var i = 0; i < 100; i++) (i % 10).toDouble(),
      ]);

      final idx = Lttb.minMax(v, 10);

      expect(idx.length, lessThanOrEqualTo(40));
      expect(idx.map((i) => v[i]).toSet(), containsAll([0.0, 9.0]));
    });
  });

  group('Given histogram bucketing', () {
    test(
      'when the bucket size is fixed then values fall into [start, start + size)',
      () {
        final h = HistogramBuckets.compute([
          series([0, 0.5, 1, 1.5, 4.9]),
        ], bucketSize: 1);

        expect(h.start, 0);
        expect(h.counts.single, [2, 2, 0, 0, 1]);
        expect(h.edge(2), 2);
      },
    );

    test(
      'when the size is automatic then it is a nice Freedman–Diaconis step',
      () {
        final r = math.Random(7);
        final values = [for (var i = 0; i < 500; i++) r.nextDouble() * 100];

        final h = HistogramBuckets.compute([series(values)]);

        expect(h.bucketSize, anyOf(5, 10, 20, 25));
        expect(h.counts.single.reduce((a, b) => a + b), 500);
        expect(h.bucketCount, lessThanOrEqualTo(HistogramBuckets.maxBuckets));
      },
    );

    test(
      'when trimming outliers then extreme values join the edge buckets',
      () {
        final h = HistogramBuckets.compute(
          [
            series([for (var i = 0; i < 98; i++) 10.0 + i % 10, -1000, 1000]),
          ],
          bucketSize: 1,
          outlierPercentile: 5,
        );

        expect(h.bucketCount, lessThan(20));
        expect(h.counts.single.reduce((a, b) => a + b), 100);
      },
    );

    test('when there are several series then they share the buckets', () {
      final h = HistogramBuckets.compute([
        series([1, 2], key: 'a'),
        series([3, 4], key: 'b'),
      ], bucketSize: 1);

      expect(h.seriesKeys, ['a', 'b']);
      expect(h.counts[0], [1, 1, 0, 0]);
      expect(h.counts[1], [0, 0, 1, 1]);
    });

    for (final (raw, nice) in [
      (0.7, 1.0),
      (1.3, 2.0),
      (2.2, 2.5),
      (3.0, 5.0),
      (7.0, 10.0),
      (130.0, 200.0),
    ]) {
      test('when rounding $raw to a nice step then it is $nice', () {
        expect(HistogramBuckets.niceStep(raw), closeTo(nice, 1e-12));
      });
    }

    test(
      'when taking percentiles then PERCENTILE.INC interpolation is used',
      () {
        expect(HistogramBuckets.percentile([1, 2, 3, 4], 0.5), 2.5);
        expect(HistogramBuckets.percentile([1, 2, 3, 4], 1), 4);
      },
    );
  });

  group('Given pie grouping', () {
    final domain = ChartDomain(
      kind: DomainKind.categorical,
      values: Float64List(5)..fillRange(0, 5, double.nan),
      labels: ['a', 'b', 'c', 'd', 'e'],
    );

    test(
      'when the slices are within the threshold then nothing is grouped',
      () {
        expect(
          PieGrouping.group(domain, series([1, 2, 3, 4, 5]), threshold: 5),
          isNull,
        );
      },
    );

    test('when there are too many slices then the smallest form "Other"', () {
      final (d, s) = PieGrouping.group(
        domain,
        series([5, 1, 4, 2, 3]),
        threshold: 3,
      )!;

      expect(d.labels, ['a', 'c', 'Other']);
      expect(s.values, [5, 4, 6]);
    });
  });
}
