import 'dart:convert';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector4;
import 'package:wonky_slides_core/motion.dart';

import '../../support/magic_move_fixture.dart';

const _w = 1920.0, _h = 1080.0;

TransitionPlan _plan(
  String type, {
  Map<String, Object?> params = const {},
  String easing = 'linear',
  int? durationMs,
  TransitionOptions options = const TransitionOptions(),
}) => TransitionCompiler.compile(
  from: SlideFrame.edit,
  to: SlideFrame.edit,
  transitionJson: jsonEncode({
    'type': type,
    'easing': easing,
    'durationMs': ?durationMs,
    'params': params,
  }),
  options: options,
);

/// Screen position of slide point ([x], [y]) under [m] (projective divide).
(double, double) _project(Matrix4 m, double x, double y) {
  final v = m.transformed(Vector4(x, y, 0, 1));
  return (v.x / v.w, v.y / v.w);
}

Matcher _point(double x, double y, [double eps = 1e-6]) =>
    isA<(double, double)>()
        .having((p) => p.$1, 'x', closeTo(x, eps))
        .having((p) => p.$2, 'y', closeTo(y, eps));

TransitionQuad _quad(TransitionFrame f, TransitionLayer l) =>
    f.quads.firstWhere((q) => q.layer == l);

const _out = TransitionLayer.outgoing, _in = TransitionLayer.incoming;

/// Whether [q] draws something on the slide: visible, not transparent,
/// not fully clipped or dissolved, and overlapping the slide rectangle.
bool _onSlide(TransitionQuad q) {
  if (!q.visible || q.opacity <= 0) return false;
  if (q.clip != null && q.clip!.progress <= 0) return false;
  if (q.dissolve != null && q.dissolve!.amount <= 0) return false;
  final r = q.region ?? const SuRect(0, 0, _w, _h);
  final pts = [
    _project(q.transform, r.x, r.y),
    _project(q.transform, r.right, r.y),
    _project(q.transform, r.right, r.bottom),
    _project(q.transform, r.x, r.bottom),
  ];
  final minX = pts.map((p) => p.$1).reduce(math.min);
  final maxX = pts.map((p) => p.$1).reduce(math.max);
  final minY = pts.map((p) => p.$2).reduce(math.min);
  final maxY = pts.map((p) => p.$2).reduce(math.max);
  return maxX > 1e-6 && minX < _w - 1e-6 && maxY > 1e-6 && minY < _h - 1e-6;
}

/// Whether [q] draws its region (or slide) unchanged (corners in place,
/// opaque, unclipped, unshaded).
bool _unchanged(TransitionQuad q) {
  final r = q.region ?? const SuRect(0, 0, _w, _h);
  bool at(double x, double y) {
    final (px, py) = _project(q.transform, x, y);
    return (px - x).abs() < 1e-6 && (py - y).abs() < 1e-6;
  }

  return at(r.x, r.y) &&
      at(r.right, r.y) &&
      at(r.right, r.bottom) &&
      at(r.x, r.bottom) &&
      q.opacity == 1 &&
      (q.clip == null || q.clip!.progress >= 1) &&
      (q.dissolve == null || q.dissolve!.amount >= 1) &&
      q.shade.abs() < 1e-9;
}

/// Whether the topmost quads drawing on the slide are [layer], unchanged,
/// and cover the slide (they then hide everything below).
bool _shows(TransitionFrame f, TransitionLayer layer) {
  var area = 0.0;
  for (final q in f.quads.where(_onSlide).toList().reversed) {
    if (q.layer != layer || !_unchanged(q)) return false;
    final r = q.region ?? const SuRect(0, 0, _w, _h);
    area += r.width * r.height;
    if (area >= _w * _h - 1e-6) return true;
  }
  return false;
}

bool _showsIncomingOnly(TransitionFrame f) => _shows(f, _in);

