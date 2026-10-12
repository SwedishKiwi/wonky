import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/format/number_format/number_format.dart';

/// Spec vectors of 06 §5.13 (locale en_US unless noted).
final List<(int, String, Object, String, String, int?)> _vectors = [
  (1, '#,##0.00', 1234.567, 'en_US', '1,234.57', null),
  (2, '#,##0.00', -1234.567, 'en_US', '-1,234.57', null),
  (3, '0.00%', 0.12345, 'en_US', '12.35%', null),
  (4, '0%', 1, 'en_US', '100%', null),
  (5, '0.00E+00', 12345, 'en_US', '1.23E+04', null),
  (6, '0.0E+0', 0.000123, 'en_US', '1.2E-4', null),
  (7, '##0.0E+0', 12345, 'en_US', '12.3E+3', null),
  (8, '0.###', 1.5, 'en_US', '1.5', null),
  (9, '0.###', 2, 'en_US', '2.', null),
  (10, '#', 0, 'en_US', '', null),
  (11, '0', 2.5, 'en_US', '3', null),
  (12, '0', -2.5, 'en_US', '-3', null),
  (13, '0.00', 2.675, 'en_US', '2.68', null),
  (14, '#,##0;(#,##0)', -1234, 'en_US', '(1,234)', null),
  (15, '#,##0;[Red](#,##0);"-"', 0, 'en_US', '-', null),
  (16, '#,##0;[Red](#,##0);"-"', -5, 'en_US', '(5)', 0xFFFF0000),
  (17, '0.0,,"M"', 1234567, 'en_US', '1.2M', null),
  (18, '#,##0,"K"', 15300, 'en_US', '15K', null),
  (19, '000-00-0000', 123456789, 'en_US', '123-45-6789', null),
  (20, '# ?/?', 1.25, 'en_US', '1 1/4', null),
  (21, '# ??/??', 3.14159265, 'en_US', '3 14/99', null),
  (22, r'"$"#,##0.00', 3.5, 'en_US', r'$3.50', null),
  (23, r'\$0', 5, 'en_US', r'$5', null),
  (24, '0 "items"', 1, 'en_US', '1 items', null),
  (25, '0;-0;0;"Text: "@', 'abc', 'en_US', 'Text: abc', null),
  (26, '[>1000]#,##0,"K";0', 1500, 'en_US', '2K', null),
  (27, '[>1000]#,##0,"K";0', 500, 'en_US', '500', null),
  (28, 'yyyy-mm-dd', 46307, 'en_US', '2026-10-12', null),
  (29, 'dddd, mmmm d, yyyy', 46307, 'en_US', 'Monday, October 12, 2026', null),
  (30, 'ddd d mmm yy', 46307, 'en_US', 'Mon 12 Oct 26', null),
  (31, 'mmm-yy', 46307, 'en_US', 'Oct-26', null),
  (32, 'mmmmm', 46307, 'en_US', 'O', null),
  (33, 'm/d/yyyy h:mm', 46307.5, 'en_US', '10/12/2026 12:00', null),
  (34, 'h:mm AM/PM', 0.75, 'en_US', '6:00 PM', null),
  (35, 'h AM/PM', 0, 'en_US', '12 AM', null),
  (36, 'h:mm A/P', 0.25, 'en_US', '6:00 A', null),
  (37, 'hh:mm:ss', 0.5, 'en_US', '12:00:00', null),
  (38, '[h]:mm', 1.5, 'en_US', '36:00', null),
  (39, '[mm]:ss', 0.0625, 'en_US', '90:00', null),
  (40, '[h]:mm:ss', -0.5, 'en_US', '-12:00:00', null),
  (41, 'ss.000', 0.5 / 86400, 'en_US', '00.500', null),
  (42, 'dd.mm.yyyy hh:mm:ss', 46307.75, 'en_US', '12.10.2026 18:00:00', null),
  (43, 'dddd', 46307, 'de_DE', 'Montag', null),
  (44, 'yyyy"年"m"月"d"日"', 46307, 'ja_JP', '2026年10月12日', null),
  (45, '#,##0.00', 1234.5, 'de_DE', '1.234,50', null),
  (46, '#,##0.00', 1234.5, 'fr_FR', '1 234,50', null),
  (47, r'[$€-407]#,##0.00', 1234.5, 'en_US', '€1,234.50', null),
  (48, r'#,##0.00 [$€-407]', 1234.5, 'de_DE', '1.234,50 €', null),
  (49, 'preset:currency', 1000.123, 'en_US', r'$1,000.12', null),
  (49, 'preset:currency', 1000.123, 'de_DE', '1.000,12 €', null),
  (50, 'preset:date', 46307, 'en_US', '10/12/2026', null),
  (50, 'preset:date', 46307, 'de_DE', '12.10.2026', null),
  (51, '[Color10]0', 7, 'en_US', '7', 0xFF008000),
  (52, '@', 123, 'en_US', '123', null),
  (53, 'preset:automatic', 1 / 3, 'en_US', '0.3333333333', null),
  (54, 'preset:automatic', math.pi, 'en_US', '3.141592654', null),
  (55, 'preset:automatic', 123456789012, 'en_US', '123456789012', null),
  (56, 'preset:automatic', 1e15, 'en_US', '1E+15', null),
  (57, 'preset:automatic', 0.1 + 0.2, 'en_US', '0.3', null),
  (58, '0.00', true, 'en_US', 'TRUE', null),
  (59, '0.00', CellErrorKind.div0, 'en_US', '#DIV/0!', null),
  (60, '0;-0;;@', 0, 'en_US', '', null),
];

void main() {
  group('Given the 06 §5.13 test vectors', () {
    final formatter = NumberFormatter();
    for (final (n, pattern, value, locale, expected, color) in _vectors) {
      test('when formatting vector $n ($pattern, $value, $locale) then it shows "$expected"', () {
        final result = formatter.format(CellValue.from(value), pattern, locale: locale);

        expect(result.plainText, equals(expected));
        expect(result.colorArgb, equals(color));
      });
    }
  });

  group('Given the parser error vectors', () {
    final cases = <(String, int)>[
      ('0.00"', 4),
      ('[Colr3]0', 0),
      ('0;0;0;0;0', 7),
      ('[>1000', 0),
      ('[Color57]0', 0),
      (r'0\', 1),
      ('0*', 1),
      ('0_', 1),
    ];
    for (final (pattern, position) in cases) {
      test('when parsing "$pattern" then it fails at position $position', () {
        expect(
          () => NumberFormatParser.parse(pattern),
          throwsA(isA<FormatParseError>().having((e) => e.position, 'position', position)),
        );
      });
    }

    test('when formatting with an invalid pattern then Automatic rules apply', () {
      expect(NumberFormatter().formatText(const NumberValue(1.5), '0.00"'), equals('1.5'));
    });
  });
}
