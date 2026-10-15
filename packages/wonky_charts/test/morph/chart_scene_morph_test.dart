import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';

import '../support/sample_data.dart';

const size = ChartSize(600, 371);

ChartScene layout(ChartSpec spec, ChartData data) => ChartPipeline.layout(
  spec,
  data,
  size: size,
  theme: sampleTheme,
  measurer: const ApproxTextMeasurer(),
).scene;

ChartData scaled(double f, {bool extraSeries = false}) {
  final d = sampleData();
  return ChartData(
    domain: d.domain,
    series: [
      for (final s in d.series)
        s.withValues(Float64List.fromList([for (final v in s.values) v * f])),
      if (extraSeries)
        ChartSeries(
          key: 'east',
          name: 'East',
          values: Float64List.fromList([5, 6, 7]),
        ),
    ],
  );
}

SRect bar(ChartScene s, String key, int i) =>
    s.flattened.whereType<SRect>().firstWhere(
      (p) =>
          p.tag?.role == SceneRole.point &&
          p.tag?.seriesKey == key &&
          p.tag?.pointIndex == i,
    );

void main() {
  const column = ChartSpec(type: ChartType.column);

  group('Given two column charts with different data', () {
    final a = layout(column, scaled(1));
    final b = layout(column, scaled(0.5));
    final morph = ChartSceneMorph(a, b);

    test('when preparing then the scenes morph geometrically', () {
      expect(morph.isCrossfade, isFalse);
      expect(morph.matchRatio, 1);
    });

    test('when at the ends then the scenes are returned', () {
      expect(morph.at(0), same(a));
      expect(morph.at(1), same(b));
    });

    test('when halfway then each bar is between its two states', () {
      final mid = morph.at(0.5);
      final ra = bar(a, 'north', 1).rect, rb = bar(b, 'north', 1).rect;
      final rm = bar(mid, 'north', 1).rect;
      expect(rm.height, closeTo((ra.height + rb.height) / 2, 1e-9));
      expect(rm.top, closeTo((ra.top + rb.top) / 2, 1e-9));
    });

    test('when rendering a frame then the renderers accept it', () {
      expect(const SvgChartRenderer().render(morph.at(0.3)), contains('<svg'));
    });
  });

  group('Given a chart that gains a series', () {
    final a = layout(column, scaled(1));
    final b = layout(column, scaled(1, extraSeries: true));
    final morph = ChartSceneMorph(a, b);

    test('when halfway then the new bars are fading in', () {
      final mid = morph.at(0.5);
      final east = mid.flattened.whereType<SRect>().where(
        (p) => p.tag?.seriesKey == 'east' && p.tag?.role == SceneRole.point,
      );
      expect(east, hasLength(3));
      expect(Argb.alpha(east.first.fill!), closeTo(128, 1));
    });

    test('when preparing then most data still matches', () {
      expect(morph.isCrossfade, isFalse);
    });
  });

  group('Given a column chart turning into a pie', () {
    test('when preparing then the morph falls back to a crossfade', () {
      final morph = ChartSceneMorph(
        layout(column, scaled(1)),
        layout(const ChartSpec(type: ChartType.pie), scaled(1)),
      );
      expect(morph.isCrossfade, isTrue);
      final mid = morph.at(0.25);
      expect(mid.primitives, hasLength(2));
      expect((mid.primitives.first as SGroup).opacity, 0.75);
    });
  });

  group('Given line charts with different point counts', () {
    test('when morphing then the polyline is resampled', () {
      const line = ChartSpec(type: ChartType.line);
      final d = sampleData();
      final longer = ChartData(
        domain: ChartDomain(
          kind: DomainKind.categorical,
          values: Float64List.fromList(List.filled(5, double.nan)),
          labels: const ['Jan', 'Feb', 'Mar', 'Apr', 'May'],
        ),
        series: [
          for (final s in d.series)
            s.withValues(Float64List.fromList([...s.values, 3, 4])),
        ],
      );
      final morph = ChartSceneMorph(layout(line, d), layout(line, longer));
      final poly = morph
          .at(0.5)
          .flattened
          .whereType<SPolyline>()
          .firstWhere((p) => p.tag?.seriesKey == 'north');
      expect(poly.length, 5);
    });
  });

  group('Given OKLab interpolation', () {
    test('when mixing then the ends are exact and alpha is linear', () {
      expect(OkLab.lerp(0xFFFF0000, 0xFF0000FF, 0), 0xFFFF0000);
      expect(OkLab.lerp(0xFFFF0000, 0xFF0000FF, 1), 0xFF0000FF);
      expect(OkLab.lerp(0x00FFFFFF, 0xFFFFFFFF, 0.5), 0x80FFFFFF);
      expect(
        OkLab.lerp(0xFF000000, 0xFFFFFFFF, 0.5) & 0xFF,
        inInclusiveRange(90, 110),
      );
    });
  });
}
