import 'package:test/test.dart';

import '../support/core.dart';
import '../support/fake_hooks.dart';
import '../support/rule_fixtures.dart';

const display = FunctionDisplayText(_plain);
String _plain(CellValue v, String? f) => f == '0.00' && v is NumberValue ? v.number.toStringAsFixed(2) : ValueText.automatic(v);

void main() {
  final conditions = ConditionEvaluator();
  ValidationContext ctx({String sheet = 's', int row = 0, int col = 0, ConditionEvaluator? ev, List<String> Function(DvRangeCriteria)? items}) =>
      ValidationContext(sheetId: sheet, row: row, col: col, conditions: ev ?? conditions, rangeItems: items);
  const engine = ValidationEngine();

  group('Given DV criteria JSON', () {
    test('when parsing a dropdown with colors then options keep values and colors', () {
      final c = DvCriteria.tryParse(
        '{"type":"oneOfList","options":[{"value":"Open","bg":"#D4EDBC","fg":"#11734B"},{"value":"Closed"}],"allowMultiple":false}',
      ) as DvListCriteria;
      expect(c.options.map((o) => o.value), ['Open', 'Closed']);
      expect(c.colorsOf('Open'), const DvChipColors(bg: '#D4EDBC', fg: '#11734B'));
      expect(c.colorsOf('Closed')!.isEmpty, isTrue);
      expect(DvCriteria.tryParse(c.encode())!.toJson(), c.toJson());
    });

    test('when parsing range, checkbox and condition criteria then the right types decode', () {
      expect(DvCriteria.tryParse('{"type":"oneOfRange","range":{"s":"x","c1":"a","c2":"a"},"colors":{"Open":{"bg":"#FFFFFF"}}}'),
          isA<DvRangeCriteria>().having((c) => c.colors['Open']!.bg, 'bg', '#FFFFFF'));
      expect(DvCriteria.tryParse('{"type":"checkbox","checked":"Yes","unchecked":"No"}'),
          isA<DvCheckboxCriteria>().having((c) => c.hasCustomValues, 'custom', isTrue));
      expect(DvCriteria.tryParse('{"type":"numberBetween","values":[{"v":"1"},{"v":"10"}]}'), isA<DvConditionCriteria>());
      expect(DvCriteria.tryParse('{"type":"blank"}'), isNull, reason: 'blank is not a DV criterion');
    });

    test('when cycling the chip palette then colors repeat after 10', () {
      expect(DvChipPalette.at(10), DvChipPalette.at(0));
      expect(DvChipPalette.colors.toSet(), hasLength(10));
    });

    test('when reading display styles then showDropdown derives from it', () {
      expect(DvDisplayStyle.parse('plainText').showDropdown, isFalse);
      expect(DvDisplayStyle.parse(null), DvDisplayStyle.chip);
    });
  });

  group('Given validation messages', () {
    DvRule rule(String json, {String? help}) => DvRule(id: 'r', criteria: DvCriteria.tryParse(json)!, helpText: help);
    final cases = <(String, CellValue, String)>[
      ('{"type":"oneOfList","options":[{"value":"a"}]}', const TextValue('x'), 'Input must be an item on the specified list'),
      ('{"type":"numberBetween","values":[{"v":"1"},{"v":"10"}]}', NumberValue(11), 'Input must be a number between 1 and 10'),
      ('{"type":"numberNotBetween","values":[{"v":"1"},{"v":"10"}]}', NumberValue(5), 'Input must be a number not between 1 and 10'),
      ('{"type":"numberGreater","values":[{"v":"5"}]}', NumberValue(5), 'Input must be greater than 5'),
      ('{"type":"numberGreaterEq","values":[{"v":"5"}]}', NumberValue(4), 'Input must be greater than or equal to 5'),
      ('{"type":"numberLess","values":[{"v":"5"}]}', NumberValue(5), 'Input must be less than 5'),
      ('{"type":"numberLessEq","values":[{"v":"5"}]}', NumberValue(6), 'Input must be less than or equal to 5'),
      ('{"type":"numberEq","values":[{"v":"5"}]}', NumberValue(6), 'Input must be equal to 5'),
      ('{"type":"numberNotEq","values":[{"v":"5"}]}', NumberValue(5), 'Input must be not equal to 5'),
      ('{"type":"textContains","values":[{"v":"x"}]}', const TextValue('abc'), 'Input must contain "x"'),
      ('{"type":"textNotContains","values":[{"v":"x"}]}', const TextValue('x'), 'Input must not contain "x"'),
      ('{"type":"textEq","values":[{"v":"x"}]}', const TextValue('y'), 'Input must be exactly "x"'),
      ('{"type":"textIsEmail"}', const TextValue('nope'), 'Input must be a valid email address'),
      ('{"type":"textIsUrl"}', const TextValue('nope'), 'Input must be a valid URL'),
      ('{"type":"dateIsValid"}', const TextValue('nope'), 'Input must be a valid date'),
      ('{"type":"dateBefore","values":[{"v":"2026-01-01"}]}', const TextValue('x'), 'Input must be a date before 2026-01-01'),
      ('{"type":"dateBetween","values":[{"v":"2026-01-01"},{"v":"2026-12-31"}]}', const TextValue('x'),
          'Input must be a date between 2026-01-01 and 2026-12-31'),
      ('{"type":"dateOnOrAfter","values":[{"rel":"today"}]}', const TextValue('x'), 'Input must be a date on or after today'),
      ('{"type":"checkbox"}', const TextValue('x'), 'Input must be TRUE or FALSE'),
      ('{"type":"checkbox","checked":"Yes","unchecked":"No"}', const TextValue('x'), 'Input must be "Yes" or "No"'),
      ('{"type":"customFormula","values":[{"v":"=FALSE"}]}', NumberValue(1), 'Input must satisfy the specified formula'),
    ];
    for (final (json, value, message) in cases) {
      test('when $json rejects $value then the message is "$message"', () {
        final r = engine.validate(value, ValueText.automatic(value), rule(json), ctx());
        expect(r, ValidationResult(false, message));
      });
    }

    test('when the rule has help text then it replaces the default message', () {
      final r = engine.validate(NumberValue(0), '0', rule('{"type":"numberGreater","values":[{"v":"5"}]}', help: 'Too small'), ctx());
      expect((r.valid, r.message, r.defaultMessage), (false, 'Too small', 'Input must be greater than 5'));
    });

    test('when the cell is empty then every rule passes', () {
      expect(engine.validate(CellValue.empty, '', rule('{"type":"textIsEmail"}'), ctx()).valid, isTrue);
      expect(engine.validate(const TextValue(''), '', rule('{"type":"checkbox"}'), ctx()).valid, isTrue);
    });
  });

  group('Given dropdown list matching', () {
    final list = DvRule(
      id: 'r',
      criteria: DvListCriteria([const DvOption('Open'), const DvOption('1.50'), const DvOption('Closed')]),
    );
    final cases = <(CellValue, String, bool)>[
      (const TextValue('Open'), 'Open', true),
      (const TextValue('open'), 'open', false),
      (NumberValue(1.5), '1.5', true),
      (NumberValue(1.5), '1.50', true),
      (NumberValue(2), '2.00', false),
      (const TextValue('Open '), 'Open ', false),
    ];
    for (final (v, d, ok) in cases) {
      test('when the cell shows "$d" then it is ${ok ? 'valid' : 'invalid'}', () {
        expect(engine.validate(v, d, list, ctx()).valid, ok);
      });
    }

    test('when multiple selection is allowed then every part must be an item', () {
      final multi = DvRule(id: 'r', criteria: DvListCriteria([const DvOption('a'), const DvOption('b')], allowMultiple: true));
      expect(engine.validate(const TextValue('a, b'), 'a, b', multi, ctx()).valid, isTrue);
      expect(engine.validate(const TextValue('a, c'), 'a, c', multi, ctx()).valid, isFalse);
    });

    test('when items come from a range then the range items are used', () {
      final r = DvRule(id: 'r', criteria: DvRangeCriteria(const GridRange(sheetId: 's')));
      expect(engine.validate(const TextValue('x'), 'x', r, ctx(items: (_) => ['x', 'y'])).valid, isTrue);
      expect(engine.validate(const TextValue('z'), 'z', r, ctx(items: (_) => ['x', 'y'])).valid, isFalse);
    });
  });

  group('Given a sheet with a list source and DV rules', () {
    late WorkbookBuilder b;
    late String sid;
    setUp(() {
      b = WorkbookBuilder();
      sid = b.sheet('Sheet1', rows: 20, cols: 4);
      b.values('D1', [
        ['Open'],
        ['Closed'],
        [null],
        ['Open'],
        [1.5],
      ]);
    });

    test('when reading the range items then distinct non-empty display values keep range order', () {
      final m = b.build();
      final reader = CellTextReader(ModelCellSource(m), display);
      final crit = DvRangeCriteria(gridRange(b, sid, 0, 3, 19, 3));
      expect(ListSource.rangeItems(crit, m.sheets.single, reader), ['Open', 'Closed', '1.5']);
      expect(ListSource.distinctValues(reader, sid, const GridRect(0, 3, 19, 3), limit: 2), ['Open', 'Closed']);
    });

    test('when converting to a dropdown then options get palette colors', () {
      final m = b.build();
      final reader = CellTextReader(ModelCellSource(m), display);
      final opts = ListSource.optionsFromValues(reader, sid, const GridRect(0, 3, 4, 3))!;
      expect(opts.map((o) => o.value), ['Open', 'Closed', '1.5']);
      expect(opts[1].colors, DvChipPalette.at(1));
    });

    test('when two rules overlap then the one with the greatest (createdAt, id) is effective', () {
      addDvRule(b, sid, fid(1), [gridRange(b, sid, 0, 0, 9, 0)], '{"type":"checkbox"}', createdAt: DateTime.utc(2026, 1, 2));
      addDvRule(b, sid, fid(2), [gridRange(b, sid, 5, 0, 14, 0)], '{"type":"checkbox"}', createdAt: DateTime.utc(2026, 1, 1));
      addDvRule(b, sid, fid(3), [gridRange(b, sid, 8, 0, 8, 0)], '{"type":"checkbox"}', createdAt: DateTime.utc(2026, 1, 2));
      final s = b.build().sheets.single;
      expect(DvRuleResolver.effectiveRuleAt(s, 6, 0)!.id, fid(1));
      expect(DvRuleResolver.effectiveRuleAt(s, 12, 0)!.id, fid(2));
      expect(DvRuleResolver.effectiveRuleAt(s, 8, 0)!.id, fid(3));
      expect(DvRuleResolver.effectiveRuleAt(s, 16, 0), isNull);
      expect(DvRuleResolver.shadowedRuleIds(s), {fid(1), fid(2)});
    });

    test('when a custom formula =B2>A2 is on B2:B100 then each row validates relative to itself', () {
      b.values('A2', [
        [1, 5],
        [10, 5],
      ]);
      addDvRule(b, sid, fid(1), [gridRange(b, sid, 1, 1, 19, 1)], '{"type":"customFormula","values":[{"v":"=B2>A2"}]}');
      final m = b.build();
      final s = m.sheets.single;
      final values = ModelCellSource(m);
      final ev = ConditionEvaluator(hooks: FakeHooks(values));
      final rule = DvRule.fromRecord(s.dvRules[fid(1)]!, s)!;
      expect(rule.anchor, const CellPos(1, 1));
      bool valid(int row) => engine
          .validate(values.cellValueAt(sid, row, 1), '', rule, ctx(sheet: sid, row: row, col: 1, ev: ev))
          .valid;
      expect(valid(1), isTrue);
      expect(valid(2), isFalse);
    });
  });

  group('Given checkbox values', () {
    test('when no custom values are set then TRUE/FALSE are used', () {
      final v = CheckboxValues.of(const DvCheckboxCriteria());
      expect((v.checked, v.unchecked), (const BoolContent(true), const BoolContent(false)));
      expect(v.stateOf(const BoolValue(true)), isTrue);
      expect(v.stateOf(const TextValue('x')), isNull);
      expect(v.toggle(const BoolValue(true)), const BoolContent(false));
      expect(v.toggle(CellValue.empty), const BoolContent(true));
    });

    test('when custom values are numbers then they are parsed like input', () {
      final v = CheckboxValues.of(const DvCheckboxCriteria(checked: '1', unchecked: 'No'));
      expect(v.checked, const NumberContent(1));
      expect(v.unchecked, const TextContent('No'));
      expect(v.stateOf(NumberValue(1)), isTrue);
      expect(v.stateOf(const TextValue('no')), isFalse);
    });

    test('when toggling a mixed selection then everything becomes checked', () {
      expect(CheckboxValues.toggleAllTarget([true, false, null]), isTrue);
      expect(CheckboxValues.toggleAllTarget([true, true]), isFalse);
    });
  });

  group('Given overlapping DV rules when a new rule is applied', () {
    test('when the new range covers part of a rule then the rule is split', () {
      final r = DvOverlap.subtract({
        'a': [const GridRect(0, 0, 9, 0)],
        'b': [const GridRect(0, 2, 9, 2)],
      }, [const GridRect(3, 0, 5, 1)]);
      expect(r.updates, {
        'a': [const GridRect(0, 0, 2, 0), const GridRect(6, 0, 9, 0)],
      });
      expect(r.deletions, isEmpty);
    });

    test('when the new range covers a whole rule then the rule is deleted', () {
      final r = DvOverlap.subtract({'a': [const GridRect(2, 0, 3, 1)]}, [const GridRect(0, 0, 9, 3)]);
      expect(r.deletions, {'a'});
    });

    test('when the rule being saved overlaps itself then it is skipped', () {
      final r = DvOverlap.subtract({'a': [const GridRect(0, 0, 9, 0)]}, [const GridRect(0, 0, 9, 0)], excludeRuleId: 'a');
      expect(r.isEmpty, isTrue);
    });

    test('when subtraction produces more rectangles than the cap then they merge into bounding rows', () {
      final holes = [for (var i = 0; i < 10; i++) GridRect(i * 2, 0, i * 2, 0)];
      final r = DvOverlap.subtract({'a': [const GridRect(0, 0, 19, 1)]}, holes, cap: 5);
      expect(r.capped, isTrue);
      expect(r.updates['a']!.length, lessThanOrEqualTo(5));
    });

    test('when coalescing adjacent rectangles then they merge', () {
      expect(RectCoalescer.coalesce([const GridRect(0, 0, 0, 0), const GridRect(0, 1, 0, 1), const GridRect(1, 0, 1, 1)]),
          [const GridRect(0, 0, 1, 1)]);
    });
  });
}
