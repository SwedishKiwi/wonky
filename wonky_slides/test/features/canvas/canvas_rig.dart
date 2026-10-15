import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_slides/features/canvas/slide_canvas.dart';
import 'package:wonky_slides/features/canvas/slide_canvas_controller.dart';
import 'package:wonky_slides/features/stage/slide_renderer.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_sync_models/ids.dart' show Base62Uuid;

import '../../harness/deck_harness.dart';
import '../../support/slides_harness.dart';
import '../stage/stage_fixture.dart' show RecordingFontRegistry;

/// A solid fill.
String solid(String color) =>
    jsonEncode({'v': 1, 'type': 'solid', 'color': color});

/// One blank slide with filled shapes `a` (100,100 400×200), `b`
/// (700,100 400×200), `c` (1300,600 300×200), an element group `g`
/// (100,600 600×300) with children `g1` (100,600 200×100) and `g2`
/// (500,800 200×100), a locked shape `locked` (1300,100 300×200) above
/// `under` (same frame), an image `img` (800,600 300×300) and a straight
/// line `line` from (200,950) to (600,950); and an empty second slide.
class CanvasFixture {
  CanvasFixture() {
    slide = b.slide(layoutKey: 'blank');
    a = _shape(100, 100, 400, 200, '#EF4444');
    bShape = _shape(700, 100, 400, 200, '#3B82F6');
    c = _shape(1300, 600, 300, 200, '#22C55E');
    g1 = b.shape(
      slide,
      x: 100,
      y: 600,
      width: 200,
      height: 100,
      parentId: groupId,
      fillJson: solid('#A855F7'),
    );
    g2 = b.shape(
      slide,
      x: 500,
      y: 800,
      width: 200,
      height: 100,
      parentId: groupId,
      fillJson: solid('#F59E0B'),
    );
    g = b.elementGroup(
      slide,
      groupId: groupId,
      x: 100,
      y: 600,
      width: 600,
      height: 300,
    );
    under = _shape(1300, 100, 300, 200, '#64748B');
    locked = b.element(
      slide,
      ElementKind.shape,
      x: 1300,
      y: 100,
      width: 300,
      height: 200,
      columns: {
        ElementCols.dataJson: jsonEncode({'v': 1, 'geometry': 'roundRect'}),
        ElementCols.fillJson: solid('#0EA5E9'),
        ElementCols.locked: true,
      },
    );
    img = b.element(
      slide,
      ElementKind.image,
      x: 800,
      y: 600,
      width: 300,
      height: 300,
      columns: {
        ElementCols.dataJson: jsonEncode({
          'v': 1,
          'src': 'wonky-file://none',
          'naturalWidth': 2,
          'naturalHeight': 2,
        }),
      },
    );
    line = b.element(
      slide,
      ElementKind.line,
      x: 200,
      y: 950,
      width: 400,
      height: 0,
      columns: {
        ElementCols.dataJson: jsonEncode({
          'v': 1,
          'routing': 'straight',
          'start': {'x': 0, 'y': 0},
          'end': {'x': 1, 'y': 0},
        }),
        ElementCols.strokeJson: jsonEncode({
          'v': 1,
          'color': '#111111',
          'width': 6,
        }),
      },
    );
    slide2 = b.slide(layoutKey: 'blank');
  }

  final DeckBuilder b = DeckBuilder(title: 'Canvas');
  final String groupId = '0b6a3c4e-1f00-4a00-8000-00000000c0de';
  late final String slide,
      slide2,
      a,
      bShape,
      c,
      g,
      g1,
      g2,
      under,
      locked,
      img,
      line;

  String _shape(double x, double y, double w, double h, String color) =>
      b.shape(slide, x: x, y: y, width: w, height: h, fillJson: solid(color));

  /// The `connect` JSON of a glue to [id]'s [site].
  static Map<String, Object?> glue(String id, String site) => {
    'elementId': Base62Uuid.encode(id),
    'site': site,
  };
}

/// A [SlideCanvas] on a [DeckHarness] (real dispatcher, planner and undo).
class CanvasRig {
  CanvasRig._(this.d, this.fixture, this.controller);

  final DeckHarness d;
  final CanvasFixture fixture;
  final SlideCanvasController controller;

