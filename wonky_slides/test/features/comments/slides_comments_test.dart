import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart'
    show CommentAnchorKind, CommentStatus;
import 'package:wonky_core/wonky_core.dart' show CommandResult, Role;
import 'package:wonky_slides/features/clipboard/system_clipboard.dart';
import 'package:wonky_slides/features/comments/comment_anchor_moves.dart';
import 'package:wonky_slides/features/comments/slides_comment_anchor.dart';
import 'package:wonky_slides/features/comments/slides_comments.dart';
import 'package:wonky_slides/features/editor_screen/deck_editor_controller.dart'
    show DeckViewMode;
import 'package:wonky_slides/features/navigator/navigator_clipboard.dart';

import 'comments_rig.dart';

void main() {
  group('Given Slides comment anchors', () {
    test('when slide, element and document anchors are encoded then they '
        'parse back', () {
      const slide = SlidesCommentAnchor.slide('s1', point: Offset(1440, 200));
      const element = SlidesCommentAnchor.element('s1', 'e1');
      final cases = [
        (slide, CommentAnchorKind.slide),
        (element, CommentAnchorKind.element),
        (const SlidesCommentAnchor.document(), CommentAnchorKind.document),
      ];
      for (final (a, kind) in cases) {
        expect(SlidesCommentAnchor.parse(kind, a.encode()), a);
      }
      expect(jsonDecode(slide.encode()), {
        'v': 1,
        'slideId': 's1',
        'point': {'x': 1440.0, 'y': 200.0},
      });
    });

    test('when an anchor of another app or malformed JSON is parsed then it '
        'is null', () {
      expect(
        SlidesCommentAnchor.parse(CommentAnchorKind.cell, '{"v":1}'),
        isNull,
      );
      expect(SlidesCommentAnchor.parse(CommentAnchorKind.slide, '{'), isNull);
      expect(
        SlidesCommentAnchor.parse(CommentAnchorKind.element, '{"slideId":"s"}'),
        isNull,
      );
    });
  });

  group('Given a deck with comments', () {
    late CommentsRig r;
    late MemorySlidesClipboard sys;

    setUp(() async {
      sys = MemorySlidesClipboard();
      SlidesSystemClipboard.instance = sys;
      SlidesSlideClipboard.debugClear();
      r = await CommentsRig.open();
    });
    tearDown(() => r.close());

    test('when commenting on a selected element then the thread anchors to '
        'it with its text quoted, and it is placed on the slide', () async {
      r.d.editor.selectElements([r.f.box]);

      final id = await r.comment('Source?');

      final t = r.thread(id);
      expect(t.anchorKind, CommentAnchorKind.element);
      final a = SlidesCommentAnchor.parse(t.anchorKind, t.anchorJson)!;
      expect((a.slideId, a.elementId), (r.f.s1, r.f.box));
      expect(t.quotedText, 'Revenue grew');
      expect(r.comments.threadsOn(r.f.s1).map((p) => p.uuid), [id]);
      expect(r.comments.labelFor(t), 'Revenue grew');
    });

    test('when commenting with nothing selected then the thread anchors to '
        'the slide, quoting its number and title', () async {
      final id = await r.comment('Nice slide');

      final t = r.thread(id);
      expect(t.anchorKind, CommentAnchorKind.slide);
      expect(t.quotedText, 'Slide 1: Our mission');
      expect(r.comments.groupOf(t), '1 · Our mission');
      expect(r.comments.sectionOf(t), isNull, reason: 'slide 1 is ungrouped');
    });

    test('when Comment on slide is chosen while an object is selected then '
        'the thread anchors to the slide; the object menu anchors to the '
        'object', () async {
      r.d.editor.selectElements([r.f.box]);

      final onSlide = await r.run('shell.comments.create', {
        'anchor': 'slide',
        'body': 'Whole slide',
      });
      final onObject = await r.run('shell.comments.create', {
        'anchor': 'element',
        'body': 'Just this',
      });

      expect(onSlide.isOk, isTrue, reason: onSlide.message);
      expect(onObject.isOk, isTrue, reason: onObject.message);
      String uuid(CommandResult res) =>
          (res.data! as Map)['threadUuid'] as String;
      expect(r.thread(uuid(onSlide)).anchorKind, CommentAnchorKind.slide);
      expect(r.thread(uuid(onObject)).anchorKind, CommentAnchorKind.element);
    });

    test('when a right-click preceded the comment then a slide pin sits at '
        'the click point', () async {
      r.comments.noteContextClick(const Offset(500, 300));

      final id = await r.comment('Here');

      final a = SlidesComments.anchorOf(r.thread(id))!;
      expect(a.point, const Offset(500, 300));
    });

    test('when commenting on a grouped slide then the panel shows the group '
        'as a section above the slide header', () async {
      r.d.editor.setCurrentSlide(r.f.s2);

      final id = await r.comment('Group');

      final section = r.comments.sectionOf(r.thread(id));
      expect(section?.title, 'Intro');
      expect(r.comments.groupOf(r.thread(id)), startsWith('2 · '));
    });

    test('when undoing the creation then the thread is deleted', () async {
      await r.comment('Undo me');

      await r.d.undo();

      expect(r.repo.threads, isEmpty);
    });

    test('when the anchored element is deleted then the thread is no longer '
        'placed and reads as deleted, and undo places it again', () async {
      r.d.editor.selectElements([r.f.box]);
      final id = await r.comment('Gone?');
      r.d.editor.selectElements([r.f.box]);

      await r.run('slides.edit.delete');

      expect(r.comments.threadsOn(r.f.s1), isEmpty);
      expect(r.comments.labelFor(r.thread(id)), contains('was deleted'));
      expect(r.comments.groupOf(r.thread(id)), 'Orphaned');
      await r.d.undo();
      expect(r.comments.threadsOn(r.f.s1).map((p) => p.uuid), [id]);
    });

    test('when the element is cut and pasted then the thread moves to the '
        'pasted element in the paste step, and undo moves it back', () async {
      r.d.editor.selectElements([r.f.box]);
      final id = await r.comment('Follow me');
      r.d.editor.selectElements([r.f.box]);
      await r.run('slides.edit.cut');
      r.d.editor.setCurrentSlide(r.f.s2);

      final p = await r.run('slides.edit.paste');
      await pumpEventQueue();

      final pasted = ((p.data! as Map)['elementIds'] as List).single as String;
      final a = SlidesComments.anchorOf(r.thread(id))!;
      expect((a.slideId, a.elementId), (r.f.s2, pasted));
      expect(r.comments.threadsOn(r.f.s2).map((p) => p.uuid), [id]);
      await r.d.undo();
      await pumpEventQueue();
      expect(SlidesComments.anchorOf(r.thread(id))!.elementId, r.f.box);
      await r.d.undo();
      expect(r.comments.threadsOn(r.f.s1).map((p) => p.uuid), [id]);
    });

    test('when an element is copied and pasted then its comments are not '
        'copied or moved', () async {
      r.d.editor.selectElements([r.f.box]);
      final id = await r.comment('Stay');
      r.d.editor.selectElements([r.f.box]);
      await r.run('slides.edit.copy');

      await r.run('slides.edit.paste');
      await pumpEventQueue();

      expect(r.repo.anchorMoves, isEmpty);
      expect(SlidesComments.anchorOf(r.thread(id))!.elementId, r.f.box);
      expect(r.repo.threads, hasLength(1));
    });

    test('when a slide is cut and pasted in the navigator then its slide and '
        'element threads move with it', () async {
      r.d.editor.setCurrentSlide(r.f.s2);
      final slideThread = await r.comment('On slide 2');
      r.d.editor.selectElements([r.f.note]);
      final elementThread = await r.comment('On the note');

      await r.run('slides.navigator.cut', {
        'slideIds': [r.f.s2],
      });
      final p = await r.run('slides.navigator.paste', {'afterSlideId': r.f.s1});
      await pumpEventQueue();

      expect(p.isOk, isTrue, reason: p.message);
      final newSlide = r.d.editor.order.entries.last.id;
      expect(newSlide, isNot(r.f.s2));
      expect(SlidesComments.anchorOf(r.thread(slideThread))!.slideId, newSlide);
      final ea = SlidesComments.anchorOf(r.thread(elementThread))!;
      expect(ea.slideId, newSlide);
      expect(r.model.element(ea.elementId!)?.slideId, newSlide);
    });

    test('when a stored slide hint is stale (the element moved) then the '
        'placement follows the element and the hint is fixed once', () async {
      final t = r.repo.seed(
        kind: CommentAnchorKind.element,
        anchorJson: SlidesCommentAnchor.element(r.f.s2, r.f.box).encode(),
      );
      await r.controller.reload();

      expect(r.comments.threadsOn(r.f.s1).map((p) => p.uuid), [t.uuid.uuid]);
      await pumpEventQueue();
      expect(r.repo.anchorMoves.single.$2, contains(r.f.s1));
    });

    test('when navigating to the next comment then it wraps in presentation '
        'order and selects the anchored element', () async {
      r.d.editor.selectElements([r.f.shape]);
      final a = await r.comment('Shape');
      r.d.editor.selectElements([r.f.box]);
      final b = await r.comment('Box');
      r.d.editor.setCurrentSlide(r.f.s2);
      final c = await r.comment('Slide 2');
      r.controller.activate(null);
      r.d.editor.setCurrentSlide(r.f.s1);

      final order = <String>[];
      for (var i = 0; i < 4; i++) {
        final res = await r.run('slides.comments.next');
        order.add((res.data! as Map)['threadUuid'] as String);
      }
      final back = await r.run('slides.comments.previous');

      // Shape (y 100) before the box (y 600), then slide 2, wrapping.
      expect(order, [a, b, c, a]);
      expect((back.data! as Map)['threadUuid'], c);
      expect(r.d.editor.currentSlideId, r.f.s2);
    });

    test('when resolved then the thread is no longer placed; the pins '
        'toggle is a view setting', () async {
      final id = await r.comment('Done');

      await r.run('shell.comments.resolve', {'threadUuid': id});
      await r.run('slides.view.toggleCommentPins');

      expect(r.thread(id).status, CommentStatus.resolved);
      expect(r.comments.threadsOn(r.f.s1), isEmpty);
      expect(r.comments.pinsOn, isFalse);
      expect(r.d.undoLabels.first, isNot('slides.view.toggleCommentPins'));
    });

    test('when the panel is opened for this slide then the scope filters to '
        'the current slide', () async {
      final here = await r.comment('Here');
      r.d.editor.setCurrentSlide(r.f.s2);
      final there = await r.comment('There');

      await r.run('slides.comments.openPanel', {'scope': 'slide'});

      expect(r.services.panels.isOpen(ShellPanels.comments), isTrue);
      expect(r.controller.scope, SlidesComments.scopeSlide);
      expect(r.controller.visible.map((t) => t.uuid.uuid), [there]);
      r.d.editor.setCurrentSlide(r.f.s1);
      expect(r.controller.visible.map((t) => t.uuid.uuid), [here]);
    });

    test('when a deep link names a thread then its slide opens with the '
        'element selected and the thread active', () async {
      r.d.editor.selectElements([r.f.note]);
      // Created on slide 1's selection is impossible: select on slide 2.
      r.d.editor.setCurrentSlide(r.f.s2);
      r.d.editor.selectElements([r.f.note]);
      final id = await r.comment('Deep');
      r.d.editor.setCurrentSlide(r.f.s1);
      r.controller.activate(null);

      r.comments.openDeepLink(id);

      expect(r.d.editor.currentSlideId, r.f.s2);
      expect(r.d.editor.selectedElementIds, [r.f.note]);
      expect(r.controller.activeThreadUuid, id);
    });

    test('when in masters view then no comment can be created', () async {
      r.d.editor.setMode(DeckViewMode.masters);

      expect(r.comments.anchorForSelection(), isNull);
    });

    test('when describing the state for MCP then open comments are '
        'counted', () async {
      await r.comment('One');

      expect(r.d.doc.describeState()['openComments'], 1);
    });
  });

  group('Given a deck opened by a commenter', () {
    test('when commenting on an element then it works without edit '
        'access', () async {
      final r = await CommentsRig.open(role: Role.commenter);
      addTearDown(r.close);
      r.d.editor.selectElements([r.f.box]);

      final id = await r.comment('As commenter');

      expect(r.thread(id).anchorKind, CommentAnchorKind.element);
    });
  });

  group('Given a deck opened by a viewer', () {
    test('when the owner hides comments then nothing can be created or '
        'seen', () async {
      final r = await CommentsRig.open(
        role: Role.viewer,
        viewersSeeComments: false,
      );
      addTearDown(r.close);

      expect(r.comments.anchorForSelection(), isNull);
      expect(r.comments.visible, isFalse);
      expect(
        r.services.dispatcher.stateOf('shell.comments.create').enabled,
        isFalse,
      );
    });
  });

  group('Given the moves of a paste', () {
    test(
      'when the originals still exist (a copy) then nothing moves',
      () async {
        final r = await CommentsRig.open();
        addTearDown(r.close);
        r.d.editor.selectElements([r.f.box]);
        await r.comment('x');

        final moves = CommentAnchorMoves.movesFor(
          {
            'elementIdMap': {r.f.box: 'new'},
          },
          model: r.model,
          threads: r.controller.threads,
        );

        expect(moves, isEmpty);
      },
    );
  });
}
