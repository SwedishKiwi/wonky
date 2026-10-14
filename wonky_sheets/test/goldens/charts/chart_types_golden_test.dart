@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/charts/editor/chart_editor_panel.dart';
import 'package:wonky_sheets/features/charts/render/chart_painter.dart';
import 'package:wonky_sheets/features/objects/objects_controller.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

/// Golden images of every implemented chart type (2D and 3D) at two sizes in
/// light and dark (08 §22), and the chart editor panel. Masters are made and
/// compared on CI Linux only (specs/15 §7): run locally with `-x golden`.
void main() {
  late SheetsHarness s;
  setUp(() => s = SheetsHarness.open());
  tearDown(() async {
    ObjectsController.maybeOf(s.editor)?.dispose();
    await s.dispose();
  });

  Future<void> seed() async {
    final rows = [
      ['Month', 'North', 'South', 'East'],
      ['Jan', '10', '4', '7'],
      ['Feb', '14', '6', '9'],
      ['Mar', '9', '5', '12'],
      ['Apr', '16', '7', '8'],
      ['May', '12', '9', '11'],
    ];
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        await s.type('${String.fromCharCode(0x41 + c)}${r + 1}', rows[r][c]);
      }
    }
  }

  final specs = <String, Map<String, Object?>>{
    for (final t in ChartType.values)
      if (t.isImplemented && !t.only3D) t.id: {'type': t.id},
    for (final t in ChartType.values)
      if (t.supports3D)
        '${t.id}_3d': {
          'type': t.id,
          'threeD': {'enabled': true},
        },
  };

  for (final dark in [false, true]) {
    for (final (name, size) in [
      ('small', const Size(240, 160)),
      ('large', const Size(480, 300)),
    ]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('chart types $name $mode', (tester) async {
        await seed();
        final g = s.sheet.gridRange(s.model.parseA1('A1:D6').rect);
        final scenes = <String, ChartScene>{};
        for (final e in specs.entries) {
          final spec = ChartSpec.fromJson({
            'v': 1,
            ...e.value,
            'data': {
              'ranges': [g.toJson()],
            },
          });
          final data = ChartPipeline.resolve(spec, s.model, s.editor.engine);
          scenes[e.key] = ChartPipeline.layout(
            spec,
            data,
            size: ChartSize(size.width, size.height),
            theme: ChartTheme.from(
              s.model.theme,
              dark: dark,
              tokens: dark ? ChartUiTokens.dark : ChartUiTokens.light,
            ),
            measurer: FlutterTextMeasurer.instance,
          ).scene;
        }
        await pumpSheets(
          tester,
          s,
          dark: dark,
          size: Size(size.width * 6 + 70, (size.height + 10) * 5),
          child: RepaintBoundary(
            key: const ValueKey('golden'),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final sc in scenes.values)
                  CustomPaint(size: size, painter: ChartScenePainter(sc)),
              ],
            ),
          ),
        );
        await expectLater(
          find.byKey(const ValueKey('golden')),
          matchesGoldenFile('chart_types_${name}_$mode.png'),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      });
    }

    testWidgets('chart editor ${dark ? 'dark' : 'light'}', (tester) async {
      await seed();
      final r = await s.run('sheets.chart.insert', {
        'ranges': ['A1:D6'],
      });
      ObjectsController.of(
        s.editor,
      ).select((r.data! as Map)['objectId']! as String);
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(360, 900),
        child: WonkyPopupMenuHost(
          child: RepaintBoundary(
            key: const ValueKey('golden'),
            child: ChartEditorPanel(services: s.services, editor: s.editor),
          ),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey('golden')),
        matchesGoldenFile('chart_editor_${dark ? 'dark' : 'light'}.png'),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
