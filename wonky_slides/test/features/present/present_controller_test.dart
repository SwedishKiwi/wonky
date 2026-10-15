import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show PresentationState;
import 'package:wonky_slides/features/present/present_controller.dart';
import 'package:wonky_slides/features/present/present_ink.dart';
import 'package:wonky_slides/features/present/present_sequence.dart';
import 'package:wonky_slides/features/present/present_settings.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/testing.dart';

/// Six slides: s0, group "Intro" (s1, s2 skipped), s3, a skipped group
/// "Backup" (s4), s5.
({DeckModel model, List<String> ids}) _deck() {
  final b = DeckBuilder(title: 'Deck');
  final s0 = b.slide(layoutKey: 'title', title: 'Welcome');
  final intro = b.group('Intro', color: 'blue');
  final s1 = b.slide(groupId: intro, title: 'Mission');
  final s2 = b.slide(groupId: intro, title: 'Problem', skipped: true);
  final s3 = b.slide(title: 'Demo');
  final backup = b.group('Backup', skipped: true);
  final s4 = b.slide(groupId: backup, title: 'Appendix');
  final s5 = b.slide(title: 'Thanks');
  return (model: b.build(), ids: [s0, s1, s2, s3, s4, s5]);
}

/// Fake timelines: slide [withSteps] has two clicks of 400 ms each.
SlideTimelineOf _steps(String withSteps) =>
    (id) => id == withSteps
    ? SlideTimeline(
        slideId: id,
        steps: const [
          TimelineStep(index: 0),
          TimelineStep(index: 1, durationMs: 400),
          TimelineStep(index: 2, durationMs: 400),
        ],
      )
    : SlideTimeline(slideId: id);

PresentationState _state({
  required int revision,
  required String slideId,
  String blank = 'none',
}) => PresentationState(
  revision: revision,
  slideId: slideId,
  step: 0,
  stepElapsedMs: 0,
  blank: blank,
  picker: false,
  endScreen: false,
  timerRunning: false,
  timerElapsedMs: 0,
);

