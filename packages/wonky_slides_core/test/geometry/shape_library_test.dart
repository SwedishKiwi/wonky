import 'package:test/test.dart';
import 'package:wonky_slides_core/scene.dart';

void main() {
  group('Given the shape library', () {
    test('when listing keys then every 03 §6.3 P0 geometry is present', () {
      const p0 = [
        'rect',
        'roundRect',
        'ellipse',
        'triangle',
        'rightTriangle',
        'diamond',
        'pentagon',
        'hexagon',
        'octagon',
        'parallelogram',
        'trapezoid',
        'donut',
        'arrowRight',
        'arrowLeft',
        'arrowUp',
        'arrowDown',
        'arrowLeftRight',
        'arrowUpDown',
        'speech',
        'calloutRect',
      ];

      expect(ShapeLibrary.keys, containsAll(p0));
      expect([
        for (final g in ShapeLibrary.all)
          if (g.p0) g.key,
      ], unorderedEquals(p0));
    });

    test('when listing keys then every category of 03 §6.3 has shapes and '
        'keys are unique', () {
      for (final c in ShapeCategory.values) {
        expect(ShapeLibrary.inCategory(c), isNotEmpty, reason: c.name);
      }
      expect(ShapeLibrary.keys.toSet(), hasLength(ShapeLibrary.keys.length));
      expect(ShapeLibrary.keys.length, greaterThanOrEqualTo(70));
    });

    for (final g in ShapeLibrary.all) {
      final tail =
          g.category == ShapeCategory.callouts &&
          g.adjusts.any((a) => a.key == 'tipY');
      test('when outlining ${g.key} in a 400 × 200 box then the outline is '
          'finite, ${tail ? '' : 'inside the box (± tolerance), '}and has '
          'the 5 named sites', () {
        final o = g.outline(400, 200, adjust: tail ? {'tipY': 0.9} : null);

        expect(o.parts, isNotEmpty);
        for (final p in o.parts) {
          expect(p.path.commands, isNotEmpty);
          final b = PathOps.flatBounds(p.path.commands)!;
          expect(b.x, greaterThanOrEqualTo(-1));
          expect(b.y, greaterThanOrEqualTo(-1));
          expect(b.right, lessThanOrEqualTo(401));
          expect(b.bottom, lessThanOrEqualTo(201));
        }
        expect(
          o.sites.map((s) => s.name),
          containsAll(['top', 'right', 'bottom', 'left', 'center']),
        );
        expect(o.textRect.width, greaterThanOrEqualTo(0));
        expect(o.textRect.height, greaterThanOrEqualTo(0));
      });
    }

    test('when outlining an unknown key then the fallback rect is used', () {
      final o = ShapeLibrary.outlineOf({'geometry': 'nope'}, 100, 50);

      expect(PathOps.bounds(o.mainPath.commands)!.toList(), [0, 0, 100, 50]);
    });

    test('when outlining a rect then its center is inside and a point '
        'outside is not', () {
      final path = ShapeLibrary.resolve('rect').outline(100, 100).mainPath;

      expect(PathOps.contains(path, 50, 50), isTrue);
      expect(PathOps.contains(path, 150, 50), isFalse);
    });

    test('when outlining a donut then its hole is outside the fill', () {
      final path = ShapeLibrary.resolve('donut').outline(200, 200).mainPath;

      expect(path.evenOdd, isTrue);
      expect(PathOps.contains(path, 100, 100), isFalse);
      expect(PathOps.contains(path, 10, 100), isTrue);
    });

    test('when outlining a triangle then the top site is the apex and the '
        'apex follows the adjust value', () {
      final g = ShapeLibrary.resolve('triangle');

      expect(g.outline(200, 100).site('top')!.x, 100);
      expect(g.outline(200, 100, adjust: {'apex': 0.25}).site('top')!.x, 50);
    });

    test('when outlining an ellipse then the text rect is the inscribed '
        'rectangle', () {
      final r = ShapeLibrary.resolve('ellipse').outline(200, 100).textRect;

      expect(r.x, closeTo(29.2, 0.1));
      expect(r.width, closeTo(141.6, 0.1));
    });

    test('when an adjust value is out of range then it is clamped', () {
      final g = ShapeLibrary.resolve('roundRect');

      expect(g.adjustValue('radius', {'radius': 3}), 0.5);
      expect(g.adjustValue('radius', {'radius': -1}), 0);
      expect(g.adjustValue('radius', null), 0.12);
    });

    test('when dragging the roundRect handle then the value follows the '
        'track and the handle sits at the radius', () {
      final g = ShapeLibrary.resolve('roundRect');

      expect(g.handles(200, 100, adjust: {'radius': 0.2})['radius'], (20, 0));
      expect(g.adjustFromPoint('radius', 200, 100, 30, 5), closeTo(0.3, 1e-9));
    });

    test('when outlining a cube then the side faces are shaded parts', () {
      final o = ShapeLibrary.resolve('cube').outline(200, 200);

      expect(o.parts.map((p) => p.shade), [0, 0.2, -0.2]);
    });

    test('when outlining brackets then no part is filled', () {
      for (final k in ['brace', 'bracket', 'doubleBrace', 'arc']) {
        final o = ShapeLibrary.resolve(k).outline(100, 300);
        expect(o.parts.every((p) => !p.fill), isTrue, reason: k);
      }
    });

    test('when outlining a callout with the tip below then the tip is a '
        'site outside the box', () {
      final o = ShapeLibrary.resolve(
        'calloutRect',
      ).outline(200, 100, adjust: {'tipX': 0.3, 'tipY': 1.5});

      expect(o.site('0')!.x, 60);
      expect(o.site('0')!.y, 150);
      final b = PathOps.bounds(o.mainPath.commands)!;
      expect(b.bottom, 150);
    });

    test('when outlining a custom shape then the SVG path is scaled from the '
        '0..1000 box', () {
      final o = ShapeLibrary.outlineOf(
        {'geometry': 'custom', 'path': 'M0 0 L1000 0 L500 1000 Z'},
        200,
        100,
      );

      expect(PathOps.bounds(o.mainPath.commands)!.toList(), [0, 0, 200, 100]);
    });
  });

  group('Given SVG path data', () {
    test('when parsing relative and absolute commands then the points are '
        'absolute', () {
      final cmds = SvgPathParser.parse('M10 10 l10 0 v10 H10 z');

      expect(cmds, [
        const PMoveTo(10, 10),
        const PLineTo(20, 10),
        const PLineTo(20, 20),
        const PLineTo(10, 20),
        const PClose(),
      ]);
    });

    test('when parsing an arc then it ends at the target point', () {
      final cmds = SvgPathParser.parse('M0 50 A50 50 0 0 1 100 50');
      final last = cmds.last as PCubicTo;

      expect(last.x, closeTo(100, 1e-9));
      expect(last.y, closeTo(50, 1e-9));
      expect(PathOps.bounds(cmds)!.y, lessThan(10));
    });

    test('when parsing quadratic and smooth curves then cubic commands are '
        'produced', () {
      final cmds = SvgPathParser.parse(
        'M0 0 Q50 100 100 0 T200 0 S250 50 300 0',
      );

      expect(cmds.whereType<PCubicTo>(), hasLength(3));
    });

    test('when parsing malformed data then the parsed prefix is kept', () {
      expect(SvgPathParser.parse('M0 0 L10 x'), [const PMoveTo(0, 0)]);
      expect(SvgPathParser.parse('garbage'), isEmpty);
    });
  });
}
