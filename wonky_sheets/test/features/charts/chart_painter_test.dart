import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/charts/chart_insert.dart';
import 'package:wonky_sheets/features/charts/render/chart_painter.dart';
import 'package:wonky_sheets/features/objects/objects_controller.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() async {
    s = SheetsHarness.open();
    final rows = [
      ['Month', 'Low', 'Open', 'Close', 'High'],
      ['Jan', '10', '12', '15', '18'],
      ['Feb', '11', '15', '13', '17'],
      ['Mar', '9', '13', '16', '19'],
      ['Apr', '12', '16', '14', '20'],
    ];
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        await s.type('${'ABCDE'[c]}${r + 1}', rows[r][c]);
      }
    }
  });
  tearDown(() async {
    ObjectsController.maybeOf(s.editor)?.dispose();
    await s.dispose();
  });

  Future<ui.Image> render(ChartScene scene) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paintChartScene(canvas, scene);
    final picture = recorder.endRecording();
    return picture.toImage(scene.width.ceil(), scene.height.ceil());
  }

  Future<Color> pixel(ui.Image img, int x, int y) async {
    final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final i = (y * img.width + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  }

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    group('Given monthly data in $mode mode', () {
      for (final t in ChartType.values.where((t) => t.isImplemented)) {
        testWidgets('when painting a ${t.id} chart then the scene paints '
            'without errors on the automatic background', (tester) async {
          final ranges = ChartInsert.rangesFromA1(s.editor, ['A1:E5']);
          final spec = ChartInsert.specFor(s.editor, ranges, type: t);
          final tokens = dark ? ChartUiTokens.dark : ChartUiTokens.light;
          final build = ChartPipeline.build(
            spec: spec,
            model: s.model,
            values: s.editor.engine,
            size: const ChartSize(320, 200),
            theme: ChartTheme.from(s.model.theme, dark: dark, tokens: tokens),
            measurer: FlutterTextMeasurer.instance,
          );
          expect(build.scene.primitives, isNotEmpty);
          await tester.runAsync(() async {
            final img = await render(build.scene);
            final corner = await pixel(img, 1, 1);
            expect(corner, Color(tokens.card));
            img.dispose();
          });
        });
      }
    });
  }

  testWidgets('when exporting a chart scene to PNG then bytes come back', (
    tester,
  ) async {
    final ranges = ChartInsert.rangesFromA1(s.editor, ['A1:B5']);
    final spec = ChartInsert.specFor(s.editor, ranges);
    final scene = ChartPipeline.build(
      spec: spec,
      model: s.model,
      values: s.editor.engine,
      size: const ChartSize(200, 120),
      theme: ChartPipeline.exportTheme(s.model),
      measurer: FlutterTextMeasurer.instance,
    ).scene;
    final png = await tester.runAsync(() => chartSceneToPng(scene));
    expect(png, isNotNull);
    expect(png!.sublist(1, 4), [0x50, 0x4e, 0x47]);
  });
}
