import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/format/number_format/number_format.dart';
import 'package:wonky_sheets_core/src/formula/values/format_hint.dart';

/// (pattern, value, expected plain text).
final List<(String, Object, String)> _cases = [
  // Digit placeholders and padding.
  ('0.0?', 1.5, '1.5 '),
  ('??0.00', 1.5, '  1.50'),
  ('#.##', 0.5, '.5'),
  ('00.0', 1.5, '01.5'),
  ('.00', 12.5, '12.50'),
  ('#', 0.4, ''),
  ('0.###', 0.0004, '0.'),
  ('#,##0', 1e20, '100,000,000,000,000,000,000'),
  ('0.0', 1e-20, '0.0'),
  ('0.00', 1.005, '1.01'),
  ('0.00', -0.001, '-0.00'),
  ('0 "x" 0', 1234, '123 x 4'),
  // Scaling and percent.
  ('0.0,', 1234, '1.2'),
  ('#,', 1500, '2'),
  ('0‰', 0.0123, '12‰'),
  ('0%%', 0.5, '5000%%'),
  // Sections and conditions.
  ('[<0]"neg "0;"pos "0', -5, '-neg 5'),
  ('[>100]"big";[<-100]"small";0', -5, '-5'),
  ('[>100]"big";[<-100]"small";0', 500, 'big'),
  ('[>=10]"ten+";0', 10, 'ten+'),
  ('[=0]"zero";0', 0, 'zero'),
  ('[<>1]"not one";0', 2, 'not one'),
  ('0;"neg"', -3, 'neg'),
  ('"x"', -3, '-x'),
  ('0.00;;', -2, ''),
  ('0;-0;;@', 'hi', 'hi'),
  ('"lit"', 'txt', 'txt'),
  ('0;0;0;', 'text', ''),
  ('0;0;0;"fixed"', 'text', 'fixed'),
  ('@" kg"', 'flour', 'flour kg'),
  ('General', -1.5, '-1.5'),
  ('General" units"', 12, '12 units'),
  ('general;-general', -2, '-2'),
  // Scientific.
  ('0.00E+00', 0, '0.00E+00'),
  ('0.00E+00', 9.999e9, '1.00E+10'),
  ('0.00E-00', 12345, '1.23E04'),
  ('##0.0E+0', 0.00012, '120.0E-6'),
  ('0.00e+00', 1234, '1.23e+03'),
  ('0.00E+00', -0.5, '-5.00E-01'),
  // Fractions.
  ('# ?/16', 1.3, '1 5/16'),
  ('?/?', 1.75, '7/4'),
  ('# ?/?', 2, '2    '),
  ('# ?/?', 0, '0    '),
  ('# ?/?', 0.999, '1    '),
  ('# ?/?', -1.25, '-1 1/4'),
  ('# ???/???', 0.333, ' 332/997'),
  ('# ?/8', 0.5, ' 4/8'),
  // Dates and times.
  ('hh:mm:ss', 59.6 / 86400, '00:01:00'),
  ('h:mm', 0.99999, '23:59'),
  ('yyyy-mm-dd', 3000000, '3000000'),
  ('yyyy-mm-dd', -1, '1899-12-29'),
  ('yyyy-mm-dd', 1, '1899-12-31'),
  ('yyyy-mm-dd', 61, '1900-03-01'),
  ('dd/mm/yyyy', -693593, '01/01/0001'),
  ('yyyy-mm-dd', 2958465, '9999-12-31'),
  ('[h]:mm:ss.00', 1.000005787, '24:00:00.50'),
  ('[s]', 0.01, '864'),
  ('mm:ss', 0.0625, '30:00'),
  ('m', 46307, '10'),
  ('d-mmm', 46307, '12-Oct'),
  ('yy', 46307, '26'),
  ('y', 46307, '26'),
  ('yyy', 46307, '2026'),
  ('DD.MM.YYYY', 46307, '12.10.2026'),
  ('mmmmmm', 46307, 'O'),
  ('AM/PM h', 0.6, 'PM 2'),
  ('am/pm', 0.6, 'pm'),
  ('h:mm a/p', 0.6, '2:24 p'),
  ('hh "h" mm', 0.5, '12 h 00'),
  ('ss.0', 0.5 / 86400, '00.5'),
  // Literals and locale tags.
  (r'[$USD] 0.00', 5, 'USD 5.00'),
  (r'[$-409]0', 5, '5'),
  (r'\-0', -2, '--2'),
  // Booleans, errors.
  ('[Red]0', true, 'TRUE'),
  ('@', false, 'FALSE'),
];

