import 'package:clock/clock.dart';
import 'package:test/test.dart';

import '../support/core.dart';

Condition cond(ConditionType t, [List<String> vs = const []]) =>
    Condition.of(t, [for (final v in vs) ConditionValue.text(v)]);

void main() {
  // 2026-10-12 (a Monday) at 10:00 UTC.
  final today = DateSerial.fromYmd(2026, 10, 12);
  final dates = SpreadsheetDates(
    clock: Clock.fixed(DateTime.utc(2026, 10, 12, 10)),
  );
  final ev = ConditionEvaluator(dates: dates);

  bool check(Condition c, CellValue v, {String? format}) =>
      ev.evaluate(c, v, sheetId: 's', row: 0, col: 0, numberFormat: format);

  group('Given the condition JSON model', () {
    test(
      'when parsing a number condition then type and literal values round-trip',
      () {
        final c = Condition.tryParse(
          '{"type":"numberGreater","values":[{"v":"100"}]}',
        )!;
        expect(c, isA<NumberCondition>());
        expect(c.values.single, const ConditionLiteral('100'));
        expect(c.encode(), '{"type":"numberGreater","values":[{"v":"100"}]}');
      },
    );

    test(
      'when a value starts with = then it is a formula and the condition is volatile',
      () {
        final c = Condition.tryParse({
          'type': 'numberBetween',
          'values': [
            {'v': '1'},
            {'v': '=B2'},
          ],
        })!;
        expect(c.values[1], const ConditionFormula('=B2'));
        expect(c.isVolatile, isTrue);
        expect(c.usesFormulas, isTrue);
      },
    );

    test('when parsing a relative date then it decodes to the enum', () {
      final c = Condition.tryParse(
        '{"type":"dateAfter","values":[{"rel":"pastWeek"}]}',
      )!;
      expect(
        c.values.single,
        const ConditionRelativeDate(RelativeDate.pastWeek),
      );
      expect(c.toJson(), {
        'type': 'dateAfter',
        'values': [
          {'rel': 'pastWeek'},
        ],
      });
    });

    test('when parsing a custom formula then the formula is exposed', () {
      final c = Condition.tryParse(
        '{"type":"customFormula","values":[{"v":"=\$C2>100"}]}',
      )!;
      expect(
        c,
        isA<CustomFormulaCondition>().having(
          (x) => x.formula,
          'formula',
          r'=$C2>100',
        ),
      );
    });

    test('when the type is unknown then parsing fails', () {
      expect(Condition.tryParse('{"type":"nope"}'), isNull);
      expect(Condition.tryParse('not json'), isNull);
    });

    test('when blank has no values then the JSON omits them', () {
      expect(cond(ConditionType.blank).toJson(), {'type': 'blank'});
    });

    test('when validating missing values then a message is returned', () {
      expect(
        Condition.of(ConditionType.numberBetween, [
          const ConditionLiteral('1'),
        ]).validate(),
        'Please enter two values.',
      );
      expect(cond(ConditionType.numberGreater, ['5']).validate(), isNull);
    });

    test('when listing uses then DV-only types are not offered to filters', () {
      expect(ConditionType.textIsEmail.usableIn(ConditionUse.filter), isFalse);
      expect(
        ConditionType.textIsEmail.usableIn(ConditionUse.dataValidation),
        isTrue,
      );
      expect(
        ConditionType.blank.usableIn(ConditionUse.dataValidation),
        isFalse,
      );
      expect(
        ConditionType.textStartsWith.usableIn(ConditionUse.conditionalFormat),
        isTrue,
      );
    });
  });

  group('Given the condition type matrix', () {
    NumberValue n(double x) => NumberValue(x);
    const t = TextValue.new;
    final cases = <(String, Condition, CellValue, bool)>[
      ('blank on empty', cond(ConditionType.blank), CellValue.empty, true),
      ('blank on empty string', cond(ConditionType.blank), t(''), true),
      ('blank on 0', cond(ConditionType.blank), n(0), false),
      ('notBlank on text', cond(ConditionType.notBlank), t('x'), true),
      (
        'textContains case-insensitive',
        cond(ConditionType.textContains, ['EAST']),
        t('Northeast'),
        true,
      ),
      (
        'textContains on number uses Automatic text',
        cond(ConditionType.textContains, ['34.5']),
        n(1234.5),
        true,
      ),
      (
        'textNotContains',
        cond(ConditionType.textNotContains, ['x']),
        t('abc'),
        true,
      ),
      (
        'textNotContains on empty',
        cond(ConditionType.textNotContains, ['x']),
        CellValue.empty,
        true,
      ),
      (
        'textStartsWith',
        cond(ConditionType.textStartsWith, ['ab']),
        t('ABC'),
        true,
      ),
      (
        'textEndsWith',
        cond(ConditionType.textEndsWith, ['bc']),
        t('ABC'),
        true,
      ),
      (
        'textEq is case-insensitive',
        cond(ConditionType.textEq, ['abc']),
        t('ABC'),
        true,
      ),
      (
        'textEq is a full match',
        cond(ConditionType.textEq, ['ab']),
        t('ABC'),
        false,
      ),
      (
        'textEq on boolean',
        cond(ConditionType.textEq, ['true']),
        const BoolValue(true),
        true,
      ),
      (
        'textIsEmail valid',
        cond(ConditionType.textIsEmail),
        t('anna@example.com'),
        true,
      ),
      (
        'textIsEmail invalid',
        cond(ConditionType.textIsEmail),
        t('anna@example'),
        false,
      ),
      (
        'textIsUrl https',
        cond(ConditionType.textIsUrl),
        t('https://wonky.work/x?y=1'),
        true,
      ),
      (
        'textIsUrl www',
        cond(ConditionType.textIsUrl),
        t('www.example.org'),
        true,
      ),
      (
        'textIsUrl invalid',
        cond(ConditionType.textIsUrl),
        t('hello world'),
        false,
      ),
      (
        'numberGreater',
        cond(ConditionType.numberGreater, ['100']),
        n(101),
        true,
      ),
      (
        'numberGreater equal',
        cond(ConditionType.numberGreater, ['100']),
        n(100),
        false,
      ),
      (
        'numberGreater on numeric text',
        cond(ConditionType.numberGreater, ['100']),
        t('200'),
        false,
      ),
      (
        'numberGreaterEq',
        cond(ConditionType.numberGreaterEq, ['100']),
        n(100),
        true,
      ),
      ('numberLess', cond(ConditionType.numberLess, ['0']), n(-1), true),
      ('numberLessEq', cond(ConditionType.numberLessEq, ['0']), n(0), true),
      (
        'numberEq with tolerance',
        cond(ConditionType.numberEq, ['0.3']),
        n(0.1 + 0.2),
        true,
      ),
      ('numberEq on text', cond(ConditionType.numberEq, ['1']), t('1'), false),
      (
        'numberNotEq on text',
        cond(ConditionType.numberNotEq, ['1']),
        t('x'),
        true,
      ),
      (
        'numberNotEq on equal number',
        cond(ConditionType.numberNotEq, ['1']),
        n(1),
        false,
      ),
      (
        'numberBetween inclusive',
        cond(ConditionType.numberBetween, ['1', '10']),
        n(10),
        true,
      ),
      (
        'numberBetween order-insensitive',
        cond(ConditionType.numberBetween, ['10', '1']),
        n(5),
        true,
      ),
      (
        'numberNotBetween',
        cond(ConditionType.numberNotBetween, ['1', '10']),
        n(11),
        true,
      ),
      (
        'numberNotBetween on text',
        cond(ConditionType.numberNotBetween, ['1', '10']),
        t('x'),
        false,
      ),
      (
        'number literal with percent',
        cond(ConditionType.numberLess, ['50%']),
        n(0.4),
        true,
      ),
      (
        'dateEq exact',
        cond(ConditionType.dateEq, ['2026-10-12']),
        n(today + 0.5),
        true,
      ),
      (
        'dateBefore exact',
        cond(ConditionType.dateBefore, ['2026-10-12']),
        n(today - 1.0),
        true,
      ),
      (
        'dateAfter exact',
        cond(ConditionType.dateAfter, ['2026-10-12']),
        n(today.toDouble()),
        false,
      ),
      (
        'dateOnOrBefore',
        cond(ConditionType.dateOnOrBefore, ['2026-10-12']),
        n(today.toDouble()),
        true,
      ),
      (
        'dateOnOrAfter',
        cond(ConditionType.dateOnOrAfter, ['2026-10-12']),
        n(today - 1.0),
        false,
      ),
      (
        'dateBetween',
        cond(ConditionType.dateBetween, ['2026-10-01', '2026-10-31']),
        n(today.toDouble()),
        true,
      ),
      (
        'dateNotBetween',
        cond(ConditionType.dateNotBetween, ['2026-10-01', '2026-10-31']),
        n(today.toDouble()),
        false,
      ),
      (
        'date on text fails',
        cond(ConditionType.dateEq, ['2026-10-12']),
        t('2026-10-12'),
        false,
      ),
      (
        'customFormula without hooks never matches',
        cond(ConditionType.customFormula, ['=TRUE']),
        n(1),
        false,
      ),
    ];
    for (final (name, c, v, expected) in cases) {
      test('when evaluating $name then the result is $expected', () {
        expect(check(c, v), expected);
      });
    }

    test(
      'when checking dateIsValid then numbers need a date format and text must parse',
      () {
        final c = cond(ConditionType.dateIsValid);
        expect(
          check(c, NumberValue(today.toDouble()), format: 'yyyy-mm-dd'),
          isTrue,
        );
        expect(
          check(c, NumberValue(today.toDouble()), format: 'preset:date'),
          isTrue,
        );
        expect(
          check(c, NumberValue(today.toDouble()), format: '0.00'),
          isFalse,
        );
        expect(check(c, NumberValue(today.toDouble())), isFalse);
        expect(check(c, const TextValue('2026-10-12')), isTrue);
        expect(check(c, const TextValue('hello')), isFalse);
      },
    );
  });

  group('Given relative dates on 2026-10-12', () {
    Condition rel(ConditionType t, RelativeDate r) =>
        Condition.of(t, [ConditionRelativeDate(r)]);
    final cases = <(ConditionType, RelativeDate, int, bool)>[
      (ConditionType.dateEq, RelativeDate.today, 0, true),
      (ConditionType.dateEq, RelativeDate.today, -1, false),
      (ConditionType.dateEq, RelativeDate.yesterday, -1, true),
      (ConditionType.dateEq, RelativeDate.tomorrow, 1, true),
      (ConditionType.dateEq, RelativeDate.pastWeek, -7, true),
      (ConditionType.dateEq, RelativeDate.pastWeek, -8, false),
      (ConditionType.dateEq, RelativeDate.pastWeek, 1, false),
      (ConditionType.dateBefore, RelativeDate.pastWeek, -8, true),
      (ConditionType.dateBefore, RelativeDate.pastWeek, -7, false),
      (ConditionType.dateAfter, RelativeDate.pastWeek, -6, true),
      (ConditionType.dateEq, RelativeDate.pastMonth, -30, true),
      (ConditionType.dateBefore, RelativeDate.pastMonth, -31, true),
      (ConditionType.dateEq, RelativeDate.pastYear, -365, true),
      (ConditionType.dateBefore, RelativeDate.pastYear, -366, true),
    ];
    for (final (type, r, offset, expected) in cases) {
      test(
        'when testing ${type.id} ${r.name} on today$offset then it is $expected',
        () {
          expect(
            check(rel(type, r), NumberValue((today + offset).toDouble())),
            expected,
          );
        },
      );
    }

    test(
      'when the time zone is ahead of UTC then today follows the local date',
      () {
        final late = SpreadsheetDates(
          timeZone: 'Pacific/Kiritimati',
          clock: Clock.fixed(DateTime.utc(2026, 10, 12, 20)),
        );
        expect(late.todaySerial(), today + 1);
        final fixed = SpreadsheetDates(
          timeZone: 'UTC-05:00',
          clock: Clock.fixed(DateTime.utc(2026, 10, 12, 2)),
        );
        expect(fixed.todaySerial(), today - 1);
      },
    );

    test('when an IANA zone has DST then the offset follows it', () {
      final berlin = SpreadsheetDates(timeZone: 'Europe/Berlin');
      expect(
        berlin.offsetAt(DateTime.utc(2026, 7, 1)),
        const Duration(hours: 2),
      );
      expect(
        berlin.offsetAt(DateTime.utc(2026, 1, 1)),
        const Duration(hours: 1),
      );
    });

    test(
      'when asking for the next midnight then it is the next local day start',
      () {
        expect(dates.nextMidnightUtc(), DateTime.utc(2026, 10, 13));
      },
    );

    test('when adding months then the day clamps to the month end', () {
      expect(
        SpreadsheetDates.addMonths(DateSerial.fromYmd(2026, 3, 31), -1),
        DateSerial.fromYmd(2026, 2, 28),
      );
      expect(
        SpreadsheetDates.addMonths(DateSerial.fromYmd(2026, 1, 15), -12),
        DateSerial.fromYmd(2025, 1, 15),
      );
    });
  });
}
