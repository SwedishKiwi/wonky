import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart'
    show PresenceJoined, PresenceRoster;
import 'package:wonky_slides/features/collab/slides_collab.dart';
import 'package:wonky_slides/features/collab/slides_presence_cursor.dart';

import '../../support/deck_screen.dart';
import 'collab_rig.dart';

void main() {
  group('Given the deck editor screen with presence', () {
    testWidgets('when Anna is on slide 2 then the navigator shows her dot, '
        'the document describes her, and avatars name her slide', (
      tester,
    ) async {
      final repo = FakePresenceRepository();
      final rig = await pumpDeckScreen(tester, presence: repo);
      final collab = SlidesCollab.of(rig.editor);
      expect(collab, isNotNull);
      expect(collab!.session, isNotNull);

      final slide2 = rig.editor.order.entries[1].id;
      repo.emit(PresenceRoster(sessionId: 'me', participants: [CollabRig.me]));
      await tester.pump();
      repo.emit(
        PresenceJoined(
          participant: CollabRig.anna.copyWith(
            cursorJson: SlidesPresenceCursor(slideId: slide2).encode(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(ValueKey('slides.presence.dot.$slide2.anna')),
        findsOneWidget,
      );
      final state = rig.doc.describeState();
      expect(
        (state['collaborators']! as List).single,
        containsPair('name', 'Anna'),
      );
      expect(collab.presence.detailOf('anna'), 'Editing slide 2 · Our mission');

      // Clicking her dot jumps to her slide.
      await tester.tap(
        find.byKey(ValueKey('slides.presence.dot.$slide2.anna')),
      );
      await tester.pump();
      expect(rig.editor.currentSlideId, slide2);

      final editor = rig.editor;
      await rig.close(tester);
      expect(SlidesCollab.of(editor), isNull);
    });
  });
}
