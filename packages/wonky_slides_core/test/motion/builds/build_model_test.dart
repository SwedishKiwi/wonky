import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';

void main() {
  group('Given the effect catalog (06 §3)', () {
    test('when listing effects then ids are unique per kind and every default '
        'easing parses', () {
      final keys = {for (final e in EffectCatalog.all) (e.kind, e.id)};

      expect(keys.length, EffectCatalog.all.length);
      for (final e in EffectCatalog.all) {
        expect(MotionEasing.tryParse(e.defaultEasing), isNotNull, reason: e.id);
      }
    });

    test(
      'when listing build-out effects then each mirrors a build-in effect',
      () {
        for (final e in EffectCatalog.buildOut) {
          expect(
            EffectCatalog.byId(SlideBuildKind.buildIn, e.mirrorOf!),
            isNotNull,
            reason: e.id,
          );
        }
        expect(EffectCatalog.buildOut.map((e) => e.id), contains('sink'));
      },
    );

    test('when asking for text effects of an image then typewriter is not '
        'offered', () {
      final ids = EffectCatalog.forElement(
        SlideBuildKind.buildIn,
        ElementKind.image,
      ).map((e) => e.id);

      expect(ids, containsAll(['fade', 'rise', 'wipe']));
      expect(ids, isNot(contains('typewriter')));
      expect(ids, isNot(contains('shimmer')));
    });

    test('when validating out-of-range numbers then they are clamped with a '
        'warning and unknown keys are kept', () {
      final v = EffectCatalog.validate(SlideBuildKind.buildIn, 'rise', {
        'distance': -5,
        'future': 1,
      });

      expect(v.isValid, isTrue);
      expect(v.value, {'distance': 0, 'future': 1});
      expect(v.warnings.single.code, 'clamped');
      expect(v.warnings.single.path, 'params.distance');
    });

    for (final (effect, params) in [
      ('rise', {'distance': 'far'}),
      ('moveIn', {'direction': 'north'}),
      ('scale', {'fade': 1}),
    ]) {
      test('when validating $effect with $params then it is an error', () {
        final v = EffectCatalog.validate(
          SlideBuildKind.buildIn,
          effect,
          params,
        );

        expect(v.errors.single.code, 'invalid_type');
      });
    }

    test('when validating an unknown effect then it is an error', () {
      final v = EffectCatalog.validate(SlideBuildKind.emphasis, 'wobble', null);

      expect(v.errors.single.code, 'unknown_effect');
    });

    test(
      'when validating a motion path of 201 segments then it is refused',
      () {
        final path = 'M0 0 ${List.filled(201, 'L1 1').join(' ')}';
        final v = EffectCatalog.validate(SlideBuildKind.motion, 'path', {
          'path': path,
        });

        expect(v.errors.single.code, 'too_long');
      },
    );

    test('when asking for fallbacks then in/out play as fade and emphasis is '
        'skipped', () {
      expect(EffectCatalog.fallback(SlideBuildKind.buildIn)!.id, 'fade');
      expect(EffectCatalog.fallback(SlideBuildKind.buildOut)!.id, 'fadeOut');
      expect(EffectCatalog.fallback(SlideBuildKind.emphasis), isNull);
    });
  });

  group('Given optionsJson (06 §2.2)', () {
    test('when decoding null then every value is a default and encoding gives '
        'null', () {
      final v = BuildOptions.decode(null);

      expect(v.value.delivery.by, DeliveryBy.all);
      expect(v.value.encode(), isNull);
    });

    test('when decoding a full object then it round-trips', () {
      const json =
          '{"v":1,"params":{"distance":60},"delivery":{"by":"paragraph",'
          '"order":"backward","parts":{"from":2,"to":4},"partTrigger":'
          '"withPrevious","staggerMs":120,"includeBackground":false},'
          '"afterBuild":{"mode":"dim","dimOpacity":0.5,"dimColor":"#888888"},'
          '"repeat":{"count":3,"autoReverse":true},"persist":false,"x":1}';
      final v = BuildOptions.decode(json);

      expect(v.isValid, isTrue);
      expect(jsonDecode(v.value.encode()!), jsonDecode(json));
    });

    test('when decoding wrong types then they are errors', () {
      final v = BuildOptions.decode(
        '{"v":1,"delivery":{"by":"bullet","staggerMs":"x"},'
        '"afterBuild":{"mode":"blur"},"repeat":{"untilNextClick":1}}',
      );

      expect(v.errors.map((e) => e.path), [
        'delivery.by',
        'delivery.staggerMs',
        'afterBuild.mode',
        'repeat.untilNextClick',
      ]);
    });

    test('when decoding out-of-range values then they are clamped', () {
      final v = BuildOptions.decode(
        '{"v":1,"repeat":{"count":50},"afterBuild":{"mode":"dim","dimOpacity":2}}',
      );

      expect(v.value.repeat.count, 20);
      expect(v.value.afterBuild.dimOpacity, 1);
      expect(v.warnings.length, 2);
    });

    test('when decoding the reserved element-click part trigger then it is an '
        'error', () {
      final v = BuildOptions.decode(
        '{"v":1,"delivery":{"by":"word","partTrigger":"onElementClick"}}',
      );

      expect(v.errors.single.path, 'delivery.partTrigger');
    });

    for (final (by, kind, trigger, stagger) in [
      (
        DeliveryBy.paragraph,
        SlideBuildKind.buildIn,
        SlideBuildTrigger.onClick,
        75,
      ),
      (
        DeliveryBy.paragraph,
        SlideBuildKind.buildOut,
        SlideBuildTrigger.afterPrevious,
        0,
      ),
      (
        DeliveryBy.word,
        SlideBuildKind.buildIn,
        SlideBuildTrigger.withPrevious,
        60,
      ),
      (
        DeliveryBy.character,
        SlideBuildKind.buildIn,
        SlideBuildTrigger.withPrevious,
        30,
      ),
      (
        DeliveryBy.series,
        SlideBuildKind.buildIn,
        SlideBuildTrigger.afterPrevious,
        150,
      ),
    ]) {
      test('when building ${by.name} parts (${kind.name}, 500 ms) then parts '
          'start ${trigger.name} with a $stagger ms stagger', () {
        final d = BuildDelivery(by: by);

        expect(d.effectivePartTrigger(kind), trigger);
        expect(d.effectiveStaggerMs(kind, 500), stagger);
      });
    }

    test('when merge-patching options then nested keys merge and nulls '
        'remove', () {
      final out = jsonMergePatch(
        {
          'params': {'distance': 40, 'fade': true},
          'delivery': {'by': 'word'},
        },
        {
          'params': {'distance': 80, 'fade': null},
          'repeat': {'count': 2},
        },
      );

      expect(out, {
        'params': {'distance': 80},
        'delivery': {'by': 'word'},
        'repeat': {'count': 2},
      });
    });
  });

  group('Given transitionJson (06 §7.1)', () {
    test(
      'when the slide has none then the deck default applies, else none',
      () {
        final deckDefaults = DeckMotionDefaults.withTransition(
          '{"v":1,"codeFontSize":20}',
          TransitionSpec.of('push'),
        );

        expect(TransitionSpec.effective(null, deckDefaults).type, 'push');
        expect(TransitionSpec.effective(null, null).type, 'none');
        expect(
          TransitionSpec.effective('{"v":1,"type":"none"}', deckDefaults).type,
          'none',
        );
        expect(jsonDecode(deckDefaults)['codeFontSize'], 20);
      },
    );

    test('when decoding a full transition then it round-trips', () {
      const json =
          '{"v":1,"type":"push","durationMs":900,"easing":"spring(0.5,0)",'
          '"params":{"direction":"up"},"reverseOnBack":false,"advance":'
          '{"mode":"auto","afterMs":2000,"autoBuilds":true,"buildDelayMs":500}}';
      final v = TransitionSpec.decode(json);

      expect(v.isValid, isTrue);
      expect(v.value.toJson(), jsonDecode(json));
    });

    test(
      'when decoding Magic Move without options then the defaults are set',
      () {
        final v = TransitionSpec.decode('{"v":1,"type":"magicMove"}');

        expect(v.value.magicMove!.textMatching, 'object');
        expect(v.value.durationMs, 1000);
      },
    );

    test('when decoding an unknown type then it is kept with a warning', () {
      final v = TransitionSpec.decode('{"v":1,"type":"shatter"}');

      expect(v.isValid, isTrue);
      expect(v.value.type, 'shatter');
      expect(v.warnings.single.code, 'unknown_transition');
    });

    test('when decoding bad values then they are errors', () {
      final v = TransitionSpec.decode(
        '{"v":1,"type":"push","easing":"wobbly","params":{"direction":"in"},'
        '"advance":{"mode":"later"}}',
      );

      expect(v.errors.map((e) => e.path), [
        'easing',
        'params.direction',
        'advance.mode',
      ]);
    });

    test('when patching the type then the new type starts from its defaults '
        'and keeps the advance', () {
      final cur = TransitionSpec.decode(
        '{"v":1,"type":"push","durationMs":900,"params":{"direction":"up"},'
        '"advance":{"mode":"auto","afterMs":1000}}',
      ).value;
      final v = TransitionSpec.patch(cur, {'type': 'cube'});

      expect(v.value.type, 'cube');
      expect(v.value.durationMs, 1000);
      expect(v.value.params, {'direction': 'left'});
      expect(v.value.advance.auto, isTrue);
    });
  });

  group('Given text for delivery (06 §2.3)', () {
    const text = 'Intro\n\n  Pricing, plans!\nDone — really.\n';

    test('when splitting by paragraph then blank paragraphs are skipped and '
        'indexes count every paragraph', () {
      expect(TextParts.paragraphs(text), const [
        TextPartRange(0, 5, 0),
        TextPartRange(7, 24, 2),
        TextPartRange(25, 39, 3),
      ]);
    });

    test('when splitting by word then punctuation sticks to the preceding '
        'word', () {
      final words = [
        for (final r in TextParts.words(text)) text.substring(r.start, r.end),
      ];

      expect(words, ['Intro', 'Pricing,', 'plans!', 'Done —', 'really.']);
    });

    test('when splitting by character then grapheme clusters stay whole and '
        'spaces are skipped', () {
      const s = 'é 👍🏽a👨‍👩‍👧';
      final chars = [
        for (final r in TextParts.characters(s)) s.substring(r.start, r.end),
      ];

      expect(chars, ['é', '👍🏽', 'a', '👨‍👩‍👧']);
    });

    test('when grouping paragraphs then nested bullets join their parent', () {
      final t = MotionText.fromDelta(
        jsonEncode([
          {'insert': 'A\nA1'},
          {
            'insert': '\n',
            'attributes': {'indent': 1},
          },
          {'insert': 'B\n'},
        ]),
      );

      expect(t.levels, [0, 1, 0]);
      expect(TextParts.paragraphGroups(t.plain, t.levels), const [
        TextPartRange(0, 4, 0),
        TextPartRange(5, 6, 2),
      ]);
    });

    for (final (order, expected) in [
      (PartOrder.forward, [0, 1, 2, 3, 4]),
      (PartOrder.backward, [4, 3, 2, 1, 0]),
      (PartOrder.center, [2, 1, 3, 0, 4]),
      (PartOrder.edges, [0, 4, 1, 3, 2]),
    ]) {
      test(
        'when ordering 5 parts ${order.name} then the order is $expected',
        () {
          expect(PartOrdering.order(5, order, 1), expected);
        },
      );
    }

    test('when ordering randomly then the order depends only on the seed', () {
      final a = PartOrdering.order(10, PartOrder.random, partSeed('b1', 0));

      expect(PartOrdering.order(10, PartOrder.random, partSeed('b1', 0)), a);
      expect(a.toSet().length, 10);
      expect(
        PartOrdering.order(10, PartOrder.random, partSeed('b2', 0)),
        isNot(a),
      );
    });

    test('when reading a chart snapshot then series and categories are '
        'counted', () {
      final shape = ChartShape.tryParse(
        jsonEncode({
          'v': 1,
          'data': {
            'domain': {
              'values': ['Q1', 'Q2', 'Q3'],
            },
            'series': [
              {
                'key': 's1',
                'values': [1, 2, 3],
              },
              {
                'key': 's2',
                'values': [4, 5, 6],
              },
            ],
          },
        }),
      )!;

      expect(shape.seriesKeys, ['s1', 's2']);
      expect(shape.categoryCount, 3);
      expect(shape.partsOf(DeliveryBy.point)!.length, 6);
      expect(shape.partsOf(DeliveryBy.chartElement)!.last.role, 'labels');
    });
  });
}