bool _showsOutgoingOnly(TransitionFrame f) => _shows(f, _out);

void main() {
  group('Given every available transition of the catalog (06 §7.2)', () {
    final types = [
      for (final t in TransitionCatalog.types)
        if (t.available && t.id != 'none' && t.id != 'magicMove') t.id,
    ];

    for (final type in types) {
      test('when "$type" starts then the outgoing slide shows and when it '
          'ends the incoming slide shows', () {
        final plan = _plan(type);

        expect(plan.type, type);
        expect(
          plan.durationMs,
          TransitionCatalog.byId(type)!.defaultDurationMs,
        );
        expect(_showsOutgoingOnly(plan.at(0)), isTrue, reason: 'start');
        expect(_showsIncomingOnly(plan.frameAt(plan.durationMs)), isTrue);
      });

      test('when "$type" is compiled twice then every frame is the same '
          'JSON', () {
        String run() => jsonEncode([
          for (final f in _plan(type, easing: 'easeInOutCubic').sample(9))
            f.toJson(),
        ]);

        expect(run(), run());
      });
    }

    test('when a type is 3D then its quads carry perspective', () {
      final f = _plan('cube').at(0.5);

      expect(_plan('cube').is3d, isTrue);
      expect(_quad(f, _out).transform.entry(3, 2), isNot(0));
      expect(_plan('push').is3d, isFalse);
    });
  });

  group('Given a cut', () {
    test('when compiling no transition then the plan is a cut that shows '
        'the incoming slide', () {
      final plan = TransitionCompiler.compile(
        from: SlideFrame.edit,
        to: SlideFrame.edit,
      );

      expect(plan.isCut, isTrue);
      expect(plan.frameAt(0).quads.single.layer, _in);
      expect(plan.describe(), {'type': 'none', 'durationMs': 0});
    });
  });

  group('Given 2D transitions', () {
    test('when pushing left halfway then both slides are shifted by half '
        'the width', () {
      final f = _plan('push').at(0.5);

      expect(_project(_quad(f, _out).transform, 0, 0), _point(-960, 0));
      expect(_project(_quad(f, _in).transform, 0, 0), _point(960, 0));
    });

    test('when pushing up then the new slide comes from below', () {
      final f = _plan('push', params: {'direction': 'up'}).at(0.25);

      expect(_project(_quad(f, _in).transform, 0, 0), _point(0, 810));
    });

    test('when covering then the old slide stays and dims by up to 20 %', () {
      final f = _plan('cover').at(0.5);

      expect(_quad(f, _out).shade, closeTo(0.1, 1e-9));
      expect(_project(_quad(f, _out).transform, 0, 0), _point(0, 0));
      expect(f.quads.last.layer, _in);
    });

    test('when uncovering then the old slide is on top and slides away', () {
      final f = _plan('uncover', params: {'direction': 'right'}).at(0.5);

      expect(f.quads.last.layer, _out);
      expect(_project(_quad(f, _out).transform, 0, 0), _point(960, 0));
    });

    test('when wiping then the new slide is clipped by the wipe progress', () {
      final f = _plan(
        'wipe',
        params: {'direction': 'topLeft', 'softness': 0.3},
      ).at(0.4);

      expect(_quad(f, _in).clip!.toJson(), {
        'kind': 'wipe',
        'progress': 0.4,
        'direction': 'topLeft',
        'softness': 0.3,
      });
    });

    test('when an iris opens from a corner then the clip says so', () {
      final f = _plan(
        'iris',
        params: {'shape': 'diamond', 'origin': 'bottomRight'},
      ).at(0.5);

      expect(_quad(f, _in).clip!.toJson(), {
        'kind': 'iris',
        'progress': 0.5,
        'shape': 'diamond',
        'origin': [1.0, 1.0],
      });
    });

    test('when zooming out then the old slide shrinks over the new one', () {
      final f = _plan('zoom', params: {'mode': 'out'}).at(0.5);

      expect(f.quads.last.layer, _out);
      expect(_project(_quad(f, _out).transform, 0, 0), _point(360, 202.5));
    });

    test('when dissolving then the noise seed comes from the entered '
        'slide', () {
      final a = _plan(
        'dissolve',
        options: const TransitionOptions(seedKey: 'slide-1'),
      ).at(0.3);
      final b = _plan(
        'dissolve',
        options: const TransitionOptions(seedKey: 'slide-2'),
      ).at(0.3);

      expect(_quad(a, _in).dissolve!.amount, closeTo(0.3, 1e-9));
      expect(_quad(a, _in).dissolve!.seed, stableHash('transition:slide-1'));
      expect(_quad(a, _in).dissolve!.seed, isNot(_quad(b, _in).dissolve!.seed));
    });

    test('when fading through black then the old slide fades out over the '
        'first half and the new one in over the second', () {
      final plan = _plan('fade', params: {'through': 'black'});

      expect(plan.at(0.25).backdrop, 0xFF000000);
      expect(_quad(plan.at(0.25), _out).opacity, closeTo(0.5, 1e-9));
      expect(_quad(plan.at(0.25), _in).visible, isFalse);
      expect(_quad(plan.at(0.75), _in).opacity, closeTo(0.5, 1e-9));
    });

    test('when fading through a hex color then it is the backdrop', () {
      expect(
        _plan('fade', params: {'through': '#336699'}).at(0.5).backdrop,
        0xFF336699,
      );
    });
  });

  group('Given 3D transitions (06 §7.2, §12.2)', () {
    test('when a cube turns left halfway then the old face is left of the '
        'center, the new one right, both visible and shaded', () {
      final f = _plan('cube').at(0.5);
      final o = _quad(f, _out), i = _quad(f, _in);

      expect(o.visible && i.visible, isTrue);
      expect(_project(o.transform, _w / 2, _h / 2).$1, lessThan(_w / 2));
      expect(_project(i.transform, _w / 2, _h / 2).$1, greaterThan(_w / 2));
      // Faces at 45°: 12 % × (1 − cos 45°).
      expect(o.shade, closeTo(faceShade * (1 - math.sqrt1_2), 1e-9));
      // The shared edge stays on one line.
      expect(
        _project(o.transform, _w, _h / 2),
        _point(
          _project(i.transform, 0, _h / 2).$1,
          _project(i.transform, 0, _h / 2).$2,
          1e-6,
        ),
      );
    });

    test('when a cube turns up then the new face comes from below', () {
      final f = _plan('cube', params: {'direction': 'up'}).at(0.3);

      expect(
        _project(_quad(f, _in).transform, _w / 2, _h / 2).$2,
        greaterThan(_h / 2),
      );
    });

    test('when flipping then the old face shows until halfway and the new '
        'face after; the other is culled', () {
      final plan = _plan('flip');
      final early = plan.at(0.3), late = plan.at(0.7);

      expect(_quad(early, _out).visible, isTrue);
      expect(_quad(early, _in).visible, isFalse);
      expect(_quad(late, _out).visible, isFalse);
      expect(_quad(late, _in).visible, isTrue);
    });

    test('when the doorway opens then both halves of the old slide swing '
        'outward toward the viewer', () {
      final f = _plan('doorway').at(0.5);
      final doors = f.quads.where((q) => q.layer == _out).toList();

      expect(doors.map((d) => d.region!.x), [0, _w / 2]);
      expect(_project(doors[0].transform, _w / 2, _h / 2).$1, lessThan(_w / 2));
      expect(
        _project(doors[1].transform, _w / 2, _h / 2).$1,
        greaterThan(_w / 2),
      );
      expect(f.quads.first.layer, _in);
    });

    test('when revolving then the old slide swings away about its left '
        'edge, which stays put', () {
      final f = _plan('revolve').at(0.5);
      final o = _quad(f, _out);

      expect(_project(o.transform, 0, 0), _point(0, 0));
      expect(_project(o.transform, _w, _h / 2).$1, lessThan(_w));
    });

    test('when swapping then the slides trade the front place at the '
        'middle', () {
      final plan = _plan('swap');

      expect(plan.at(0.4).quads.last.layer, _out);
      expect(plan.at(0.6).quads.last.layer, _in);
    });

    test('when a quad is turned away then frontFacing says so', () {
      final m = Matrix4.identity()..rotateY(math.pi * 0.75);

      expect(
        frontFacing(Matrix4.identity(), const SuRect(0, 0, 10, 10)),
        isTrue,
      );
      expect(frontFacing(m, const SuRect(0, 0, 10, 10)), isFalse);
    });
  });

  group('Given reversed playback (06 §6 reverseOnBack)', () {
    test('when pushing left backwards then it looks like a push right: the '
        'slide being left goes right', () {
      final back = _plan(
        'push',
        options: const TransitionOptions(reverse: true),
      );
      final f = back.at(0.25);

      expect(_showsOutgoingOnly(back.at(0)), isTrue);
      expect(_project(_quad(f, _out).transform, 0, 0), _point(480, 0));
      expect(_project(_quad(f, _in).transform, 0, 0), _point(-1440, 0));
      expect(_showsIncomingOnly(back.at(1)), isTrue);
    });
  });

  group('Given fallbacks', () {
    test('when the type is unknown then it plays as a fade with a '
        'warning', () {
      final plan = _plan('sparkle');

      expect(plan.type, 'fade');
      expect(plan.requestedType, 'sparkle');
      expect(plan.warnings.map((w) => w.code), ['unknownTransition']);
    });

    test('when the type is P2 then it plays as a fade', () {
      final plan = _plan('pageCurl');

      expect(plan.type, 'fade');
      expect(plan.warnings.map((w) => w.code), ['unavailableTransition']);
    });

    test('when reduce motion is on then every transition is a 300 ms fade '
        '(06 §13)', () {
      const rm = TransitionOptions(reducedMotion: true);
      for (final type in ['cube', 'push', 'magicMove', 'fade']) {
        final plan = _plan(type, durationMs: 1200, options: rm);
        expect(plan.type, 'fade', reason: type);
        expect(plan.durationMs, reducedMotionMs, reason: type);
      }
      expect(_plan('none', options: rm).isCut, isTrue);
    });

    test('when Magic Move has no slides then it crossfades', () {
      final plan = _plan('magicMove');

      expect(plan.type, 'fade');
      expect(plan.warnings.map((w) => w.code), ['magicMoveNoSlides']);
    });
  });

  group('Given springs', () {
    test('when the easing is a spring then the plan lasts its settle '
        'time', () {
      final plan = _plan('push', easing: 'spring(0.5,0.3)', durationMs: 500);

      expect(
        plan.durationMs,
        MotionEasing.parse('spring(0.5,0.3)').bind(500).durationMs,
      );
      expect(plan.durationMs, greaterThan(500));
    });
  });

  group('Given a deck whose second slide has Magic Move', () {
    test('when compiling between the slides then the matched shape morphs '
        'and the plan describes it', () {
      final f = MagicMoveFixture();
      f.shape(f.a, key: 'k');
      final sb = f.shape(f.bSlide, key: 'k', x: 1000);
      f.setTransition(f.bSlide, {'type': 'magicMove', 'durationMs': 800});
      final plan = TransitionCompiler.between(
        f.model,
        fromSlideId: f.a,
        toSlideId: f.bSlide,
      );

      expect(plan.type, 'magicMove');
      expect(plan.describe(), {
        'type': 'magicMove',
        'durationMs': 800,
        'pairs': 1,
      });
      expect(plan.frameAt(400).magicMove!.pairs.keys, [sb]);
    });
  });
}
