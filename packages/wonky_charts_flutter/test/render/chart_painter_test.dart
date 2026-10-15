import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_charts_flutter/wonky_charts_flutter.dart';

ChartScene _scene() {
  final data = ChartData(
    domain: ChartDomain(
      kind: DomainKind.categorical,
      values: Float64List.fromList([double.nan, double.nan]),
      labels: const ['A', 'B'],
    ),
    series: [
      ChartSeries(key: 's', name: 'S', values: Float64List.fromList([1, 2])),
    ],
  );
  return ChartPipeline.layout(
    const ChartSpec(type: ChartType.column),
    data,
    size: const ChartSize(300, 200),
    theme: ChartTheme.from(
      const ChartThemeColors(accentArgbs: [0xFF4285F4]),
      export: true,
    ),
    measurer: FlutterTextMeasurer.instance,
  ).scene;
}

void main() {
  group('Given a chart scene laid out from plain ChartData', () {
    testWidgets('when painted twice then the 2D picture is recorded once', (
      tester,
    ) async {
      final scene = _scene();
      final before = ChartScenePainter.debugSceneWalks;
      Widget chart() => CustomPaint(
        size: const Size(300, 200),
        painter: ChartScenePainter(scene),
      );
      await tester.pumpWidget(Center(child: chart()));
      await tester.pumpWidget(Center(child: RepaintBoundary(child: chart())));
      expect(ChartScenePainter.debugSceneWalks - before, 1);
    });

    testWidgets('when rendering to PNG then PNG bytes are produced', (
      tester,
    ) async {
      final bytes = await tester.runAsync(
        () => chartSceneToPng(_scene(), pixelRatio: 1),
      );
      expect(bytes, isNotNull);
      expect(bytes!.sublist(1, 4), 'PNG'.codeUnits);
    });

    test('when nothing changed then the painter does not repaint', () {
      final scene = _scene();
      expect(
        ChartScenePainter(scene).shouldRepaint(ChartScenePainter(scene)),
        isFalse,
      );
      expect(
        ChartScenePainter(
          scene,
          scale: 2,
        ).shouldRepaint(ChartScenePainter(scene)),
        isTrue,
      );
    });
  });
}
