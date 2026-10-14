import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';
import 'package:wonky_sheets_core/src/format/attributes.dart';
import 'package:wonky_sheets_core/src/format/borders.dart';

void main() {
  group('Given stored edge values', () {
    final cases = <(String?, BorderSpec?)>[
      ('thin|#FF0000', const BorderSpec(BorderStyle.thin, '#FF0000')),
      ('dashed', const BorderSpec(BorderStyle.dashed)),
      ('none', BorderSpec.none),
      ('wavy|#000000', null),
      (null, null),
    ];
    for (final (s, spec) in cases) {
      test('when parsing "$s" then it is $spec', () {
        expect(BorderSpec.tryParse(s), spec);
      });
    }
  });

  group('Given a shared edge', () {
    const thin = BorderSpec(BorderStyle.thin, '#000000');
    const thick = BorderSpec(BorderStyle.thick, '#FF0000');
    const otherThin = BorderSpec(BorderStyle.thin, '#00FF00');

    test('when one side is heavier then it wins', () {
      expect(BorderSpec.resolveShared(thin, thick), thick);
      expect(BorderSpec.resolveShared(thick, thin), thick);
    });

    test('when both weigh the same then the upper/left edge wins', () {
      expect(BorderSpec.resolveShared(thin, otherThin), thin);
    });

    test('when one side is none then the visible edge wins', () {
      expect(BorderSpec.resolveShared(BorderSpec.none, thin), thin);
      expect(BorderSpec.resolveShared(null, BorderSpec.none), isNull);
    });
  });

  group('Given the border presets on B2:C3 of a 5×5 sheet', () {
    const rect = GridRect(1, 1, 2, 2);
    const spec = BorderSpec(BorderStyle.medium, '#000000');
    Map<(int, int, FormatAttr), String?> plan(BorderPreset p) => {
      for (final w in BorderPresetPlanner.plan(
        p,
        rect,
        spec,
        rowCount: 5,
        colCount: 5,
      ))
        (w.row, w.col, w.attr): w.value,
    };

    test('when applying outer then the four sides are set and facing edges '
        'outside are cleared', () {
      final w = plan(BorderPreset.outer);

      expect(w[(1, 1, FormatAttr.borderTop)], 'medium|#000000');
      expect(w[(2, 2, FormatAttr.borderBottom)], 'medium|#000000');
      expect(w[(1, 1, FormatAttr.borderLeft)], 'medium|#000000');
      expect(w[(2, 2, FormatAttr.borderRight)], 'medium|#000000');
      expect(w.containsKey((0, 1, FormatAttr.borderBottom)), isTrue);
      expect(w[(0, 1, FormatAttr.borderBottom)], isNull);
      expect(w.containsKey((1, 1, FormatAttr.borderBottom)), isFalse);
    });

    test(
      'when applying inner then lines are stored on the upper/left cells',
      () {
        final w = plan(BorderPreset.inner);

        expect(w[(1, 1, FormatAttr.borderBottom)], 'medium|#000000');
        expect(w[(1, 1, FormatAttr.borderRight)], 'medium|#000000');
        expect(w[(2, 1, FormatAttr.borderTop)], isNull);
        expect(w.containsKey((1, 1, FormatAttr.borderTop)), isFalse);
      },
    );

    test('when clearing then every edge of the range and the facing edges '
        'are removed', () {
      final w = plan(BorderPreset.clear);

      expect(w.values.every((v) => v == null), isTrue);
      expect(w.containsKey((3, 2, FormatAttr.borderTop)), isTrue);
      expect(w.containsKey((1, 3, FormatAttr.borderLeft)), isTrue);
      expect(w.length, 4 * 4 + 8);
    });

    test('when the range touches the sheet edge then outside cells are '
        'skipped', () {
      final w = BorderPresetPlanner.plan(
        BorderPreset.top,
        const GridRect(0, 0, 0, 0),
        spec,
        rowCount: 5,
        colCount: 5,
      );

      expect(w.single.attr, FormatAttr.borderTop);
    });
  });
}
