import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';

import '../support/sample_data.dart';

const size = ChartSize(600, 371);

ChartScene layout(ChartSpec spec, {ChartReveal? reveal, ChartData? data}) =>
    ChartPipeline.layout(
      spec,
      data ?? sampleData(),
      size: size,
      theme: sampleTheme,
      measurer: const ApproxTextMeasurer(),
      reveal: reveal,
    ).scene;

List<T> dataOf<T extends ScenePrimitive>(ChartScene s, [String? series]) => [
  for (final p in s.flattened)
    if (p is T &&
        (p.tag?.role == SceneRole.point || p.tag?.role == SceneRole.series) &&
        (series == null || p.tag?.seriesKey == series))
      p,
];

ChartReveal growSeries(String key, double g) => ChartReveal(
  parts: {
    const ChartRevealKey(seriesKey: 'north'): ChartPartReveal(
      grow: key == 'north' ? g : 1,
    ),
    const ChartRevealKey(seriesKey: 'south'): ChartPartReveal(
      grow: key == 'south' ? g : 1,
    ),
  },
);

void main() {
  const column = ChartSpec(type: ChartType.column);

  group('Given a column chart', () {
    final full = layout(column);

    test('when the reveal is full then the scene is unchanged', () {
      expect(ChartReveal.full.applyTo(full, column), same(full));
      expect(
        jsonEncode(layout(column, reveal: ChartReveal.full).toJson()),
        jsonEncode(full.toJson()),
      );
    });

    test('when a series grows to 50 % then its bars are half as tall from the '
        'baseline', () {
      final half = growSeries('north', 0.5).applyTo(full, column);
      final before = dataOf<SRect>(full, 'north');
      final after = dataOf<SRect>(half, 'north');
      expect(after.length, before.length);
      for (var i = 0; i < before.length; i++) {
        expect(after[i].rect.height, closeTo(before[i].rect.height / 2, 1e-9));
        expect(after[i].rect.bottom, closeTo(before[i].rect.bottom, 1e-9));
      }
      // The other series is untouched.
      expect(
        dataOf<SRect>(half, 'south').map((r) => r.rect.height),
        dataOf<SRect>(full, 'south').map((r) => r.rect.height),
      );
    });

    test('when a series has not started then its bars are gone', () {
      final none = growSeries('south', 0).applyTo(full, column);
      expect(dataOf<SRect>(none, 'south'), isEmpty);
      expect(dataOf<SRect>(none, 'north'), hasLength(3));
    });

    test('when the background is hidden then axes and legend are faded', () {
      final s = const ChartReveal(backgroundOpacity: 0).applyTo(full, column);
      expect(
        s.flattened.where((p) => p.tag?.role == SceneRole.axisLabel),
        isEmpty,
      );
      expect(dataOf<SRect>(s), hasLength(6));
      final half = const ChartReveal(
        backgroundOpacity: 0.5,
      ).applyTo(full, column);
      final label = half.flattened.whereType<SText>().firstWhere(
        (p) => p.tag?.role == SceneRole.axisLabel,
      );
      expect(Argb.alpha(label.style.color), closeTo(128, 1));
    });

    test('when a category is revealed then only its points show', () {
      final r = ChartReveal(
        parts: {
          ChartRevealKey.all: ChartPartReveal.hidden,
          const ChartRevealKey(pointIndex: 1): ChartPartReveal.shown,
        },
      );
      final s = r.applyTo(full, column);
      expect(dataOf<SRect>(s).map((p) => p.tag!.pointIndex).toSet(), {1});
    });

    test('when a point fades then its color alpha drops', () {
      final r = ChartReveal(
        parts: {
          const ChartRevealKey(seriesKey: 'north', pointIndex: 2):
              const ChartPartReveal(opacity: 0.25),
        },
      );
      final p = dataOf<SRect>(
        r.applyTo(full, column),
        'north',
      ).firstWhere((p) => p.tag!.pointIndex == 2);
      expect(Argb.alpha(p.fill!), closeTo(64, 1));
    });

    test('when highlighting a series then the others dim', () {
      const r = ChartReveal(highlightSeries: 'south', highlightMix: 1);
      final s = r.applyTo(full, column);
      expect(Argb.alpha(dataOf<SRect>(s, 'north').first.fill!), closeTo(77, 1));
      expect(Argb.alpha(dataOf<SRect>(s, 'south').first.fill!), 255);
    });

    test('when rendering a partial reveal then every renderer accepts it', () {
      final s = growSeries('north', 0.3).applyTo(full, column);
      expect(const SvgChartRenderer().render(s), contains('<svg'));
      expect(const RasterChartRenderer().render(s), isNotEmpty);
      expect(
        const PdfChartRenderer().renderDocument(s),
        completion(isNotEmpty),
      );
    });
  });

  group('Given negative values', () {
    test('when growing then bars below the baseline grow downwards', () {
      final data = sampleData();
      final neg = ChartData(
        domain: data.domain,
        series: [
          for (final s in data.series)
            s.withValues(
              s.values.map((v) => s.key == 'north' ? -v : v).toList().toFloat(),
            ),
        ],
      );
      final full = layout(column, data: neg);
      final half = growSeries('north', 0.5).applyTo(full, column);
      final a = dataOf<SRect>(full, 'north').first;
      final b = dataOf<SRect>(half, 'north').first;
      expect(b.rect.top, closeTo(a.rect.top, 1e-9));
      expect(b.rect.height, closeTo(a.rect.height / 2, 1e-9));
    });
  });

  group('Given a bar chart', () {
    test('when growing then bars grow horizontally', () {
      const bar = ChartSpec(type: ChartType.bar);
      final full = layout(bar);
      final half = growSeries('north', 0.5).applyTo(full, bar);
      final a = dataOf<SRect>(full, 'north').first;
      final b = dataOf<SRect>(half, 'north').first;
      expect(b.rect.height, a.rect.height);
      expect(b.rect.width, closeTo(a.rect.width / 2, 1e-9));
      expect(b.rect.left, closeTo(a.rect.left, 1e-9));
    });
  });

  group('Given a line chart', () {
    const line = ChartSpec(
      type: ChartType.line,
      series: {'north': SeriesStyle(pointSize: 6)},
    );
    final full = layout(line);

    test('when a series is half drawn then the polyline ends midway', () {
      final s = growSeries('north', 0.5).applyTo(full, line);
      final a = dataOf<SPolyline>(full, 'north').single;
      final b = dataOf<SPolyline>(s, 'north').single;
      expect(b.xy.first, a.xy.first);
      expect(b.length, 3); // first, second and the cut point
      expect(b.xy[4], lessThan(a.xy[4]));
    });

    test('when the line has not reached a marker then it is hidden', () {
      final s = growSeries('north', 0.4).applyTo(full, line);
      final m = dataOf<SMarkers>(s, 'north').single;
      expect(m.sizeOf(0), 6);
      expect(m.sizeOf(2), 0);
    });

    test('when categories build one by one then the line follows them', () {
      final r = ChartReveal(
        parts: {
          const ChartRevealKey(pointIndex: 0): ChartPartReveal.shown,
          const ChartRevealKey(pointIndex: 1): const ChartPartReveal(grow: 0.5),
          const ChartRevealKey(pointIndex: 2): ChartPartReveal.hidden,
        },
      );
      final b = dataOf<SPolyline>(r.applyTo(full, line), 'north').single;
      final a = dataOf<SPolyline>(full, 'north').single;
      expect(b.length, 2);
      expect(b.xy[2], closeTo((a.xy[0] + a.xy[2]) / 2, 1e-6));
    });
  });

  group('Given an area chart', () {
    test('when half revealed then the fill is clipped to the left half', () {
      const area = ChartSpec(type: ChartType.area);
      final full = layout(area);
      final s = growSeries('north', 0.5).applyTo(full, area);
      final clips = s.primitives.whereType<SClip>().where(
        (c) => c.children.any((p) => p is SPath),
      );
      expect(clips, isNotEmpty);
    });
  });

  group('Given a pie chart', () {
    const pie = ChartSpec(
      type: ChartType.pie,
      series: {'north': SeriesStyle(dataLabels: DataLabelsSpec(show: true))},
    );
    final data = sampleData();
    final one = ChartData(domain: data.domain, series: [data.series.first]);
    final full = layout(pie, data: one);

    test('when a slice grows then it sweeps from its start angle', () {
      final r = ChartReveal(
        parts: {
          const ChartRevealKey(pointIndex: 0): const ChartPartReveal(grow: 0.5),
        },
      );
      final s = r.applyTo(full, pie);
      final a = full.flattened.whereType<SArc>().first;
      final b = s.flattened.whereType<SArc>().first;
      expect(b.start, a.start);
      expect(b.sweep, closeTo(a.sweep / 2, 1e-9));
    });

    test('when a slice is below 80 % then its label is hidden', () {
      final r = ChartReveal(
        parts: {ChartRevealKey.all: const ChartPartReveal(grow: 0.7)},
      );
      final labels = r
          .applyTo(full, pie)
          .flattened
          .where((p) => p.tag?.role == SceneRole.dataLabel);
      expect(labels, isEmpty);
      final r9 = ChartReveal(
        parts: {ChartRevealKey.all: const ChartPartReveal(grow: 0.9)},
      );
      expect(
        r9
            .applyTo(full, pie)
            .flattened
            .where((p) => p.tag?.role == SceneRole.dataLabel),
        isNotEmpty,
      );
    });
  });

  group('Given a 3D column chart', () {
    const col3d = ChartSpec(
      type: ChartType.column,
      threeD: ChartThreeD(enabled: true),
    );

    test('when a series grows then its 3D boxes are lower', () {
      final full = layout(col3d);
      final half = layout(col3d, reveal: growSeries('north', 0.5));
      double height(ChartScene s, String key) => s.threeD!.model.items
          .whereType<Chart3DBox>()
          .where((b) => b.tag?.seriesKey == key && b.part == Chart3DPart.data)
          .map((b) => b.max.y - b.min.y)
          .reduce((a, b) => a + b);
      expect(height(half, 'north'), closeTo(height(full, 'north') / 2, 1e-6));
      expect(height(half, 'south'), closeTo(height(full, 'south'), 1e-6));
    });

    test('when a series is hidden then its items are left out', () {
      final s = layout(col3d, reveal: growSeries('south', 0));
      expect(
        s.threeD!.model.items.where((i) => i.tag?.seriesKey == 'south'),
        isEmpty,
      );
    });

    test('when fading then the items blend toward the background', () {
      final r = ChartReveal(
        parts: {ChartRevealKey.all: const ChartPartReveal(opacity: 0.5)},
      );
      final full = layout(col3d);
      final s = layout(col3d, reveal: r);
      final a = full.threeD!.model.dataItems.first;
      final b = s.threeD!.model.dataItems.first;
      expect(b.color, Argb.lerp(full.threeD!.model.background, a.color, 0.5));
    });
  });
}

extension on List<double> {
  Float64List toFloat() => Float64List.fromList(this);
}
