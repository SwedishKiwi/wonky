import 'package:test/test.dart';
import 'package:wonky_numfmt/wonky_numfmt.dart';

void main() {
  group('Given the pattern formatter', () {
    final f = NumberPatternFormatter();

    for (final (x, pattern, locale, expected) in [
      (1234.5, '#,##0.00', 'en_US', '1,234.50'),
      (1234.5, '#,##0.00', 'de_DE', '1.234,50'),
      (0.256, '0%', 'en_US', '26%'),
      (1234.0, r'[$€]#,##0', 'en_US', '€1,234'),
      (45000.0, 'yyyy-mm-dd', 'en_US', '2023-03-15'),
      (1234.5, null, 'en_US', '1234.5'),
      (1234.5, 'preset:automatic', 'en_US', '1234.5'),
      (double.infinity, '0.00', 'en_US', '#NUM!'),
    ]) {
      test(
        'when formatting $x with $pattern in $locale then it is $expected',
        () {
          expect(f.formatNumberText(x, pattern, locale: locale), expected);
        },
      );
    }

    test('when formatting text then the text section applies', () {
      expect(f.formatString('abc', '0;0;0;"<"@">"').plainText, '<abc>');
      expect(f.formatString('abc', '0.00').plainText, 'abc');
      expect(f.formatString('abc', null).plainText, 'abc');
    });

    test('when formatting the same value twice then the cache answers', () {
      final c = NumberPatternFormatter();
      final first = c.formatNumber(1.5, '0.00');
      final before = c.cache.valueCount;
      expect(first.plainText, '1.50');
      expect(c.formatNumber(1.5, '0.00'), same(first));
      expect(c.cache.valueCount, before);
    });

    test('when a pattern is invalid then Automatic is used', () {
      expect(f.formatNumberText(1.5, '0.00"'), '1.5');
    });

    test('when a preset depends on the locale then it is resolved for it', () {
      expect(
        f.formatNumberText(1000.12, NumberFormatPresets.currency),
        r'$1,000.12',
      );
      expect(
        f.formatNumberText(
          1000.12,
          NumberFormatPresets.currency,
          locale: 'de_DE',
        ),
        '1.000,12 €',
      );
    });
  });

  group('Given serial dates', () {
    test('when converting civil dates then they round-trip', () {
      final s = DateSerial.fromYmd(2024, 2, 29);
      expect(DateSerial.toYmd(s.toDouble()), (year: 2024, month: 2, day: 29));
      expect(DateSerial.fromYmd(1899, 12, 30), 0);
      expect(SerialCalendar.serialOf(2024, 2, 29), s);
    });
  });
}
