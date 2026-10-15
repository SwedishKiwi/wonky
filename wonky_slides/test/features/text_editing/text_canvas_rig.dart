import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_slides/features/canvas/slide_canvas.dart';
import 'package:wonky_slides/features/canvas/slide_canvas_controller.dart';
import 'package:wonky_slides/features/editor_screen/canvas_region.dart';
import 'package:wonky_slides/features/stage/slide_renderer.dart';
import 'package:wonky_slides/features/text_editing/text_editing_host.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;

import '../../harness/deck_harness.dart';
import '../../support/slides_harness.dart';
import '../stage/stage_fixture.dart' show RecordingFontRegistry;

/// A blank slide with a text box `box` ("Hello world", 200,700 900×120), a
/// shape `shape` with text (1300,600 400×200) and a plain shape `plain`
/// (1300,150 300×200); and a `titleBody` slide `placeholders` (empty title
/// and body placeholders).
class TextCanvasFixture {
  TextCanvasFixture() {
    slide = b.slide(layoutKey: 'blank');
    box = b.textBox(slide, 'Hello world', x: 200, y: 700, width: 900);
    shape = b.shape(
      slide,
      x: 1300,
      y: 600,
      width: 400,
      height: 200,
      text: 'Shape text',
    );
    plain = b.shape(slide, x: 1300, y: 150, width: 300, height: 200);
    placeholders = b.slide(layoutKey: 'titleBody');
  }

  final DeckBuilder b = DeckBuilder(title: 'Text');
  late final String slide, box, shape, plain, placeholders;
}

/// The canvas region (key scope + [SlideCanvas]) of a [DeckHarness] with
/// text editing (real dispatcher, planner and undo).
class TextCanvasRig {
  TextCanvasRig._(this.d, this.f, this.c);

  final DeckHarness d;
  final TextCanvasFixture f;
  final SlideCanvasController c;

  DeckModel get model => d.model;
  SlideTextEditing get text => textEditingOf(d.editor);

  static Future<TextCanvasRig> pump(
    WidgetTester tester, {
    Size size = const Size(1000, 600),
    Brightness brightness = Brightness.light,
    Role role = Role.owner,
  }) async {
    final f = TextCanvasFixture();
    final d = DeckHarness.open(fixture: f.b, role: role);
    final renderer = SlideRenderer(
      model: d.session.model,
      fonts: RecordingFontRegistry(),
    );
    final c = SlideCanvasController.attach(d.editor, renderer: renderer);
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
      size: size,
      brightness: brightness,
    );
    return TextCanvasRig._(d, f, c);
  }

  /// Shows the placeholders slide and returns its instance of [type].
  Future<String> placeholder(
    WidgetTester tester,
    SlidePlaceholderType type,
  ) async {
    d.editor.setCurrentSlide(f.placeholders);
    await tester.pump();
    return c.slide!.elements.firstWhere((e) => e.placeholderType == type).id;
  }

  /// The plain text of element [id].
  String textOf(String id) => SlidesText.plainText(model.element(id)?.text);

  /// Global position of slide point ([x], [y]).
  Offset at(WidgetTester tester, double x, double y) =>
      tester.getTopLeft(find.byType(SlideCanvas)) +
      c.viewport.toViewport(Offset(x, y));

  int _time = 1000;
  Duration _next([int ms = 1000]) => Duration(milliseconds: _time += ms);

  Future<void> click(WidgetTester tester, double x, double y) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.down(at(tester, x, y), timeStamp: _next());
    await g.up(timeStamp: _next(10));
    await tester.pump();
    await tester.pump();
  }

  Future<void> doubleClick(WidgetTester tester, double x, double y) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final p = at(tester, x, y);
    await g.down(p, timeStamp: _next());
    await g.up(timeStamp: _next(20));
    await g.down(p, timeStamp: _next(80));
    await g.up(timeStamp: _next(20));
    await tester.pump();
    await tester.pump();
  }

  Future<void> drag(
    WidgetTester tester,
    Offset from,
    Offset to, {
    int steps = 4,
  }) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.down(at(tester, from.dx, from.dy), timeStamp: _next());
    for (var i = 1; i <= steps; i++) {
      final p = Offset.lerp(from, to, i / steps)!;
      await g.moveTo(at(tester, p.dx, p.dy), timeStamp: _next(16));
      await tester.pump();
    }
    await g.up(timeStamp: _next(16));
    await tester.pump();
    await tester.pump();
  }
}
