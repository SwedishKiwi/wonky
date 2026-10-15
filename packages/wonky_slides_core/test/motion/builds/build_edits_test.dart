import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_slides_core/maintenance.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/session.dart';

import '../../support/planner_fixture.dart';

/// Build and transition edits (06 §15) on the planner fixture (slide s3:
/// build1 fades the shape in, build2 the caption).
List<(String, SlidesOperation Function(DeckReader))> _cases(
  PlannerFixture f,
) => [
  (
    'add rise builds on two elements',
    (d) => BuildEdits.add(
      d,
      f.s3,
      [f.shape, f.shape2],
      kind: SlideBuildKind.buildIn,
      effect: 'rise',
    ),
  ),
  (
    'deliver a build by paragraph with dimming',
    (d) => BuildEdits.update(
      d,
      [f.build2],
      options: {
        'delivery': {'by': 'paragraph'},
        'afterBuild': {'mode': 'dim'},
      },
    ),
  ),
  ('change the effect', (d) => BuildEdits.update(d, [f.build1], effect: 'pop')),
  (
    'set the trigger and delay of two builds',
    (d) => BuildEdits.update(
      d,
      [f.build1, f.build2],
      trigger: SlideBuildTrigger.withPrevious,
      delayMs: 250,
    ),
  ),
  (
    'move a build to the front as a new click',
    (d) => BuildEdits.move(
      d,
      [f.build2],
      index: 0,
      trigger: SlideBuildTrigger.onClick,
    ),
  ),
  ('remove all animations', (d) => BuildEdits.removeAll(d, [f.s3])),
  (
    'paste the shape\'s animation onto the second shape',
    (d) => BuildEdits.paste(d, BuildEdits.copy(d, f.shape), [f.shape2])!,
  ),
  (
    'set a push transition on two slides',
    (d) => BuildEdits.setTransition(
      d,
      [f.s2, f.s3],
      {
        'type': 'push',
        'params': {'direction': 'up'},
      },
    ),
  ),
  ('remove the transition', (d) => BuildEdits.removeTransition([f.s2])),
  (
    'advance automatically',
    (d) => BuildEdits.setAdvance(d, [f.s3], {'mode': 'auto', 'afterMs': 3000}),
  ),
  (
    'apply a transition to all slides',
    (d) => BuildEdits.applyTransitionToAll(
      d,
      transition: TransitionSpec.of('fade'),
    ),
  ),
];

