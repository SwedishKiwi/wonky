import 'package:clock/clock.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart' hide TextNode;
import 'package:super_editor/super_editor_test.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_slides/features/canvas/slide_canvas.dart';
import 'package:wonky_slides/features/text_editing/slide_text_editor.dart';
import 'package:wonky_slides/features/text_editing/text_editing_layer.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart'
    show GroupNode, SceneNode, TextNode;
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;

import 'text_canvas_rig.dart';

/// Runs [body] with a fixed clock (undo coalescing window, 15 §4).
Future<void> _fixed(Future<void> Function() body) =>
    withClock(Clock.fixed(DateTime.utc(2026, 10, 15, 12)), body);

Finder get _layer => find.byKey(SlideTextEditingLayer.layerKey);

/// The text node of [id] in the canvas' stage scene, or null.
TextNode? _stageText(WidgetTester tester, String id) {
  final canvas = tester.widget<SlideCanvas>(find.byType(SlideCanvas));
  TextNode? walk(SceneNode n) {
    if (n is TextNode && n.elementId == id) return n;
    if (n is GroupNode) {
      for (final c in n.children) {
        final t = walk(c);
        if (t != null) return t;
      }
    }
    return null;
  }

  for (final n in canvas.controller.scene!.nodes) {
    final t = walk(n);
    if (t != null) return t;
  }
  return null;
}

