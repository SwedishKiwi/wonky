import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/format/number_format/serial_calendar.dart';
import 'package:wonky_sheets_core/src/input/input.dart';

final DateTime _today = DateTime(2026, 10, 12);
const double _oct12 = 46307;
const String _date = 'preset:date';
const String _dateTime = 'preset:dateTime';

double _time(int h, int m, [num s = 0]) => (h * 3600 + m * 60 + s) / 86400;
double _serial(int y, int m, int d) => SerialCalendar.serialOf(y, m, d).toDouble();

/// (input, expected content, expected auto format).
typedef _Case = (String, CellContent, String?);

final Map<String, List<_Case>> _tables = {
  'en_US': [
    ('1234', const NumberContent(1234), null),
    ('-12.5', const NumberContent(-12.5), null),
    ('1,234.5', const NumberContent(1234.5), '#,##0.0'),
    ('1,234', const NumberContent(1234), '#,##0'),
    ('1,234,567', const NumberContent(1234567), '#,##0'),
    ('.5', const NumberContent(0.5), null),
    ('+7', const NumberContent(7), null),
    ('1.5E3', const NumberContent(1500), '0.00E+00'),
    ('1e-3', const NumberContent(0.001), '0.00E+00'),
    ('12%', const NumberContent(0.12), '0%'),
    ('12.5 %', const NumberContent(0.125), '0.0%'),
    ('12.50%', const NumberContent(0.125), '0.00%'),
    ('0.07%', const NumberContent(0.0007), '0.00%'),
    (r'$12', const NumberContent(12), r'"$"#,##0'),
    (r'-$1,200.50', const NumberContent(-1200.5), r'"$"#,##0.00'),
    (r'$-5', const NumberContent(-5), r'"$"#,##0'),
    (r'($5)', const NumberContent(-5), r'"$"#,##0'),
    (r'$1,200.5', const NumberContent(1200.5), r'"$"#,##0.00'),
    (r'$1.234', const NumberContent(1.234), r'"$"#,##0.000'),
    ('€12', const NumberContent(12), r'[$€]#,##0'),
    ('£ 3.5', const NumberContent(3.5), r'[$£] #,##0.00'),
    ('12 ¥', const NumberContent(12), r'#,##0 [$¥]'),
    ('(123)', const NumberContent(-123), null),
    ('10/12/2026', const NumberContent(_oct12), _date),
    ('10-12-2026', const NumberContent(_oct12), _date),
    ('Oct 12 2026', const NumberContent(_oct12), _date),
    ('Oct 12, 2026', const NumberContent(_oct12), _date),
    ('12-Oct-2026', const NumberContent(_oct12), _date),
    ('October 12, 2026', const NumberContent(_oct12), _date),
    ('Mon, Oct 12, 2026', const NumberContent(_oct12), _date),
    ('12 Oct 26', const NumberContent(_oct12), _date),
    ('Sept 1 2026', NumberContent(_serial(2026, 9, 1)), _date),
    ('Oct 2026', NumberContent(_serial(2026, 10, 1)), _date),
    ('10/2026', NumberContent(_serial(2026, 10, 1)), _date),
    ('2026-10-12', const NumberContent(_oct12), 'yyyy-mm-dd'),
    ('2026/10/12', const NumberContent(_oct12), _date),
    ('14:30', NumberContent(_time(14, 30)), 'h:mm'),
    ('2:30 PM', NumberContent(_time(14, 30)), 'h:mm AM/PM'),
    ('2:30pm', NumberContent(_time(14, 30)), 'h:mm AM/PM'),
    ('12:00 AM', const NumberContent(0), 'h:mm AM/PM'),
    ('3 PM', NumberContent(_time(15, 0)), 'h:mm AM/PM'),
    ('14:30:15', NumberContent(_time(14, 30, 15)), 'h:mm:ss'),
    ('14:30:15.5', NumberContent(_time(14, 30, 15.5)), 'h:mm:ss.000'),
    ('10/12/2026 14:30', NumberContent(_oct12 + _time(14, 30)), _dateTime),
    ('Oct 12, 2026 2:30 PM', NumberContent(_oct12 + _time(14, 30)), _dateTime),
    ('2026-10-12 14:30', NumberContent(_oct12 + _time(14, 30)), 'yyyy-mm-dd hh:mm'),
    ('2026-10-12T14:30:05', NumberContent(_oct12 + _time(14, 30, 5)), 'yyyy-mm-dd hh:mm:ss'),
    ('36:15:00', NumberContent(_time(36, 15)), '[h]:mm:ss'),
    ('36:15', NumberContent(_time(36, 15)), '[h]:mm'),
    ('TRUE', const BoolContent(true), null),
    ('false', const BoolContent(false), null),
    ('#N/A', const ErrorContent(CellErrorKind.na), null),
    ('#div/0!', const ErrorContent(CellErrorKind.div0), null),
    ('1/2', NumberContent(_serial(2026, 1, 2)), _date),
    (' 42 ', const NumberContent(42), null),
    ('00123', const NumberContent(123), null),
    ('1/2/30', NumberContent(_serial(1930, 1, 2)), _date),
    ('1/2/29', NumberContent(_serial(2029, 1, 2)), _date),
    ('2/29/2028', NumberContent(_serial(2028, 2, 29)), _date),
    ('13/1/2026', const TextContent('13/1/2026'), null),
    ('2/30/2026', const TextContent('2/30/2026'), null),
    ('1,23', const TextContent('1,23'), null),
    ('12,34.5', const TextContent('12,34.5'), null),
    ('1 234', const TextContent('1 234'), null),
    ('abc', const TextContent('abc'), null),
    ('May', const TextContent('May'), null),
    ('Q1-2026', const TextContent('Q1-2026'), null),
    ('#LOADING', const TextContent('#LOADING'), null),
    ('   ', const TextContent('   '), null),
    ('25:99', const TextContent('25:99'), null),
    ('13:00 PM', const TextContent('13:00 PM'), null),
  ],
  'de_DE': [
    ('1234', const NumberContent(1234), null),
    ('-12,5', const NumberContent(-12.5), null),
    ('1.234,5', const NumberContent(1234.5), '#,##0.0'),
    ('1.234', const NumberContent(1234), '#,##0'),
    ('1,5E3', const NumberContent(1500), '0.00E+00'),
    ('12 %', const NumberContent(0.12), '0%'),
    ('12 €', const NumberContent(12), r'#,##0 [$€]'),
    ('-1.200,50 €', const NumberContent(-1200.5), r'#,##0.00 [$€]'),
    ('12€', const NumberContent(12), r'#,##0[$€]'),
    ('(123)', const NumberContent(-123), null),
    ('12.10.2026', const NumberContent(_oct12), _date),
    ('12.10.26', const NumberContent(_oct12), _date),
    ('12. Okt. 2026', const NumberContent(_oct12), _date),
    ('12. Oktober 2026', const NumberContent(_oct12), _date),
    ('Montag, 12. Oktober 2026', const NumberContent(_oct12), _date),
    ('12. März 2026', NumberContent(_serial(2026, 3, 12)), _date),
    ('2026-10-12', const NumberContent(_oct12), 'yyyy-mm-dd'),
    ('14:30', NumberContent(_time(14, 30)), 'h:mm'),
    ('12.10.2026 14:30', NumberContent(_oct12 + _time(14, 30)), _dateTime),
    ('36:15:00', NumberContent(_time(36, 15)), '[h]:mm:ss'),
    ('WAHR', const BoolContent(true), null),
    ('falsch', const BoolContent(false), null),
    ('TRUE', const BoolContent(true), null),
    ('1/2', NumberContent(_serial(2026, 2, 1)), _date),
    ('1.5', NumberContent(_serial(2026, 5, 1)), _date),
    ('12.10.', const NumberContent(_oct12), _date),
    ('1.5.2026', NumberContent(_serial(2026, 5, 1)), _date),
    ('1,234.5', const TextContent('1,234.5'), null),
  ],
  'en_GB': [
    ('10/12/2026', NumberContent(_serial(2026, 12, 10)), _date),
    ('12/10/2026', const NumberContent(_oct12), _date),
    ('1/2', NumberContent(_serial(2026, 2, 1)), _date),
    ('£1,200.50', const NumberContent(1200.5), r'[$£]#,##0.00'),
    ('12 October 2026', const NumberContent(_oct12), _date),
  ],
  'fr_FR': [
    ('1 234,5', const NumberContent(1234.5), '#,##0.0'),
    ('1 234,5', const NumberContent(1234.5), '#,##0.0'),
    ('1 234', const NumberContent(1234), '#,##0'),
    ('12/10/2026', const NumberContent(_oct12), _date),
    ('12 oct. 2026', const NumberContent(_oct12), _date),
    ('12 octobre 2026', const NumberContent(_oct12), _date),
    ('12,5 %', const NumberContent(0.125), '0.0%'),
    ('12,50 €', const NumberContent(12.5), r'#,##0.00 [$€]'),
  ],
  'ja_JP': [
    ('2026/10/12', const NumberContent(_oct12), _date),
    ('26/10/12', const NumberContent(_oct12), _date),
    ('1,234.5', const NumberContent(1234.5), '#,##0.0'),
    ('¥1,200', const NumberContent(1200), r'[$¥]#,##0'),
  ],
  'en_IN': [
    ('12,34,567', const NumberContent(1234567), '#,##0'),
    ('1,234,567', const NumberContent(1234567), '#,##0'),
    ('₹1,200', const NumberContent(1200), r'[$₹]#,##0'),
  ],
  'de_CH': [
    ("1'234.5", const NumberContent(1234.5), '#,##0.0'),
    ('12.10.2026', const NumberContent(_oct12), _date),
  ],
};

