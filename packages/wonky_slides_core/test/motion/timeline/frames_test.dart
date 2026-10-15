import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';

import '../../support/motion_fixture.dart';

const _emphasis = SlideBuildKind.emphasis;
const _motion = SlideBuildKind.motion;
const _out = SlideBuildKind.buildOut;

/// Where the state's transform puts slide point ([x], [y]).
(double, double) _map(ElementVisualState s, double x, double y) {
  final v = s.transform.transform3(Vector3(x, y, 0));
  return (v.x, v.y);
}

Matcher _point(double x, double y) => isA<(double, double)>()
    .having((p) => p.$1, 'x', closeTo(x, 1e-6))
    .having((p) => p.$2, 'y', closeTo(y, 1e-6));

/// One shape (center (300, 200)) with one build; returns the timeline and
/// the element id.
(SlideTimeline, String) _one(
  String effect, {
  SlideBuildKind kind = SlideBuildKind.buildIn,
  Map<String, Object?>? params,
  String easing = 'linear',
  int durationMs = 1000,
  String? text,
}) {
  final f = MotionFixture();
  final el = f.shape(text: text);
  f.build(
    'X',
    el,
    kind: kind,
    effect: effect,
    easing: easing,
    durationMs: durationMs,
    options: params == null ? null : {'params': params},
  );
  return (f.compile(), el);
}

ElementVisualState _at(SlideTimeline t, String el, int ms, [int step = 1]) =>
    t.frameAt(TimelinePosition(step, ms)).stateOf(el);