void main() {
  group('Given a slide with a text box on the canvas', () {
    testWidgets('when the box is double-clicked then text editing starts with '
        'the overlay, and Esc selects the box again', (tester) async {
      final r = await TextCanvasRig.pump(tester);

      await r.doubleClick(tester, 400, 740);

      expect(r.text.elementId, r.f.box);
      expect(r.d.editor.textEditing, isTrue);
      expect(_layer, findsOneWidget);
      expect(r.d.editor.selectedElementIds, [r.f.box]);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(r.text.isEditing, isFalse);
      expect(r.d.editor.textEditing, isFalse);
      expect(r.d.editor.selectedElementIds, [r.f.box]);
      expect(_layer, findsNothing);
    });

    testWidgets('when Enter is pressed on the selected box and text is typed '
        'then it is written as one "Typing" step, and a click on another '
        'object ends editing and selects it', (tester) async {
      await _fixed(() async {
        final r = await TextCanvasRig.pump(tester);
        await r.click(tester, 400, 740);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(r.text.elementId, r.f.box);

        await tester.typeImeText('!');
        await tester.pump(const Duration(milliseconds: 350));

        expect(r.textOf(r.f.box), 'Hello world!\n');
        expect(r.d.undoLabels, ['Typing']);

        await r.click(tester, 1450, 250);

        expect(r.text.isEditing, isFalse);
        expect(r.d.editor.selectedElementIds, [r.f.plain]);
      });
    });

    testWidgets('when a character is typed with the box selected then editing '
        'starts at the end with that character (type-to-edit)', (tester) async {
      final r = await TextCanvasRig.pump(tester);
      await r.click(tester, 400, 740);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyX, character: 'x');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyX);
      await tester.pump(const Duration(milliseconds: 350));

      expect(r.text.elementId, r.f.box);
      expect(r.textOf(r.f.box), 'Hello worldx\n');
    });

    testWidgets('when arrows and T are pressed while editing then they move '
        'the caret and type instead of nudging or arming a tool', (
      tester,
    ) async {
      final r = await TextCanvasRig.pump(tester);
      await r.doubleClick(tester, 400, 740);
      final before = r.model.element(r.f.box)!.x;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pump();

      expect(r.model.element(r.f.box)!.x, before);
      expect(r.d.editor.armedTool, isNull);
      expect(r.text.isEditing, isTrue);
    });

    testWidgets('when text is selected and Ctrl+B is pressed then the bold '
        'command formats it in one step', (tester) async {
      final r = await TextCanvasRig.pump(tester);
      await r.doubleClick(tester, 400, 740);
      r.text.active!.selectRange(0, 5);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      final ops = SlidesText.parse(r.model.element(r.f.box)!.text).operations;
      expect(ops.first.data, 'Hello');
      expect(ops.first.attributes?['bold'], isTrue);
      expect(r.d.undoLabels, ['Bold']);
      expect(r.text.isEditing, isTrue);
    });

    testWidgets('when typing is pending and the Edit menu undo runs then the '
        'typing is written first and undone with the burst', (tester) async {
      await _fixed(() async {
        final r = await TextCanvasRig.pump(tester);
        await r.doubleClick(tester, 400, 740);
        r.text.active!.selectRange(11);
        await tester.typeImeText(' there');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.typeImeText(' again');
        await tester.pump(const Duration(milliseconds: 50));
        expect(r.text.active!.hasPendingEdits, isTrue);

        await r.d.h.services.dispatcher.invoke(
          'shell.edit.undo',
          source: InvocationSource.menu,
        );
        await tester.pump();

        expect(r.text.active!.hasPendingEdits, isFalse);
        expect(r.textOf(r.f.box), 'Hello world\n');
        expect(r.d.undoLabels, isEmpty);
      });
    });

    testWidgets('when the IME composes text then the composition survives the '
        'idle write and the committed text is stored', (tester) async {
      final r = await TextCanvasRig.pump(tester);
      await r.click(tester, 400, 740);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      final client = imeClientGetter();
      var v = client.currentTextEditingValue!;
      final at = v.selection.baseOffset;

      await tester.ime.sendDeltas([
        TextEditingDeltaInsertion(
          oldText: v.text,
          textInserted: 'k',
          insertionOffset: at,
          selection: TextSelection.collapsed(offset: at + 1),
          composing: TextRange(start: at, end: at + 1),
        ),
      ], getter: imeClientGetter);
      await tester.pump(const Duration(milliseconds: 350));
      final composing = r.text.active!.composer.composingRegion.value;
      v = client.currentTextEditingValue!;
      await tester.ime.sendDeltas([
        TextEditingDeltaReplacement(
          oldText: v.text,
          replacementText: 'か',
          replacedRange: TextRange(start: at, end: at + 1),
          selection: TextSelection.collapsed(offset: at + 1),
          composing: TextRange.empty,
        ),
      ], getter: imeClientGetter);
      await tester.pump(const Duration(milliseconds: 350));

      expect(composing, isNotNull);
      expect(r.textOf(r.f.box), 'Hello worldか\n');
    });
  });

  group('Given empty placeholders', () {
    testWidgets('when the title prompt is clicked then the caret is in it, and '
        'typing replaces the prompt', (tester) async {
      final r = await TextCanvasRig.pump(tester);
      final title = await r.placeholder(tester, SlidePlaceholderType.title);
      final f = r.c.frameOf(title)!;

      await r.click(tester, f.cx, f.cy);
      expect(r.text.elementId, title);

      await tester.typeImeText('Agenda');
      await tester.pump(const Duration(milliseconds: 350));
      expect(r.textOf(title), 'Agenda\n');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_stageText(tester, title), isNotNull);
    });

    testWidgets('when text is typed into the body placeholder then its '
        'paragraphs are bulleted by the layout default, in the overlay and '
        'on the stage', (tester) async {
      final r = await TextCanvasRig.pump(tester);
      final body = await r.placeholder(tester, SlidePlaceholderType.body);
      final f = r.c.frameOf(body)!;
      await r.click(tester, f.cx, f.cy);
      expect(r.text.elementId, body);

      await tester.typeImeText('Point');
      await tester.pump(const Duration(milliseconds: 350));
      final overlayPara = find
          .descendant(
            of: _layer,
            matching: find.byWidgetPredicate((w) => w is RichText),
          )
          .evaluate()
          .map((e) => e.renderObject! as RenderParagraph)
          .firstWhere((p) => p.text.toPlainText() == 'Point');
      final root = tester.renderObject<RenderBox>(
        find.descendant(of: _layer, matching: find.byType(CustomScrollView)),
      );
      final overlayX = overlayPara
          .localToGlobal(Offset.zero, ancestor: root)
          .dx;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      final node = _stageText(tester, body)!;
      expect(r.textOf(body), 'Point\n');
      expect(node.layout.lines.first.left, greaterThan(0));
      expect(overlayX, greaterThan(0));
    });
  });

  group('Given the text box tool', () {
    testWidgets('when it is armed and the slide is clicked then an editable '
        'auto-width box is created there; left empty it disappears with its '
        'undo step', (tester) async {
      final r = await TextCanvasRig.pump(tester);
      await r.d.h.services.dispatcher.invoke(
        'slides.insert.textBox',
        source: InvocationSource.toolbar,
      );
      expect(r.d.editor.armedTool, 'text');

      await r.click(tester, 80, 1030);

      final id = r.text.elementId!;
      final e = r.model.element(id)!;
      expect(e.kind, ElementKind.text);
      expect(e.x, closeTo(80, 1));
      expect(e.textStyleJson, contains('"wrap":false'));
      expect(r.d.editor.armedTool, isNull);
      expect(r.d.undoLabels, hasLength(1));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(r.model.element(id), isNull);
      expect(r.d.undoLabels, isEmpty);
    });

    testWidgets('when a box is dragged out and typed into then it keeps the '
        'dragged width and its text', (tester) async {
      final r = await TextCanvasRig.pump(tester);
      await r.d.h.services.dispatcher.invoke(
        'slides.insert.textBox',
        source: InvocationSource.toolbar,
      );

      await r.drag(tester, const Offset(60, 1000), const Offset(560, 1060));
      final id = r.text.elementId!;
      await tester.typeImeText('Note');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      final e = r.model.element(id)!;
      expect(e.width, closeTo(500, 2));
      expect(r.textOf(id), 'Note\n');
      expect(e.textStyleJson, isNot(contains('"wrap":false')));
    });
  });

  for (final (name, size, brightness) in [
    ('light, wide', const Size(1000, 600), Brightness.light),
    ('dark, narrow', const Size(360, 640), Brightness.dark),
  ]) {
    testWidgets('Given the $name canvas when a box is edited then the overlay '
        'renders without errors', (tester) async {
      final r = await TextCanvasRig.pump(
        tester,
        size: size,
        brightness: brightness,
      );
      final f = r.c.frameOf(r.f.shape)!;

      await r.doubleClick(tester, f.cx, f.cy);
      await tester.typeImeText('!');
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull);
      expect(_layer, findsOneWidget);
      expect(
        find.descendant(of: _layer, matching: find.byType(SuperEditor)),
        findsOneWidget,
      );
      expect(r.textOf(r.f.shape), contains('!'));
      expect(
        find.descendant(
          of: _layer,
          matching: find.byType(SlideTextEditorOverlay),
        ),
        findsOneWidget,
      );
    });
  }
}
