import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/motion/motion_stage.dart';
import 'package:wonky_slides/features/motion/player/slide_player.dart';
import 'package:wonky_slides/features/motion/render/motion_masks.dart';
import 'package:wonky_slides/features/motion/render/motion_node_paint.dart';
import 'package:wonky_slides/features/motion/render/text_range_geometry.dart';
import 'package:wonky_slides/features/stage/slide_renderer.dart';
import 'package:wonky_slides/features/stage/slide_stage.dart';
import 'package:wonky_slides/features/transitions/magic_move_code.dart';
import 'package:wonky_slides/features/transitions/transition_painter.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/testing.dart';

import '../stage/stage_fixture.dart';
import 'motion_fixture.dart';

Future<SlideRenderer> _stage(
  WidgetTester tester,
  StageFixture f,
  SlideFrame frame,
) async {
  final r = f.renderer();
  addTearDown(r.dispose);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 640,
          height: 360,
          child: MotionStage(
            view: SlidePlayerView(f.slideId, 0, frame),
            renderer: r,
          ),
        ),
      ),
    ),
  );
  return r;
}

RenderObject _layer(WidgetTester tester, String id) => tester.renderObject(
  find.descendant(
    of: find.byKey(ValueKey(id)),
    matching: find.byType(CustomPaint),
  ),
);

