import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';

import '../../support/motion_fixture.dart';

const _with = SlideBuildTrigger.withPrevious;
const _after = SlideBuildTrigger.afterPrevious;
const _click = SlideBuildTrigger.onClick;

void main() {
  group('Given builds with triggers (06 §4.2 step compilation)', () {
    test('when every build is on click then each opens a step and step 0 is '
        'empty', () {
      final f = MotionFixture();
      final a = f.shape(), b = f.shape(), c = f.shape();
      f
        ..build('A', a)
        ..build('B', b)
        ..build('C', c);

      final t = f.compile();

      expect(f.table(t), [
        '0/0:',
        '1/500: A@0+500',
        '2/500: B@0+500',
        '3/500: C@0+500',
      ]);
      expect(t.stepCount, 3);
      expect(t.durationMs, 1500);
    });

    test('when builds come before the first click then they form step 0 and '
        'start with/after the previous with their delays', () {
      final f = MotionFixture();
      final a = f.shape(), b = f.shape(), c = f.shape(), d = f.shape();
      f
        ..build('A', a, trigger: _with)
        ..build('B', b, trigger: _after, delayMs: 200)
        ..build('C', c)
        ..build('D', d, trigger: _with, delayMs: 100);

      expect(f.table(f.compile()), [
        '0/1200: A@0+500 B@700+500',
        '1/600: C@0+500 D@100+500',
      ]);
    });

    test('when the first build is after previous then it starts after its '
        'delay in step 0', () {
      final f = MotionFixture();
      f.build('A', f.shape(), trigger: _after, delayMs: 300);

      expect(f.table(f.compile()), ['0/800: A@300+500']);
    });

    test('when a with-previous build follows an after-previous one then it '
        'starts with it', () {
      final f = MotionFixture();
      final a = f.shape(), b = f.shape(), c = f.shape();
      f
        ..build('A', a)
        ..build('B', b, trigger: _after, durationMs: 300)
        ..build('C', c, trigger: _with, delayMs: 50);

      expect(f.table(f.compile()), [
        '0/0:',
        '1/1050: A@0+500 B@500+300 C@550+500',
      ]);
    });

    test('when a build on a text box is delivered by paragraph then each '
        'paragraph is a click and the next with-previous build joins the last '
        'one', () {
      final f = MotionFixture();
      final text = f.text('One\nTwo\nThree');
      final other = f.shape();
      f
        ..build(
          'T',
          text,
          options: {
            'delivery': {'by': 'paragraph'},
          },
        )
        ..build('X', other, trigger: _with);

      expect(f.table(f.compile()), [
        '0/0:',
        '1/500: T#1@0+500',
        '2/500: T#2@0+500',
        '3/500: T#3@0+500 X@0+500',
      ]);
    });

    test(
      'when words build with the previous then they are staggered 60 ms',
      () {
        final f = MotionFixture();
        f.build(
          'W',
          f.text('One two three'),
          options: {
            'delivery': {'by': 'word'},
          },
        );

        expect(f.table(f.compile()), [
          '0/0:',
          '1/620: W#1@0+500 W#2@60+500 W#3@120+500',
        ]);
      },
    );

    test('when parts build after the previous with a stagger then each waits '
        'for the previous part', () {
      final f = MotionFixture();
      f.build(
        'P',
        f.text('A\nB\nC'),
        options: {
          'delivery': {
            'by': 'paragraph',
            'partTrigger': 'afterPrevious',
            'staggerMs': 100,
          },
        },
      );

      expect(f.table(f.compile()), [
        '0/0:',
        '1/1700: P#1@0+500 P#2@600+500 P#3@1200+500',
      ]);
    });

    test('when earlier bullets dim after the build then the dimming is part '
        'of the next bullet\'s step', () {
      final f = MotionFixture();
      f.build(
        'D',
        f.text('A\nB\nC'),
        options: {
          'delivery': {'by': 'paragraph'},
          'afterBuild': {'mode': 'dim'},
        },
      );

      expect(f.table(f.compile()), [
        '0/0:',
        '1/500: D#1@0+500',
        '2/500: D#2@0+500 D#2~dim@0+300',
        '3/500: D#3@0+500 D#3~dim@0+300',
      ]);
    });

    test('when only parts 2 to 3 build in center order then the others are '
        'not scheduled', () {
      final f = MotionFixture();
      f.build(
        'R',
        f.text('A\nB\nC\nD'),
        options: {
          'delivery': {
            'by': 'paragraph',
            'parts': {'from': 2, 'to': 4},
            'order': 'backward',
            'partTrigger': 'withPrevious',
            'staggerMs': 10,
          },
        },
      );

      expect(f.table(f.compile()), [
        '0/0:',
        '1/520: R#4@0+500 R#3@10+500 R#2@20+500',
      ]);
    });

    test('when an emphasis repeats 3 times then its length is 3 plays; until '
        'the next click it loops', () {
      final f = MotionFixture();
      final a = f.shape(), b = f.shape();
      f
        ..build(
          'P',
          a,
          kind: SlideBuildKind.emphasis,
          effect: 'pulse',
          options: {
            'repeat': {'count': 3},
          },
        )
        ..build(
          'L',
          b,
          kind: SlideBuildKind.emphasis,
          effect: 'pulse',
          trigger: _with,
          options: {
            'repeat': {'untilNextClick': true},
          },
        );

      final t = f.compile();

      expect(f.table(t), ['0/0:', '1/1500: P@0+1500 L@0+500']);
      expect(t.steps[1].hasLoops, isTrue);
    });

    test('when a build eases with a spring then its length is the settle '
        'time', () {
      final f = MotionFixture();
      f.build(
        'S',
        f.shape(),
        effect: 'rise',
        easing: 'spring(0.6,0)',
        durationMs: 600,
      );

      final t = f.compile();
      final settle = (SpringEasing(0.6, 0).settleSeconds * 1000).ceil();

      expect(t.steps[1].durationMs, settle);
      expect(t.steps[1].effects.single.easing!.durationMs, settle);
    });

    test('when a typewriter types 6 characters at 30 cps then it takes 200 ms '
        'and ignores the duration', () {
      final f = MotionFixture();
      f.build('T', f.text('abc def'), effect: 'typewriter', durationMs: 5000);

      expect(f.table(f.compile()), ['0/0:', '1/200: T#1@0+200']);
    });

    test('when the transition advances automatically with auto builds then '
        'clicks become after-previous with the build delay', () {
      final f = MotionFixture();
      final a = f.shape(), b = f.shape();
      f
        ..build('A', a)
        ..build('B', b);

      final t = f.compile(
        transitionJson:
            '{"v":1,"type":"fade","advance":{"mode":"auto","autoBuilds":true,'
            '"buildDelayMs":250}}',
      );

      expect(f.table(t), ['0/1500: A@250+500 B@1000+500']);
    });

    test('when a build is triggered by an element click (reserved) then it is '
        'skipped with a warning', () {
      final f = MotionFixture();
      final a = f.shape();
      f.build('E', a, trigger: SlideBuildTrigger.onElementClick);

      final t = f.compile();

      expect(f.table(t), ['0/0:']);
      expect(t.warnings.single.code, 'unsupportedTrigger');
    });
  });

  group('Given invalid build sequences (06 §2.4)', () {
    test(
      'when an element builds in twice then the second build is skipped',
      () {
        final f = MotionFixture();
        final a = f.shape();
        f
          ..build('A1', a)
          ..build('A2', a);

        final t = f.compile();

        expect(f.table(t), ['0/0:', '1/500: A1@0+500']);
        expect(t.warnings.single.code, 'alreadyVisible');
      },
    );

    test('when an element builds out first and then out again then the second '
        'is skipped, and emphasis on the hidden element too', () {
      final f = MotionFixture();
      final a = f.shape();
      f
        ..build('O1', a, kind: SlideBuildKind.buildOut, effect: 'fadeOut')
        ..build('O2', a, kind: SlideBuildKind.buildOut, effect: 'fadeOut')
        ..build('E', a, kind: SlideBuildKind.emphasis, effect: 'pulse');

      final t = f.compile();

      expect(f.table(t), ['0/0:', '1/500: O1@0+500']);
      expect(t.warnings.map((w) => w.code), ['alreadyHidden', 'hiddenTarget']);
    });

    test('when the animated element no longer exists then the build is '
        'skipped', () {
      final f = MotionFixture();
      f.build('G', '00000000-0000-4000-8000-0000000000aa');

      final t = f.compile();

      expect(t.stepCount, 0);
      expect(t.warnings.single.code, 'elementMissing');
    });

    test('when an effect is unknown then in-builds play as fade and emphasis '
        'is skipped', () {
      final f = MotionFixture();
      final a = f.shape(), b = f.shape();
      f
        ..build('N', a, effect: 'shatter')
        ..build('E', b, kind: SlideBuildKind.emphasis, effect: 'wobble');

      final t = f.compile();

      expect(t.steps[1].effects.single.effectId, 'fade');
      expect(t.stepCount, 1);
      expect(t.warnings.map((w) => w.code), [
        'unsupportedEffect',
        'unsupportedEffect',
      ]);
    });

    test('when a text effect targets an image-like shape without text then it '
        'falls back to fade', () {
      final f = MotionFixture();
      f.build('C', f.shape(), effect: 'chartGrow');

      final t = f.compile();

      expect(t.steps[1].effects.single.effectId, 'fade');
      expect(t.warnings.single.code, 'wrongElementKind');
    });
  });

  group('Given reduced motion (06 §13)', () {
    test('when compiling then moving builds fade within 300 ms, transient '
        'emphasis is skipped and typing appears per paragraph', () {
      final f = MotionFixture();
      final a = f.shape(), b = f.shape(), text = f.text('One\nTwo');
      f
        ..build('R', a, effect: 'rise', durationMs: 600)
        ..build(
          'P',
          b,
          kind: SlideBuildKind.emphasis,
          effect: 'pulse',
          trigger: _with,
        )
        ..build('T', text, effect: 'typewriter', trigger: _click);

      final t = f.compile(options: const CompileOptions(reducedMotion: true));

      expect(f.table(t), [
        '0/0:',
        '1/300: R@0+300',
        '2/400: T#1@0+200 T#2@200+200',
      ]);
      expect(t.steps[1].effects.single.effectId, 'fade');
    });

    test('when a motion path plays reduced then it fades out and in at the end '
        'position', () {
      final f = MotionFixture();
      f.build(
        'M',
        f.shape(),
        kind: SlideBuildKind.motion,
        effect: 'path',
        options: {
          'params': {'path': 'M0 0 L100 0'},
        },
      );

      final t = f.compile(options: const CompileOptions(reducedMotion: true));
      final mid = t
          .frameAt(const TimelinePosition(1, 100))
          .stateOf(t.steps[1].effects.single.elementId);
      final late = t
          .frameAt(const TimelinePosition(1, 300))
          .stateOf(t.steps[1].effects.single.elementId);

      expect(f.table(t), ['0/0:', '1/400: M@0+400']);
      expect(mid.opacity, closeTo(0.5, 1e-9));
      expect(mid.transform.getTranslation().x, 0);
      expect(late.opacity, closeTo(0.5, 1e-9));
      expect(late.transform.getTranslation().x, closeTo(100, 1e-9));
    });
  });

  group('Given hand-made timelines and the transition stub (12 §5.5)', () {
    test('when a fake timeline has steps then its frames are edit frames and '
        'every transition is a cut until SL-25', () {
      const t = SlideTimeline(
        slideId: 's',
        steps: [
          TimelineStep(index: 0),
          TimelineStep(index: 1, durationMs: 400),
        ],
      );

      expect(t.stepCount, 1);
      expect(t.frameAt(const TimelinePosition(1, 100)), same(SlideFrame.edit));
      expect(t.describe(), {'clicks': 1, 'durationMs': 400});
      expect(
        TransitionCompiler.compile(from: t.finalFrame, to: t.initial),
        same(TransitionPlan.cut),
      );
    });

    test('when compiling builds then the build steps and tracks are '
        'reported', () {
      final f = MotionFixture();
      final text = f.text('A\nB');
      final id = f.build(
        'T',
        text,
        options: {
          'delivery': {'by': 'paragraph'},
        },
      );

      final t = f.compile();

      expect(t.stepsOfBuild(id), [1, 2]);
      expect(t.tracks[text]!.length, 2);
      expect(t.describe()['clicks'], 2);
    });
  });
}