void main() {
  final parser = InputParser();

  for (final MapEntry(key: locale, value: cases) in _tables.entries) {
    group('Given the $locale locale and an Automatic target cell', () {
      for (final (input, content, format) in cases) {
        test('when typing "$input" then it stores $content with format $format', () {
          final result = parser.parse(input, locale: locale, today: _today);

          expect(result.content, equals(content));
          expect(result.autoNumberFormat, equals(format));
          expect(result.formulaA1, isNull);
        });
      }
    });
  }

  group('Given special targets and prefixes', () {
    test('when typing into a plain-text (@) cell then everything is text', () {
      final r = parser.parse('12%', targetNumberFormat: '@', today: _today);
      expect(r.content, equals(const TextContent('12%')));
      expect(r.autoNumberFormat, isNull);
    });

    test('when typing 5% into a 0.00 cell then the value is 0.05 and no format is detected', () {
      final r = parser.parse('5%', targetNumberFormat: '0.00', today: _today);
      expect(r.content, equals(const NumberContent(0.05)));
      expect(r.autoNumberFormat, isNull);
    });

    test('when the target is preset:automatic then detection applies', () {
      final r = parser.parse('5%', targetNumberFormat: 'preset:automatic', today: _today);
      expect(r.autoNumberFormat, equals('0%'));
    });

    test('when typing a leading apostrophe then the rest is text', () {
      expect(parser.parse("'123").content, equals(const TextContent('123')));
    });

    test('when typing an empty string then the value is cleared', () {
      expect(parser.parse('').isClear, isTrue);
    });

    test('when typing a formula then it is returned as typed with closed parentheses', () {
      final r = parser.parse('=SUM(A1,MAX(1,2');
      expect(r.formulaA1, equals('=SUM(A1,MAX(1,2))'));
      expect(r.content, isNull);
    });

    test('when a formula has parentheses inside strings then they are ignored', () {
      expect(InputParser.closeParentheses('=CONCAT("(", A1'), equals('=CONCAT("(", A1)'));
    });

    test('when typing "=" alone then it is text', () {
      expect(parser.parse('=').content, equals(const TextContent('=')));
    });

    test('when typing -A1 with a formula validator then it becomes =-A1', () {
      final r = parser.parse('-A1', isFormula: (f) => f == '=-A1');
      expect(r.formulaA1, equals('=-A1'));
    });

    test('when typing -abc that is no formula then it is text', () {
      final r = parser.parse('-abc', isFormula: (_) => false);
      expect(r.content, equals(const TextContent('-abc')));
    });

    test('when text keeps surrounding spaces then they are preserved', () {
      expect(parser.parse(' hello ').content, equals(const TextContent(' hello ')));
    });
  });

  group('Given whole-cell links', () {
    final cases = <(String, String?)>[
      ('https://example.com/a?b=1', 'https://example.com/a?b=1'),
      ('http://wonky.work', 'http://wonky.work'),
      ('www.example.com', 'https://www.example.com'),
      ('bob@example.com', 'mailto:bob@example.com'),
      ('mailto:bob@example.com', 'mailto:bob@example.com'),
      ('see www.example.com', null),
      ('example', null),
      ('a@b', null),
    ];
    for (final (input, link) in cases) {
      test('when typing "$input" then the link is $link and the content stays text', () {
        final r = parser.parse(input);
        expect(r.autoLinkUrl, equals(link));
        expect(r.content, equals(TextContent(input)));
      });
    }
  });

  group('Given parseValue', () {
    test('when recognizing a percent then the kind is percent', () {
      final v = parser.parseValue('12%');
      expect(v?.kind, equals(RecognizedKind.percent));
    });

    test('when recognizing text then null is returned', () {
      expect(parser.parseValue('hello'), isNull);
    });

    test('when no today is injected then partial dates use the clock year', () {
      final v = parser.parseValue('1/2', today: DateTime(2030, 6, 1));
      expect(v?.content, equals(NumberContent(_serial(2030, 1, 2))));
    });
  });
}
