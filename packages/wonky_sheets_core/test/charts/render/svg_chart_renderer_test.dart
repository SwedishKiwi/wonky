import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/charts/render/render.dart';
import 'package:wonky_sheets_core/src/charts/scene/geometry.dart';
import 'package:wonky_sheets_core/src/charts/scene/path.dart';
import 'package:wonky_sheets_core/src/charts/scene/scene.dart';
import 'package:xml/xml.dart';

import 'render_test_scenes.dart';

XmlDocument _svg(ChartScene scene) =>
    XmlDocument.parse(const SvgChartRenderer().render(scene));

XmlElement _only(XmlDocument doc, String name) =>
    doc.findAllElements(name).single;

XmlElement _text(SText t) =>
    _only(_svg(RenderTestScenes.scene([t], background: 0)), 'text');

void main() {
  group('Given the kitchen-sink scene', () {
    final scene = RenderTestScenes.kitchenSink();

    test(
      'when rendering to SVG then the output parses as XML with an svg root',
      () {
        final doc = _svg(scene);

        expect(doc.rootElement.name.local, equals('svg'));
        expect(
          doc.rootElement.getAttribute('xmlns'),
          equals('http://www.w3.org/2000/svg'),
        );
        expect(doc.rootElement.getAttribute('width'), equals('400'));
        expect(doc.rootElement.getAttribute('height'), equals('300'));
        expect(doc.rootElement.getAttribute('viewBox'), equals('0 0 400 300'));
      },
    );

    test('when rendering twice then the output is identical', () {
      expect(
        const SvgChartRenderer().render(scene),
        equals(const SvgChartRenderer().render(RenderTestScenes.kitchenSink())),
      );
    });

    test('when rendering then the background is the first painted element', () {
      final first = _svg(scene).rootElement.childElements.first;

      expect(first.name.local, equals('rect'));
      expect(first.getAttribute('width'), equals('400'));
      expect(first.getAttribute('fill'), equals('#ffffff'));
    });

    test('when rendering then every primitive type produces its element', () {
      final doc = _svg(scene);

      expect(doc.findAllElements('rect').length, greaterThanOrEqualTo(5));
      expect(doc.findAllElements('polyline').length, equals(1));
      expect(doc.findAllElements('circle').length, equals(7));
      expect(doc.findAllElements('text').length, equals(2));
      expect(doc.findAllElements('clipPath').length, equals(1));
      expect(doc.findAllElements('path').length, greaterThanOrEqualTo(8));
    });

    test(
      'when rendering then clip ids are unique and referenced by a group',
      () {
        final doc = _svg(scene);
        final ids = [
          for (final c in doc.findAllElements('clipPath')) c.getAttribute('id'),
        ];
        final refs = [
          for (final g in doc.findAllElements('g'))
            if (g.getAttribute('clip-path') != null)
              g.getAttribute('clip-path'),
        ];

        expect(ids, equals(['wc-clip-1']));
        expect(refs, equals(['url(#wc-clip-1)']));
      },
    );

    test('when rendering then the group carries its opacity', () {
      final groups = _svg(
        scene,
      ).findAllElements('g').where((g) => g.getAttribute('opacity') != null);

      expect(groups.single.getAttribute('opacity'), equals('0.5'));
      expect(groups.single.findElements('rect').length, equals(2));
    });

    test('when rendering then the even-odd path declares its fill rule', () {
      final evenOdd = _svg(scene)
          .findAllElements('path')
          .where((p) => p.getAttribute('fill-rule') == 'evenodd');

      expect(evenOdd.length, equals(2)); // the path and the full doughnut ring
    });

    test('when rendering then per-marker fills override the shared fill', () {
      final circles = _svg(scene).findAllElements('circle').take(6).toList();

      expect(
        [for (final c in circles) c.getAttribute('fill')],
        equals([
          '#ff0000',
          '#0000ff',
          '#ff0000',
          '#0000ff',
          '#ff0000',
          '#0000ff',
        ]),
      );
      expect([
        for (final c in circles) c.getAttribute('r'),
      ], equals(['4', '5', '6', '7', '8', '9']));
    });
  });

  group('Given a rectangle with a translucent fill and a styled stroke', () {
    final doc = _svg(
      RenderTestScenes.scene([
        const SRect(
          ChartRect(10.004, 20.5, 30.126, 40),
          fill: 0x4DFF0000,
          stroke: SStroke(
            0x80000000,
            width: 1.5,
            dash: [4, 2, 1],
            cap: SStrokeCap.square,
            join: SStrokeJoin.round,
          ),
          radius: 4,
        ),
      ], background: 0),
    );
    final rect = _only(doc, 'rect');

    test('when rendering then numbers are rounded to two decimals', () {
      expect(rect.getAttribute('x'), equals('10'));
      expect(rect.getAttribute('y'), equals('20.5'));
      expect(rect.getAttribute('width'), equals('30.13'));
      expect(rect.getAttribute('rx'), equals('4'));
    });

    test('when rendering then alpha becomes fill and stroke opacity', () {
      expect(rect.getAttribute('fill'), equals('#ff0000'));
      expect(rect.getAttribute('fill-opacity'), equals('0.3'));
      expect(rect.getAttribute('stroke-opacity'), equals('0.5'));
    });

    test('when rendering then dash, cap and join are emitted', () {
      expect(rect.getAttribute('stroke-width'), equals('1.5'));
      expect(rect.getAttribute('stroke-dasharray'), equals('4 2 1 4 2 1'));
      expect(rect.getAttribute('stroke-linecap'), equals('square'));
      expect(rect.getAttribute('stroke-linejoin'), equals('round'));
    });

    test(
      'when the background is transparent then no background rect is drawn',
      () {
        expect(doc.findAllElements('rect').length, equals(1));
      },
    );
  });

  group('Given a path with every command', () {
    test('when rendering then the path data uses M, L, C and Z', () {
      final doc = _svg(
        RenderTestScenes.scene([
          const SPath([
            PMoveTo(0, 0),
            PLineTo(10, 0),
            PCubicTo(10, 5, 5, 10, 0, 10),
            PClose(),
          ], stroke: SStroke(0xFF000000)),
        ]),
      );

      final path = _only(doc, 'path');
      expect(path.getAttribute('d'), equals('M0 0 L10 0 C10 5 5 10 0 10 Z'));
      expect(path.getAttribute('fill'), equals('none'));
    });
  });

  group('Given markers of every shape', () {
    for (final shape in MarkerShape.values) {
      test(
        'when rendering a ${shape.name} marker then one shape element is drawn',
        () {
          final doc = _svg(
            RenderTestScenes.scene([
              SMarkers(
                Float64List.fromList([50, 50]),
                shape,
                10,
                fill: RenderTestScenes.red,
              ),
            ]),
          );

          final g = doc.findAllElements('g').single;
          expect(g.childElements.length, equals(1));
          expect(g.getAttribute('fill'), equals('#ff0000'));
        },
      );
    }
  });

  group('Given text with special characters', () {
    test(
      'when rendering then the text is escaped and reads back unchanged',
      () {
        final t = _text(
          const SText(
            'a < b & "c" > d',
            ChartPoint(5, 5),
            RenderTestScenes.text,
          ),
        );

        expect(t.innerText, equals('a < b & "c" > d'));
      },
    );

    test(
      'when the text contains XML-invalid control characters then they are dropped',
      () {
        final t = _text(
          const SText('a\u0001b', ChartPoint(5, 5), RenderTestScenes.text),
        );

        expect(t.innerText, equals('ab'));
      },
    );

    test('when the text has leading spaces then whitespace is preserved', () {
      final t = _text(
        const SText('  x', ChartPoint(5, 5), RenderTestScenes.text),
      );

      expect(t.getAttribute('xml:space'), equals('preserve'));
    });
  });

  group('Given text styles', () {
    test(
      'when the family has a space then it is quoted before the fallbacks',
      () {
        final t = _text(
          const SText(
            'x',
            ChartPoint(0, 0),
            TextStyleSpec(
              family: 'Open Sans',
              size: 13.5,
              bold: true,
              italic: true,
            ),
          ),
        );

        expect(
          t.getAttribute('font-family'),
          equals("'Open Sans', Inter, 'Helvetica Neue', Arial, sans-serif"),
        );
        expect(t.getAttribute('font-size'), equals('13.5'));
        expect(t.getAttribute('font-weight'), equals('bold'));
        expect(t.getAttribute('font-style'), equals('italic'));
      },
    );

    test('when a custom fallback is configured then it follows the family', () {
      final svg = const SvgChartRenderer(fontFamilyFallback: 'serif').render(
        RenderTestScenes.scene([
          const SText('x', ChartPoint(0, 0), TextStyleSpec(family: 'Roboto')),
        ]),
      );

      expect(
        _only(XmlDocument.parse(svg), 'text').getAttribute('font-family'),
        equals('Roboto, serif'),
      );
    });

    test('when the color is translucent then fill-opacity is set', () {
      final t = _text(
        const SText('x', ChartPoint(0, 0), TextStyleSpec(color: 0x80123456)),
      );

      expect(t.getAttribute('fill'), equals('#123456'));
      expect(t.getAttribute('fill-opacity'), equals('0.5'));
    });
  });

  group('Given text with measured metrics (height 20, ascent 16)', () {
    final cases = <(TextAnchor, String?, String?)>[
      (TextAnchor.topLeft, null, '16'),
      (TextAnchor.topCenter, 'middle', '16'),
      (TextAnchor.topRight, 'end', '16'),
      (TextAnchor.middleLeft, null, '6'),
      (TextAnchor.center, 'middle', '6'),
      (TextAnchor.middleRight, 'end', '6'),
      (TextAnchor.bottomLeft, null, '-4'),
      (TextAnchor.bottomCenter, 'middle', '-4'),
      (TextAnchor.bottomRight, 'end', '-4'),
      (TextAnchor.baselineLeft, null, null),
      (TextAnchor.baselineCenter, 'middle', null),
      (TextAnchor.baselineRight, 'end', null),
    ];
    for (final (anchor, textAnchor, dy) in cases) {
      test(
        'when anchored ${anchor.name} then text-anchor is $textAnchor and dy is $dy',
        () {
          final t = _text(
            SText(
              'x',
              const ChartPoint(50, 40),
              RenderTestScenes.text,
              anchor: anchor,
              width: 30,
              height: 20,
              ascent: 16,
            ),
          );

          expect(t.getAttribute('text-anchor'), equals(textAnchor));
          expect(t.getAttribute('dy'), equals(dy));
          expect(t.getAttribute('x'), equals('50'));
          expect(t.getAttribute('y'), equals('40'));
        },
      );
    }
  });

  group('Given text without measured metrics', () {
    final cases = <(TextAnchor, String?)>[
      (TextAnchor.topLeft, 'text-before-edge'),
      (TextAnchor.center, 'central'),
      (TextAnchor.bottomRight, 'text-after-edge'),
      (TextAnchor.baselineLeft, null),
    ];
    for (final (anchor, baseline) in cases) {
      test(
        'when anchored ${anchor.name} then dominant-baseline is $baseline',
        () {
          final t = _text(
            SText(
              'x',
              const ChartPoint(0, 0),
              RenderTestScenes.text,
              anchor: anchor,
            ),
          );

          expect(t.getAttribute('dominant-baseline'), equals(baseline));
        },
      );
    }
  });

  group('Given rotated text', () {
    test(
      'when rendering then it rotates in degrees around its anchor point',
      () {
        final t = _text(
          const SText(
            'Axis',
            ChartPoint(12, 80.5),
            RenderTestScenes.text,
            anchor: TextAnchor.center,
            angle: -math.pi / 2,
          ),
        );

        expect(t.getAttribute('transform'), equals('rotate(-90 12 80.5)'));
      },
    );
  });

  group('Given the number formatter', () {
    final cases = <(double, String)>[
      (0, '0'),
      (1, '1'),
      (-0.001, '0'),
      (1.234, '1.23'),
      (1.5, '1.5'),
      (100.1, '100.1'),
      (-3.456, '-3.46'),
      (12345.678, '12345.68'),
      (double.nan, '0'),
      (double.infinity, '0'),
    ];
    for (final (v, s) in cases) {
      test('when formatting $v then the result is "$s"', () {
        expect(SvgChartRenderer.formatNumber(v), equals(s));
      });
    }
  });

  group('Given a group with zero opacity', () {
    test('when rendering then the group is omitted', () {
      final doc = _svg(
        RenderTestScenes.scene([
          const SGroup([
            SRect(ChartRect(0, 0, 10, 10), fill: RenderTestScenes.red),
          ], opacity: 0),
        ], background: 0),
      );

      expect(doc.findAllElements('rect'), isEmpty);
    });
  });

  group('Given a scene with non-finite coordinates', () {
    test('when rendering SVG then broken geometry is left out', () {
      final svg = const SvgChartRenderer().render(RenderTestScenes.nonFinite());

      expect(svg, isNot(contains('NaN')));
      expect(svg, isNot(contains('Infinity')));
      final doc = XmlDocument.parse(svg);
      expect(doc.findAllElements('polyline'), hasLength(2));
      expect(doc.findAllElements('text'), isEmpty);
    });
  });
}
