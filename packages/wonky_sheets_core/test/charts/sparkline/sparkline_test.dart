import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';
import 'package:wonky_sheets_core/src/charts/charts.dart';

FArray options(List<(String, Object)> pairs) => FArray(pairs.length, 2, [
  for (final (k, v) in pairs) ...[
    FText(k),
    switch (v) {
      final num n => FNumber(n.toDouble()),
      final bool b => FBool(b),
      _ => FText('$v'),
    },
  ],
]);

SparklineData data(List<double> ys) => SparklineData(Float64List.fromList(ys));

void main() {
  group('Given SPARKLINE options (05 §17)', () {
    test('when no options are given then it is a line sparkline', () {
      final s = SparklineSpec.fromOptions(null);

      expect(s.type, SparklineType.line);
      expect(s.lineWidth, 1);
    });

    test(
      'when options are a two-column array then they are read case-insensitively',
      () {
        final s = SparklineSpec.fromOptions(
          options([
            ('charttype', 'column'),
            ('Color', 'red'),
            ('negcolor', '#00f'),
            ('axis', true),
            ('ymax', 10),
          ]),
        );

        expect(s.type, SparklineType.column);
        expect(s.color, 0xFFFF0000);
        expect(s.negColor, 0xFF0000FF);
        expect(s.axis, isTrue);
        expect(s.ymax, 10);
      },
    );

    for (final (name, pairs) in [
      ('an unknown chart type', [('charttype', 'pie')]),
      ('an option of another type', [('charttype', 'bar'), ('linewidth', 2)]),
      ('a bad color', [('color', 'notacolor')]),
      ('a bad empty mode', [('empty', 'skip')]),
    ]) {
      test('when given $name then the options are invalid', () {
        expect(
          () => SparklineSpec.fromOptions(options(pairs)),
          throwsA(isA<SparklineOptionException>()),
        );
      });
    }

    test(
      'when normalizing data with empties as zero then empties become 0',
      () {
        final s = SparklineSpec.fromOptions(options([('empty', 'zero')]));

        final d = s.normalize(
          FArray(1, 3, [const FNumber(1), FEmpty.instance, const FText('x')]),
        );

        expect(d.y[0], 1);
        expect(d.y[1], 0);
        expect(d.y[2], isNaN);
      },
    );

    test('when line data has two columns then they are x and y', () {
      const s = SparklineSpec();

      final d = s.normalize(
        FArray(3, 2, [
          for (var i = 0; i < 3; i++) ...[FNumber(i * 2.0), FNumber(i * 1.0)],
        ]),
      );

      expect(d.x, [0, 2, 4]);
      expect(d.y, [0, 1, 2]);
    });
  });

  group('Given sparkline layout in a 100 × 20 cell', () {
    test('when laying out a line then one polyline spans the padded cell', () {
      final scene = SparklineRenderer.layout(
        const SparklineSpec(),
        data([1, 3, 2, 5]),
        100,
        20,
      );
      final line = scene.flattened.whereType<SPolyline>().single;

      expect(line.length, 4);
      expect(line.xy.first, 2);
      expect(line.xy[line.xy.length - 2], 98);
      expect(line.xy[1], 18); // minimum at the bottom
      expect(line.xy[7], 2); // maximum at the top
    });

    test(
      'when laying out right-to-left then the first point is on the right',
      () {
        final scene = SparklineRenderer.layout(
          const SparklineSpec(rtl: true),
          data([1, 3]),
          100,
          20,
        );

        expect(scene.flattened.whereType<SPolyline>().single.xy.first, 98);
      },
    );

    test(
      'when laying out columns then negatives hang below the axis in their color',
      () {
        final scene = SparklineRenderer.layout(
          const SparklineSpec(
            type: SparklineType.column,
            negColor: 0xFFFF0000,
            axis: true,
          ),
          data([2, -1, 3]),
          100,
          20,
        );
        final bars = scene.flattened.whereType<SRect>().toList();

        expect(bars, hasLength(3));
        expect(bars[1].fill, 0xFFFF0000);
        expect(bars[1].rect.top, closeTo(bars[0].rect.bottom, 1e-9));
        expect(scene.flattened.whereType<SPolyline>(), hasLength(1));
      },
    );

    test('when laying out win/loss then every bar has the same height', () {
      final scene = SparklineRenderer.layout(
        const SparklineSpec(type: SparklineType.winloss),
        data([5, -2, 0, 1]),
        100,
        20,
      );
      final bars = scene.flattened.whereType<SRect>().toList();

      expect(bars, hasLength(3));
      expect(bars.map((b) => b.rect.height).toSet(), hasLength(1));
    });

    test('when laying out a bar then two values share the width up to max', () {
      final scene = SparklineRenderer.layout(
        const SparklineSpec(type: SparklineType.bar, max: 10),
        data([3, 2]),
        104,
        20,
      );
      final bars = scene.flattened.whereType<SRect>().toList();

      expect(bars[0].rect.width, closeTo(30, 1e-9));
      expect(bars[1].rect.left, closeTo(bars[0].rect.right, 1e-9));
      expect(bars[1].rect.width, closeTo(20, 1e-9));
    });

    test(
      'when there are more than 10,000 points then they are bucketed per pixel',
      () {
        final scene = SparklineRenderer.layout(
          const SparklineSpec(),
          data([for (var i = 0; i < 20000; i++) (i % 7).toDouble()]),
          100,
          20,
        );

        expect(
          scene.flattened.whereType<SPolyline>().single.length,
          lessThanOrEqualTo(4 * 96),
        );
      },
    );
  });

  group('Given a SPARKLINE formula result', () {
    test('when laying it out then its chart type and options apply', () {
      const value = SparklineValue('column', [1, 2, 3], {'color': 'green'});

      final scene = SparklineRenderer.layoutValue(value, 60, 20);
      final bars = scene.flattened.whereType<SRect>().toList();

      expect(bars, hasLength(3));
      expect(bars.first.fill, 0xFF008000);
    });

    test('when its options are invalid then the scene is empty', () {
      const value = SparklineValue('line', [1, 2], {'negcolor': 'red'});

      expect(SparklineRenderer.layoutValue(value, 60, 20).primitives, isEmpty);
    });
  });
}
