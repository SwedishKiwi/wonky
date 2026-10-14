import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

void main() {
  group('Given XLSX number format ids', () {
    const vectors = [
      (0, null),
      (1, '0'),
      (4, '#,##0.00'),
      (10, '0.00%'),
      (14, 'preset:date'),
      (22, 'preset:dateTime'),
      (49, '@'),
      (164, 'yyyy-mm-dd'),
      (200, null),
    ];
    for (final (id, pattern) in vectors) {
      test('when importing id $id then the pattern is $pattern', () {
        expect(
          ExcelNumberFormats.importId(id, const {164: 'yyyy-mm-dd'}),
          pattern,
        );
      });
    }

    test(
      'when an id is an East Asian locale format then it is approximated',
      () {
        final warnings = <String>[];
        expect(
          ExcelNumberFormats.importId(30, const {}, warn: warnings.add),
          'yyyy-mm-dd',
        );
        expect(warnings, hasLength(1));
      },
    );
  });

  group('Given XLSX format codes', () {
    const vectors = [
      ('General', null),
      (r'[$-409]dd/mm/yyyy', 'dd/mm/yyyy'),
      (r'[$-F800]dddd, mmmm dd, yyyy', 'dddd, mmmm dd, yyyy'),
      (r'#,##0.00 [$€-407]', r'#,##0.00 [$€-407]'),
      ('[Red]#,##0;(#,##0)', '[Red]#,##0;(#,##0)'),
      ('[<0]"neg";0', '[<0]"neg";0'),
      (r'"[$-409]"0', r'"[$-409]"0'),
      ('# ?/?', '# ?/?'),
    ];
    for (final (code, pattern) in vectors) {
      test('when importing "$code" then the pattern is $pattern', () {
        expect(ExcelNumberFormats.importPattern(code), pattern);
      });
    }

    test('when a code has a numeral system tag then it is removed with a '
        'warning', () {
      final warnings = <String>[];
      expect(
        ExcelNumberFormats.importPattern('[DBNum1]0', warn: warnings.add),
        '0',
      );
      expect(warnings.single, contains('DBNum1'));
    });
  });

  group('Given Wonky number formats', () {
    const vectors = [
      (null, 0, 'General'),
      ('preset:automatic', 0, 'General'),
      ('preset:date', 14, 'm/d/yyyy'),
      ('0.00%', 10, '0.00%'),
      ('#,##0', 3, '#,##0'),
      ('yyyy-mm-dd', null, 'yyyy-mm-dd'),
      ('preset:currency', null, r'"$"#,##0.00'),
    ];
    for (final (pattern, id, code) in vectors) {
      test('when exporting $pattern then the id is $id and the code $code', () {
        final e = ExcelNumberFormats.export(pattern);
        expect((e.id, e.code), (id, code));
      });
    }

    test('when exporting a preset for another locale then it is localized', () {
      expect(
        ExcelNumberFormats.export('preset:time', locale: 'de_DE').code,
        'hh:mm:ss',
      );
    });
  });

  group('Given patterns', () {
    const dates = [
      ('yyyy-mm-dd', true, false),
      ('m/d/yyyy h:mm', true, true),
      ('mmm-yy', true, false),
      ('h:mm AM/PM', false, true),
      ('mm:ss', false, true),
      ('[h]:mm:ss', false, true),
      ('#,##0.00', false, false),
      ('0.00E+00', false, false),
      ('"day" 0', false, false),
      ('[Red]0', false, false),
      ('preset:date', true, false),
      ('preset:dateTime', true, true),
    ];
    for (final (p, date, time) in dates) {
      test('when classifying "$p" then date is $date and time is $time', () {
        expect(ExcelNumberFormats.isDatePattern(p), date);
        expect(ExcelNumberFormats.isTimePattern(p), time);
      });
    }
  });
}
