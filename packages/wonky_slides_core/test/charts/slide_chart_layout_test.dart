import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_slides_core/charts.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/schema.dart';

import '../support/chart_fixture.dart';

void main() {
  group('Given a slide with a linked chart', () {
    for (final compress in [false, true]) {
      test('when building the scene ${compress ? 'from gz: columns ' : ''}then '
          'the chart is laid out into its frame', () {
        final f = ChartFixture(compress: compress);
        final layout = SlideChartLayout();
        final scene = f.scene.scene(charts: layout);
        final node = scene.nodesOf(f.chart).whereType<ChartNode>().single;
        expect(node.dst.width, 1200);
        expect(node.scene.width, 600);
        expect(node.scene.height, 371);
        expect(jsonEncode(node.scene.toJson()), contains('North'));
      });
    }

    test('when laying out twice then the cached build is reused', () {
      final f = ChartFixture();
      final layout = SlideChartLayout();
      final model = f.scene.model();
      final theme = f.scene.resolve(model: model).theme;
      final rec = model.element(f.chart)!;
      final a = layout.build(rec, model, theme, width: 1200, height: 742);
      final b = layout.build(rec, model, theme, width: 1200, height: 742);
      expect(identical(a, b), isTrue);
      expect(a!.snapshot.dataSnapshot.version, 'log:abc:42');
    });

    test('when a build reveals one series then only its bars show', () {
      final f = ChartFixture();
      final layout = SlideChartLayout();
      final model = f.scene.model();
      final theme = f.scene.resolve(model: model).theme;
      final rec = model.element(f.chart)!;
      final b = layout.build(
        rec,
        model,
        theme,
        width: 1200,
        height: 742,
        reveal: ChartReveal(
          parts: {
            const ChartRevealKey(seriesKey: 'south'): ChartPartReveal.hidden,
          },
        ),
      )!;
      final keys = {
        for (final p in b.scene.flattened)
          if (p.tag?.role == SceneRole.point) p.tag!.seriesKey,
      };
      expect(keys, {'north'});
    });

    test('when a 3D chart is laid out with a camera then the view applies', () {
      final f = ChartFixture(threeD: true);
      final layout = SlideChartLayout();
      final model = f.scene.model();
      final theme = f.scene.resolve(model: model).theme;
      final b = layout.build(
        model.element(f.chart)!,
        model,
        theme,
        width: 1200,
        height: 742,
        view: Chart3DView.presets['side'],
      )!;
      expect(b.scene.threeD!.model.azimuth, 80);
      expect(b.scene.threeD!.model.fov, 15);
    });
  });

  group('Given charts without data', () {
    test('when the link holds a placeholder then the scene builder draws its '
        'placeholder', () {
      final f = ChartFixture();
      final el = f.scene.element(
        ElementKind.chart,
        x: 10,
        columns: {
          ElementCols.dataJson: jsonEncode({'source': 'linked'}),
        },
      );
      f.scene.b.chartLink(
        el,
        sourceSpecJson: '{"v":1}',
        dataSnapshotJson: '{"v":1}',
      );
      final scene = f.scene.scene(charts: SlideChartLayout());
      expect(scene.nodesOf(el).whereType<ChartNode>(), isEmpty);
      expect(scene.nodesOf(f.chart).whereType<ChartNode>(), hasLength(1));
    });

    test('when a native chart (P1) is drawn then it is a placeholder', () {
      final f = ChartFixture();
      final el = f.scene.element(
        ElementKind.chart,
        x: 10,
        columns: {
          ElementCols.dataJson: jsonEncode({'source': 'native'}),
        },
      );
      final scene = f.scene.scene(charts: SlideChartLayout());
      expect(scene.nodesOf(el).whereType<ChartNode>(), isEmpty);
    });
  });

  group('Given a static chart', () {
    test('when building the scene then its own snapshot is drawn', () {
      final f = ChartFixture();
      final el = f.staticChart();
      final scene = f.scene.scene(charts: SlideChartLayout());
      final node = scene.nodesOf(el).whereType<ChartNode>().single;
      expect(node.scene.width, 250);
      expect(jsonEncode(node.scene.toJson()), contains('Revenue by region'));
    });
  });
}