void main() {
  final formatter = NumberFormatter();

  group('Given edge-case patterns in en_US', () {
    for (final (pattern, value, expected) in _cases) {
      test(
        'when formatting $value with "$pattern" then it shows "$expected"',
        () {
          expect(
            formatter.formatText(CellValue.from(value), pattern),
            equals(expected),
          );
        },
      );
    }
  });

  group('Given segment output', () {
    test('when a pattern has a spacer then a spacer segment is produced', () {
      final r = formatter.format(const NumberValue(5), '#,##0.00_);(#,##0.00)');
      expect(
        r.segments,
        equals([const TextSegment('5.00'), const SpacerSegment(')')]),
      );
    });

    test('when a pattern has a repeat then one repeat segment is produced', () {
      final r = formatter.format(const NumberValue(5), '0*-*=');
      expect(
        r.segments,
        equals([const TextSegment('5'), const RepeatSegment('-')]),
      );
    });

    test(
      'when the accounting preset formats a negative then spacer and repeat are kept',
      () {
        final r = formatter.format(
          const NumberValue(-1000.12),
          'preset:accounting',
        );
        expect(
          r.segments,
          equals([
            const SpacerSegment('('),
            const TextSegment(r'$'),
            const RepeatSegment(' '),
            const TextSegment('(1,000.12)'),
          ]),
        );
      },
    );

    test('when a ? pads a digit then a digit-wide spacer is produced', () {
      final r = formatter.format(const NumberValue(1.5), '?0.0');
      expect(r.segments.first, equals(const SpacerSegment('0')));
    });
  });

  group('Given value kinds', () {
    test('when formatting a number then overflow hashes are requested', () {
      expect(
        formatter.format(const NumberValue(1), '0.00').overflowHashes,
        isTrue,
      );
    });

    test('when formatting text then no overflow hashes are requested', () {
      expect(
        formatter.format(const TextValue('a'), '@').overflowHashes,
        isFalse,
      );
    });

    test('when formatting an empty value then nothing is shown', () {
      expect(formatter.format(CellValue.empty, '0.00').segments, isEmpty);
    });

    test(
      'when formatting with two colored sections then the section color applies',
      () {
        final r = formatter.format(const NumberValue(-3), '[Blue]0;[Red]-0');
        expect((r.plainText, r.colorArgb), equals(('-3', 0xFFFF0000)));
      },
    );

    test('when color names are upper case then they are recognized', () {
      expect(
        formatter.format(const NumberValue(3), '[BLUE]0').colorArgb,
        equals(0xFF0000FF),
      );
    });

    test('when a text section has a color then text values get it', () {
      final r = formatter.format(const TextValue('x'), '0;0;0;[Magenta]@');
      expect(r.colorArgb, equals(0xFFFF00FF));
    });

    test('when NaN is formatted then #NUM! is shown', () {
      expect(
        formatter.formatText(const NumberValue(double.nan), '0'),
        equals('#NUM!'),
      );
    });

    test('when negative zero is formatted then it shows as zero', () {
      expect(
        formatter.formatText(const NumberValue(-0.0), '0.0'),
        equals('0.0'),
      );
    });
  });

  group('Given format hints', () {
    test(
      'when an Automatic cell has a date hint then the date preset is used',
      () {
        final hint = NumberFormatter.hintFor(FormatHint.date, 'en_US');
        final r = formatter.formatWithHint(
          const NumberValue(46307),
          null,
          hintPattern: hint,
        );
        expect(r.plainText, equals('10/12/2026'));
      },
    );

    test('when the cell has an explicit format then the hint is ignored', () {
      final r = formatter.formatWithHint(
        const NumberValue(46307),
        '0',
        hintPattern: 'preset:date',
      );
      expect(r.plainText, equals('46307'));
    });

    final hints = <(FormatHint, String?)>[
      (FormatHint.none, null),
      (FormatHint.time, 'preset:time'),
      (FormatHint.dateTime, 'preset:dateTime'),
      (FormatHint.duration, '[h]:mm:ss'),
      (FormatHint.percent, '0.00%'),
      (FormatHint.scientific, '0.00E+00'),
      (FormatHint.currencyDefault, 'preset:currency'),
      (FormatHint.currency('EUR'), r'[$€-409]#,##0.00'),
      (FormatHint.fromCell('0.0'), '0.0'),
      (FormatHint.fromCell('preset:automatic'), null),
    ];
    for (final (hint, expected) in hints) {
      test('when mapping $hint then the pattern is $expected', () {
        expect(NumberFormatter.hintFor(hint, 'en_US'), equals(expected));
      });
    }
  });

  group('Given the cache', () {
    test(
      'when formatting the same value twice then the cached result is returned',
      () {
        final f = NumberFormatter(cache: NumberFormatCache(valueCapacity: 2));
        final a = f.format(const NumberValue(1), '0.00');
        final b = f.format(const NumberValue(1), '0.00');
        expect(identical(a, b), isTrue);
      },
    );

    test(
      'when the value cache is full then the least recently used entry is evicted',
      () {
        final cache = NumberFormatCache(valueCapacity: 2);
        final f = NumberFormatter(cache: cache);
        f.format(const NumberValue(1), '0');
        f.format(const NumberValue(2), '0');
        f.format(const NumberValue(1), '0');
        f.format(const NumberValue(3), '0');
        expect(cache.lookup('0', 'en_US', 2.0), isNull);
        expect(cache.lookup('0', 'en_US', 1.0), isNotNull);
      },
    );

    test('when an invalid pattern is cached then its error is available', () {
      final cache = NumberFormatCache();
      expect(cache.ast('[Colr3]0'), isNull);
      expect(cache.error('[Colr3]0')?.position, equals(0));
    });

    test('when the AST cache is full then old patterns are evicted', () {
      final cache = NumberFormatCache(astCapacity: 3);
      for (var i = 0; i < 5; i++) {
        cache.ast('0.${'0' * i}');
      }
      expect(cache.astCount, equals(3));
    });
  });
}
