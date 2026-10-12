import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/charts/render/render.dart';
import 'package:wonky_sheets_core/src/charts/scene/geometry.dart';
import 'package:wonky_sheets_core/src/charts/scene/path.dart';
import 'package:wonky_sheets_core/src/charts/scene/scene.dart';

import 'render_test_scenes.dart';

img.Image _render(ChartScene scene, {double scale = 1}) =>
    img.decodePng(const RasterChartRenderer().render(scene, scale: scale))!;

img.Image _one(ScenePrimitive p, {double scale = 1, int background = RenderTestScenes.white}) =>
    _render(RenderTestScenes.scene([p], background: background), scale: scale);

const _white = (255, 255, 255, 255);
const _red = (255, 0, 0, 255);
const _blue = (0, 0, 255, 255);

Matcher _near((int, int, int, int) expected, {int tolerance = 2}) =>
    predicate<(int, int, int, int)>(
      (c) =>
          (c.$1 - expected.$1).abs() <= tolerance &&
          (c.$2 - expected.$2).abs() <= tolerance &&
          (c.$3 - expected.$3).abs() <= tolerance &&
          (c.$4 - expected.$4).abs() <= tolerance,
      'within $tolerance of $expected',
    );

void main() {
  group('Given the kitchen-sink scene', () {
    final scene = RenderTestScenes.kitchenSink();

    for (final scale in [1.0, 2.0, 0.5]) {
      test('when rendering at scale $scale then the PNG is scene size × scale', () {
        final image = _render(scene, scale: scale);

        expect(image.width, equals((400 * scale).round()));
        expect(image.height, equals((300 * scale).round()));
      });
    }

    test('when rendering twice then the bytes are identical', () {
      expect(
        const RasterChartRenderer().render(scene),
        equals(const RasterChartRenderer().render(RenderTestScenes.kitchenSink())),
      );
    });

    test('when rendering to an image then it matches the decoded PNG', () {
      final direct = const RasterChartRenderer().renderImage(scene);
      final decoded = _render(scene);

      expect(rgbaAt(direct, 30, 30), equals(rgbaAt(decoded, 30, 30)));
    });
  });

  group('Given an opaque red rectangle', () {
    final image = _one(const SRect(ChartRect(20, 20, 40, 30), fill: RenderTestScenes.red));

    test('when rendering then its center is red', () {
      expect(rgbaAt(image, 40, 35), equals(_red));
    });

    test('when rendering then pixels outside it keep the background', () {
      expect(rgbaAt(image, 10, 10), equals(_white));
      expect(rgbaAt(image, 61, 35), equals(_white));
    });

    test('when rendering at scale 2 then the rectangle covers the scaled area', () {
      final big = _one(
        const SRect(ChartRect(20, 20, 40, 30), fill: RenderTestScenes.red),
        scale: 2,
      );

      expect(rgbaAt(big, 41, 41), equals(_red));
      expect(rgbaAt(big, 119, 99), equals(_red));
      expect(rgbaAt(big, 121, 101), equals(_white));
    });
  });

  group('Given a 50 % alpha blue fill over white', () {
    test('when rendering then the color blends with the background', () {
      final image = _one(const SRect(ChartRect(0, 0, 50, 50), fill: 0x800000FF));

      expect(rgbaAt(image, 25, 25), _near((127, 127, 255, 255)));
    });
  });

  group('Given a transparent background', () {
    test('when rendering then uncovered pixels are fully transparent', () {
      final image = _one(
        const SRect(ChartRect(0, 0, 10, 10), fill: RenderTestScenes.red),
        background: 0,
      );

      expect(rgbaAt(image, 50, 50), equals((0, 0, 0, 0)));
      expect(rgbaAt(image, 5, 5), equals(_red));
    });

    test('when a translucent fill is drawn then the PNG keeps straight alpha', () {
      final image = _one(const SRect(ChartRect(0, 0, 10, 10), fill: 0x80FF0000), background: 0);

      expect(rgbaAt(image, 5, 5), _near((255, 0, 0, 128)));
    });
  });

  group('Given a rectangle clipped to a smaller rectangle', () {
    final image = _one(
      const SClip(ChartRect(30, 30, 20, 20), [
        SRect(ChartRect(0, 0, 100, 100), fill: RenderTestScenes.red),
      ]),
    );

    test('when rendering then the inside of the clip is filled', () {
      expect(rgbaAt(image, 40, 40), equals(_red));
    });

    test('when rendering then the area outside the clip stays background', () {
      expect(rgbaAt(image, 29, 40), equals(_white));
      expect(rgbaAt(image, 50, 40), equals(_white));
      expect(rgbaAt(image, 40, 29), equals(_white));
      expect(rgbaAt(image, 40, 50), equals(_white));
    });

    test('when text is clipped then no ink appears outside the clip', () {
      final clipped = _one(
        const SClip(ChartRect(0, 0, 20, 100), [
          SText(
            'WWWWWWWW',
            ChartPoint(5, 50),
            TextStyleSpec(size: 14),
            anchor: TextAnchor.middleLeft,
          ),
        ]),
      );

      expect(inkCount(clipped, 0, 30, 20, 70), greaterThan(0));
      expect(inkCount(clipped, 20, 0, 100, 100), equals(0));
    });
  });

  group('Given a triangle with a diagonal edge', () {
    test('when rendering then edge pixels are anti-aliased', () {
      final image = _one(
        const SPath([
          PMoveTo(10, 10),
          PLineTo(90, 10),
          PLineTo(10, 90),
          PClose(),
        ], fill: 0xFF000000),
      );

      // Pixel (49, 50) is split by the diagonal x + y = 100.
      final (r, _, _, _) = rgbaAt(image, 49, 50);
      expect(r, inExclusiveRange(40, 215));
      expect(rgbaAt(image, 20, 20), equals((0, 0, 0, 255)));
      expect(rgbaAt(image, 80, 80), equals(_white));
    });
  });

  group('Given two nested squares wound the same way', () {
    const cmds = [
      PMoveTo(10, 10),
      PLineTo(90, 10),
      PLineTo(90, 90),
      PLineTo(10, 90),
      PClose(),
      PMoveTo(30, 30),
      PLineTo(70, 30),
      PLineTo(70, 70),
      PLineTo(30, 70),
      PClose(),
    ];
    final cases = <(bool, (int, int, int, int))>[(false, _red), (true, _white)];
    for (final (evenOdd, center) in cases) {
      test('when filling with evenOdd=$evenOdd then the center is $center', () {
        final image = _one(const SPath(cmds, fill: RenderTestScenes.red).copyRule(evenOdd));

        expect(rgbaAt(image, 50, 50), equals(center));
        expect(rgbaAt(image, 20, 20), equals(_red));
      });
    }
  });

  group('Given a dashed horizontal line', () {
    final image = _one(
      SPolyline(
        Float64List.fromList([0, 50.5, 100, 50.5]),
        const SStroke(RenderTestScenes.black, width: 3, dash: [10, 10]),
      ),
    );

    test('when rendering then dashes are drawn', () {
      expect(rgbaAt(image, 5, 50), equals((0, 0, 0, 255)));
      expect(rgbaAt(image, 25, 50), equals((0, 0, 0, 255)));
    });

    test('when rendering then the gaps stay background', () {
      expect(rgbaAt(image, 15, 50), equals(_white));
      expect(rgbaAt(image, 35, 50), equals(_white));
    });
  });

  group('Given a 50 % opacity group of two overlapping opaque rectangles', () {
    test('when rendering then the overlap is not blended twice', () {
      final image = _one(
        const SGroup([
          SRect(ChartRect(10, 10, 50, 50), fill: RenderTestScenes.blue),
          SRect(ChartRect(40, 40, 50, 50), fill: RenderTestScenes.blue),
        ], opacity: 0.5),
      );

      expect(rgbaAt(image, 50, 50), equals(rgbaAt(image, 20, 20)));
      expect(rgbaAt(image, 20, 20), _near((127, 127, 255, 255)));
    });
  });

  group('Given a translucent self-crossing polyline', () {
    test('when rendering then the crossing has the same color as the rest of the line', () {
      final image = _one(
        SPolyline(
          Float64List.fromList([10, 10, 90, 90, 90, 10, 10, 90]),
          const SStroke(0x800000FF, width: 6),
        ),
      );

      expect(rgbaAt(image, 50, 50), equals(rgbaAt(image, 30, 30)));
      expect(rgbaAt(image, 30, 30), _near((127, 127, 255, 255)));
    });
  });

  group('Given a line end with each cap', () {
    final cases = <(SStrokeCap, bool)>[
      (SStrokeCap.butt, false),
      (SStrokeCap.round, true),
      (SStrokeCap.square, true),
    ];
    for (final (cap, extends_) in cases) {
      test('when the cap is ${cap.name} then ink past the end is $extends_', () {
        final image = _one(
          SPolyline(
            Float64List.fromList([20, 50, 60, 50]),
            SStroke(RenderTestScenes.black, width: 10, cap: cap),
          ),
        );

        expect(inkCount(image, 62, 48, 64, 52) > 0, equals(extends_));
        expect(rgbaAt(image, 40, 50), equals((0, 0, 0, 255)));
      });
    }
  });

  group('Given a sharp corner with each join', () {
    // A right angle at (50, 20): the miter tip reaches (55, 15), a bevel cuts the corner.
    final cases = <(SStrokeJoin, bool)>[
      (SStrokeJoin.miter, true),
      (SStrokeJoin.bevel, false),
      (SStrokeJoin.round, false),
    ];
    for (final (join, tip) in cases) {
      test('when the join is ${join.name} then the outer corner pixel is inked: $tip', () {
        final image = _one(
          SPolyline(
            Float64List.fromList([10, 20, 50, 20, 50, 80]),
            SStroke(RenderTestScenes.black, width: 10, join: join),
          ),
        );

        expect(inkCount(image, 54, 15, 55, 16) > 0, equals(tip));
        expect(rgbaAt(image, 50, 20), equals((0, 0, 0, 255)));
      });
    }
  });

  group('Given a hairline stroke thinner than a pixel', () {
    test('when rendering then it is visible with reduced intensity', () {
      final image = _one(
        SPolyline(
          Float64List.fromList([0, 50.5, 100, 50.5]),
          const SStroke(RenderTestScenes.black, width: 0.5),
        ),
      );

      expect(rgbaAt(image, 50, 50), _near((128, 128, 128, 255), tolerance: 3));
    });
  });

  group('Given markers of every shape', () {
    for (final shape in MarkerShape.values) {
      test('when rendering a ${shape.name} then its center is filled', () {
        final image = _one(
          SMarkers(
            Float64List.fromList([50, 50]),
            shape,
            20,
            fill: RenderTestScenes.red,
            stroke: const SStroke(RenderTestScenes.black, width: 1),
          ),
        );

        expect(rgbaAt(image, 50, 50), equals(_red));
        expect(rgbaAt(image, 50, 85), equals(_white));
      });
    }

    test('when markers have own sizes and fills then each uses its own', () {
      final image = _one(
        SMarkers(
          Float64List.fromList([20, 50, 70, 50]),
          MarkerShape.square,
          4,
          fill: RenderTestScenes.black,
          sizes: Float64List.fromList([4, 20]),
          fills: Int32List.fromList([RenderTestScenes.red, RenderTestScenes.blue]),
        ),
      );

      expect(rgbaAt(image, 20, 50), equals(_red));
      expect(rgbaAt(image, 78, 58), equals(_blue));
      expect(rgbaAt(image, 23, 50), equals(_white));
    });
  });

  group('Given arcs', () {
    test('when rendering a quarter slice then only its sweep is filled', () {
      final image = _one(
        const SArc(ChartPoint(50, 50), 40, 0, math.pi / 2, fill: RenderTestScenes.red),
      );

      expect(
        rgbaAt(image, 65, 65),
        equals(_red),
      ); // bottom-right quadrant (clockwise from 3 o'clock)
      expect(rgbaAt(image, 35, 35), equals(_white));
      expect(rgbaAt(image, 65, 35), equals(_white));
    });

    test('when rendering a full doughnut then the hole stays background', () {
      final image = _one(
        const SArc(
          ChartPoint(50, 50),
          40,
          0,
          2 * math.pi,
          innerRadius: 20,
          fill: RenderTestScenes.red,
        ),
      );

      expect(rgbaAt(image, 50, 50), equals(_white));
      expect(rgbaAt(image, 50, 20), equals(_red));
      expect(rgbaAt(image, 50, 95), equals(_white));
    });
  });

  group('Given unrotated text with different anchors', () {
    // (anchor, ink right of x, ink left of x, ink below y, ink above y)
    final cases = <(TextAnchor, bool, bool, bool, bool)>[
      (TextAnchor.topLeft, true, false, true, false),
      (TextAnchor.bottomRight, false, true, false, true),
      (TextAnchor.center, true, true, true, true),
      (TextAnchor.baselineCenter, true, true, false, true),
    ];
    for (final (anchor, right, left, below, above) in cases) {
      test('when anchored ${anchor.name} then the ink lies on the expected sides', () {
        final image = _one(
          SText('HHHH', const ChartPoint(50, 50), const TextStyleSpec(size: 14), anchor: anchor),
        );

        expect(inkCount(image, 51, 0, 100, 100) > 0, equals(right));
        expect(inkCount(image, 0, 0, 49, 100) > 0, equals(left));
        expect(inkCount(image, 0, 51, 100, 100) > 0, equals(below));
        expect(inkCount(image, 0, 0, 100, 49) > 0, equals(above));
      });
    }
  });

  group('Given text rotated 90° clockwise anchored top-left', () {
    test('when rendering then the ink runs down and to the left of the anchor', () {
      final image = _one(
        const SText(
          'HHHH',
          ChartPoint(50, 50),
          TextStyleSpec(size: 14),
          anchor: TextAnchor.topLeft,
          angle: math.pi / 2,
        ),
      );

      expect(inkCount(image, 30, 51, 50, 100), greaterThan(20));
      expect(inkCount(image, 51, 0, 100, 100), equals(0));
      expect(inkCount(image, 0, 0, 100, 49), equals(0));
    });
  });

  group('Given styled text', () {
    final cases = <(String, TextStyleSpec)>[
      ('regular', const TextStyleSpec(size: 12)),
      ('bold', const TextStyleSpec(size: 12, bold: true)),
      ('italic', const TextStyleSpec(size: 12, italic: true)),
      ('tiny', const TextStyleSpec(size: 6)),
      ('huge', const TextStyleSpec(size: 60)),
    ];
    for (final (name, style) in cases) {
      test('when drawing $name text then some pixels inside its box are inked', () {
        final image = _render(
          RenderTestScenes.scene(width: 300, height: 100, [
            SText('Ag <~>', const ChartPoint(10, 50), style, anchor: TextAnchor.middleLeft),
          ]),
        );

        expect(inkCount(image, 0, 0, 300, 100), greaterThan(5));
        expect(inkCount(image, 0, 0, 9, 100), equals(0));
      });
    }

    test('when drawing bold text then it has more ink than regular text', () {
      int ink(bool bold) => inkCount(
        _one(SText('Hello', const ChartPoint(10, 50), TextStyleSpec(size: 14, bold: bold))),
        0,
        0,
        100,
        100,
      );

      expect(ink(true), greaterThan(ink(false)));
    });

    test('when the text color is translucent then the ink is lighter', () {
      int darkest(int color) {
        final image = _one(
          SText('HHH', const ChartPoint(10, 50), TextStyleSpec(size: 24, color: color)),
        );
        var min = 255;
        for (var y = 0; y < 100; y++) {
          for (var x = 0; x < 100; x++) {
            min = math.min(min, rgbaAt(image, x, y).$1);
          }
        }
        return min;
      }

      expect(darkest(0xFF000000), lessThan(10));
      expect(darkest(0x80000000), inInclusiveRange(110, 145));
    });
  });

  group('Given a 600×371 chart with a 10,000-vertex polyline', () {
    test('when rendering at scale 2 then the line is drawn', () {
      final xy = Float64List(20000);
      for (var i = 0; i < 10000; i++) {
        xy[2 * i] = 20 + i * 560 / 10000;
        xy[2 * i + 1] = 185 + 120 * math.sin(i / 300);
      }
      final image = _render(
        RenderTestScenes.scene(width: 600, height: 371, [
          SPolyline(xy, const SStroke(0xFF4285F4, width: 2, join: SStrokeJoin.round)),
        ]),
        scale: 2,
      );

      expect(image.width, equals(1200));
      expect(rgbaAt(image, 40, 370), _near((66, 133, 244, 255), tolerance: 8));
    });
  });
}

extension on SPath {
  SPath copyRule(bool evenOdd) => SPath(cmds, fill: fill, stroke: stroke, evenOdd: evenOdd);
}
