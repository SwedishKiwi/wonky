import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/charts/chart_insert.dart';
import 'package:wonky_sheets/features/charts/editor/chart_type_picker.dart';
import 'package:wonky_sheets/features/charts/render/chart_painter.dart';
import 'package:wonky_sheets/features/charts3d/chart3d_gpu.dart';
import 'package:wonky_sheets/features/charts3d/editor/chart3d_section.dart';
import 'package:wonky_sheets/features/grid/grid_area.dart';
import 'package:wonky_sheets/features/objects/objects_controller.dart';
import 'package:wonky_sheets/features/objects/objects_layer.dart';
import 'package:wonky_sheets/l10n/sheets_l10n.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

/// Records GPU paint calls instead of drawing.
class _FakeGpu implements Chart3DGpuRenderer {
  final List<Object> keys = [];

  @override
  bool paint(
    ui.Canvas canvas,
    Chart3DScene scene, {
    required Object key,
    required double pixelRatio,
  }) {
    keys.add(key);
    return true;
  }

  @override
  void release(Object key) {}
}

void main() {
  late SheetsHarness s;

  ObjectsController objects() => ObjectsController.of(s.editor);
  ChartSpec specOf(String id) =>
      ChartSpec.fromJson(objects().record(id)!.specJson);

  Future<void> seed() async {
    final rows = [
      ['Region', 'Q1', 'Q2'],
      ['North', '10', '12'],
      ['South', '7', '9'],
      ['East', '4', '6'],
    ];
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < 3; c++) {
        await s.type('${'ABC'[c]}${r + 1}', rows[r][c]);
      }
    }
  }

  Future<String> insert({String type = 'column'}) async {
    final r = await s.run('sheets.chart.insert', {
      'ranges': ['A1:C4'],
      'type': type,
      'anchor': {'cell': 'E2', 'width': 360, 'height': 240},
    });
    expect(r.isOk, isTrue, reason: '${r.message}');
    return (r.data! as Map)['objectId']! as String;
  }

  setUp(() async {
    s = SheetsHarness.open();
    await seed();
  });
  tearDown(() async {
    ObjectsController.maybeOf(s.editor)?.dispose();
    await s.dispose();
  });

  group('Given a column chart', () {
    late String id;
    setUp(() async => id = await insert());

    test('when switching to the 3D column variant then threeD is on and one '
        'undo step turns it off', () async {
      final r = await s.run('sheets.chart.setType', {
        'objectId': id,
        'type': 'column',
        'threeD': true,
      });

      expect(r.isOk, isTrue);
      expect(specOf(id).is3D, isTrue);
      expect(variantOf(specOf(id)).id, 'column3d');
      await s.undo();
      expect(specOf(id).is3D, isFalse);
    });

    test('when toggling 3D twice then it is off again', () async {
      await s.run('sheets.chart.toggle3D', {'objectId': id});
      expect(specOf(id).is3D, isTrue);
      await s.run('sheets.chart.toggle3D', {'objectId': id});
      expect(specOf(id).is3D, isFalse);
    });

    test(
      'when rotating and resetting the view then the angles follow',
      () async {
        await s.run('sheets.chart.toggle3D', {'objectId': id});
        await s.run('sheets.chart.rotate3D', {
          'objectId': id,
          'dAzimuth': -30,
          'dElevation': 100,
        });
        expect(specOf(id).threeD.azimuth, 350);
        expect(specOf(id).threeD.elevation, 90);

        await s.run('sheets.chart.reset3DView', {'objectId': id});
        expect(specOf(id).threeD.azimuth, isNull);
        expect(specOf(id).threeD.elevation, isNull);
        await s.undo();
        expect(specOf(id).threeD.azimuth, 350);
      },
    );

    test('when the chart is a scatter chart then 3D does not apply', () async {
      await s.run('sheets.chart.setType', {'objectId': id, 'type': 'scatter'});

      await expectLater(
        s.run('sheets.chart.toggle3D', {'objectId': id}),
        throwsA(anything),
      );
      expect(specOf(id).is3D, isFalse);
    });

    test('when the 3D data changes then the controller animates', () async {
      await s.run('sheets.chart.toggle3D', {'objectId': id});
      final c = objects().chartOf(objects().record(id)!);
      c.sceneFor(360, 240, dark: false, tokens: ChartUiTokens.light);
      final before = c.transitionRequests.value;

      await s.type('B2', '30');
      c.invalidateData();
      c.sceneFor(360, 240, dark: false, tokens: ChartUiTokens.light);

      expect(c.transitionRequests.value, before + 1);
      expect(c.transition3D, 0);
      c.transition3D = 1;
      expect(c.transition3D, 1);
    });
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    group('Given 3D charts in $mode mode', () {
      for (final type in ChartType.values.where((t) => t.supports3D)) {
        testWidgets('when painting a 3D ${type.id} chart in software then it '
            'draws without errors', (tester) async {
          final ranges = ChartInsert.rangesFromA1(s.editor, ['A1:C4']);
          final spec = ChartInsert.specFor(
            s.editor,
            ranges,
            type: type,
          ).copyWith(threeD: const ChartThreeD(enabled: true));
          final tokens = dark ? ChartUiTokens.dark : ChartUiTokens.light;
          final scene = ChartPipeline.build(
            spec: spec,
            model: s.model,
            values: s.editor.engine,
            size: const ChartSize(360, 240),
            theme: ChartTheme.from(s.model.theme, dark: dark, tokens: tokens),
            measurer: FlutterTextMeasurer.instance,
          ).scene;
          expect(scene.threeD, isNotNull);
          await tester.runAsync(() async {
            final png = await chartSceneToPng(scene, pixelRatio: 1);
            expect(png, isNotNull);
          });
        });
      }

      testWidgets('when a GPU backend is given then it draws the geometry', (
        tester,
      ) async {
        final ranges = ChartInsert.rangesFromA1(s.editor, ['A1:C4']);
        final spec = ChartInsert.specFor(
          s.editor,
          ranges,
        ).copyWith(threeD: const ChartThreeD(enabled: true));
        final scene = ChartPipeline.build(
          spec: spec,
          model: s.model,
          values: s.editor.engine,
          size: const ChartSize(360, 240),
          theme: ChartTheme.from(s.model.theme, dark: dark),
          measurer: FlutterTextMeasurer.instance,
        ).scene;
        final gpu = _FakeGpu();
        final recorder = ui.PictureRecorder();
        paintChartScene(ui.Canvas(recorder), scene, gpu: gpu, gpuKey: 'k');
        recorder.endRecording().dispose();

        expect(gpu.keys, ['k']);
      });

      testWidgets('when showing the 3D section at 360 px then every control '
          'fits and toggling writes threeD', (tester) async {
        final patches = <Map<String, Object?>>[];
        var spec = const ChartSpec(
          threeD: ChartThreeD(enabled: true, azimuth: 40),
        );
        await pumpSheets(
          tester,
          s,
          dark: dark,
          size: const Size(360, 900),
          child: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: chart3DControls(sheetsL10n(context), spec, (
                    p, [
                    _,
                  ]) {
                    patches.add(p);
                    setState(() => spec = spec.patch(p));
                  }),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('chartEditor.azimuth')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('chartEditor.reset3DView')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('chartEditor.reset3DView')));
        await tester.pump();
        expect(patches.last, {
          'threeD': {'azimuth': null, 'elevation': null},
        });

        await tester.tap(find.text('Show in 3D'));
        await tester.pump();
        expect(patches.last, {
          'threeD': {'enabled': null},
        });
        expect(find.byKey(const ValueKey('chartEditor.azimuth')), findsNothing);
      });

      testWidgets('when painting the 3D type icons then they draw', (
        tester,
      ) async {
        await pumpSheets(
          tester,
          s,
          dark: dark,
          child: Wrap(
            children: [
              for (final v in chartVariantGroups['3d']!)
                SizedBox(
                  width: 48,
                  height: 36,
                  child: ChartTypeIcon(variant: v),
                ),
            ],
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(ChartTypeIcon), findsNWidgets(11));
      });
    });
  }

  group('Given a selected 3D chart over the grid', () {
    testWidgets('when dragging inside the plot then it orbits instead of '
        'moving, in one undo step', (tester) async {
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
      final id = await insert();
      await s.run('sheets.chart.toggle3D', {'objectId': id});
      objects().select(id);
      await tester.pumpAndSettle();
      final anchor = objects().record(id)!.anchorJson;
      final az0 = specOf(id).threeD.azimuthFor(ChartType.column);
      final box = find.byKey(ValueKey('sheets.object.$id'));
      final center = tester.getCenter(box);

      final g = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
      );
      for (var i = 0; i < 8; i++) {
        await g.moveBy(const Offset(-10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 200));
      await g.up();
      await tester.pumpAndSettle();

      final az = specOf(id).threeD.azimuth!;
      expect(az, isNot(az0));
      expect(objects().record(id)!.anchorJson, anchor);
      await s.undo();
      expect(specOf(id).threeD.azimuth, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