void main() {
  late StageFixture f;
  setUp(() => f = StageFixture());

  group('Given an element in a wipe or iris build', () {
    testWidgets('when the wipe is hard then the element is clipped', (
      tester,
    ) async {
      final id = f.shape();
      await _stage(
        tester,
        f,
        SlideFrame({
          id: ElementVisualState(
            clip: const ClipSpec(kind: 'wipe', progress: 0.5),
          ),
        }),
      );

      expect(_layer(tester, id), paints..clipPath());
    });

    testWidgets('when the wipe is feathered then the layer is masked with '
        'a gradient', (tester) async {
      final id = f.shape();
      await _stage(
        tester,
        f,
        SlideFrame({
          id: ElementVisualState(
            clip: const ClipSpec(kind: 'wipe', progress: 0.5, softness: 0.2),
          ),
        }),
      );

      expect(_layer(tester, id), paints..rect());
    });

    testWidgets('when the clip has not started then nothing is painted', (
      tester,
    ) async {
      final id = f.shape();
      await _stage(
        tester,
        f,
        SlideFrame({
          id: ElementVisualState(
            clip: const ClipSpec(kind: 'iris', progress: 0),
          ),
        }),
      );

      expect(_layer(tester, id), isNot(paints..path()));
    });

    test('when the iris grows then it reaches the farthest corner at 1', () {
      const box = Rect.fromLTWH(0, 0, 200, 100);
      for (final shape in ['circle', 'rect', 'diamond']) {
        final full = MotionMask.irisPath(
          box,
          ClipSpec(kind: 'iris', progress: 1, shape: shape),
        );
        expect(full.contains(const Offset(1, 1)), isTrue, reason: shape);
        expect(full.contains(const Offset(199, 99)), isTrue, reason: shape);
        final half = MotionMask.irisPath(
          box,
          ClipSpec(kind: 'iris', progress: 0.3, shape: shape),
        );
        expect(half.contains(const Offset(1, 1)), isFalse, reason: shape);
        expect(half.contains(const Offset(100, 50)), isTrue, reason: shape);
      }
    });
  });

  group('Given an element dissolving', () {
    testWidgets('when it is half dissolved then the noise mask is drawn', (
      tester,
    ) async {
      final id = f.shape();
      await _stage(
        tester,
        f,
        SlideFrame({
          id: ElementVisualState(dissolve: const DissolveState(0.5, 42, 6)),
        }),
      );

      expect(_layer(tester, id), paints..drawImageRect());
    });
  });

  group('Given a text box built by paragraph', () {
    testWidgets(
      'when one part is hidden and one rises then the static text '
      'is clipped to its glyphs and the moving part draws its own glyph run',
      (tester) async {
        final id = f.text('One\nTwo\nThree');
        await _stage(
          tester,
          f,
          SlideFrame({
            id: ElementVisualState(
              parts: TextPartStates(
                parts: [
                  TextPartState(start: 4, end: 8, opacity: 0.5),
                  TextPartState(start: 8, end: 13, visible: false),
                ],
              ),
            ),
          }),
        );

        // The static text clipped to its glyphs, then the rising part's own
        // glyph run ("Two" and its line break).
        expect(
          _layer(tester, id),
          paints
            ..clipPath()
            ..paragraph()
            ..paragraph(),
        );
      },
    );

    testWidgets('when a typewriter runs then the revealed glyphs and the '
        'caret are drawn', (tester) async {
      final id = f.text('Typewriter');
      await _stage(
        tester,
        f,
        SlideFrame({
          id: ElementVisualState(
            parts: TextPartStates(
              parts: [
                TextPartState(start: 0, end: 10, revealEnd: 4, caret: true),
              ],
            ),
          ),
        }),
      );

      expect(
        _layer(tester, id),
        paints
          ..clipPath()
          ..paragraph()
          ..rect(),
      );
    });

    testWidgets('when a highlight sweeps then a marker is drawn behind the '
        'text', (tester) async {
      final id = f.text('Highlight me');
      await _stage(
        tester,
        f,
        SlideFrame({
          id: ElementVisualState(
            highlights: const [
              TextHighlightState(
                start: 0,
                end: 9,
                color: 0x80ffeb3b,
                style: 'marker',
                progress: 0.5,
              ),
            ],
          ),
        }),
      );

      expect(
        _layer(tester, id),
        paints
          ..rrect(color: const Color(0x80ffeb3b))
          ..paragraph(),
      );
    });

    testWidgets('when the text color changes then the glyphs are tinted', (
      tester,
    ) async {
      final id = f.text('Recolor');
      await _stage(
        tester,
        f,
        SlideFrame({
          id: ElementVisualState(
            colors: const {
              'text': ColorOverride(from: 0xff000000, to: 0xffff0000),
            },
          ),
        }),
      );

      expect(
        _layer(tester, id),
        paints
          ..paragraph()
          ..rect(color: const Color(0xffff0000)),
      );
    });

    testWidgets('when measuring part boxes then each line of a range has a '
        'box', (tester) async {
      final id = f.text('One\nTwo\nThree');
      final r = await _stage(tester, f, SlideFrame.edit);
      final scene = r.scene(f.slideId, purpose: ScenePurpose.present)!;
      final node = scene.nodesOf(id).whereType<TextNode>().first;

      final boxes = TextRangeGeometry.boxes(node.layout, 0, 13);

      expect(boxes, hasLength(3));
      expect(boxes[1].top, greaterThan(boxes[0].top));
    });
  });

  group('Given a shape whose fill changes and outline draws on', () {
    testWidgets('when the fill override is complete then the new color fills '
        'the shape', (tester) async {
      final id = f.shape();
      await _stage(
        tester,
        f,
        SlideFrame({
          id: ElementVisualState(
            colors: const {'fill': ColorOverride(to: 0xff00ff00)},
          ),
        }),
      );

      expect(_layer(tester, id), paints..path(color: const Color(0xff00ff00)));
    });

    test('when drawing a path partially then its length is the fraction', () {
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(100, 0)
        ..lineTo(100, 100);

      final half = MotionNodePaint.partialPath(path, 0.5);
      final back = MotionNodePaint.partialPath(path, 0.25, reverse: true);

      double length(Path p) =>
          p.computeMetrics().fold(0.0, (a, m) => a + m.length);
      expect(length(half), closeTo(100, 1e-6));
      expect(length(back), closeTo(50, 1e-6));
      expect(back.getBounds().top, closeTo(50, 1e-6));
    });
  });

  group('Given transitions between slides of a deck', () {
    late MotionDeck d;
    late DeckModel m;
    late SlidePlayer player;

    setUp(() {
      d = MotionDeck();
      m = d.model();
      final timelines = <String, SlideTimeline>{};
      player = SlidePlayer(
        timelineOf: (id) => timelines[id] ??= SlideTimelineCompiler.compile(
          SlideMotionInput.fromDeck(m, id),
        ),
        planOf: (r) => TransitionCompiler.between(
          m,
          fromSlideId: r.fromSlideId,
          toSlideId: r.toSlideId,
          fromFrame: r.fromFrame,
          toFrame: r.toFrame,
          options: TransitionOptions(reverse: r.reverse),
        ),
      );
    });

    Future<void> pump(WidgetTester tester, PlayerView view) async {
      final r = SlideRenderer(model: m, fonts: RecordingFontRegistry());
      addTearDown(r.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 800,
            height: 450,
            child: MotionStage(
              view: view,
              renderer: r,
              letterbox: const Color(0xff000000),
            ),
          ),
        ),
      );
    }

    for (final (name, from, to) in [('push', 'a', 'b'), ('cube', 'c', 'd')]) {
      testWidgets('when a $name transition is half way then both snapshots '
          'are drawn as quads', (tester) async {
        final ids = {'a': d.a, 'b': d.b, 'c': d.c, 'd': d.d};
        player.show(ids[from]!, 0, now: 0);
        player.enter(ids[to]!, now: 0, fromSlideId: ids[from], fromStep: 0);

        await pump(tester, player.viewAt(500)!);

        final painter =
            tester
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('slides.motion.transition')),
                    )
                    .painter!
                as TransitionPainter;
        expect(painter.outgoing, isA<ui.Image>());
        expect(painter.incoming, isA<ui.Image>());
        expect(
          tester.renderObject(
            find.byKey(const ValueKey('slides.motion.transition')),
          ),
          paints
            ..drawImageRect()
            ..drawImageRect(),
        );
      });
    }

    testWidgets('when Magic Move is half way then both scenes are painted '
        'live', (tester) async {
      player.show(d.b, 1, now: 0);
      player.enter(d.c, now: 0, fromSlideId: d.b, fromStep: 1);

      await pump(tester, player.viewAt(500)!);

      expect(
        find.byKey(const ValueKey('slides.motion.magicMove')),
        findsOneWidget,
      );
      expect(
        tester.renderObject(
          find.byKey(const ValueKey('slides.motion.magicMove')),
        ),
        paints..path(),
      );
    });

    test('when two code elements match across slides then the incoming one '
        'draws the token morph and the outgoing one hides (06 AC 6)', () {
      final b = DeckBuilder();
      final s1 = b.slide(layoutKey: 'blank');
      final s2 = b.slide(layoutKey: 'blank');
      final (c1, _) = b.codeBlock(s1, states: ['int a = 1;\nprint(a);']);
      final (c2, _) = b.codeBlock(
        s2,
        states: ['int a = 1;\nint b = 2;\nprint(a + b);'],
      );
      var rows = b.rows;
      final key = rows.firstWhere((r) => r.$2['id'] == c1).$2['matchKey'];
      rows = [
        for (final r in rows)
          r.$2['id'] == c2
              ? (r.$1, {...r.$2, 'matchKey': key})
              : r.$2['id'] == s2
              ? (
                  r.$1,
                  {
                    ...r.$2,
                    'transitionJson':
                        '{"v":1,"type":"magicMove","durationMs":1000}',
                  },
                )
              : r,
      ];
      final model = DeckModel.fromRows(b.deckId, rows);
      final r = SlideRenderer(model: model, fonts: RecordingFontRegistry());
      addTearDown(r.dispose);
      final from = r.scene(s1, purpose: ScenePurpose.present)!;
      final to = r.scene(s2, purpose: ScenePurpose.present)!;
      final plan = TransitionCompiler.between(
        model,
        fromSlideId: s1,
        toSlideId: s2,
        fromScene: from,
        toScene: to,
      );
      final mm = plan.frameAt(plan.durationMs ~/ 2).magicMove!;

      final (frame, scene) = MagicMoveCodeMorphs.apply(
        plan.magicMove!,
        mm,
        to,
        model,
        r.resolver.resolve(s2),
      );

      expect(frame.outgoing.stateOf(c1).visible, isFalse);
      final node = scene.nodesOf(c2).whereType<CodeNode>().single;
      expect(node.scene.glyphs, isNotEmpty);
      expect(node.scene.lines, isEmpty);
    });

    testWidgets('when degraded then the snapshots crossfade', (tester) async {
      player.show(d.a, 0, now: 0);
      player.enter(d.b, now: 0, fromSlideId: d.a, fromStep: 0);
      player.degrade(100);

      await pump(tester, player.viewAt(300)!);

      expect(
        find.byKey(const ValueKey('slides.motion.crossfade')),
        findsOneWidget,
      );
    });

    testWidgets('when a slide view shows then the stage draws its frame', (
      tester,
    ) async {
      player.show(d.a, 2, now: 0);

      await pump(tester, player.viewAt(0)!);

      expect(find.byType(SlideStage), findsOneWidget);
    });
  });
}
