import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/formatting/sheets_user_defaults.dart';
import 'package:wonky_sheets/features/grid/grid_area.dart';
import 'package:wonky_sheets/features/objects/objects_controller.dart';
import 'package:wonky_sheets/features/objects/objects_layer.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

List<ScenePrimitive> _all(List<ScenePrimitive> list) {
  final out = <ScenePrimitive>[];
  void visit(ScenePrimitive p) {
    out.add(p);
    if (p is SGroup) p.children.forEach(visit);
    if (p is SClip) p.children.forEach(visit);
  }

  list.forEach(visit);
  return out;
}

void main() {
  late SheetsHarness s;

  Future<String> lineChart() async {
    await s.type('A1', 'Month');
    await s.type('B1', 'Sales');
    await s.type('C1', 'Costs');
    for (var i = 0; i < 4; i++) {
      await s.type('A${i + 2}', 'M$i');
      await s.type('B${i + 2}', '${10 + i}');
      await s.type('C${i + 2}', '${5 + 2 * i}');
    }
    final r = await s.run('sheets.chart.insert', {
      'ranges': ['A1:C5'],
      'type': 'line',
      'anchor': {'cell': 'E2', 'width': 300, 'height': 200},
    });
    return (r.data! as Map)['objectId']! as String;
  }

  setUp(() => s = SheetsHarness.open());
  tearDown(() async {
    ObjectsController.maybeOf(s.editor)?.dispose();
    await s.dispose();
  });

  test(
    'when series are distinguished by pattern then the second series '
    'line is dashed, and the scene updates when the setting changes',
    () async {
      final id = await lineChart();
      final objects = ObjectsController.of(s.editor);
      final c = objects.chartOf(objects.record(id)!);
      List<SStroke> lineStrokes() => [
        for (final p in _all(
          c
              .sceneFor(300, 200, dark: false, tokens: ChartUiTokens.light)
              .primitives,
        ))
          if (p is SPolyline && p.tag?.role == SceneRole.series) p.stroke,
      ];
      expect(lineStrokes().every((st) => st.dash == null), isTrue);

      await SheetsUserDefaults.of(
        s.services,
      ).set(SheetsUserDefaults.keyChartSeriesByPattern, true);

      final strokes = lineStrokes();
      expect(strokes, hasLength(2));
      expect(strokes.any((st) => st.dash != null), isTrue);
    },
  );

  testWidgets('when a screen reader focuses a chart then it offers the data '
      'table as an action', (tester) async {
    final id = await lineChart();
    await pumpSheets(
      tester,
      s,
      child: WonkyPopupMenuHost(
        child: SheetObjectsHost(
          editor: s.editor,
          services: s.services,
          child: GridArea(controller: s.editor, services: s.services),
        ),
      ),
    );
    await tester.pump();
    final semantics = tester
        .widgetList<Semantics>(
          find.descendant(
            of: find.byKey(ValueKey('sheets.object.$id')),
            matching: find.byType(Semantics),
          ),
        )
        .firstWhere((w) => w.properties.customSemanticsActions != null);
    final actions = semantics.properties.customSemanticsActions!;
    expect(actions.keys.single.label, 'View data as table');

    actions.values.single();
    await tester.pump();
    expect(s.services.recentCommands.first, 'sheets.chart.viewDataTable');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
