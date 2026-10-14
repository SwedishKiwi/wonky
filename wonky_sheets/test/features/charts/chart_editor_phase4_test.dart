import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/charts/editor/chart_editor_mcp.dart';
import 'package:wonky_sheets/features/charts/editor/chart_editor_panel.dart';
import 'package:wonky_sheets/features/objects/objects_controller.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  ObjectsController objects() => ObjectsController.of(s.editor);

  ChartSpec specOf(String id) =>
      ChartSpec.fromJson(objects().record(id)!.specJson);

  Future<String> chart(String type) async {
    await s.type('A1', 'Month');
    await s.type('B1', 'Sales');
    await s.type('C1', 'Costs');
    final rows = [
      ['Jan', '10', '4'],
      ['Feb', '14', '6'],
      ['Mar', '9', '5'],
      ['Apr', '16', '7'],
    ];
    for (var i = 0; i < rows.length; i++) {
      await s.type('A${i + 2}', rows[i][0]);
      await s.type('B${i + 2}', rows[i][1]);
      await s.type('C${i + 2}', rows[i][2]);
    }
    final r = await s.run('sheets.chart.insert', {
      'ranges': [type == 'pie' || type == 'waterfall' ? 'A1:B5' : 'A1:C5'],
      'type': type,
      'anchor': {'cell': 'E2', 'width': 360, 'height': 240},
    });
    expect(r.isOk, isTrue, reason: r.message);
    final id = (r.data! as Map)['objectId']! as String;
    objects().select(id);
    return id;
  }

  Future<void> pumpPanel(WidgetTester tester, {bool dark = false}) async {
    await pumpSheets(
      tester,
      s,
      dark: dark,
      size: const Size(360, 1400),
      child: WonkyPopupMenuHost(
        child: ChartEditorPanel(services: s.services, editor: s.editor),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('chartEditor.tab.customize')));
    await tester.pumpAndSettle();
  }

  Future<void> openSection(WidgetTester tester, String title) async {
    await tester.ensureVisible(find.text(title).first);
    await tester.tap(find.text(title).first);
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  setUp(() => s = SheetsHarness.open());
  tearDown(() async {
    ObjectsController.maybeOf(s.editor)?.dispose();
    await s.dispose();
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    group('Given the chart editor at 360 px ($mode)', () {
      testWidgets('when a data point of one series is formatted then the '
          'point gets its own color and can be removed again', (tester) async {
        final id = await tester.runAsync(() => chart('column'));
        await pumpPanel(tester, dark: dark);
        await openSection(tester, 'Series');
        final key = specOf(id!).series.keys.isNotEmpty
            ? specOf(id).series.keys.first
            : objects().chartOf(objects().record(id)!).data.series.first.key;
        await s.run('sheets.chart.update', {
          'objectId': id,
          'patch': {
            'series': {
              key: {
                'points': {
                  '2': {'color': '#FF0000'},
                },
              },
            },
          },
        });
        await tester.pumpAndSettle();
        expect(specOf(id).seriesStyle(key).points[2]?.color, '#FF0000');
        expect(tester.takeException(), isNull);

        await s.run('sheets.chart.update', {
          'objectId': id,
          'patch': {
            'series': {
              key: {
                'points': {'2': null},
              },
            },
          },
        });
        expect(specOf(id).seriesStyle(key).points, isEmpty);
        await settle(tester);
      });

      testWidgets('when error bars are turned on then the controls show and '
          'the scene draws whiskers', (tester) async {
        final id = await tester.runAsync(() => chart('column'));
        await pumpPanel(tester, dark: dark);
        await openSection(tester, 'Series');
        final check = find.byKey(const ValueKey('chartEditor.errorBars'));
        await tester.ensureVisible(check);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Error bars'));
        await tester.pumpAndSettle();
        final spec = specOf(id!);
        final key = objects()
            .chartOf(objects().record(id)!)
            .data
            .series
            .first
            .key;
        expect(spec.seriesStyle(key).errorBars, {
          'type': 'constant',
          'value': 10,
        });
        expect(
          find.byKey(
            const ValueKey('chartEditor.errorBarsType.ErrorBarType.constant'),
          ),
          findsOneWidget,
        );
        final scene = objects()
            .chartOf(objects().record(id)!)
            .sceneFor(360, 240, dark: dark, tokens: ChartUiTokens.light);
        expect(
          _find(scene.primitives, (p) => p.tag?.detail == 'errorBars'),
          isNotEmpty,
        );
        expect(tester.takeException(), isNull);
        await settle(tester);
      });

      testWidgets('when a pie slice is pulled out then the slice offset is '
          'written', (tester) async {
        final id = await tester.runAsync(() => chart('pie'));
        await pumpPanel(tester, dark: dark);
        await openSection(tester, 'Pie slice');
        expect(
          find.byKey(const ValueKey('chartEditor.sliceOffset')),
          findsOneWidget,
        );
        await s.run('sheets.chart.update', {
          'objectId': id,
          'patch': {
            'typeOptions': {
              'slices': {
                '1': {'offset': 0.3},
              },
            },
          },
        });
        await tester.pumpAndSettle();
        expect(specOf(id!).pieOptions.slices[1]?.offset, 0.3);
        expect(tester.takeException(), isNull);
        await settle(tester);
      });

      testWidgets('when a waterfall subtotal is added then it is listed with '
          'a label field and one undo removes it', (tester) async {
        final id = await tester.runAsync(() => chart('waterfall'));
        await pumpPanel(tester, dark: dark);
        await openSection(tester, 'Waterfall');
        final add = find.byKey(const ValueKey('chartEditor.subtotalAdd'));
        await tester.ensureVisible(add);
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(specOf(id!).waterfallOptions.subtotals, hasLength(1));
        expect(
          find.byKey(const ValueKey('chartEditor.subtotalRemove.0')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await s.undo();
        await tester.pump();
        expect(specOf(id).waterfallOptions.subtotals, isEmpty);
        await settle(tester);
      });
    });
  }

  group('Given a scorecard chart', () {
    test('when the key value cell is set then the scorecard shows that '
        'cell', () async {
      await s.type('A1', 'Total');
      await s.type('B1', '100');
      await s.type('D7', '42');
      final r = await s.run('sheets.chart.insert', {
        'ranges': ['A1:B1'],
        'type': 'scorecard',
      });
      final id = (r.data! as Map)['objectId']! as String;
      final range = s.sheet.gridRange(GridRect.cell(6, 3));
      await s.run('sheets.chart.update', {
        'objectId': id,
        'patch': {
          'typeOptions': {'keyValueRef': range.toJson()},
        },
      });
      final c = objects().chartOf(objects().record(id)!);
      c.invalidateData();
      expect(c.data.scorecard?.keyValue, 42);
    });
  });

  group('Given the chart editor described for agents', () {
    test('when describing and setting fields then they map to spec paths '
        'with one undo step each', () async {
      final id = await chart('line');
      final d = ChartEditorMcp.describe(s.editor)!;
      expect(d['objectId'], id);
      final fields = (d['fields']! as List).cast<Map<String, Object?>>();
      final ids = [for (final f in fields) f['id']];
      expect(ids, containsAll(['type', 'title.text', 'legend.position']));
      final key = objects().chartOf(objects().record(id)!).data.series.first;
      expect(ids, contains('series.${key.key}.color'));

      final steps = s.h.undoLabels.length;
      expect(
        await ChartEditorMcp.setField(s.editor, 'title.text', 'Sales'),
        isNull,
      );
      expect(specOf(id).title.text, 'Sales');
      expect(
        await ChartEditorMcp.setField(
          s.editor,
          'series.${key.key}.color',
          '#ff0000',
        ),
        isNull,
      );
      expect(specOf(id).seriesStyle(key.key).color, '#FF0000');
      expect(
        await ChartEditorMcp.setField(
          s.editor,
          'series.${key.key}.errorBars.type',
          'percent',
        ),
        isNull,
      );
      expect(specOf(id).seriesStyle(key.key).errorBars?['type'], 'percent');
      expect(s.h.undoLabels.length, steps + 3);
      expect(
        await ChartEditorMcp.setField(s.editor, 'title.text', null),
        isNull,
      );
      expect(specOf(id).title.text, '');

      expect(
        await ChartEditorMcp.setField(s.editor, 'style.background', 'red'),
        contains('#RRGGBB'),
      );
      expect(
        await ChartEditorMcp.setField(s.editor, 'nope', 1),
        startsWith('Unknown field'),
      );
      expect(await ChartEditorMcp.setField(s.editor, 'type', 'column'), isNull);
      expect(specOf(id).type, ChartType.column);
    });
  });
}

List<ScenePrimitive> _find(
  List<ScenePrimitive> list,
  bool Function(ScenePrimitive p) test,
) {
  final out = <ScenePrimitive>[];
  void visit(ScenePrimitive p) {
    if (test(p)) out.add(p);
    if (p is SGroup) p.children.forEach(visit);
    if (p is SClip) p.children.forEach(visit);
  }

  list.forEach(visit);
  return out;
}
