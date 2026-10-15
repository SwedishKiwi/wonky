import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/config/slides_features.dart';
import 'package:wonky_slides/features/elements/chart/chart_canvas_mode.dart';
import 'package:wonky_slides_core/charts.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/schema.dart' show ElementCols;
import 'package:wonky_slides_core/themes.dart'
    show ResolvedBackground, ResolvedSolidFill, SuRect;

import '../../canvas/canvas_rig.dart';
import 'chart_fixture.dart';

/// The canvas side of charts (Slides 08 §9.4, §10.2): charts render from
/// their snapshots, orbit by drag on a selected 3D chart, morph on update.
void main() {
  setUp(() {
    SlidesFeatures.enabled = {...SlidesFeatures.shipped, SlidesFeature.charts};
  });
  tearDown(SlidesFeatures.reset);

  (CanvasFixture, String) fixture({bool threeD = true}) {
    final f = CanvasFixture();
    final id = f.b.element(
      f.slide,
      ElementKind.chart,
      x: 400,
      y: 250,
      width: 1100,
      height: 680,
      columns: {
        ElementCols.dataJson: jsonEncode({
          'v': 1,
          'source': 'linked',
          'style': {'useDeckTheme': true},
        }),
      },
    );
    final r = resolved(threeD: threeD);
    f.b.chartLink(
      id,
      sourceSpecJson: r.sourceSpecJson,
      dataSnapshotJson: r.dataSnapshotJson,
      sourceVersion: r.sourceVersion,
    );
    return (f, id);
  }

  testWidgets('Given a linked chart when the canvas draws the slide then it '
      'shows the snapshot as a chart node', (tester) async {
    final (f, id) = fixture(threeD: false);
    final rig = await CanvasRig.pump(tester, fixture: f);
    final nodes = rig.controller.scene!.nodesOf(id);
    expect(nodes.expand(_charts), isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Given a selected 3D chart when its plot is dragged then it '
      'orbits in one undo step instead of moving', (tester) async {
    final (f, id) = fixture();
    final rig = await CanvasRig.pump(tester, fixture: f);
    rig.d.editor.selectElements([id]);
    await tester.pump();
    final before = rig.frame(id);
    await rig.drag(tester, const Offset(950, 600), const Offset(1100, 640));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(rig.frame(id), before);
    final cam = ChartElementData.fromJson(
      rig.model.element(id)!.dataJson,
    ).camera;
    expect(cam, isNotNull);
    expect(cam!.azimuth, isNot(20));
    expect(rig.d.undoLabels, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  test('Given a scene when a chart node is replaced then only that node '
      'changes', () {
    final chart = ChartScene(
      width: 10,
      height: 10,
      background: 0,
      primitives: const [],
    );
    final other = ChartScene(
      width: 20,
      height: 20,
      background: 0,
      primitives: const [],
    );
    final scene = SlideScene(
      slideId: 's',
      width: 100,
      height: 100,
      background: const ResolvedBackground(ResolvedSolidFill(0xffffffff), null),
      nodes: [
        GroupNode(
          elementId: 'g',
          children: [
            ChartNode(
              elementId: 'c',
              scene: chart,
              dst: const SuRect(0, 0, 10, 10),
            ),
          ],
        ),
      ],
    );
    final out = ChartCanvasMode.replaceChart(scene, 'c', other);
    final node = (out.nodes.single as GroupNode).children.single as ChartNode;
    expect(identical(node.scene, other), isTrue);
    expect(
      identical(ChartCanvasMode.replaceChart(scene, 'x', other), scene),
      isTrue,
    );
  });
}

Iterable<ChartNode> _charts(SceneNode n) => switch (n) {
  ChartNode() => [n],
  GroupNode(:final children) => children.expand(_charts),
  _ => const [],
};