  DeckModel get model => d.model;

  /// Opens the harness and pumps the canvas at [size].
  static Future<CanvasRig> pump(
    WidgetTester tester, {
    CanvasFixture? fixture,
    Size size = const Size(1000, 600),
    Brightness brightness = Brightness.light,
    Role role = Role.owner,
  }) async {
    final f = fixture ?? CanvasFixture();
    final d = DeckHarness.open(fixture: f.b, role: role);
    final renderer = SlideRenderer(
      model: d.session.model,
      fonts: RecordingFontRegistry(),
    );
    final c = SlideCanvasController.attach(d.editor, renderer: renderer);
    addTearDown(() async {
      c.dispose();
      renderer.dispose();
      await d.dispose();
    });
    await pumpSlides(
      tester,
      d.h,
      SlideCanvas(editor: d.editor, controller: c),
      size: size,
      brightness: brightness,
    );
    return CanvasRig._(d, f, c);
  }

  /// Global position of slide point ([x], [y]).
  Offset at(WidgetTester tester, double x, double y) =>
      tester.getTopLeft(find.byType(SlideCanvas)) +
      controller.viewport.toViewport(Offset(x, y));

  int _time = 1000;

  Duration _next([int ms = 1000]) => Duration(milliseconds: _time += ms);

  /// A mouse click at slide point ([x], [y]) (separate clicks never count as
  /// a double click).
  Future<void> click(
    WidgetTester tester,
    double x,
    double y, {
    int buttons = kPrimaryMouseButton,
  }) async {
    final g = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: buttons,
    );
    await g.down(at(tester, x, y), timeStamp: _next());
    await g.up(timeStamp: _next(10));
    await tester.pump();
  }

  /// A double click at slide point ([x], [y]).
  Future<void> doubleClick(WidgetTester tester, double x, double y) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final p = at(tester, x, y);
    await g.down(p, timeStamp: _next());
    await g.up(timeStamp: _next(20));
    await g.down(p, timeStamp: _next(80));
    await g.up(timeStamp: _next(20));
    await tester.pump();
  }

  /// A mouse drag between slide points, in [steps] moves; the gesture is
  /// released unless [hold].
  Future<TestGesture> drag(
    WidgetTester tester,
    Offset from,
    Offset to, {
    int steps = 4,
    bool hold = false,
  }) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.down(at(tester, from.dx, from.dy), timeStamp: _next());
    for (var i = 1; i <= steps; i++) {
      final p = Offset.lerp(from, to, i / steps)!;
      await g.moveTo(at(tester, p.dx, p.dy), timeStamp: _next(16));
      await tester.pump();
    }
    if (!hold) {
      await g.up(timeStamp: _next(16));
      await tester.pumpAndSettle();
    }
    return g;
  }

  /// A drag from viewport point [fromPx] (e.g. a handle) to slide point
  /// [to].
  Future<void> dragFromPx(
    WidgetTester tester,
    Offset fromPx,
    Offset to, {
    int steps = 4,
  }) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final origin = tester.getTopLeft(find.byType(SlideCanvas));
    await g.down(origin + fromPx, timeStamp: _next());
    final start = controller.viewport.toSlide(fromPx);
    for (var i = 1; i <= steps; i++) {
      final p = Offset.lerp(start, to, i / steps)!;
      await g.moveTo(at(tester, p.dx, p.dy), timeStamp: _next(16));
      await tester.pump();
    }
    await g.up(timeStamp: _next(16));
    await tester.pumpAndSettle();
  }

  /// Holds [key] while running [body].
  static Future<void> holding(
    WidgetTester tester,
    LogicalKeyboardKey key,
    Future<void> Function() body,
  ) async {
    await tester.sendKeyDownEvent(key);
    try {
      await body();
    } finally {
      await tester.sendKeyUpEvent(key);
    }
  }

  /// The selected ids.
  List<String> get selected => d.editor.selectedElementIds;

  /// The stored frame of [id].
  SuRectLike frame(String id) {
    final e = model.element(id)!;
    return (x: e.x!, y: e.y!, w: e.width!, h: e.height!);
  }
}

/// A stored frame as a record (readable expectations).
typedef SuRectLike = ({double x, double y, double w, double h});
