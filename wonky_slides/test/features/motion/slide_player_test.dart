import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/motion/player/slide_player.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';

import 'motion_fixture.dart';

/// A player over [m] with compiled timelines and plans (counted).
(SlidePlayer, List<TransitionRequest>) _player(DeckModel m) {
  final timelines = <String, SlideTimeline>{};
  final requests = <TransitionRequest>[];
  final p = SlidePlayer(
    timelineOf: (id) => timelines[id] ??= SlideTimelineCompiler.compile(
      SlideMotionInput.fromDeck(m, id),
    ),
    planOf: (r) {
      requests.add(r);
      return TransitionCompiler.between(
        m,
        fromSlideId: r.fromSlideId,
        toSlideId: r.toSlideId,
        fromFrame: r.fromFrame,
        toFrame: r.toFrame,
        options: TransitionOptions(reverse: r.reverse),
      );
    },
  );
  return (p, requests);
}

String _json(SlideFrame f) => f.toJson().toString();

void main() {
  late MotionDeck d;
  late DeckModel m;
  setUp(() {
    d = MotionDeck();
    m = d.model();
  });

  group('Given a slide with a click build', () {
    test('when step 1 plays then frames follow the timeline exactly and '
        'settle at its end', () {
      final (p, _) = _player(m);
      final t = SlideTimelineCompiler.compile(
        SlideMotionInput.fromDeck(m, d.a),
      );
      p.show(d.a, 0, now: 0);

      p.playStep(1, now: 1000);

      final mid = p.viewAt(1250)! as SlidePlayerView;
      expect(
        _json(mid.frame),
        _json(t.frameAt(const TimelinePosition(1, 250))),
      );
      expect(mid.frame.stateOf(d.aShape).opacity, closeTo(0.5, 1e-9));
      expect(p.isRunning(1250), isTrue);
      expect(p.needsTicks(1250), isTrue);
      final end = p.viewAt(1600)! as SlidePlayerView;
      expect(_json(end.frame), _json(t.endOfStep(1)));
      expect(p.isRunning(1600), isFalse);
      expect(p.needsTicks(1600), isFalse);
    });

    test('when it is finished during the build then the end state shows at '
        'once', () {
      final (p, _) = _player(m);
      p.show(d.a, 0, now: 0);
      p.playStep(1, now: 0);

      p.finish();

      final v = p.viewAt(100)! as SlidePlayerView;
      expect(v.frame.stateOf(d.aShape).opacity, 1);
      expect(p.isRunning(100), isFalse);
    });

    test('when showing a step then it is settled without animation', () {
      final (p, _) = _player(m);

      p.show(d.a, 1, now: 0);

      expect(p.isRunning(0), isFalse);
      final v = p.viewAt(0)! as SlidePlayerView;
      expect(v.frame.stateOf(d.aShape).opacity, 1);
      expect(v.frame.stateOf(d.aText).parts, isNotNull);
    });
  });

  group('Given a push transition into a slide with a step-0 build', () {
    test('when entering it then the transition plays, then step 0, then it '
        'settles', () {
      final (p, requests) = _player(m);
      p.show(d.a, 4, now: 0);

      p.enter(d.b, now: 1000, fromSlideId: d.a, fromStep: 4);

      expect(requests.single.toStep, -1);
      final t0 = p.viewAt(1350)! as TransitionPlayerView;
      expect(t0.plan.type, 'push');
      expect(t0.fromSlideId, d.a);
      expect(t0.slideId, d.b);
      expect(
        t0.frame.toJson().toString(),
        t0.plan.frameAt(350).toJson().toString(),
      );
      expect(p.inTransition(1350), isTrue);
      // Step 0 (300 ms fade with the transition's end).
      final s0 = p.viewAt(1700 + 150)! as SlidePlayerView;
      expect(s0.step, 0);
      expect(s0.frame.stateOf(d.moved).opacity, closeTo(0.5, 1e-9));
      final end = p.viewAt(3000)! as SlidePlayerView;
      expect(end.frame.stateOf(d.moved).opacity, 1);
      expect(p.isRunning(3000), isFalse);
    });

    test('when finished during the transition then step 0 is settled', () {
      final (p, _) = _player(m);
      p.show(d.a, 4, now: 0);
      p.enter(d.b, now: 0, fromSlideId: d.a, fromStep: 4);

      p.finish();

      final v = p.viewAt(10)! as SlidePlayerView;
      expect(v.slideId, d.b);
      expect(v.frame.stateOf(d.moved).opacity, 1);
    });

    test('when going back then the transition plays reversed and the '
        'previous slide shows at its final step', () {
      final (p, requests) = _player(m);
      p.show(d.b, 0, now: 0);

      p.enter(
        d.a,
        now: 0,
        fromSlideId: d.b,
        fromStep: 0,
        toStep: 4,
        reverse: true,
        playStep0: false,
      );

      expect(requests.single.reverse, isTrue);
      final t = p.viewAt(100)! as TransitionPlayerView;
      expect(t.plan.reverse, isTrue);
      expect(t.plan.type, 'push');
      final end = p.viewAt(800)! as SlidePlayerView;
      expect((end.slideId, end.step), (d.a, 4));
      expect(p.isRunning(800), isFalse);
    });

    test('when the animation degrades then the rest is a crossfade to the '
        'settled frame', () {
      final (p, _) = _player(m);
      p.show(d.a, 4, now: 0);
      p.enter(d.b, now: 0, fromSlideId: d.a, fromStep: 4);

      p.degrade(200);

      expect(p.degraded, isTrue);
      final x = p.viewAt(300)! as CrossfadePlayerView;
      expect(x.fromSlideId, d.a);
      expect(x.slideId, d.b);
      expect(x.mix, greaterThan(0));
      expect(x.mix, lessThan(1));
      final end = p.viewAt(5000)! as SlidePlayerView;
      expect(end.frame.stateOf(d.moved).opacity, 1);
    });
  });

  group('Given Magic Move and cube transitions', () {
    test('when entering the Magic Move slide then frames carry both scenes '
        'with the matched pair', () {
      final (p, _) = _player(m);
      p.show(d.b, 1, now: 0);

      p.enter(d.c, now: 0, fromSlideId: d.b, fromStep: 1);

      final v = p.viewAt(500)! as TransitionPlayerView;
      final mm = v.frame.magicMove!;
      expect(mm.pairs.keys, contains(d.cMoved));
      expect(mm.layers, isNotEmpty);
    });

    test('when entering the cube slide then its quads are 3D', () {
      final (p, _) = _player(m);
      p.show(d.c, 0, now: 0);

      p.enter(d.d, now: 0, fromSlideId: d.c, fromStep: 0);

      final v = p.viewAt(400)! as TransitionPlayerView;
      expect(v.plan.is3d, isTrue);
      expect(v.frame.quads.where((q) => q.visible), isNotEmpty);
      expect(v.frame.quads.first.transform.entry(3, 2), isNot(0));
    });
  });

  group('Given a looping emphasis', () {
    test('when its step is past its duration then the stage keeps ticking '
        'but the step no longer counts as running', () {
      final b = MotionDeck().builder;
      final s = b.slide(layoutKey: 'blank');
      final e = b.shape(s);
      b.build_(
        s,
        e,
        kind: SlideBuildKind.emphasis,
        effect: 'pulse',
        optionsJson: '{"v":1,"repeat":{"untilNextClick":true}}',
      );
      final model = b.build();
      final (p, _) = _player(model);
      p.show(s, 0, now: 0);

      p.playStep(1, now: 0);

      expect(p.isRunning(5000), isFalse);
      expect(p.needsTicks(5000), isTrue);
    });
  });
}
