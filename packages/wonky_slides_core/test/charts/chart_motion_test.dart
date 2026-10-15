import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_slides_core/charts.dart';
import 'package:wonky_slides_core/motion.dart';

import '../support/chart_fixture.dart';

void main() {
  group(
    'Given a linked chart stored in gz: columns with a chartGrow build',
    () {
      final f = ChartFixture(compress: true);
      f.scene.b.build_(
        f.scene.slideId,
        f.chart,
        effect: 'chartGrow',
        durationMs: 1000,
        optionsJson: jsonEncode({
          'delivery': {'by': 'series'},
        }),
      );
      final model = f.scene.model();

      test(
        'when reading its shape then series, categories and flags are found',
        () {
          final shape = SlideChartMotion.shapes(model)(
            model.element(f.chart)!,
          )!;
          expect(shape.seriesKeys, ['north', 'south']);
          expect(shape.categoryCount, 3);
          expect(shape.pie, isFalse);
          expect(shape.is3d, isFalse);
        },
      );

      test(
        'when compiling with the hook then the build has one part per series',
        () {
          final t = SlideTimelineCompiler.compile(
            SlideMotionInput.fromDeck(
              model,
              f.scene.slideId,
              chartShapeOf: SlideChartMotion.shapes(model),
            ),
          );
          final state = t
              .frameAt(const TimelinePosition(1, 300))
              .stateOf(f.chart)
              .chart;
          final reveal = SlideChartMotion.reveal(state);
          expect(reveal.partOf('north', null).grow, greaterThan(0));
          expect(reveal.partOf('south', null).isHidden, isTrue);

          // The layout draws that frame: north bars only.
          final theme = f.scene.resolve(model: model).theme;
          final b = SlideChartLayout().build(
            model.element(f.chart)!,
            model,
            theme,
            width: 1200,
            height: 742,
            reveal: reveal,
          )!;
          final series = {
            for (final p in b.scene.flattened)
              if (p.tag?.role == SceneRole.point) p.tag!.seriesKey,
          };
          expect(series, {'north'});
        },
      );
    },
  );

  group('Given frame chart states', () {
    test('when converting parts then every role maps to a reveal key', () {
      final r = SlideChartMotion.reveal(
        const ChartRevealState(
          backgroundOpacity: 0.5,
          parts: [
            ChartPartState(ChartPartKey('series', series: 'a'), grow: 0.2),
            ChartPartState(ChartPartKey('category', index: 1), opacity: 0.3),
            ChartPartState(
              ChartPartKey('point', series: 'b', index: 2),
              grow: 0.7,
            ),
            ChartPartState(ChartPartKey('labels'), opacity: 0),
            ChartPartState(ChartPartKey('all'), grow: 0),
          ],
          highlight: {
            'target': {
              'point': ['b', 2],
            },
            'dimOthers': 0.1,
          },
          highlightMix: 0.5,
        ),
      );
      expect(r.backgroundOpacity, 0.5);
      expect(r.partOf('a', 0).grow, 0.2);
      expect(r.partOf('c', 1).opacity, 0.3);
      expect(r.partOf('b', 2).grow, 0.7);
      expect(r.partOf('c', 5).grow, 0);
      expect(r.dataLabels.opacity, 0);
      expect(r.highlightPoint, ('b', 2));
      expect(r.dimOthers, 0.1);
      expect(r.dimOf('a', 0), closeTo(0.55, 1e-9));
      expect(r.dimOf('b', 2), 1);
      expect(SlideChartMotion.reveal(null).isFull, isTrue);
    });

    test('when a chartCamera build is halfway then the view is between the '
        'angles along the shortest arc', () {
      const base = Chart3DView(azimuth: 350, elevation: 20, perspective: 15);
      final v = SlideChartMotion.view(
        const ChartRevealState(
          camera: {'azimuth': 30, 'elevation': null, 'perspective': null},
          cameraMix: 0.5,
        ),
        base,
      );
      expect(v.azimuth, closeTo(10, 1e-9));
      expect(v.elevation, 20);
    });

    test('when the camera names a preset then the preset angles are used', () {
      const base = Chart3DView(azimuth: 20, elevation: 20, perspective: 15);
      final v = SlideChartMotion.view(
        const ChartRevealState(camera: {'preset': 'isometric'}, cameraMix: 1),
        base,
      );
      expect(v, Chart3DView.presets['isometric']);
      final fit = SlideChartMotion.fitViews(
        const ChartRevealState(camera: {'preset': 'isometric'}, cameraMix: 0.2),
        base,
      )!;
      expect(fit, [base, Chart3DView.presets['isometric']]);
    });

    test('when orbiting then the offsets rotate the view', () {
      const base = Chart3DView(azimuth: 20, elevation: 20);
      final v = SlideChartMotion.view(
        const ChartRevealState(azimuthDelta: 90, elevationDelta: 80),
        base,
      );
      expect(v.azimuth, 110);
      expect(v.elevation, 90);
      expect(SlideChartMotion.fitViews(null, base), isNull);
    });
  });
}
