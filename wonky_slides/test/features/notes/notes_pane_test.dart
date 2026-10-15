import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:wonky_client/wonky_client.dart' show AccessRole;
import 'package:wonky_slides/commands/navigator_commands.dart' show notesZoomOf;
import 'package:wonky_slides/features/notes/notes_edit_controller.dart';
import 'package:wonky_slides/l10n/slides_l10n.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_ui/testing.dart';

import '../../support/deck_screen.dart';

Finder key(String k) => find.byKey(ValueKey<String>(k));

/// The speaker notes pane (Slides 04 §8, SL-16).
void main() {
  final l = slidesL10nEnglish;

  String mission(DeckScreenRig r) => r.editor.order.entries[1].id;

  testWidgets('Given a slide with notes when the pane is clicked then the '
      'notes are edited in place, written after idle typing as one undo step '
      'per burst, and undo patches the editor', (tester) async {
    final r = await pumpDeckScreen(tester);
    final id = mission(r);
    await r.run('slides.nav.goToSlide', {'slideId': id});
    await tester.pump();
    expect(find.text('Say hello first'), findsOneWidget);

    await tester.tap(find.text('Say hello first'));
    await tester.pump();
    await tester.pump();
    expect(key('slides.notes.editor.$id'), findsOneWidget);
    expect(key('slides.notes.toolbar.bold'), findsOneWidget);
    expect(r.editor.notesFocus.hasFocus, isTrue);

    await tester.typeImeText(' and');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.typeImeText(' smile');
    await tester.pump(const Duration(milliseconds: 400));
    String notes() =>
        SlidesText.plainText(r.session.model.slide(id)!.notes).trim();
    expect(notes(), 'Say hello first and smile');
    await tester.typeImeText('!');
    await tester.pump(const Duration(milliseconds: 400));
    expect(notes(), 'Say hello first and smile!');
    // One burst, one step.
    expect(r.h.undoLabels, hasLength(1));

    await r.h.undo();
    await tester.pump();
    expect(notes(), 'Say hello first');
    expect(find.textContaining('smile', findRichText: true), findsNothing);
    await settleTooltips(tester);
    await r.close(tester);
  });

  testWidgets('Given a viewer when the notes are clicked then they stay '
      'read-only', (tester) async {
    final r = await pumpDeckScreen(tester, role: AccessRole.viewer);
    final id = mission(r);
    await r.run('slides.nav.goToSlide', {'slideId': id});
    await tester.pump();
    await tester.tap(find.text('Say hello first'));
    await tester.pump();
    expect(key('slides.notes.editor.$id'), findsNothing);
    await settleTooltips(tester);
    await r.close(tester);
  });

  testWidgets('Given an empty slide when the editor shows then the '
      'placeholder invites notes, and the notes zoom scales the text', (
    tester,
  ) async {
    final r = await pumpDeckScreen(tester);
    expect(find.text(l.notesPlaceholder), findsOneWidget);
    await r.run('slides.notes.zoom', {'percent': 150});
    expect(notesZoomOf(r.editor).value, 150);
    await r.run('slides.nav.goToSlide', {'slideId': mission(r)});
    await tester.pump();
    final text = tester.widget<Text>(find.text('Say hello first'));
    expect(text.textSpan!.style!.fontSize, 21);
    await settleTooltips(tester);
    await r.close(tester);
  });

  testWidgets('Given a notes edit session when lists and bold are applied '
      'then the notes subset is written', (tester) async {
    final r = await pumpDeckScreen(tester);
    final id = mission(r);
    final c = NotesEditController(
      session: r.session,
      slideId: id,
      undo: r.services.undo,
      undoLabel: 'Edit notes',
    );
    addTearDown(c.dispose);
    c.toggleList(ListItemType.unordered);
    final node = c.document.toList().first as TextNode;
    c.editor.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: node.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: node.id,
            nodePosition: const TextNodePosition(offset: 3),
          ),
        ),
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
    ]);
    c.toggleAttribution(boldAttribution);
    expect(c.hasAttribution(boldAttribution), isTrue);
    c.setLink('https://wonky.work');
    c.commit();
    final notes = r.session.model.slide(id)!.notes!;
    expect(notes, contains('"list":"bullet"'));
    expect(notes, contains('"bold":true'));
    expect(notes, contains('https://wonky.work'));
    await r.close(tester);
  });
}
