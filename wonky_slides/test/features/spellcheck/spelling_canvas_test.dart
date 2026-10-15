import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart' show TextComponent;
import 'package:wonky_slides/features/canvas/canvas_interactions.dart';
import 'package:wonky_slides/features/canvas/canvas_overlay_painter.dart';
import 'package:wonky_slides/features/canvas/canvas_tokens.dart';
import 'package:wonky_slides/features/spellcheck/editor_spelling.dart';
import 'package:wonky_slides/features/spellcheck/slides_spelling.dart';
import 'package:wonky_slides/features/spellcheck/spelling_actions.dart';
import 'package:wonky_slides/features/spellcheck/spelling_canvas.dart';
import 'package:wonky_slides_core/ops.dart' show ElementText, SetText;
import 'package:wonky_slides_core/testing.dart' show deltaOf;
import 'package:wonky_ui/wonky_ui.dart' show WonkyMenuItem;

import '../text_editing/text_canvas_rig.dart';
import 'spelling_fixture.dart';

/// Spelling on the canvas (Slides 03 §14, SL-44): squiggles under the
/// misspelled words of the slide, in the body being edited, the context
/// menu's suggestions, and Insert › Special characters / Emoji typing into
/// the text being edited.
void main() {
  setUp(installFakeSpelling);
  tearDown(resetSpelling);

  Future<TextCanvasRig> rig(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    final r = await TextCanvasRig.pump(tester, brightness: brightness);
    r.d.session.execute(
      SetText(ElementText(r.f.box), deltaOf('Helo wrold here')),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    return r;
  }

  Finder overlay() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is CanvasOverlayPainter,
  );

  for (final brightness in Brightness.values) {
    testWidgets('Given a text box with misspelled words (${brightness.name}) '
        'when the slide shows then each word is underlined below its glyphs, '
        'and nothing with Underline errors off', (tester) async {
      final r = await rig(tester, brightness: brightness);
      final layer = CanvasInteractions.find<SpellingCanvasLayer>(r.c)!;
      final segments = layer.squiggles(r.c.scene!);
      expect(segments, hasLength(2));
      final (a, b) = segments.first;
      final (c, _) = segments.last;
      // Inside the box (200,700 900 wide), on one line, left to right.
      for (final p in [a, b, c]) {
        expect(p.dx, inInclusiveRange(200, 1100));
        expect(p.dy, inInclusiveRange(700, 860));
      }
      expect(b.dx, greaterThan(a.dx));
      expect(c.dx, greaterThan(b.dx));
      expect(a.dy, closeTo(c.dy, 0.01));
      final red = CanvasTokens.forBrightness(brightness).spellingError;
      expect(
        tester.renderObject(overlay()),
        paints
          ..path(color: red)
          ..path(color: red),
      );

      await r.d.run('slides.spelling.toggleUnderline');
      await tester.pump();
      expect(tester.renderObject(overlay()), isNot(paints..path(color: red)));
    });
  }

  testWidgets('Given the box being edited when the caret leaves the words '
      'then the overlay underlines them (not the word being typed) and the '
      'canvas squiggles leave the box to the overlay', (tester) async {
    final r = await rig(tester);
    await r.doubleClick(tester, 400, 740);
    expect(r.text.elementId, r.f.box);
    r.text.active!.selectRange(15);
    await tester.pump();
    await tester.pump();
    final addon = r.text.active!.addons.whereType<EditorSpelling>().single;
    final node = r.text.active!.document.first.id;
    expect([for (final e in addon.errorsOf(node)) e.word], ['Helo', 'wrold']);
    final component = tester.widget<TextComponent>(
      find.byType(TextComponent).first,
    );
    expect(
      component.underlines.expand((u) => u.underlines),
      contains(const TextRange(start: 0, end: 4)),
    );
    final layer = CanvasInteractions.find<SpellingCanvasLayer>(r.c)!;
    expect(layer.squiggles(r.c.scene!, skipElementId: r.f.box), isEmpty);

    // Typing a misspelled word: flagged once the caret leaves it.
    r.text.active!.insertText(' teh');
    await tester.pump();
    await tester.pump();
    expect([for (final e in addon.errorsOf(node)) e.word], ['Helo', 'wrold']);
    r.text.active!.selectRange(0);
    await tester.pump();
    await tester.pump();
    // Moving into a flagged word keeps it flagged (its context menu).
    expect(
      [for (final e in addon.errorsOf(node)) e.word],
      ['Helo', 'wrold', 'teh'],
    );
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('Given the box being edited when a misspelled word is '
      'right-clicked then the caret moves into it and the context menu offers '
      'its suggestions; one replaces the word as one undo step', (
    tester,
  ) async {
    final r = await rig(tester);
    final layer = CanvasInteractions.find<SpellingCanvasLayer>(r.c)!;
    final (from, to) = layer.squiggles(r.c.scene!).first;
    await r.doubleClick(tester, 700, 740);
    r.text.active!.selectRange(15);
    await tester.pump();
    await tester.pump();

    final g = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await g.down(r.at(tester, (from.dx + to.dx) / 2, from.dy - 6));
    await g.up();
    await tester.pump();
    await tester.pump();
    final caret = r.text.active!.selectionRange!;
    expect(caret.$1, inInclusiveRange(0, 4));

    final entries = canvasSpellingMenu(r.d.editor);
    final items = entries.whereType<WonkyMenuItem>().toList();
    expect(
      [for (final i in items) i.label],
      ['hello', 'help', 'hole', 'Ignore', 'Add “Helo” to dictionary'],
    );
    items.first.onSelected!();
    await tester.pump();
    await tester.pump();
    expect(r.textOf(r.f.box).trim(), startsWith('hello wrold'));
    expect(r.text.isEditing, isTrue);
    expect(r.d.undoLabels.first, 'slides.spelling.replace');

    await r.d.undo();
    await tester.pump();
    expect(r.textOf(r.f.box).trim(), startsWith('Helo wrold'));

    // *Ignore* stops flagging the word everywhere in the session.
    r.text.active!.selectRange(1);
    await tester.pump();
    await tester.pump();
    canvasSpellingMenu(r.d.editor)
        .whereType<WonkyMenuItem>()
        .firstWhere((i) => i.label == 'Ignore')
        .onSelected!();
    await tester.pump();
    await tester.pump();
    expect(SlidesSpelling.of(r.d.editor).ignoredWords, {'Helo'});
    expect(canvasSpellingMenu(r.d.editor), isEmpty);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('Given text being edited when a special character or an emoji '
      'is inserted then it is typed at the caret (no new object) and undoes '
      'with the typing', (tester) async {
    final r = await rig(tester);
    await r.doubleClick(tester, 400, 740);
    r.text.active!.selectRange(4);
    final count = r.model.elementsOf(r.f.slide).length;
    expect(
      r.d.services.dispatcher.stateOf('slides.insert.specialCharacter').enabled,
      isTrue,
    );

    await r.d.run('slides.insert.specialCharacter', {'char': '→'});
    await tester.pump();
    expect(r.textOf(r.f.box).trim(), 'Helo→ wrold here');
    await r.d.run('slides.insert.emoji', {'char': '🎉'});
    await tester.pump();
    expect(r.textOf(r.f.box).trim(), 'Helo→🎉 wrold here');
    expect(r.model.elementsOf(r.f.slide).length, count);

    await r.d.undo();
    await tester.pump();
    expect(r.textOf(r.f.box).trim(), 'Helo wrold here');

    await tester.pump(const Duration(milliseconds: 400));
  });
}
