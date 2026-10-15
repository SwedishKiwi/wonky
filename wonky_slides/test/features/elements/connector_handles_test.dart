import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/canvas/canvas_interactions.dart';
import 'package:wonky_slides/features/canvas/slide_canvas.dart';
import 'package:wonky_slides/features/canvas/slide_canvas_controller.dart';
import 'package:wonky_slides/features/editor_screen/canvas_region.dart';
import 'package:wonky_slides/features/elements/line/connector_handles.dart';
import 'package:wonky_slides/features/stage/slide_renderer.dart';
import 'package:wonky_slides/features/text_editing/text_editing_host.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart' show ConnectorRouter;
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_sync_models/ids.dart' show Base62Uuid;

import '../../harness/deck_harness.dart';
import '../../support/slides_harness.dart';
import '../stage/stage_fixture.dart' show RecordingFontRegistry;

/// Two shapes `a` (100,400 300×200) and `b` (1200,100 300×200) and a
/// connector from a's right site to b's left site with [routing].
class _Fixture {
  _Fixture(String routing) {
    slide = b.slide(layoutKey: 'blank');
    a = b.shape(slide, x: 100, y: 400, width: 300, height: 200);
    c = b.shape(slide, x: 1200, y: 100, width: 300, height: 200);
    line = b.element(
      slide,
      ElementKind.line,
      x: 400,
      y: 200,
      width: 800,
      height: 300,
      columns: {
        ElementCols.dataJson: jsonEncode({
          'v': 1,
          'routing': routing,
          'start': {
            'x': 0,
            'y': 1,
            'connect': {'elementId': Base62Uuid.encode(a), 'site': 'right'},
          },
          'end': {
            'x': 1,
            'y': 0,
            'connect': {'elementId': Base62Uuid.encode(c), 'site': 'left'},
          },
        }),
      },
    );
  }

  final DeckBuilder b = DeckBuilder(title: 'Connectors');
  late final String slide, a, c, line;
}

void main() {
  late _Fixture f;
  late DeckHarness d;
  late SlideCanvasController c;

  Future<void> pump(WidgetTester tester, String routing) async {
    f = _Fixture(routing);
    d = DeckHarness.open(fixture: f.b);
    d.editor.setCurrentSlide(f.slide);
    final renderer = SlideRenderer(
      model: d.session.model,
      fonts: RecordingFontRegistry(),
    );
    c = SlideCanvasController.attach(d.editor, renderer: renderer);
    addTearDown(() async {
      textEditingOf(d.editor).dispose();
      c.dispose();
      renderer.dispose();
      await d.dispose();
    });
    await pumpSlides(
      tester,
      d.h,
      CanvasRegion(
        services: d.services,
        editor: d.editor,
        onContextMenu: (_, _) {},
      ),
      size: const Size(1000, 600),
    );
    selectionOf(d.editor).select([f.line]);
    await tester.pump();
  }

  Offset at(WidgetTester tester, Offset su) =>
      tester.getTopLeft(find.byType(SlideCanvas)) + c.viewport.toViewport(su);

  Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.down(at(tester, from), timeStamp: const Duration(seconds: 5));
    for (var i = 1; i <= 4; i++) {
      await g.moveTo(
        at(tester, Offset.lerp(from, to, i / 4)!),
        timeStamp: Duration(seconds: 5, milliseconds: 16 * i),
      );
      await tester.pump();
    }
    await g.up(timeStamp: const Duration(seconds: 5, milliseconds: 100));
    await tester.pump();
    await tester.pump();
  }

  List<Offset> route() => [
    for (final p in c.scene!.routes[f.line]!) Offset(p.x, p.y),
  ];

  testWidgets('Given a selected elbow connector when its middle segment '
      'handle is dragged then the segment moves across (one step), the '
      'ends stay glued, and undo restores the automatic route', (tester) async {
    await pump(tester, 'elbow');
    final layer = CanvasInteractions.find<ConnectorHandles>(c)!;
    final handles = layer.target!.$3;
    expect(handles, hasLength(1));
    final h = handles.single;
    expect(h.horizontal, isFalse);
    final before = route();
    expect(before, hasLength(4));

    await drag(tester, h.at, h.at + const Offset(120, 40));

    final after = route();
    expect(after.first, before.first);
    expect(after.last, before.last);
    expect(after[1].dx, closeTo(before[1].dx + 120, 1e-3));
    expect(after[2].dx, closeTo(before[2].dx + 120, 1e-3));
    expect(after[1].dy, closeTo(before[1].dy, 1e-3));
    expect(d.undoLabels, ['slides.line.setWaypoints']);

    // The glued end still follows its shape.
    await d.run('slides.element.move', {
      'dx': 0,
      'dy': 50,
      'ids': [f.a],
    });
    await tester.pump();
    expect(route().first.dy, closeTo(before.first.dy + 50, 1e-3));

    await d.undo();
    await d.undo();
    await tester.pump();
    expect(route(), before);
  });

  testWidgets('Given a selected curved connector when its bend handle is '
      'dragged then the curve passes through the drop point', (tester) async {
    await pump(tester, 'curved');
    final layer = CanvasInteractions.find<ConnectorHandles>(c)!;
    final h = layer.target!.$3.single;
    expect(h.curved, isTrue);
    const to = Offset(800, 600);
    await drag(tester, h.at, to);

    final pts = c.scene!.routes[f.line]!;
    final m = ConnectorRouter.curveMidpoint(pts);
    expect(m.x, closeTo(to.dx, 1e-2));
    expect(m.y, closeTo(to.dy, 1e-2));
    // The handle sits on the new bend.
    expect(layer.target!.$3.single.at.dx, closeTo(to.dx, 1e-2));
  });

  testWidgets('Given connectors when agents set waypoints then straight '
      'lines refuse them and [] resets the route', (tester) async {
    await pump(tester, 'elbow');
    final before = route();
    final r = await d.run('slides.line.setWaypoints', {
      'id': f.line,
      'waypoints': [
        {'x': 700, 'y': 500},
        {'x': 700, 'y': 200},
      ],
    });
    expect(r.isOk, isTrue);
    await tester.pump();
    expect(route()[1].dx, closeTo(700, 1e-3));
    await d.run('slides.line.setWaypoints', {'id': f.line, 'waypoints': []});
    await tester.pump();
    expect(route(), before);

    await d.run('slides.line.setRouting', {
      'routing': 'straight',
      'ids': [f.line],
    });
    final straight = await d.run('slides.line.setWaypoints', {
      'id': f.line,
      'waypoints': [
        {'x': 1, 'y': 2},
      ],
    });
    expect(straight.isOk, isFalse);
    expect(CanvasInteractions.find<ConnectorHandles>(c)!.target, isNull);
  });
}
