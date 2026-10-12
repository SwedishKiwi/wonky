import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/format/number_format/number_format.dart';

void main() {
  group('Given increase/decrease decimals on patterns', () {
    final cases = <(String?, int, CellValue?, String)>[
      ('#,##0.00', 1, null, '#,##0.000'),
      ('#,##0.00', -1, null, '#,##0.0'),
      ('#,##0.0', -1, null, '#,##0'),
      ('#,##0', -1, null, '#,##0'),
      ('0', 1, null, '0.0'),
      ('0%', 1, null, '0.0%'),
      ('0.00%', -1, null, '0.0%'),
      ('0.00E+00', 1, null, '0.000E+00'),
      ('0E+00', 1, null, '0.0E+00'),
      (r'"$"#,##0', 1, null, r'"$"#,##0.0'),
      ('#,##0;(#,##0)', 1, null, '#,##0.0;(#,##0.0)'),
      ('#,##0.00;[Red](#,##0.00);"-"', -1, null, '#,##0.0;[Red](#,##0.0);"-"'),
      ('#,##0,"K"', 1, null, '#,##0.0,"K"'),
      ('0;-0;;@', 1, null, '0.0;-0.0;;@'),
      ('# ?/?', 1, null, '# ?/?'),
      ('h:mm:ss', 1, null, 'h:mm:ss.0'),
      ('h:mm:ss.0', 1, null, 'h:mm:ss.00'),
      ('h:mm:ss.000', 1, null, 'h:mm:ss.000'),
      ('h:mm:ss.0', -1, null, 'h:mm:ss'),
      ('h:mm:ss.00', -1, null, 'h:mm:ss.0'),
      ('[h]:mm:ss', 1, null, '[h]:mm:ss.0'),
      ('h:mm', 1, null, 'h:mm'),
      ('@', 1, null, '@'),
      ('preset:currency', 1, null, r'"$"#,##0.000'),
      ('preset:automatic', 1, const NumberValue(1.25), '#,##0.000'),
      (null, -1, const NumberValue(1.25), '#,##0.0'),
      (null, -1, const NumberValue(3), '#,##0'),
      (null, 1, const NumberValue(3), '#,##0.0'),
      (null, 1, null, '#,##0.0'),
      (null, 1, const NumberValue(1.5e20), '0.00E+00'),
      ('[Colr]0', 1, null, '[Colr]0'),
      ('0.${'0' * 30}', 1, null, '0.${'0' * 30}'),
    ];
    for (final (pattern, delta, active, expected) in cases) {
      test('when adjusting "$pattern" by $delta then it becomes "$expected"', () {
        expect(DecimalsAdjuster.adjust(pattern, delta, activeValue: active), equals(expected));
      });
    }

    test('when presets are adjusted in de_DE then the locale pattern is the base', () {
      expect(
        DecimalsAdjuster.adjust('preset:currency', -1, locale: 'de_DE'),
        equals(r'#,##0.0 [$€-407]'),
      );
    });

    test('when adjusting by two steps then two decimals are added', () {
      expect(DecimalsAdjuster.adjust('0', 2), equals('0.00'));
    });
  });
}
