import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';

import '../../support/magic_move_fixture.dart';

Matcher _point(double x, double y) => isA<(double, double)>()
    .having((p) => p.$1, 'x', closeTo(x, 1e-6))
    .having((p) => p.$2, 'y', closeTo(y, 1e-6));

void main() {
  group('Given a duplicated slide whose shape moved, grew and was '
      'recolored (06 §18 AC 5)', () {
    late MagicMoveFixture f;
    late String sa, sb;
    setUp(() {
      f = MagicMoveFixture();
      sa = f.shape(f.a, key: 'k1', fill: '#FF0000');
      sb = f.shape(
        f.bSlide,
        key: 'k1',
        x: 900,
        y: 500,
        w: 800,
        h: 400,
        fill: '#0000FF',
      );
    });

    test('when planning then the shapes pair by key and replace', () {
      final plan = f.plan();

      expect(plan.pairs.single.toJson(), {
        'from': sa,
        'to': sb,
        'pass': 'key',
        'mode': 'replace',
        'index': 0,
        'logSize': true,
      });
      expect(plan.hasMatches, isTrue);
    });

    test('when halfway then only the new shape is drawn, stretched onto the '
        'middle geometry, with its fill blended from red to blue', () {
      final frame = f.plan().frameAt(500);
      final s = frame.incoming.stateOf(sb);

      expect(frame.outgoing.stateOf(sa).visible, isFalse);
      // B's center (1300, 700) goes to the midpoint of both centers.
      expect(mapPoint(s.transform, 1300, 700), _point(800, 450));
      // Size in log space: 400 → 800 is 400·√2 at the middle.
      final g = frame.pairs[sb]!.geometry;
      expect(g.width, closeTo(565.685425, 1e-6));
      expect(s.colors['fill']!.toJson(), {
        'from': 0xFFFF0000,
        'to': 0xFF0000FF,
        'mix': 0.5,
      });
    });

    test('when done then the new shape is in its authored state', () {
      final plan = f.plan();
      final s = plan.frameAt(plan.durationMs).incoming.stateOf(sb);

      expect(mapPoint(s.transform, 1300, 700), _point(1300, 700));
      expect(mapPoint(s.transform, 900, 500), _point(900, 500));
    });

    test('when starting then the new shape covers the old one exactly', () {
      final s = f.plan().frameAt(0).incoming.stateOf(sb);

      expect(mapPoint(s.transform, 900, 500), _point(100, 100));
      expect(mapPoint(s.transform, 1700, 900), _point(500, 300));
    });
  });

  group('Given rotated matched shapes', () {
    test('when rotating from 350° to 10° then the shortest arc passes 0°', () {
      final f = MagicMoveFixture();
      f.shape(f.a, key: 'k', rotation: 350);
      final b = f.shape(f.bSlide, key: 'k', rotation: 10);

      final g = f.plan().frameAt(500).pairs[b]!.geometry;

      expect(g.rotation % 360, closeTo(0, 1e-9));
    });

    test('when rotation is literal then the stored values interpolate '
        '(a 720° spin)', () {
      final f = MagicMoveFixture();
      f.shape(f.a, key: 'k', rotation: 0);
      final b = f.shape(f.bSlide, key: 'k', rotation: 720);
      final plan = f.plan(options: {'rotation': 'literal'});

      expect(plan.pairs.single.rotationDelta, 720);
      expect(plan.frameAt(250).pairs[b]!.geometry.rotation, closeTo(180, 1e-9));
    });
  });

  group('Given a rectangle that became an ellipse', () {
    test('when planning then the outline morphs through resampled '
        'points', () {
      final f = MagicMoveFixture();
      f.shape(f.a, key: 'k');
      final b = f.shape(f.bSlide, key: 'k', geometry: 'ellipse');
      final plan = f.plan();

      expect(plan.pairs.single.mode, MorphMode.path);
      final start = plan.frameAt(0).pairs[b]!.path!;
      final end = plan.frameAt(1000).pairs[b]!.path!;
      expect(start.commands, hasLength(PathMorph.samples + 1));
      // At the start every point lies on the rectangle's border.
      final p0 = plan.pairs.single.path!.pointsAt(0, 400, 200);
      for (var i = 0; i < PathMorph.samples; i++) {
        final x = p0[2 * i], y = p0[2 * i + 1];
        final onBorder =
            (x - 0).abs() < 1e-6 ||
            (x - 400).abs() < 1e-6 ||
            (y - 0).abs() < 1e-6 ||
            (y - 200).abs() < 1e-6;
        expect(onBorder, isTrue, reason: 'point $i ($x, $y)');
      }
      expect(end.commands, hasLength(PathMorph.samples + 1));
    });
  });

  group('Given unmatched elements (06 §8.1)', () {
    late MagicMoveFixture f;
    late String gone, kept, fresh;
    setUp(() {
      f = MagicMoveFixture();
      gone = f.shape(f.a, x: 1200, geometry: 'ellipse');
      kept = f.shape(f.a, key: 'k');
      f.shape(f.bSlide, key: 'k', x: 300);
      fresh = f.shape(f.bSlide, y: 700, geometry: 'triangle');
    });

    test('when halfway then the old one is half faded out and the new one '
        'half faded in', () {
      final frame = f.plan().frameAt(500);

      expect(frame.outgoing.stateOf(gone).opacity, closeTo(0.5, 1e-9));
      expect(frame.incoming.stateOf(fresh).opacity, closeTo(0.5, 1e-9));
      expect(f.plan().outgoingIds, [gone]);
      expect(f.plan().incomingIds, [fresh]);
    });

    test('when unmatched objects fade out first then they are gone at 35 % '
        'and the morph starts there', () {
      final plan = f.plan(options: {'fadeUnmatched': 'before'});
      final at35 = plan.frameAt(350);

      expect(at35.outgoing.stateOf(gone).opacity, closeTo(0, 1e-9));
      expect(at35.pairs.values.single.progress, closeTo(0, 1e-9));
      expect(
        plan.frameAt(675).pairs.values.single.progress,
        closeTo(0.5, 1e-9),
      );
    });

    test('when unmatched objects fade in after then the morph ends at 65 % '
        'and the new one only then appears', () {
      final plan = f.plan(options: {'fadeUnmatched': 'after'});

      expect(plan.frameAt(650).pairs.values.single.progress, closeTo(1, 1e-9));
      expect(plan.frameAt(650).incoming.stateOf(fresh).opacity, 0);
      expect(plan.frameAt(1000).incoming.stateOf(fresh).opacity, 1);
    });

    test('when playing backwards then "before" plays as "after"', () {
      final plan = f.plan(options: {'fadeUnmatched': 'before'}, reverse: true);

      expect(plan.options.fadeUnmatched, 'after');
    });

    test('when the old slide drew it below the kept shape then it is '
        'painted right below the kept shape\'s counterpart', () {
      final layers = f.plan().layers.map((l) => l.toJson()).toList();

      final keptB = f.plan().pairs.single.to.id;
      expect(f.plan().pairs.single.from.id, kept);
      expect(layers, ['to:bg', 'from:$gone', 'to:$keptB', 'to:$fresh']);
    });
  });

  group('Given a stagger (06 §8.6)', () {
    test('when two pairs morph then the lower one starts later and the '
        'transition lasts longer', () {
      final f = MagicMoveFixture();
      f.shape(f.a, key: 'top', y: 0);
      f.shape(f.a, key: 'low', y: 600);
      final top = f.shape(f.bSlide, key: 'top', x: 900, y: 0);
      final low = f.shape(f.bSlide, key: 'low', x: 900, y: 600);
      final plan = f.plan(options: {'stagger': 200});

      expect(plan.durationMs, 1200);
      final frame = plan.frameAt(600);
      expect(frame.pairs[top]!.progress, closeTo(0.6, 1e-9));
      expect(frame.pairs[low]!.progress, closeTo(0.4, 1e-9));
    });
  });

  group('Given text matched by character (06 §8.4)', () {
    late MagicMoveFixture f;
    late String ta, tb;
    late MagicMovePlan plan;
    setUp(() {
      f = MagicMoveFixture();
      ta = f.text(f.a, 'Hello world', key: 't');
      tb = f.text(f.bSlide, 'Hello brave world', key: 't', y: 100);
      plan = f.plan(options: {'textMatching': 'character'});
    });

    test('when planning then the shared characters form glyph runs and the '
        'new word is added', () {
      final tm = plan.pairs.single.text!;

      expect(plan.pairs.single.mode, MorphMode.glyphs);
      expect(
        [for (final r in tm.runs) (r.fromStart, r.fromEnd, r.toStart, r.toEnd)],
        [(0, 5, 0, 5), (6, 11, 12, 17)],
      );
      expect(
        [for (final s in tm.added) s.toJson()],
        [
          [6, 11],
        ],
      );
      expect(tm.removed, isEmpty);
    });

    test('when done then each run of the old text lands on its place in '
        'the new text', () {
      final frame = plan.frameAt(1000);
      final aState = frame.outgoing.stateOf(ta);
      final run = plan.pairs.single.text!.runs[1];
      final part = aState.parts!.parts.firstWhere((p) => p.start == 6);

      // Old-local top-left of the run → slide space at the end.
      final local = part.transform;
      final slide = aState.transform.clone()
        ..multiply(plan.from.elements.single.geometry.local)
        ..multiply(local);
      expect(
        mapPoint(slide, run.fromBox.x, run.fromBox.y),
        _point(100 + run.toBox.x, 100 + run.toBox.y),
      );
      // The new element hides its matched ranges and shows the new word.
      final bState = frame.incoming.stateOf(tb);
      expect(
        [for (final p in bState.parts!.parts) p.toJson()],
        [
          {
            'range': [0, 5],
            'visible': false,
          },
          {
            'range': [6, 11],
          },
          {
            'range': [12, 17],
            'visible': false,
          },
        ],
      );
    });

    test('when a quarter through then added glyphs are still hidden', () {
      final b = plan.frameAt(250).incoming.stateOf(tb);

      expect(b.parts!.parts[1].opacity, 0);
    });
  });

  group('Given text matched by word', () {
    test('when a word is replaced then the other words move and the '
        'replaced ones fade', () {
      final f = MagicMoveFixture();
      f.text(f.a, 'The quick fox', key: 't');
      f.text(f.bSlide, 'The slow fox', key: 't');
      final tm = f.plan(options: {'textMatching': 'word'}).pairs.single.text!;

      expect(tm.level, 'word');
      expect(
        [for (final s in tm.removed) s.toJson()],
        [
          [4, 9],
        ],
      );
      expect(
        [for (final s in tm.added) s.toJson()],
        [
          [4, 8],
        ],
      );
      expect(tm.runs.map((r) => (r.fromStart, r.toStart)), [(0, 0), (10, 9)]);
    });
  });

  group('Given object-level text matching', () {
    test('when the text is identical then it still moves glyph by glyph '
        '(font size and color interpolate)', () {
      final f = MagicMoveFixture();
      f.text(f.a, 'Same title', key: 't');
      f.text(f.bSlide, 'Same title', key: 't', x: 600);

      final p = f.plan().pairs.single;
      expect(p.mode, MorphMode.glyphs);
      expect(p.text!.removed, isEmpty);
      expect(p.text!.added, isEmpty);
    });

    test('when the text differs then both crossfade over the middle 60 %', () {
      final f = MagicMoveFixture();
      final a = f.text(f.a, 'Old title', key: 't');
      final b = f.text(f.bSlide, 'New title', key: 't');
      final plan = f.plan();

      expect(plan.pairs.single.mode, MorphMode.crossfade);
      expect(plan.frameAt(200).incoming.stateOf(b).opacity, 0);
      expect(plan.frameAt(500).outgoing.stateOf(a).opacity, closeTo(0.5, 1e-9));
      expect(plan.frameAt(800).outgoing.stateOf(a).opacity, 0);
    });
  });

  group('Given 3D charts at different camera angles (06 §18 AC 6)', () {
    test('when morphing then the camera turns along the shortest arc and '
        'the chart is not crossfaded', () {
      final f = MagicMoveFixture();
      f.element(
        f.a,
        ElementKind.chart,
        key: 'c',
        data: {
          'camera': {'azimuth': 350, 'elevation': 10, 'perspective': 15},
        },
      );
      final b = f.element(
        f.bSlide,
        ElementKind.chart,
        key: 'c',
        data: {
          'camera': {'azimuth': 30, 'elevation': 40, 'perspective': 45},
        },
      );
      final plan = f.plan();
      final frame = plan.frameAt(500);

      expect(plan.pairs.single.mode, MorphMode.replace);
      expect(frame.pairs[b]!.camera!.toJson(), {
        'azimuth': 10.0,
        'elevation': 25.0,
        'perspective': 30.0,
      });
      expect(frame.incoming.stateOf(b).chart!.toJson(), {
        'camera': {'azimuth': 10.0, 'elevation': 25.0, 'perspective': 30.0},
        'cameraMix': 1.0,
      });
    });

    test('when the outgoing slide ended on a chartCamera emphasis then the '
        'morph starts from that camera', () {
      final f = MagicMoveFixture();
      final a = f.element(
        f.a,
        ElementKind.chart,
        key: 'c',
        data: {
          'camera': {'azimuth': 0, 'elevation': 10, 'perspective': 15},
        },
      );
      final b = f.element(
        f.bSlide,
        ElementKind.chart,
        key: 'c',
        data: {
          'camera': {'azimuth': 90, 'elevation': 10, 'perspective': 15},
        },
      );
      final finalA = SlideFrame({
        a: ElementVisualState(
          chart: const ChartRevealState(camera: {'azimuth': 60}, cameraMix: 1),
        ),
      });
      final plan = MagicMovePlan.compile(
        f.slideA(frame: finalA),
        f.slideB(),
        spec: MagicMoveFixture.magicMove(),
      );

      expect(plan.frameAt(0).pairs[b]!.camera!.azimuth, 60);
    });
  });

  group('Given element groups (06 §8.3)', () {
    test('when two groups match then their children match recursively and '
        'an unmatched child rides with the group', () {
      final f = MagicMoveFixture();
      Map<String, Object?> bounds(double x, double y) => {
        'childBounds': {'x': x, 'y': y, 'w': 1000, 'h': 600},
      };
      const ga = 'groupA', gb = 'groupB';
      final childA = f.element(
        f.a,
        ElementKind.shape,
        key: 'gc',
        data: {'geometry': 'rect'},
        x: 0,
        y: 300,
        parentId: ga,
      );
      final loner = f.element(
        f.a,
        ElementKind.shape,
        data: {'geometry': 'ellipse'},
        x: 500,
        y: 0,
        parentId: ga,
      );
      f.element(
        f.a,
        ElementKind.group,
        key: 'g',
        id: ga,
        data: bounds(0, 0),
        x: 0,
        y: 0,
        w: 1000,
        h: 600,
      );
      final childB = f.element(
        f.bSlide,
        ElementKind.shape,
        key: 'gc',
        data: {'geometry': 'rect'},
        x: 200,
        y: 400,
        parentId: gb,
      );
      f.element(
        f.bSlide,
        ElementKind.group,
        key: 'g',
        id: gb,
        data: bounds(100, 100),
        x: 100,
        y: 100,
        w: 1000,
        h: 600,
      );
      final plan = f.plan();

      expect(plan.matches.toJson(), {
        'pairs': [
          {
            'from': ga,
            'to': gb,
            'pass': 'key',
            'children': {
              'pairs': [
                {'from': childA, 'to': childB, 'pass': 'key'},
              ],
              'outgoing': [loner],
              'incoming': <String>[],
            },
          },
        ],
        'outgoing': <String>[],
        'incoming': <String>[],
      });
      expect(plan.pairs.map((p) => p.mode), [
        MorphMode.group,
        MorphMode.replace,
      ]);
      // The loner moves with its group: halfway the group is 50 su right
      // and down.
      final s = plan.frameAt(500).outgoing.stateOf(loner);
      expect(mapPoint(s.transform, 700, 100), _point(750, 150));
      expect(s.opacity, closeTo(0.5, 1e-9));
      expect(plan.outgoingIds, [loner]);
    });
  });

  group('Given slides without any match (06 §8.5)', () {
    test('when compiling the transition then it plays as a crossfade with '
        'the Magic Move duration', () {
      final f = MagicMoveFixture();
      f.shape(f.a);
      f.shape(f.bSlide, geometry: 'ellipse');
      final plan = TransitionCompiler.compile(
        from: SlideFrame.edit,
        to: SlideFrame.edit,
        spec: MagicMoveFixture.magicMove(durationMs: 800),
        fromSlide: f.slideA(),
        toSlide: f.slideB(),
      );

      expect(plan.type, 'fade');
      expect(plan.durationMs, 800);
      expect(plan.warnings.map((w) => w.code), ['magicMoveNoMatches']);
    });
  });

  group('Given the same slide compiled twice (06 §9.3 determinism)', () {
    test('when evaluating every 100 ms then the frames are identical JSON', () {
      String run() {
        final f = MagicMoveFixture();
        f.shape(f.a, key: 'k', fill: '#FF0000', rotation: 30);
        f.shape(f.bSlide, key: 'k', x: 700, fill: '#00FF00', geometry: 'star5');
        f.text(f.a, 'Alpha beta gamma', key: 't');
        f.text(f.bSlide, 'Alpha gamma delta', key: 't', y: 300);
        f.shape(f.a, y: 800);
        f.shape(f.bSlide, x: 1400, y: 800);
        final plan = f.plan(
          options: {'textMatching': 'character', 'stagger': 50},
        );
        return jsonEncode([
          plan.toJson(),
          for (var ms = 0; ms <= plan.durationMs; ms += 100)
            plan.frameAt(ms).toJson(),
        ]);
      }

      expect(run(), run());
    });
  });
}
