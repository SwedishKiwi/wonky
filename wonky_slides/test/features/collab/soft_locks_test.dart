import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/collab/collab_canvas_layer.dart';
import 'package:wonky_slides/features/collab/presence_widgets.dart';
import 'package:wonky_slides/features/collab/soft_locks.dart';
import 'package:wonky_slides/features/collab/slides_presence_cursor.dart';
import 'package:wonky_slides/features/text_editing/text_editing_host.dart';

import '../../support/slides_harness.dart';
import 'collab_rig.dart';

const _popover = ValueKey('slides.softLock.popover');
const _yes = ValueKey('slides.softLock.yes');
const _no = ValueKey('slides.softLock.no');

void main() {
  group('Given the claim race rule', () {
    const mine = EditingClaim(kind: 'text', elementId: 'e', since: 2000);

    test('when the other claim is earlier then it wins; later loses', () {
      const earlier = EditingClaim(kind: 'text', elementId: 'e', since: 1000);
      const later = EditingClaim(kind: 'text', elementId: 'e', since: 3000);

      expect(SlidesSoftLocks.beats(earlier, 'zz', mine, 'me'), isTrue);
      expect(SlidesSoftLocks.beats(later, 'aa', mine, 'me'), isFalse);
    });

    test('when both started at once then the smaller session id wins', () {
      const same = EditingClaim(kind: 'text', elementId: 'e', since: 2000);

      expect(SlidesSoftLocks.beats(same, 'alpha', mine, 'me'), isTrue);
      expect(SlidesSoftLocks.beats(same, 'zulu', mine, 'me'), isFalse);
    });

    test('when either claim is forced then nobody loses', () {
      const forced = EditingClaim(
        kind: 'text',
        elementId: 'e',
        since: 1000,
        forced: true,
      );

      expect(SlidesSoftLocks.beats(forced, 'a', mine, 'me'), isFalse);
      expect(
        SlidesSoftLocks.beats(
          const EditingClaim(kind: 'text', elementId: 'e', since: 1),
          'a',
          mine.copyWith(forced: true),
          'me',
        ),
        isFalse,
      );
    });
  });

  group('Given two users on one deck', () {
    testWidgets('when this user edits a text box then the claim is published '
        'and released on exit', (tester) async {
      final r = await CollabRig.pump(tester);

      await r.doubleClick(tester, 400, 740);
      expect(r.text.elementId, r.f.box);
      final claimed = (await r.lastSent(tester)).editing;
      expect(claimed?.kind, 'text');
      expect(claimed?.elementId, r.f.box);
      expect(claimed?.slideId, r.f.slide);
      expect(claimed?.forced, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect((await r.lastSent(tester)).editing, isNull);
      await r.close(tester);
    });

    testWidgets('when Anna edits a text box then it is outlined with "✎ Anna '
        'is editing", formatting it skips it, and double-clicking it asks: '
        'Cancel keeps it, Edit anyway edits with a forced claim', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        final r = await CollabRig.pump(tester, brightness: brightness);
        await r.join(
          tester,
          CollabRig.anna,
          r.cursor(editing: r.claim(r.f.box)),
        );

        // (The mouse of the first pass may still hover the box: the flag
        // then carries the hover text.)
        final flag = tester.widget<CollabFlag>(
          find.descendant(
            of: find.byKey(ValueKey('slides.collab.lockFlag.${r.f.box}')),
            matching: find.byType(CollabFlag),
          ),
        );
        expect(flag.label, contains('Anna is editing'));
        expect(r.collab.locks.heldBy(r.f.box), 'Anna');
        expect(r.collab.locks.heldBy(r.f.shape), isNull);

        // Formatting whole elements skips the claimed body.
        final before = r.model.element(r.f.box)!.text;
        final shapeBefore = r.model.element(r.f.shape)!.text;
        r.d.editor.selectElements([r.f.box, r.f.shape]);
        await r.d.run('slides.format.bold');
        expect(r.model.element(r.f.box)!.text, before);
        expect(r.model.element(r.f.shape)!.text, isNot(shapeBefore));
        r.d.editor.selectElements(const []);
        await tester.pump();

        await r.doubleClick(tester, 400, 740);
        expect(find.byKey(_popover), findsOneWidget);
        expect(find.text('Anna is editing this text.'), findsOneWidget);
        expect(r.text.isEditing, isFalse);

        await tester.tap(find.byKey(_no));
        await tester.pump();
        await tester.pump();
        expect(find.byKey(_popover), findsNothing);
        expect(r.text.isEditing, isFalse);

        await r.doubleClick(tester, 400, 740);
        await tester.tap(find.byKey(_yes));
        await tester.pump();
        await tester.pump();
        expect(r.text.elementId, r.f.box);
        final sent = (await r.lastSent(tester)).editing;
        expect(sent?.elementId, r.f.box);
        expect(sent?.forced, isTrue);
        await r.close(tester);
      }
    });

    testWidgets('when slides.text.editAnyway runs on a claimed box then '
        'editing starts with a forced claim', (tester) async {
      final r = await CollabRig.pump(tester);
      await r.join(tester, CollabRig.anna, r.cursor(editing: r.claim(r.f.box)));
      r.d.editor.selectElements([r.f.box]);

      final res = await r.d.run('slides.text.editAnyway', {
        'elementId': r.f.box,
      });
      await tester.pump();

      expect(res.isOk, isTrue);
      expect(r.text.elementId, r.f.box);
      expect(r.collab.locks.localClaims.single.forced, isTrue);
      await r.close(tester);
    });

    testWidgets('when Anna claimed the same box a moment earlier then this '
        'user is asked; Stop editing ends editing', (tester) async {
      final r = await CollabRig.pump(tester);
      await r.join(tester, CollabRig.anna, r.cursor());
      await r.doubleClick(tester, 400, 740);
      final mine = r.collab.locks.localClaims.single;

      await r.move(
        tester,
        'anna',
        r.cursor(editing: r.claim(r.f.box, since: mine.since - 50)),
      );

      expect(find.byKey(_popover), findsOneWidget);
      expect(
        find.text('Anna started editing this text first.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_no));
      await tester.pump();
      await tester.pump();
      expect(r.text.isEditing, isFalse);
      expect(r.collab.locks.localClaims, isEmpty);
      await r.close(tester);
    });

    testWidgets('when this user lost the race and keeps editing then the '
        'claim turns forced', (tester) async {
      final r = await CollabRig.pump(tester);
      await r.join(tester, CollabRig.anna, r.cursor());
      await r.doubleClick(tester, 400, 740);
      final mine = r.collab.locks.localClaims.single;

      await r.move(
        tester,
        'anna',
        r.cursor(editing: r.claim(r.f.box, since: mine.since - 50)),
      );
      await tester.tap(find.byKey(_yes));
      await tester.pump();

      expect(r.text.elementId, r.f.box);
      expect(r.collab.locks.localClaims.single.forced, isTrue);
      expect((await r.lastSent(tester)).editing?.forced, isTrue);
      await r.close(tester);
    });

    testWidgets('when Anna claimed the box after this user then nobody asks '
        'this user', (tester) async {
      final r = await CollabRig.pump(tester);
      await r.join(tester, CollabRig.anna, r.cursor());
      await r.doubleClick(tester, 400, 740);
      final mine = r.collab.locks.localClaims.single;

      await r.move(
        tester,
        'anna',
        r.cursor(editing: r.claim(r.f.box, since: mine.since + 50)),
      );

      expect(find.byKey(_popover), findsNothing);
      expect(r.text.elementId, r.f.box);
      await r.close(tester);
    });

    testWidgets('when this user stops typing for 60 s then the claim is '
        'dropped, and typing claims again', (tester) async {
      final r = await CollabRig.pump(tester);
      await r.doubleClick(tester, 400, 740);
      expect(r.collab.locks.published, isNotNull);

      await tester.pump(SlidesSoftLocks.idleTimeout);
      await tester.pump();
      expect(r.collab.locks.published, isNull);
      expect((await r.lastSent(tester)).editing, isNull);

      r.text.active!.insertText('!');
      await tester.pump();
      expect(r.collab.locks.published?.elementId, r.f.box);
      await r.close(tester);
    });

    testWidgets('when Anna edits the speaker notes then the notes banner '
        'names her and entering them asks first', (tester) async {
      final r = await CollabRig.pump(tester);
      final target = TextLockTarget.notes(r.f.slide);
      await r.join(
        tester,
        CollabRig.anna,
        r.cursor(
          editing: EditingClaim(kind: 'notes', slideId: r.f.slide, since: 1),
        ),
      );
      expect(r.collab.locks.heldByTarget(target), 'Anna');
      await pumpSlides(tester, r.d.h, NotesLockBanner(editor: r.d.editor));
      expect(find.text('✎ Anna is editing the notes'), findsOneWidget);

      final answer = r.collab.locks.requestTarget(target);
      expect(answer, isA<Future<bool>>());
      await tester.pump();
      expect(find.text('Anna is editing these notes.'), findsOneWidget);
      await tester.tap(find.byKey(_yes));
      expect(await answer, isTrue);

      r.collab.locks.claimTarget(target);
      expect(r.collab.locks.published?.kind, 'notes');
      expect(r.collab.locks.published?.forced, isTrue);
      r.collab.locks.releaseTarget(target);
      expect(r.collab.locks.published, isNull);
      await r.close(tester);
    });

    testWidgets('when a table cell is edited then the claim names the cell '
        'row of the server soft-lock check', (tester) async {
      final r = await CollabRig.pump(tester);
      const target = TextLockTarget.cell('table1', 'row1', 'col1');

      r.collab.locks.claimTarget(target);
      final claim = r.collab.locks.published!;

      expect(claim.kind, 'tableCell');
      expect(claim.elementId, 'table1');
      expect(claim.cellId, isNotNull);
      expect(claim.target, target);
      r.collab.locks.releaseTarget(target);
      await r.close(tester);
    });
  });
}
