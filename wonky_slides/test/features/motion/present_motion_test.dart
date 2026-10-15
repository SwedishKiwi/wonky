import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show PresentationState;
import 'package:wonky_slides/features/motion/player/motion_budget.dart';
import 'package:wonky_slides/features/motion/player/slide_player.dart';
import 'package:wonky_slides/features/present/present_controller.dart';
import 'package:wonky_slides/features/present/present_sequence.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';

import 'motion_fixture.dart';

void main() {
  late int now;
  setUp(() => now = 1000000);

  PresentController controller(
    DeckModel model, {
    PresentView view = PresentView.present,
    bool reducedMotion = false,
    bool kiosk = false,
  }) {
    final c = PresentController(
      model: model,
      view: view,
      nowMs: () => now,
      inkPrefix: 't',
      reducedMotion: reducedMotion,
      kiosk: kiosk,
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Presses Next / Previous after the burst window.
  bool next(PresentController c) {
    now += 200;
    return c.next();
  }

  bool previous(PresentController c) {
    now += 200;
    return c.previous();
  }

  group('Given present mode over a deck with builds and transitions', () {
    test('when Next is pressed then the click build animates and a Next '
        'during it finishes it first (06 AC 4)', () {
      final d = MotionDeck();
      final c = controller(d.model());
      expect(c.position, PresentPosition(d.a));

      next(c);
      now += 100;

      expect(c.stepRunning, isTrue);
      expect(c.animating, isTrue);
      expect(c.frame.stateOf(d.aShape).opacity, closeTo(0.2, 1e-9));
      next(c); // finishes the build
      expect(c.position, PresentPosition(d.a, 1));
      expect(c.stepRunning, isFalse);
      expect(c.frame.stateOf(d.aShape).opacity, 1);
      next(c); // starts the first bullet
      expect(c.position, PresentPosition(d.a, 2));
      expect(c.stepRunning, isTrue);
    });

    test('when crossing to the next slide then its transition plays, then '
        'step 0, and Previous plays it reversed (06 §6)', () {
      final d = MotionDeck();
      final c = controller(d.model());
      c.goTo(d.a, 4);
      now += 5000;

      next(c);

      expect(c.position, PresentPosition(d.b));
      final t = c.playerView! as TransitionPlayerView;
      expect(t.plan.type, 'push');
      expect(t.plan.reverse, isFalse);
      now += 800; // past the 700 ms push, into the 300 ms step 0
      final s0 = c.playerView! as SlidePlayerView;
      expect(s0.slideId, d.b);
      expect(s0.frame.stateOf(d.moved).opacity, lessThan(1));
      now += 5000;

      previous(c);

      expect(c.position, PresentPosition(d.a, 4));
      final back = c.playerView! as TransitionPlayerView;
      expect(back.plan.reverse, isTrue);
      expect(back.fromSlideId, d.b);
    });

    test('when going back within a slide then the previous step shows '
        'without animation (10 AC 3)', () {
      final d = MotionDeck();
      final c = controller(d.model());
      next(c);
      now += 1000;

      previous(c);

      expect(c.position, PresentPosition(d.a));
      expect(c.animating, isFalse);
      expect(c.frame.stateOf(d.aShape).visible, isFalse);
    });

    test('when advanceDuringBuild is skip then Next during a build starts '
        'the next step at once', () {
      final d = MotionDeck(presentJson: {'advanceDuringBuild': 'skip'});
      final c = controller(d.model());
      next(c);
      now += 50;

      next(c);

      expect(c.position, PresentPosition(d.a, 2));
      expect(c.stepRunning, isTrue);
    });

    test('when reverseOnBack is off then going back plays the target\'s '
        'transition forward', () {
      final d = MotionDeck(
        defaults: {
          'transition': {'v': 1, 'type': 'fade', 'durationMs': 400},
        },
      );
      final patched = d.patched(d.b, {
        'transitionJson': jsonEncode({
          'v': 1,
          'type': 'push',
          'durationMs': 700,
          'reverseOnBack': false,
        }),
      });
      final c = controller(patched.model());
      c.goTo(d.b);
      now += 5000;

      previous(c);

      final t = c.playerView! as TransitionPlayerView;
      expect((t.plan.type, t.plan.reverse), ('fade', false));
    });

    test('when entering the Magic Move slide then the plan is cached and '
        'prefetched before the click', () {
      final d = MotionDeck();
      final c = controller(d.model());
      c.goTo(d.b, 1);
      now += 5000;
      final upcoming = c.upcomingTransition!;
      expect(upcoming.toSlideId, d.c);
      final ahead = c.planOf(upcoming);

      next(c);

      final t = c.playerView! as TransitionPlayerView;
      expect(identical(t.plan, ahead), isTrue);
      expect(t.frame.magicMove, isNotNull);
    });
  });

  group('Given reduced motion (06 §13, 06 AC 8)', () {
    test('when crossing slides then every transition is a 300 ms fade and '
        'Magic Move a crossfade', () {
      final d = MotionDeck();
      final c = controller(d.model(), reducedMotion: true);
      c.goTo(d.a, 4);
      now += 5000;

      next(c);
      final push = (c.playerView! as TransitionPlayerView).plan;
      now += 5000;
      next(c); // the typewriter click
      now += 5000;
      next(c);
      final mm = (c.playerView! as TransitionPlayerView).plan;

      expect((push.type, push.durationMs), ('fade', 300));
      expect((mm.type, mm.durationMs), ('fade', 300));
      expect(mm.magicMove, isNull);
    });

    test('when the deck asks for reduced motion while presenting then it '
        'applies too', () {
      final d = MotionDeck(presentJson: {'reduceMotion': true});
      final c = controller(d.model());
      c.goTo(d.a, 4);
      now += 5000;

      next(c);

      expect((c.playerView! as TransitionPlayerView).plan.type, 'fade');
    });
  });

  group('Given kiosk mode (10 §9, 10 AC 8)', () {
    test('when time passes then steps and slides advance on their own and '
        'the deck loops; user navigation is ignored', () {
      final d = MotionDeck(presentJson: {'mode': 'kiosk'});
      final c = controller(d.model());
      expect(c.kiosk, isTrue);

      expect(c.next(), isFalse);
      expect(c.position, PresentPosition(d.a));
      // Step 0 is empty: the first click comes after buildDelayMs (1 s).
      now += 999;
      c.autoTick();
      expect(c.position, PresentPosition(d.a));
      now += 1;
      c.autoTick();
      expect(c.position, PresentPosition(d.a, 1));
      // Clicks 2–4, each 1 s after the previous settles.
      for (var i = 0; i < 3; i++) {
        now += 600 + 1000;
        c.autoTick();
      }
      expect(c.position, PresentPosition(d.a, 4));
      // The last step: the slide stays 5 s after it settles.
      now += 600 + 4999;
      c.autoTick();
      expect(c.position, PresentPosition(d.a, 4));
      now += 1;
      c.autoTick();
      expect(c.position?.slideId, d.b);
      // To the end, then the first slide again.
      for (var i = 0; i < 20 && c.position?.slideId != d.a; i++) {
        now += 10000;
        c.autoTick();
      }
      expect(c.position, PresentPosition(d.a));
      expect(c.endScreen, isFalse);
    });

    test('when started with ?kiosk=1 then the deck runs as a kiosk', () {
      final d = MotionDeck();
      final c = controller(d.model(), kiosk: true);

      expect((c.kiosk, c.loops), (true, true));
      expect(c.autoAdvanceAt, isNotNull);
    });

    test('when a slide has rehearsed timings then they set the pace', () {
      final d = MotionDeck(presentJson: {'mode': 'kiosk'});
      final patched = d.patched(d.a, {
        'timingsJson': jsonEncode({
          'v': 1,
          'stepsMs': [3000, 2000, 2000, 2000, 2000],
        }),
      });
      final c = controller(patched.model());

      expect(c.autoAdvanceAt, 1000000 + 3000);
    });
  });

  group('Given a slide that advances automatically (06 §4.4)', () {
    test('when its last step settles then the next slide follows after '
        'afterMs', () {
      final d = MotionDeck();
      final patched = d.patched(d.d, {
        'transitionJson': jsonEncode({
          'v': 1,
          'type': 'fade',
          'durationMs': 500,
          'advance': {'mode': 'auto', 'afterMs': 2000},
        }),
      });
      final c = controller(patched.model());
      c.goTo(d.d);

      expect(c.autoAdvanceAt, now + 500 + 2000);
      now += 2500;
      c.autoTick();
      expect(c.endScreen, isTrue);
    });
  });

  group('Given an audience view', () {
    test('when the presenter state arrives mid-transition then it plays '
        'from the same point', () {
      final d = MotionDeck();
      final c = controller(d.model(), view: PresentView.audience);
      c.applyState(
        PresentationState(
          revision: 1,
          slideId: d.a,
          step: 4,
          stepElapsedMs: 10000,
          blank: 'none',
          picker: false,
          endScreen: false,
          timerRunning: false,
          timerElapsedMs: 0,
        ),
      );

      c.applyState(
        PresentationState(
          revision: 2,
          slideId: d.b,
          step: 0,
          stepElapsedMs: 350,
          blank: 'none',
          picker: false,
          endScreen: false,
          timerRunning: false,
          timerElapsedMs: 0,
        ),
      );

      final t = c.playerView! as TransitionPlayerView;
      expect(t.ms, 350);
      expect(t.plan.type, 'push');
    });
  });

  group('Given the performance budgets (06 §14)', () {
    test('when more than four elements blur then only four keep their blur '
        'and sigmas are capped', () {
      final frame = SlideFrame({
        for (var i = 0; i < 6; i++)
          'e$i': ElementVisualState(blurSigma: i == 0 ? 80 : 10),
      });

      final limited = MotionBudget.limitBlur(frame);

      final sigmas = [
        for (var i = 0; i < 6; i++) limited.stateOf('e$i').blurSigma,
      ];
      expect(sigmas, [40, 10, 10, 10, 0, 0]);
    });

    test('when ten frames in a row miss the budget during a build then the '
        'rest plays as a crossfade', () {
      final d = MotionDeck();
      final c = controller(d.model());
      c.goTo(d.a, 4);
      now += 5000;
      next(c); // into the push transition

      for (var i = 0; i < 11; i++) {
        now += 40;
        c.animationFrame();
      }

      expect(c.degraded, isTrue);
      expect(c.playerView, isA<CrossfadePlayerView>());
    });

    test('when frames keep the budget then nothing degrades', () {
      final budget = FrameBudget();
      var t = 0;
      var degraded = false;
      for (var i = 0; i < 100; i++) {
        t += 16;
        degraded |= budget.frame(t);
      }
      expect(degraded, isFalse);
    });
  });
}