void main() {
  group('Given build-in effects (06 §3.1)', () {
    test('when a fade build is pending, halfway and done then the element is '
        'hidden, half transparent and in its edit state', () {
      final (t, el) = _one('fade');

      expect(t.initial.stateOf(el).visible, isFalse);
      expect(t.endOfStep(0).stateOf(el).visible, isFalse);
      expect(_at(t, el, 500).opacity, closeTo(0.5, 1e-9));
      expect(t.endOfStep(1).elements, isEmpty);
      expect(t.frameAt(const TimelinePosition(1, 1000)).elements, isEmpty);
    });

    test('when rising halfway then it is 20 su below and half faded', () {
      final (t, el) = _one('rise');
      final s = _at(t, el, 500);

      expect(s.transform.getTranslation().y, closeTo(20, 1e-9));
      expect(s.opacity, closeTo(0.5, 1e-9));
    });

    test('when moving in from the left off the slide then it starts with its '
        'right edge at the slide edge', () {
      final (t, el) = _one('moveIn');

      expect(_map(_at(t, el, 0), 500, 200), _point(0, 200));
      expect(_map(_at(t, el, 500), 500, 200), _point(250, 200));
    });

    test('when scaling from 0.5 about the center then the center stays and '
        'the corners move halfway in', () {
      final (t, el) = _one('scale', params: {'fade': false});
      final s = _at(t, el, 0);

      expect(_map(s, 300, 200), _point(300, 200));
      expect(_map(s, 100, 100), _point(200, 150));
    });

    test('when scaling from the top-left anchor then that corner stays', () {
      final (t, el) = _one('scale', params: {'origin': 'topLeft'});

      expect(_map(_at(t, el, 0), 100, 100), _point(100, 100));
    });

    test('when rotating in by -90° then it starts turned about its center', () {
      final (t, el) = _one('rotate', params: {'fade': false});
      final s = _at(t, el, 0);

      expect(_map(s, 300, 200), _point(300, 200));
      expect(_map(s, 400, 200), _point(300, 100));
    });

    test('when flipping in then the transform has perspective', () {
      final (t, el) = _one('flip');
      final s = _at(t, el, 500);

      expect(s.transform.entry(3, 2), isNot(0));
      expect(s.transform.entry(3, 0), isNot(0));
    });

    test('when zooming and blurring in then scale and blur shrink to the '
        'edit state', () {
      final (zoom, z) = _one('zoom');
      final (blur, b) = _one('blur');

      expect(_map(_at(zoom, z, 0), 400, 200), _point(600, 200));
      expect(_at(blur, b, 500).blurSigma, closeTo(12, 1e-9));
    });

    test('when wiping and irising then the clip follows the progress', () {
      final (wipe, w) = _one('wipe', params: {'direction': 'top'});
      final (iris, i) = _one('iris', params: {'shape': 'diamond'});

      expect(_at(wipe, w, 250).clip!.toJson(), {
        'kind': 'wipe',
        'progress': 0.25,
        'direction': 'top',
        'softness': 0.2,
      });
      expect(_at(iris, i, 750).clip!.shape, 'diamond');
      expect(_at(iris, i, 750).clip!.progress, 0.75);
    });

    test('when dissolving then the noise seed is the build\'s', () {
      final (t, el) = _one('dissolve');
      final d = _at(t, el, 300).dissolve!;

      expect(d.amount, closeTo(0.3, 1e-9));
      expect(d.seed, partSeed(t.steps[1].effects.single.buildId, 0));
      expect(d.cell, 6);
    });

    test('when dropping then it falls from above the slide and bounces back to '
        'rest', () {
      final (t, el) = _one('drop');

      expect(_at(t, el, 0).transform.getTranslation().y, closeTo(-300, 1e-9));
      expect(t.endOfStep(1).elements, isEmpty);
      expect(_at(t, el, 300).transform.getTranslation().y, lessThan(0));
    });

    test('when drawing a line then the stroke draws first and the fill '
        'follows after the fill delay', () {
      final (t, el) = _one('lineDraw');

      expect(_at(t, el, 300).drawProgress, closeTo(0.3, 1e-9));
      expect(_at(t, el, 300).fillOpacity, 0);
      expect(_at(t, el, 800).fillOpacity, closeTo(0.5, 1e-9));
    });

    test('when appearing then it is visible at once', () {
      final (t, el) = _one('appear');

      expect(t.steps[1].durationMs, 0);
      expect(t.endOfStep(0).stateOf(el).visible, isFalse);
      expect(t.endOfStep(1).elements, isEmpty);
    });
  });

  group('Given build-out effects (06 §3.2)', () {
    test('when fading out halfway and done then it is half visible and then '
        'hidden', () {
      final (t, el) = _one('fadeOut', kind: _out);

      expect(t.initial.elements, isEmpty);
      expect(_at(t, el, 500).opacity, closeTo(0.5, 1e-9));
      expect(t.endOfStep(1).stateOf(el).visible, isFalse);
    });

    test('when moving out to the right then it ends off the slide', () {
      final (t, el) = _one(
        'moveOut',
        kind: _out,
        params: {'direction': 'right'},
      );

      expect(_map(_at(t, el, 999), 100, 200).$1, greaterThan(1900));
    });

    test('when popping out then it first grows by the anticipation', () {
      final (t, el) = _one('popOut', kind: _out);

      expect(_map(_at(t, el, 200), 400, 200), _point(408, 200));
    });
  });

  group('Given emphasis and motion (06 §3.3–§3.4)', () {
    test('when pulsing then it grows to 110 % at the middle and returns', () {
      final (t, el) = _one('pulse', kind: _emphasis);

      expect(_map(_at(t, el, 500), 400, 200), _point(410, 200));
      expect(t.endOfStep(1).elements, isEmpty);
    });

    test('when shaking and bouncing then they move and return', () {
      final (shake, s) = _one('shake', kind: _emphasis);
      final (bounce, b) = _one('bounce', kind: _emphasis);

      expect(_at(shake, s, 50).transform.getTranslation().x, isNot(0));
      expect(
        _at(bounce, b, 500).transform.getTranslation().y,
        closeTo(-40, 1e-9),
      );
      expect(bounce.endOfStep(1).elements, isEmpty);
    });

    test('when blinking twice then the element is off, on, off, on', () {
      final (t, el) = _one('blink', kind: _emphasis);

      expect(
        [
          for (final ms in [100, 300, 600, 800]) _at(t, el, ms).opacity,
        ],
        [0.0, 1.0, 0.0, 1.0],
      );
    });

    test('when spinning 90° then the rotation persists after the step', () {
      final (t, el) = _one('spin', kind: _emphasis, params: {'angle': 90});
      final end = t.endOfStep(1).stateOf(el);

      expect(_map(end, 400, 200), _point(300, 300));
      expect(
        _map(_at(t, el, 500), 400, 200),
        _point(
          300 + 100 * math.cos(math.pi / 4),
          200 + 100 * math.sin(math.pi / 4),
        ),
      );
    });

    test('when growing to 120 % then the size persists', () {
      final (t, el) = _one('grow', kind: _emphasis);

      expect(_map(t.endOfStep(1).stateOf(el), 400, 200), _point(420, 200));
    });

    test('when moving to a new frame then position and size interpolate and '
        'persist', () {
      final (t, el) = _one(
        'moveTo',
        kind: _motion,
        params: {
          'to': {'x': 900, 'w': 800},
        },
      );

      expect(_map(t.endOfStep(1).stateOf(el), 100, 100), _point(900, 100));
      expect(_map(_at(t, el, 500), 100, 100), _point(500, 100));
    });

    test('when following a motion path then it ends at the path\'s end', () {
      final (t, el) = _one(
        'path',
        kind: _motion,
        params: {'path': 'M0 0 L100 0 L100 100', 'orientToPath': true},
      );

      expect(_map(t.endOfStep(1).stateOf(el), 300, 200), _point(400, 300));
      expect(_map(_at(t, el, 250), 300, 200), _point(350, 200));
    });

    test('when changing transparency then the opacity persists', () {
      final (t, el) = _one('opacityTo', kind: _emphasis);

      expect(_at(t, el, 500).opacity, closeTo(0.7, 1e-9));
      expect(t.endOfStep(1).stateOf(el).opacity, closeTo(0.4, 1e-9));
    });

    test('when changing the fill color then the override persists', () {
      final (t, el) = _one(
        'colorChange',
        kind: _emphasis,
        params: {'to': '#FF0000'},
      );

      expect(_at(t, el, 500).colors['fill']!.mix, closeTo(0.5, 1e-9));
      expect(t.endOfStep(1).stateOf(el).colors['fill']!.to, 0xFFFF0000);
    });

    test('when highlighting text then the sweep covers the text and stays', () {
      final (t, el) = _one('highlight', kind: _emphasis, text: 'Hello');
      final h = t.endOfStep(1).stateOf(el).highlights.single;

      expect([h.start, h.end, h.style, h.progress], [0, 5, 'marker', 1]);
      expect(_at(t, el, 500).highlights.single.progress, closeTo(0.5, 1e-9));
    });
  });

  group('Given text builds in parts (06 §2.3)', () {
    test('when bullets build by paragraph then unbuilt bullets and the box are '
        'hidden, built ones visible', () {
      final f = MotionFixture();
      final text = f.text('One\nTwo\nThree');
      f.build(
        'T',
        text,
        options: {
          'delivery': {'by': 'paragraph'},
        },
      );
      final t = f.compile();

      final initial = t.initial.stateOf(text).parts!;
      final after1 = t.endOfStep(1).stateOf(text).parts!;

      expect(t.initial.stateOf(text).visible, isTrue);
      expect(initial.backgroundOpacity, 0);
      expect(
        [for (final p in initial.parts) (p.start, p.visible)],
        [(0, false), (4, false), (8, false)],
      );
      expect(after1.backgroundOpacity, 1);
      expect([for (final p in after1.parts) p.start], [4, 8]);
      expect(t.endOfStep(3).elements, isEmpty);
    });

    test('when bullets dim after build then earlier bullets end dimmed to '
        '35 %', () {
      final f = MotionFixture();
      final text = f.text('One\nTwo\nThree');
      f.build(
        'T',
        text,
        options: {
          'delivery': {'by': 'paragraph'},
          'afterBuild': {'mode': 'dim'},
        },
      );
      final t = f.compile();

      final end = t.endOfStep(3).stateOf(text).parts!;
      final mid = t.frameAt(const TimelinePosition(2, 150)).stateOf(text);

      expect(
        [for (final p in end.parts) (p.start, p.dim)],
        [(0, 0.35), (4, 0.35)],
      );
      expect(mid.parts!.partAt(0)!.dim, closeTo(0.675, 1e-9));
    });

    test('when building only from part 2 then part 1 and the box are visible '
        'from the start', () {
      final f = MotionFixture();
      final text = f.text('One\nTwo');
      f.build(
        'T',
        text,
        options: {
          'delivery': {
            'by': 'paragraph',
            'parts': {'from': 2},
          },
        },
      );
      final parts = f.compile().initial.stateOf(text).parts!;

      expect(parts.backgroundOpacity, 1);
      expect([for (final p in parts.parts) (p.start, p.visible)], [(4, false)]);
    });

    test('when a typewriter runs then characters are revealed in order with '
        'a caret', () {
      final f = MotionFixture();
      final text = f.text('abc def');
      f.build('T', text, effect: 'typewriter');
      final t = f.compile();

      final part = t
          .frameAt(const TimelinePosition(1, 140))
          .stateOf(text)
          .parts!
          .parts
          .single;

      expect(part.revealEnd, 5);
      expect(part.caret, isTrue);
      expect(t.endOfStep(1).elements, isEmpty);
    });

    test('when words rise then each word moves on its own', () {
      final f = MotionFixture();
      final text = f.text('One two');
      f.build(
        'W',
        text,
        effect: 'rise',
        options: {
          'delivery': {'by': 'word'},
        },
      );
      final t = f.compile();

      final s = t.frameAt(const TimelinePosition(1, 30)).stateOf(text).parts!;

      expect(s.parts.first.transform.getTranslation().y, greaterThan(0));
      expect(s.parts.last.visible, isFalse);
    });
  });

  group('Given chart and code elements', () {
    MotionElement chart(String id) => MotionElement(
      id: id,
      kind: ElementKind.chart,
      frame: const SuRect(100, 100, 400, 200),
      chart: const ChartShape(seriesKeys: ['a', 'b'], categoryCount: 3),
    );

    MotionElement code(String id) => MotionElement(
      id: id,
      kind: ElementKind.code,
      frame: const SuRect(100, 100, 400, 200),
      codeStates: const [
        MotionCodeState(length: 20, highlightSteps: 2),
        MotionCodeState(length: 40, mode: 'morph'),
      ],
    );

    test('when a chart grows by series then the background comes with series '
        'a and series b waits', () {
      final f = MotionFixture();
      final c = f.special(ElementKind.chart, chart);
      f.build(
        'G',
        c,
        effect: 'chartGrow',
        options: {
          'delivery': {'by': 'series'},
        },
      );
      final t = f.compile();

      final mid = t.frameAt(const TimelinePosition(1, 400)).stateOf(c).chart!;

      expect(t.initial.stateOf(c).chart!.backgroundOpacity, 0);
      expect(mid.toJson(), {
        'parts': [
          {
            'key': {'role': 'series', 'series': 'a'},
            'grow': 0.937718,
          },
          {
            'key': {'role': 'series', 'series': 'b'},
            'grow': 0.0,
            'opacity': 0.0,
          },
        ],
      });
      expect(t.endOfStep(1).elements, isEmpty);
    });

    test('when a chart highlights a series, rotates the camera and orbits '
        'then the states persist or return', () {
      final f = MotionFixture();
      final c = f.special(ElementKind.chart, chart);
      f
        ..build(
          'H',
          c,
          kind: _emphasis,
          effect: 'chartHighlight',
          options: {
            'params': {
              'target': {'series': 'a'},
            },
          },
        )
        ..build(
          'C',
          c,
          kind: _emphasis,
          effect: 'chartCamera',
          options: {
            'params': {'azimuth': 45},
          },
        )
        ..build('O', c, kind: _emphasis, effect: 'chartOrbit');
      final t = f.compile();

      final end = t.endOfStep(3).stateOf(c).chart!;

      expect(end.highlight, {
        'target': {'series': 'a'},
        'dimOthers': 0.3,
      });
      expect(end.camera!['azimuth'], 45);
      expect(end.azimuthDelta, 0);
      expect(
        t
            .frameAt(const TimelinePosition(3, 250))
            .stateOf(c)
            .chart!
            .azimuthDelta,
        greaterThan(0),
      );
    });

    test('when code types in, highlights a step and changes state then the '
        'code view follows', () {
      final f = MotionFixture();
      final c = f.special(ElementKind.code, code);
      f
        ..build('T', c, effect: 'codeType')
        ..build(
          'H',
          c,
          kind: _emphasis,
          effect: 'codeHighlight',
          options: {
            'params': {'step': 2},
          },
        )
        ..build('S', c, kind: _emphasis, effect: 'codeState');
      final t = f.compile();

      expect(t.initial.stateOf(c).code!.typing, 0);
      expect(
        t.frameAt(const TimelinePosition(1, 100)).stateOf(c).code!.typing,
        greaterThan(0),
      );
      expect(t.endOfStep(1).stateOf(c).code!.toJson(), {'state': 0});
      expect(t.endOfStep(2).stateOf(c).code!.highlightStep, 1);
      final morph = t.frameAt(const TimelinePosition(3, 400)).stateOf(c).code!;
      expect(
        [morph.stateIndex, morph.fromStateIndex, morph.mode],
        [1, 0, 'morph'],
      );
      expect(t.endOfStep(3).stateOf(c).code!.toJson(), {'state': 1});
      expect(t.printFrame.stateOf(c).code!.stateIndex, 1);
    });

    test('when a code step doesn\'t exist in the current state then the build '
        'is skipped', () {
      final f = MotionFixture();
      final c = f.special(ElementKind.code, code);
      f.build(
        'H',
        c,
        kind: _emphasis,
        effect: 'codeHighlight',
        options: {
          'params': {'step': 4},
        },
      );
      final t = f.compile();

      expect(t.stepCount, 0);
      expect(t.warnings.single.code, 'codeStepMissing');
    });
  });

  group('Given the print frame (06 §9.6, Q24)', () {
    test('when a slide has in, out and motion builds then printing shows the '
        'authored layout', () {
      final f = MotionFixture();
      final a = f.shape(), b = f.shape();
      f
        ..build('I', a)
        ..build('O', b, kind: _out, effect: 'fadeOut')
        ..build(
          'M',
          a,
          kind: _motion,
          effect: 'path',
          options: {
            'params': {'path': 'M0 0 L100 0'},
          },
        );
      final t = f.compile();

      expect(t.printFrame.elements, isEmpty);
      expect(t.finalFrame.stateOf(b).visible, isFalse);
      expect(t.finalFrame.stateOf(a).transform.getTranslation().x, 100);
    });
  });

  group('Given the same input twice (06 §9.3 determinism)', () {
    test('when compiling and evaluating every 50 ms then the frames are '
        'identical JSON', () {
      MotionFixture fixture() {
        final f = MotionFixture();
        final text = f.text('Alpha beta gamma\nDelta');
        final a = f.shape();
        f
          ..build(
            'W',
            text,
            effect: 'typewriter',
            options: {
              'params': {'jitter': 0.6},
              'delivery': {'by': 'word', 'order': 'random'},
            },
          )
          ..build(
            'D',
            a,
            effect: 'dissolve',
            trigger: SlideBuildTrigger.withPrevious,
          )
          ..build(
            'P',
            a,
            kind: _emphasis,
            effect: 'pulse',
            easing: 'spring(0.5,0.3)',
          );
        return f;
      }

      List<Object?> run() {
        final t = fixture().compile();
        return [
          for (final s in t.steps)
            for (var ms = 0; ms <= s.durationMs + 50; ms += 50)
              t.frameAt(TimelinePosition(s.index, ms)).toJson(),
        ];
      }

      final a = run(), b = run();

      expect(a, b);
      expect(a.length, greaterThan(10));
    });

    test('when evaluating a rise halfway then the frame JSON is the recorded '
        'one', () {
      final (t, el) = _one('rise', easing: 'easeOut', durationMs: 600);

      expect(t.frameAt(const TimelinePosition(1, 300)).toJson(), {
        el: {
          'opacity': 0.684643,
          'transform': [
            1.0, 0.0, 0.0, 0.0, //
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 12.614273, 0.0, 1.0,
          ],
        },
      });
    });
  });
}