void main() {
  final f = PlannerFixture();

  group('Given the planner fixture and build edits', () {
    for (final (what, op) in _cases(f)) {
      test('when I $what, undo and redo then the deck returns to the state '
          'before and after', () async {
        final deck = f.session();
        final handler = SlidesRowsUndoHandler(() => deck);
        final before = deck.model.dump();

        final plan = deck.execute(op(deck.model));
        final after = deck.model.dump();
        final undone = await handler.undo(
          SlidesRowsUndoEntry(plan.changes, label: plan.label),
        );
        final afterUndo = deck.model.dump();
        await handler.redo(undone);

        expect(plan.isEmpty, isFalse);
        expect(afterUndo, before);
        expect(deck.model.dump(), after);
        expect(DeckMaintenance.detect(deck.model), isEmpty);
      });
    }

    test('when adding to two elements then the top one comes first on click '
        'and the other with it', () {
      final deck = f.session();
      final plan = deck.execute(
        BuildEdits.add(
          deck.model,
          f.s3,
          [f.shape, f.shape2],
          kind: SlideBuildKind.buildIn,
          effect: 'rise',
        ),
      );
      final ids = (plan.result['buildIds']! as List).cast<String>();
      final builds = [for (final id in ids) deck.model.build(id)!];

      expect([for (final b in builds) b.elementId], [f.shape2, f.shape]);
      expect(
        [for (final b in builds) b.trigger],
        [SlideBuildTrigger.onClick, SlideBuildTrigger.withPrevious],
      );
      expect(builds.first.durationMs, 600);
      expect(builds.first.easing, 'spring(0.6,0)');
      expect(plan.label, 'Add animations');
    });

    test('when changing the effect then duration, easing and params reset to '
        'the new effect\'s defaults', () {
      final deck = f.session();
      deck.execute(
        BuildEdits.update(
          deck.model,
          [f.build1],
          options: {
            'params': {'distance': 10},
            'delivery': {'by': 'word'},
          },
        ),
      );
      deck.execute(BuildEdits.update(deck.model, [f.build1], effect: 'zoom'));
      final b = deck.model.build(f.build1)!;

      expect([b.effect, b.durationMs, b.easing], ['zoom', 600, 'easeOutQuint']);
      expect(jsonDecode(b.optionsJson!), {
        'v': 1,
        'delivery': {'by': 'word'},
      });
    });

    test('when editing the duration of a spring-eased build then the spring '
        'duration follows', () {
      final deck = f.session();
      deck.execute(
        BuildEdits.update(
          deck.model,
          [f.build1],
          effect: 'rise',
          durationMs: 900,
        ),
      );

      expect(deck.model.build(f.build1)!.easing, 'spring(0.9,0)');
    });

    test('when options are out of range then they are clamped with plan '
        'warnings', () {
      final deck = f.session();
      final plan = deck.execute(
        UpdateBuilds({
          f.build1: {'optionsJson': '{"v":1,"repeat":{"count":99}}'},
        }),
      );

      expect(plan.warnings, ['repeat.count: Clamped to 20']);
      expect(jsonDecode(deck.model.build(f.build1)!.optionsJson!)['repeat'], {
        'count': 20,
      });
    });

    test('when applying a transition to all slides then the default holds it '
        'and every slide inherits it', () {
      final deck = f.session();
      deck.execute(
        BuildEdits.setTransition(deck.model, [f.s2], {'type': 'cube'}),
      );
      final plan = deck.execute(
        BuildEdits.applyTransitionToAll(deck.model, fromSlideId: f.s2),
      );
      final model = deck.model;

      expect(plan.label, 'Apply transition to all slides');
      expect(model.slides.every((s) => s.transitionJson == null), isTrue);
      expect(
        TransitionSpec.effective(null, model.deck!.defaultsJson).type,
        'cube',
      );
    });

    test('when adding a slide then it inherits the deck default (null)', () {
      final deck = f.session();
      deck.execute(
        BuildEdits.applyTransitionToAll(
          deck.model,
          transition: TransitionSpec.of('push'),
        ),
      );
      final plan = deck.execute(AddSlides(afterSlideId: f.s2));
      final id = (plan.result['slideIds']! as List).single as String;

      expect(deck.model.slide(id)!.transitionJson, isNull);
    });
  });

  group('Given invalid build and transition edits', () {
    for (final (what, op) in [
      (
        'an unknown effect',
        (PlannerFixture f) => AddBuilds(f.s3, [
          BuildSpec(
            elementId: f.shape,
            kind: SlideBuildKind.emphasis,
            effect: 'fade',
            durationMs: 500,
          ),
        ]),
      ),
      (
        'an unknown easing',
        (PlannerFixture f) => UpdateBuilds({
          f.build1: {BuildCols.easing: 'wobbly'},
        }),
      ),
      (
        'the reserved element-click trigger',
        (PlannerFixture f) => UpdateBuilds({
          f.build1: {BuildCols.trigger: 'onElementClick'},
        }),
      ),
      (
        'a duration over 20 s',
        (PlannerFixture f) => UpdateBuilds({
          f.build1: {BuildCols.durationMs: 25000},
        }),
      ),
      (
        'options of the wrong type',
        (PlannerFixture f) => UpdateBuilds({
          f.build1: {
            BuildCols.optionsJson: '{"v":1,"delivery":{"by":"bullet"}}',
          },
        }),
      ),
      (
        'a transition with a bad easing',
        (PlannerFixture f) => SetSlideProps([
          f.s2,
        ], transitionJson: const Patch('{"v":1,"type":"push","easing":"x"}')),
      ),
      (
        'a deck default transition that is not an object',
        (PlannerFixture f) =>
            const SetDeckProps(defaultsJson: Patch('{"v":1,"transition":3}')),
      ),
    ]) {
      test('when planning $what then it is refused', () {
        final deck = f.session();
        final before = deck.model.dump();

        expect(
          () => deck.execute(op(f)),
          throwsA(
            isA<PlanException>().having(
              (e) => e.code,
              'code',
              PlanException.invalidArgument,
            ),
          ),
        );
        expect(deck.model.dump(), before);
      });
    }

    test('when setting a transition with a bad value then the edit helper '
        'refuses it', () {
      final deck = f.session();

      expect(
        () => BuildEdits.setTransition(deck.model, [f.s2], {'durationMs': 'x'}),
        throwsFormatException,
      );
    });
  });
}
