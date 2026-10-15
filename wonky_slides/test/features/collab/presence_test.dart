import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart'
    show PresenceFollowerCount, PresenceState;
import 'package:wonky_slides/features/collab/collab_canvas_layer.dart';
import 'package:wonky_slides/features/collab/presence_widgets.dart';
import 'package:wonky_slides/features/collab/slides_presence_cursor.dart';
import 'package:wonky_slides/features/editor_screen/deck_editor_controller.dart';

import '../../support/slides_harness.dart';
import 'collab_rig.dart';

void main() {
  group('Given a Slides presence cursor', () {
    test('when encoded and parsed then it round-trips', () {
      const c = SlidesPresenceCursor(
        viewMode: 'grid',
        slideId: 's1',
        selection: ['e1', 'e2'],
        navSlides: ['s1'],
        navGroups: ['g1'],
        editing: EditingClaim(
          kind: 'tableCell',
          slideId: 's1',
          elementId: 't1',
          cellId: 'c1',
          rowId: 'r1',
          columnId: 'k1',
          since: 1760262734123,
          forced: true,
        ),
        transform: true,
        viewport: DeckViewport(slideId: 's1', zoom: 1.5, cx: 960, cy: 540),
        presenting: PresentingState(presentationId: 'p1', slideId: 's1'),
        following: 'bo',
      );

      final parsed = SlidesPresenceCursor.tryParse(c.encode());

      expect(parsed, c);
      expect(parsed!.editing!.target?.key, 'tableCell:t1|r1|k1');
      expect(parsed.isPresenting, isTrue);
    });

    test('when the JSON is another app\'s cursor or broken then parsing '
        'returns null', () {
      expect(SlidesPresenceCursor.tryParse('{"sheetId":"x"}'), isNull);
      expect(SlidesPresenceCursor.tryParse('not json'), isNull);
      expect(SlidesPresenceCursor.tryParse(null), isNull);
    });

    test('when it carries a claim then the editing JSON has the fields the '
        'server soft-lock check reads (09 §2.1)', () {
      const c = SlidesPresenceCursor(
        slideId: 's1',
        editing: EditingClaim(
          kind: 'text',
          slideId: 's1',
          elementId: 'e1',
          since: 5,
        ),
      );
      final editing = SlidesPresenceCursor.tryParse(c.encode())!.editing!;

      expect(editing.toJson(), {
        'kind': 'text',
        'slideId': 's1',
        'elementId': 'e1',
        'cellId': null,
        'stateId': null,
        'since': 5,
        'forced': false,
      });
    });
  });

  group('Given two users on one deck', () {
    testWidgets('when this user selects an element then the cursor is sent '
        'with the slide and the selection', (tester) async {
      final r = await CollabRig.pump(tester);

      r.d.editor.selectElements([r.f.box]);
      final sent = await r.lastSent(tester);

      expect(sent.slideId, r.f.slide);
      expect(sent.selection, [r.f.box]);
      expect(sent.route, 'editor');
      expect(sent.editing, isNull);
      expect(sent.viewport, isNull);
      await r.close(tester);
    });

    testWidgets('when Anna selects an element then her outline and name flag '
        'show on this slide, the navigator dot and the avatar tooltip name '
        'her slide, in light and dark', (tester) async {
      for (final brightness in Brightness.values) {
        final r = await CollabRig.pump(tester, brightness: brightness);
        await r.join(tester, CollabRig.anna, r.cursor(selection: [r.f.shape]));

        expect(r.collab.presence.cursorsOn(r.f.slide), hasLength(1));
        expect(
          find.byKey(const ValueKey('slides.collab.selectionFlag.anna')),
          findsOneWidget,
        );
        expect(find.text('Anna'), findsOneWidget);
        expect(r.collab.presence.bySlide[r.f.slide], hasLength(1));
        expect(
          r.collab.presence.detailOf('anna'),
          'Editing slide 1 · Untitled slide',
        );
        expect(
          r.session.avatars().firstWhere((a) => a.sessionId == 'anna').detail,
          'Editing slide 1 · Untitled slide',
        );

        // The flag fades after 3 s; the outline stays.
        await tester.pump(const Duration(seconds: 4));
        final flag = tester.widget<AnimatedOpacity>(
          find.descendant(
            of: find.byKey(const ValueKey('slides.collab.selectionFlag.anna')),
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(flag.opacity, 0);
        await r.close(tester);
      }
    });

    testWidgets('when Anna is on another slide then nothing is drawn here and '
        'jumping to her switches to her slide and flashes her selection', (
      tester,
    ) async {
      final r = await CollabRig.pump(tester);
      await r.join(
        tester,
        CollabRig.anna,
        r.cursor(slideId: r.f.placeholders, selection: const []),
      );
      expect(r.collab.presence.cursorsOn(r.f.slide), isEmpty);
      expect(
        find.byKey(const ValueKey('slides.collab.selectionFlag.anna')),
        findsNothing,
      );

      final res = await r.d.run('slides.presence.jumpTo', {
        'sessionId': 'anna',
      });

      expect(res.isOk, isTrue);
      expect(r.d.editor.currentSlideId, r.f.placeholders);
      expect(r.collab.presence.flashSession, 'anna');
      await tester.pump(const Duration(seconds: 2));
      expect(r.collab.presence.flashSession, isNull);
      await r.close(tester);
    });

    testWidgets('when Anna is away then she is not drawn and has no dot', (
      tester,
    ) async {
      final r = await CollabRig.pump(tester);
      await r.join(tester, CollabRig.anna, r.cursor(selection: [r.f.box]));
      await r.move(
        tester,
        'anna',
        r.cursor(selection: [r.f.box]),
        state: PresenceState.away,
      );

      expect(r.collab.presence.cursorsOn(r.f.slide), isEmpty);
      expect(r.collab.presence.bySlide, isEmpty);
      await r.close(tester);
    });

    testWidgets('when this user follows Anna then her slide changes are '
        'tracked with the banner, and a local navigation stops following', (
      tester,
    ) async {
      final r = await CollabRig.pump(tester);
      await r.join(tester, CollabRig.anna, r.cursor());

      await r.d.run('slides.presence.follow', {'sessionId': 'anna'});
      await tester.pump();
      expect(r.collab.presence.following.value, 'anna');
      expect(
        find.byKey(const ValueKey('slides.collab.followBanner')),
        findsOneWidget,
      );
      expect(find.text('Following Anna'), findsOneWidget);
      expect((await r.lastSent(tester)).following, 'anna');

      await r.move(tester, 'anna', r.cursor(slideId: r.f.placeholders));
      expect(r.d.editor.currentSlideId, r.f.placeholders);
      expect(r.collab.presence.following.value, 'anna');

      // Her viewport on the same slide: zoom and center.
      await r.move(
        tester,
        'anna',
        r.cursor(
          slideId: r.f.placeholders,
          viewport: DeckViewport(
            slideId: r.f.placeholders,
            zoom: 1,
            cx: 400,
            cy: 300,
          ),
        ),
      );
      expect(r.d.editor.zoom, 1);
      expect(r.collab.presence.following.value, 'anna');

      r.d.editor.setCurrentSlide(r.f.slide);
      await tester.pump();
      expect(r.collab.presence.following.value, isNull);
      expect(
        find.byKey(const ValueKey('slides.collab.followBanner')),
        findsNothing,
      );
      await r.close(tester);
    });

    testWidgets('when following then Esc, Stop or Anna leaving stop it', (
      tester,
    ) async {
      final r = await CollabRig.pump(tester);
      await r.join(tester, CollabRig.anna, r.cursor());

      await r.d.run('slides.presence.follow', {'sessionId': 'anna'});
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(r.collab.presence.following.value, isNull);

      await r.d.run('slides.presence.follow', {'sessionId': 'anna'});
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('slides.collab.followStop')));
      await tester.pump();
      expect(r.collab.presence.following.value, isNull);

      await r.d.run('slides.presence.follow', {'sessionId': 'anna'});
      await r.leave(tester, 'anna');
      expect(r.collab.presence.following.value, isNull);
      await r.close(tester);
    });

    testWidgets('when this user is followed then the viewport is sent, and '
        'Anna\'s tooltip says she follows', (tester) async {
      final r = await CollabRig.pump(tester);
      await r.join(tester, CollabRig.anna, r.cursor(following: 'me'));
      expect(
        r.collab.presence.detailOf('anna'),
        'Editing slide 1 · Untitled slide · Following you',
      );

      r.repo.emit(PresenceFollowerCount(count: 1));
      await tester.pump();
      final sent = await r.lastSent(tester);

      expect(sent.viewport?.slideId, r.f.slide);
      expect(sent.viewport?.zoom, isNull);
      await r.close(tester);
    });

    testWidgets('when Anna presents without a session then the status pill '
        'offers Follow, which follows her presented slide', (tester) async {
      final r = await CollabRig.pump(tester);
      await r.join(
        tester,
        CollabRig.anna,
        r.cursor(
          presenting: PresentingState(slideId: r.f.placeholders, step: 0),
        ),
      );

      expect(r.collab.presence.presenters, hasLength(1));
      expect(r.collab.presence.detailOf('anna'), 'Presenting');
      expect(r.collab.presence.bySlide[r.f.placeholders], hasLength(1));

      final res = await r.d.run('slides.presence.followPresenter', {
        'sessionId': 'anna',
      });

      expect(res.isOk, isTrue);
      expect(r.collab.presence.following.value, 'anna');
      expect(r.d.editor.currentSlideId, r.f.placeholders);
      await r.close(tester);
    });

    testWidgets('when the presence dots of a slide are tapped then this user '
        'jumps to that participant', (tester) async {
      final r = await CollabRig.pump(tester);
      await r.join(tester, CollabRig.anna, r.cursor(slideId: r.f.placeholders));
      await pumpSlides(
        tester,
        r.d.h,
        Row(
          children: [
            SlidePresenceDots(editor: r.d.editor, slideId: r.f.placeholders),
            PresenterPill(editor: r.d.editor),
          ],
        ),
      );

      final dot = find.byKey(
        ValueKey('slides.presence.dot.${r.f.placeholders}.anna'),
      );
      expect(dot, findsOneWidget);
      await tester.tap(dot);
      await tester.pump();

      expect(r.d.editor.currentSlideId, r.f.placeholders);
      expect(
        find.byKey(const ValueKey('slides.status.presenter')),
        findsNothing,
      );
      await r.close(tester);
    });

    testWidgets('when the editor switches to grid view then the cursor names '
        'the view mode', (tester) async {
      final r = await CollabRig.pump(tester);

      r.d.editor.setMode(DeckViewMode.grid);
      final sent = await r.lastSent(tester);

      expect(sent.viewMode, 'grid');
      // Silence the unused import of the layer in this file.
      expect(CollabCanvasLayer, isNotNull);
      await r.close(tester);
    });
  });
}
