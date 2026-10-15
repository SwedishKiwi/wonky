import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_slides_core/charts.dart';

import '../support/chart_fixture.dart';

void main() {
  group('Given the override allowlist', () {
    for (final (path, allowed) in [
      ('title.text', true),
      ('legend.position', true),
      ('axes.h.title.text', true),
      ('axes.v.labels.font.size', true),
      ('axes.v.numberFormat', true),
      ('axes.v.min', false),
      ('axes.v.logScale', false),
      ('gridlines.major.color', true),
      ('series.north.color', true),
      ('series.north.dataLabels.show', true),
      ('series.north.type', false),
      ('series.north.axis', false),
      ('style.palette', true),
      ('style.smooth', false),
      ('threeD.lighting', true),
      ('threeD.enabled', false),
      ('threeD.azimuth', false),
      ('typeOptions.pieHole', true),
      ('typeOptions.slices.3.offset', true),
      ('typeOptions.buckets', false),
      ('data.ranges', false),
      ('type', false),
      ('stacking', false),
    ]) {
      test(
        'when checking "$path" then it is ${allowed ? '' : 'not '}allowed',
        () {
          expect(ChartOverrides.allows(path.split('.')), allowed);
        },
      );
    }
  });

  group('Given a style patch', () {
    test('when it touches data then the paths are rejected', () {
      expect(
        ChartOverrides.rejectedPaths({
          'legend': {'position': 'top'},
          'data': {'ranges': <Object?>[]},
          'series': {
            'north': {'color': '#000000', 'type': 'line'},
          },
          'type': 'pie',
        }),
        ['data', 'series.north.type', 'type'],
      );
    });

    test('when it clears a series then that is allowed', () {
      expect(
        ChartOverrides.rejectedPaths({
          'series': {'north': null},
        }),
        isEmpty,
      );
    });

    test('when merging then nulls clear and empty objects are pruned', () {
      final merged = ChartOverrides.merge(
        {
          'series': {
            'north': {'color': '#000000'},
          },
          'legend': {'position': 'top'},
        },
        {
          'series': {
            'north': {'color': null},
          },
        },
      );
      expect(merged, {
        'legend': {'position': 'top'},
      });
    });
  });

  group('Given stored overrides', () {
    test('when filtering then disallowed keys are dropped', () {
      expect(
        ChartOverrides.filter({
          'title': {'text': 'Hi'},
          'axes': {
            'v': {'min': 0, 'showLine': false},
          },
          'series': {'north': null},
        }),
        {
          'title': {'text': 'Hi'},
          'axes': {
            'v': {'showLine': false},
          },
        },
      );
    });

    test('when a series is gone then it is reported unused', () {
      expect(
        ChartOverrides.unusedSeries({
          'series': {
            'north': {'color': '#000000'},
            'west': {'color': '#000000'},
          },
        }, revenueData()),
        ['west'],
      );
      expect(ChartOverrides.unusedSeries({}, ChartData.empty()), isEmpty);
    });
  });
}