void main() {
  group('PresentSequence', () {
    test('Given skipped slides and a skipped group when stepping then they '
        'are left out of next and previous', () {
      final d = _deck();
      final ids = d.ids;
      final seq = PresentSequence(
        d.model.indexes.order,
        timelineOf: (id) => SlideTimeline(slideId: id),
      );

      final order = <String>[];
      PresentPosition? p = seq.first();
      while (p != null) {
        order.add(p.slideId);
        p = seq.next(p);
      }
      expect(order, [ids[0], ids[1], ids[3], ids[5]]);
      expect(seq.previous(PresentPosition(ids[5]))!.slideId, ids[3]);
      expect(seq.last()!.slideId, ids[5]);
    });

    test('Given a skipped slide shown via go-to when Next then the next '
        'presented slide follows', () {
      final d = _deck();
      final seq = PresentSequence(
        d.model.indexes.order,
        timelineOf: (id) => SlideTimeline(slideId: id),
      );

      final shown = seq.goTo(d.ids[2])!;

      expect(shown.slideId, d.ids[2]);
      expect(seq.next(shown)!.slideId, d.ids[3]);
      expect(seq.goToNumber(5)!.slideId, d.ids[4]);
      expect(seq.startAt(d.ids[4])!.slideId, d.ids[5]);
    });

    test('Given Show skipped slides when stepping then skipped slides are '
        'included', () {
      final d = _deck();
      final seq = PresentSequence(
        d.model.indexes.order,
        timelineOf: (id) => SlideTimeline(slideId: id),
        showSkipped: true,
      );

      expect(seq.next(PresentPosition(d.ids[1]))!.slideId, d.ids[2]);
      expect(seq.presented, hasLength(6));
    });

    test('Given a slide with two clicks when stepping then steps come '
        'before the next slide and Previous lands on the final step', () {
      final d = _deck();
      final seq = PresentSequence(
        d.model.indexes.order,
        timelineOf: _steps(d.ids[1]),
      );
      final p = PresentPosition(d.ids[1]);

      expect(seq.next(p), PresentPosition(d.ids[1], 1));
      expect(seq.next(PresentPosition(d.ids[1], 2)), PresentPosition(d.ids[3]));
      expect(
        seq.previous(PresentPosition(d.ids[3])),
        PresentPosition(d.ids[1], 2),
      );
      expect(seq.nextSlide(p), PresentPosition(d.ids[3]));
      expect(
        seq.previousSlide(PresentPosition(d.ids[3])),
        PresentPosition(d.ids[1]),
      );
    });
  });

  group('PresentController', () {
    late int now;
    PresentController controller(
      DeckModel model, {
      String? start,
      SlideTimelineOf? timelines,
      PresentView view = PresentView.present,
    }) => PresentController(
      model: model,
      view: view,
      startSlideId: start,
      timelineOf: timelines,
      nowMs: () => now,
      inkPrefix: 't',
    );

    setUp(() => now = 1000000);

    test('Given present mode when Next is pressed through the deck then the '
        'end screen shows and the next advance ends', () {
      final d = _deck();
      final c = controller(d.model);
      var ended = 0;
      c.onEnd = () => ended++;

      for (var i = 0; i < 3; i++) {
        now += 500;
        expect(c.next(), isTrue);
      }
      expect(c.position!.slideId, d.ids[5]);
      now += 500;
      c.next();
      expect(c.endScreen, isTrue);
      now += 500;
      c.previous();
      expect(c.endScreen, isFalse);
      now += 500;
      c.next();
      now += 500;
      c.next();
      expect(ended, 1);
      expect(c.ended, isTrue);
    });

    test('Given rapid inputs when they come within 120 ms then they are '
        'collapsed into one', () {
      final d = _deck();
      final c = controller(d.model);

      expect(c.next(), isTrue);
      now += 50;
      expect(c.next(), isFalse);
      now += 100;
      expect(c.next(), isTrue);

      expect(c.position!.slideId, d.ids[3]);
    });

    test('Given a running build when Next then it finishes first and the '
        'second Next advances', () {
      final d = _deck();
      final c = controller(
        d.model,
        start: d.ids[1],
        timelines: _steps(d.ids[1]),
      );

      now += 500;
      c.next();
      expect(c.position, PresentPosition(d.ids[1], 1));
      expect(c.stepRunning, isTrue);
      now += 200;
      c.next();
      expect(c.position, PresentPosition(d.ids[1], 1));
      expect(c.stepRunning, isFalse);
      now += 200;
      c.next();
      expect(c.position, PresentPosition(d.ids[1], 2));
    });

    test('Given a black screen when navigating then the slide returns first '
        'without advancing', () {
      final d = _deck();
      final c = controller(d.model);

      c.setBlank(PresentBlank.black);
      expect(c.blank, PresentBlank.black);
      now += 500;
      c.next();
      expect(c.blank, PresentBlank.none);
      expect(c.position!.slideId, d.ids[0]);
      c.setBlank(PresentBlank.white);
      c.setBlank(PresentBlank.white);
      expect(c.blank, PresentBlank.none);
    });

    test('Given typed digits when Enter then that deck position shows, '
        'skipped or not', () {
      final d = _deck();
      final c = controller(d.model);

      c.typeDigit(3);
      expect(c.numberEntry, '3');
      expect(c.commitNumber(), isTrue);

      expect(c.position!.slideId, d.ids[2]);
      expect(c.counter, (3, 6));
      now += 500;
      c.next();
      expect(c.position!.slideId, d.ids[3]);
    });

    test('Given Esc with transient states then they close one by one before '
        'the presentation may end', () {
      final d = _deck();
      final c = controller(d.model);
      c.setTool(PresentTool.pen);
      c.setPicker(true);
      c.typeDigit(2);

      expect(c.escape(), isTrue);
      expect(c.numberEntry, isNull);
      expect(c.escape(), isTrue);
      expect(c.pickerOpen, isFalse);
      expect(c.escape(), isTrue);
      expect(c.tool, PresentTool.arrow);
      expect(c.escape(), isFalse);
    });

    test('Given the pen when drawing on a slide then the stroke survives '
        'navigating away and back, Undo and the eraser remove strokes, and '
        'ending discards the ink', () {
      final d = _deck();
      final c = controller(d.model);
      final slide = d.ids[0];

      c.setTool(PresentTool.pen);
      c.pointerDown(const Offset(100, 100));
      now += 16;
      c.pointerMove(const Offset(200, 100));
      c.pointerUp();
      c.setTool(PresentTool.highlighter);
      c.pointerDown(const Offset(100, 500));
      c.pointerMove(const Offset(300, 500));
      c.pointerUp();
      expect(c.ink.strokesOf(slide), hasLength(2));
      expect(c.ink.strokesOf(slide).last.width, InkColors.highlighterWidth);

      now += 500;
      c.next();
      now += 500;
      c.previous();
      expect(c.ink.strokesOf(slide), hasLength(2));

      expect(c.undoInk(), isTrue);
      expect(c.ink.strokesOf(slide), hasLength(1));
      c.setTool(PresentTool.eraser);
      c.pointerDown(const Offset(150, 100));
      expect(c.ink.strokesOf(slide), isEmpty);

      c.setTool(PresentTool.pen);
      c.pointerDown(const Offset(10, 10));
      c.pointerUp();
      c.end();
      expect(c.ink.strokesOf(slide), isEmpty);
    });

    test('Given the laser when moving then the dot and its 300 ms trail '
        'follow and the arrow hides it', () {
      final d = _deck();
      final c = controller(d.model);

      c.setTool(PresentTool.laser, toggle: true);
      c.pointerMove(const Offset(10, 20));
      now += 100;
      c.pointerMove(const Offset(30, 40));
      expect(c.laser, const Offset(30, 40));
      expect(c.laserTrail, hasLength(2));
      now += 250;
      expect(c.laserTrail, hasLength(1));
      c.setTool(PresentTool.laser, toggle: true);
      expect(c.tool, PresentTool.arrow);
      expect(c.laser, isNull);
    });

    test('Given loop mode when advancing past the end then the first slide '
        'follows', () {
      final b = DeckBuilder(title: 'Loop');
      final a = b.slide(title: 'A');
      b.slide(title: 'B');
      final rows = b.rows;
      rows[0] = (
        rows[0].$1,
        {
          ...rows[0].$2,
          'presentJson': jsonEncode({'v': 1, 'mode': 'loop'}),
        },
      );
      final model = DeckModel.fromRows(b.deckId, rows);
      final c = controller(model);

      now += 500;
      c.next();
      now += 500;
      c.next();

      expect(c.position!.slideId, a);
      expect(c.endScreen, isFalse);
    });

    test('Given an audience controller when the presenter state arrives '
        'then it follows, and its navigation becomes commands', () {
      final d = _deck();
      final c = controller(d.model, view: PresentView.audience);
      expect(c.position, isNull);

      c.applyState(_state(revision: 2, slideId: d.ids[3]));
      expect(c.position!.slideId, d.ids[3]);
      c.applyState(_state(revision: 1, slideId: d.ids[1]));
      expect(c.position!.slideId, d.ids[3]);
      c.applyState(
        _state(revision: 3, slideId: 'not-synced-yet', blank: 'black'),
      );
      expect(c.catchingUp, isTrue);
      expect(c.blank, PresentBlank.black);
    });
  });

  group('PresentController timelines', () {
    test(
      'Given a rise build on a shape when presenting then the timeline '
      'compiles from the deck, and reduced motion replaces it with a fade',
      () {
        final b = DeckBuilder();
        final slide = b.slide(layoutKey: 'blank');
        final shape = b.shape(slide);
        b.build_(slide, shape, effect: 'rise');
        final model = b.build();
        final c = PresentController(
          model: model,
          view: PresentView.present,
          nowMs: () => 0,
          inkPrefix: 't',
        );
        addTearDown(c.dispose);

        final t = c.timelineOf(slide);
        expect(t.stepCount, 1);
        expect(t.warnings, isEmpty);
        final effect = t.steps[1].effects.single;
        expect((effect.elementId, effect.effectId), (shape, 'rise'));

        c.reducedMotion = true;
        final reduced = c.timelineOf(slide).steps[1].effects.single;
        expect(reduced.effectId, isNot('rise'));
        expect(reduced.durationMs, lessThanOrEqualTo(300));
      },
    );
  });

  group('PresentSettings', () {
    test('Given no presentJson then defaults apply, and a patch validates', () {
      final s = PresentSettings.parse(null);
      expect(s.endBehavior, 'endScreen');
      expect(s.letterboxColor, 0xff000000);

      final p = s.patched({'endBehavior': 'loop', 'letterboxColor': '#112233'});
      expect(p.loops, isTrue);
      expect(
        PresentSettings.parse(jsonEncode(p.toJson())).letterboxColor,
        0xff112233,
      );
      expect(() => s.patched({'mode': 'disco'}), throwsFormatException);
      expect(() => s.patched({'nope': 1}), throwsFormatException);
    });
  });

  group('InkStroke', () {
    test('Given a stroke when encoded then points are quantized to 0.5 su '
        'and it parses back', () {
      final s = InkStroke(
        id: 'a',
        tool: PresentTool.pen,
        color: 0xffef4444,
        width: 8,
        points: const [Offset(1.26, 2.74), Offset(10, 10)],
      );
      final back = InkStroke.tryParse(s.encode())!;
      expect(back.points.first, const Offset(1.5, 2.5));
      expect(back.touches(const Offset(5, 6), 1), isTrue);
      expect(back.touches(const Offset(50, 6), 1), isFalse);
    });
  });
}
