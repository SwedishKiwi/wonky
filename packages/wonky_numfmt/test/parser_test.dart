import 'package:test/test.dart';
import 'package:wonky_numfmt/wonky_numfmt.dart';

void main() {
  group('Given section kinds', () {
    final cases = <(String, List<NfSectionKind>)>[
      ('General', [NfSectionKind.general]),
      ('#,##0.00', [NfSectionKind.number]),
      ('0.00E+00', [NfSectionKind.scientific]),
      ('# ?/?', [NfSectionKind.fraction]),
      ('yyyy-mm-dd', [NfSectionKind.dateTime]),
      ('[h]:mm', [NfSectionKind.dateTime]),
      ('@', [NfSectionKind.text]),
      ('"x"', [NfSectionKind.literal]),
      (
        '0;-0;;@',
        [
          NfSectionKind.number,
          NfSectionKind.number,
          NfSectionKind.empty,
          NfSectionKind.text,
        ],
      ),
    ];
    for (final (pattern, kinds) in cases) {
      test('when parsing "$pattern" then the sections are $kinds', () {
        final ast = NumberFormatParser.parse(pattern);
        expect([for (final s in ast.sections) s.kind], equals(kinds));
      });
    }
  });

  group('Given month and minute tokens', () {
    final cases = <(String, List<NfDateUnit>)>[
      ('h:mm', [NfDateUnit.hour, NfDateUnit.minute]),
      ('mm:ss', [NfDateUnit.minute, NfDateUnit.second]),
      ('m/d/yyyy', [NfDateUnit.month, NfDateUnit.day, NfDateUnit.year]),
      ('hh "h" mm', [NfDateUnit.hour, NfDateUnit.minute]),
      ('mmm', [NfDateUnit.month]),
      (
        'yyyy-mm-dd hh:mm',
        [
          NfDateUnit.year,
          NfDateUnit.month,
          NfDateUnit.day,
          NfDateUnit.hour,
          NfDateUnit.minute, //
        ],
      ),
    ];
    for (final (pattern, units) in cases) {
      test('when parsing "$pattern" then the units are $units', () {
        final s = NumberFormatParser.parse(pattern).sections.single;
        expect([
          for (final t in s.tokens)
            if (t is NfDatePart) t.unit,
        ], equals(units));
      });
    }

    test('when [h] precedes mm then mm is minutes', () {
      final s = NumberFormatParser.parse('[h]:mm').sections.single;
      expect(
        s.tokens.whereType<NfDatePart>().single.unit,
        equals(NfDateUnit.minute),
      );
    });
  });

  group('Given number layouts', () {
    test(
      'when parsing #,##0.00 then grouping and two decimals are recorded',
      () {
        final l = NumberFormatParser.parse('#,##0.00').sections.single.layout!;
        expect((
          l.integerPlaceholders,
          l.decimalPlaceholders,
          l.grouping,
          l.scaleExponent,
        ), equals((4, 2, true, 0)));
      },
    );

    test('when parsing 0.0,,"M" then the scale is 10^-6', () {
      expect(
        NumberFormatParser.parse(
          '0.0,,"M"',
        ).sections.single.layout!.scaleExponent,
        equals(-6),
      );
    });

    test('when parsing 0.00% then the scale is 10^2', () {
      expect(
        NumberFormatParser.parse('0.00%').sections.single.layout!.scaleExponent,
        equals(2),
      );
    });

    test('when parsing a fixed denominator then it is recorded', () {
      final l = NumberFormatParser.parse('# ?/16').sections.single.layout!;
      expect((l.fixedDenominator, l.fractionHasInteger), equals((16, true)));
    });

    test('when parsing ss.000 then fractional seconds have 3 digits', () {
      final s = NumberFormatParser.parse('ss.000').sections.single;
      expect(
        s.tokens.whereType<NfFractionalSeconds>().single.digits,
        equals(3),
      );
    });
  });

  group('Given brackets', () {
    test('when parsing a condition then operator and value are recorded', () {
      final c = NumberFormatParser.parse(
        '[<=-5.5]0;0',
      ).sections.first.condition!;
      expect((c.op, c.value), equals((NfConditionOp.le, -5.5)));
    });

    test('when parsing a locale tag then symbol and LCID are recorded', () {
      final s = NumberFormatParser.parse(r'[$€-407]#,##0.00').sections.single;
      final tag = s.tokens.whereType<NfLocaleTag>().single;
      expect((tag.symbol, tag.lcid, s.lcid), equals(('€', 0x407, 0x407)));
    });

    test(
      'when parsing a locale tag without LCID then only the symbol is kept',
      () {
        final tag =
            NumberFormatParser.parse(r'[$USD]0').sections.single.tokens.first
                as NfLocaleTag;
        expect((tag.symbol, tag.lcid), equals(('USD', null)));
      },
    );

    test('when parsing [Color56] then the last palette color is used', () {
      expect(
        NumberFormatParser.parse('[Color56]0').sections.single.colorArgb,
        equals(0xFF333333),
      );
    });

    test('when a section has two conditions then parsing fails', () {
      expect(
        () => NumberFormatParser.parse('[>1][<5]0'),
        throwsA(isA<FormatParseError>()),
      );
    });
  });

  group('Given tokens with source spans', () {
    test('when parsing then token spans point into the pattern', () {
      const p = '"a"0.00';
      final s = NumberFormatParser.parse(p).sections.single;
      expect([
        for (final t in s.tokens) p.substring(t.start, t.end),
      ], equals(['"a"', '0', '.', '0', '0']));
    });

    test('when validating a valid pattern then no error is returned', () {
      expect(NumberFormatParser.validate('#,##0'), isNull);
    });

    test('when tokens are upper case then they parse like lower case', () {
      final s = NumberFormatParser.parse('YYYY-MM-DD HH:MM:SS').sections.single;
      expect(s.tokens.whereType<NfDatePart>().length, equals(6));
    });
  });
}
