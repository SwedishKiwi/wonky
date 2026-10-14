@Tags(['slow'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/charts/render/chart_painter.dart';
import 'package:wonky_sheets/features/grid/grid_area.dart';
import 'package:wonky_sheets/features/objects/objects_controller.dart';
import 'package:wonky_sheets/features/objects/objects_layer.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

/// 08 §12 / §22 performance: 50 charts on a sheet scroll without being laid
/// out or repainted again (each chart is a `RepaintBoundary` whose scene is
/// cached; scrolling only moves it), (the 1M-point layout budget is a core
/// test: `chart_scale_test.dart`). Timings are printed for comparison (the widget test binding
/// is not a frame-time benchmark; the assertions are about work done).
void main() {
  late SheetsHarness s;
  setUp(() => s = SheetsHarness.open());
  tearDown(() async {
    ObjectsController.maybeOf(s.editor)?.dispose();
    await s.dispose();
  });

  testWidgets('when 50 charts are visible and the grid scrolls then no chart '
      'scene is laid out or walked again', (tester) async {
    await s.type('A1', 'Month');
    await s.type('B1', 'Sales');
    await s.type('C1', 'Costs');
    for (var i = 0; i < 12; i++) {
      await s.type('A${i + 2}', 'M${i + 1}');
      await s.type('B${i + 2}', '${10 + i * 3 % 7}');
      await s.type('C${i + 2}', '${5 + i * 5 % 11}');
    }
    const types = ['column', 'line', 'area', 'bar', 'pie', 'scatter'];
    for (var i = 0; i < 50; i++) {
      final row = 2 + (i ~/ 10) * 9;
      final col = String.fromCharCode(0x45 + (i % 10) * 2); // E, G, I …
      await s.run('sheets.chart.insert', {
        'ranges': ['A1:C13'],
        'type': types[i % types.length],
        'anchor': {'cell': '$col$row', 'width': 180, 'height': 150},
      });
    }
    await pumpSheets(
      tester,
      s,
      size: const Size(2200, 1300),
      child: WonkyPopupMenuHost(
        child: SheetObjectsHost(
          editor: s.editor,
          services: s.services,
          child: GridArea(controller: s.editor, services: s.services),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final visible = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('sheets.object.'),
    );
    expect(visible.evaluate().length, greaterThanOrEqualTo(40));

    final walks = ChartScenePainter.debugSceneWalks;
    final sw = Stopwatch()..start();
    for (var i = 0; i < 60; i++) {
      s.editor.scroll.scrollBy(0, i < 30 ? 6 : -6);
      await tester.pump(const Duration(milliseconds: 16));
    }
    sw.stop();
    debugPrint(
      '50 charts: 60 scroll frames in ${sw.elapsedMilliseconds} ms '
      '(${(sw.elapsedMicroseconds / 60 / 1000).toStringAsFixed(2)} ms/frame '
      'in the test binding)',
    );
    expect(
      ChartScenePainter.debugSceneWalks,
      walks,
      reason: 'scrolling moves charts, it does not repaint them',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
