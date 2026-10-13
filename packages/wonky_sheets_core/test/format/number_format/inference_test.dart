import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/format/number_format/number_format.dart';

void main() {
  final today = DateTime(2026, 10, 12);

  group('Given the 06 §5.9 detection table', () {
    final cases = <(String, String, String?)>[
      ('12%', 'en_US', '0%'),
      ('12.50%', 'en_US', '0.00%'),
      (r'$1,200', 'en_US', r'"$"#,##0'),
      (r'$1,200.5', 'en_US', r'"$"#,##0.00'),
      ('€1,200', 'en_US', r'[$€]#,##0'),
      ('1,234', 'en_US', '#,##0'),
      ('1,234.5', 'en_US', '#,##0.0'),
      ('1234.5', 'en_US', null),
      ('1.5E3', 'en_US', '0.00E+00'),
      ('10/12/2026', 'en_US', 'preset:date'),
      ('2026-10-12', 'en_US', 'yyyy-mm-dd'),
      ('2:30 PM', 'en_US', 'h:mm AM/PM'),
      ('2:30:15 PM', 'en_US', 'h:mm:ss AM/PM'),
      ('10/12/2026 14:30', 'en_US', 'preset:dateTime'),
      ('36:15:00', 'en_US', '[h]:mm:ss'),
      ('12,5 %', 'de_DE', '0.0%'),
      ('hello', 'en_US', null),
    ];
    for (final (input, locale, format) in cases) {
      test('when inferring "$input" in $locale then the format is $format', () {
        expect(
          FormatInference.infer(input, locale: locale, today: today),
          equals(format),
        );
      });
    }
  });

  group('Given the pattern builders', () {
    test(
      'when building a currency with one typed decimal then two decimals are used',
      () {
        expect(
          FormatInference.currency('€', 1, before: false, spaced: true),
          r'#,##0.00 [$€]',
        );
      },
    );

    test('when checking applicability then only Automatic targets apply', () {
      expect([
        FormatInference.appliesTo(null),
        FormatInference.appliesTo('preset:automatic'),
        FormatInference.appliesTo('0.00'),
      ], equals([true, true, false]));
    });
  });
}
