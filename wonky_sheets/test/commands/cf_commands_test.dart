import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/formatting/formatting_features.dart';
import 'package:wonky_sheets_core/model.dart';

import '../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() {
    s = SheetsHarness.open();
    FormattingFeatures.install(s.editor);
  });
  tearDown(() async {
    FormattingFeatures.maybeOf(s.editor)?.dispose();
    await s.dispose();
  });

  CellDisplay? display(String a1) {
    final r = s.model.parseA1(a1, contextSheetId: s.sheetId);
    return s.editor.cells.displayAt(s.sheetId, r.rect.top, r.rect.left);
  }

  String? fill(String a1) => display(a1)?.fillColor;

  Map<String, Object?> greaterThan(String v, {String fill = '#FAD2CF'}) => {
    'v': 1,
    'type': 'boolean',
    'condition': {
      'type': 'numberGreater',
      'values': [
        {'v': v},
      ],
    },
    'format': {'fillColor': fill},
    'stopIfTrue': true,
  };

  group('Given numbers in A1:A3', () {
    setUp(() async {
      await s.type('A1', '50');
      await s.type('A2', '150');
      await s.type('A3', '250');
    });

    test('when adding a "greater than 100" rule then matching cells are '
        'filled, in one undo step', () async {
      final before = s.h.undoLabels.length;
      final r = await s.run('sheets.cf.addRule', {
        'ranges': ['A1:A3'],
        'rule': greaterThan('100'),
      });

      expect(r.isOk, isTrue);
      expect(fill('A1'), isNull);
      expect(fill('A2'), '#FAD2CF');
      expect(fill('A3'), '#FAD2CF');
      expect(s.h.undoLabels.length, before + 1);
      await s.undo();
      expect(s.sheet.cfRules, isEmpty);
      expect(fill('A2'), isNull);
    });

    test('when a value changes then the highlight follows', () async {
      await s.run('sheets.cf.addRule', {
        'ranges': ['A1:A3'],
        'rule': greaterThan('100'),
      });
      await s.type('A1', '500');
      expect(fill('A1'), '#FAD2CF');
    });

    test('when disabling, re-enabling and deleting the rule then the '
        'rendering follows each step', () async {
      await s.run('sheets.cf.addRule', {
        'ranges': ['A1:A3'],
        'rule': greaterThan('100'),
      });
      final id = s.sheet.cfRules.keys.single;

      await s.run('sheets.cf.setEnabled', {'ruleId': id, 'enabled': false});
      expect(fill('A2'), isNull);
      await s.run('sheets.cf.setEnabled', {'ruleId': id, 'enabled': true});
      expect(fill('A2'), '#FAD2CF');
      await s.run('sheets.cf.deleteRule', {'ruleId': id});
      expect(fill('A2'), isNull);
    });

    test('when two matching rules default to stop-if-true then only the '
        'first applies; reordering swaps them (AC-F10)', () async {
      await s.run('sheets.cf.addRule', {
        'ranges': ['A1:A3'],
        'rule': greaterThan('100', fill: '#FF0000'),
      });
      await s.run('sheets.cf.addRule', {
        'ranges': ['A1:A3'],
        'rule': {
          ...greaterThan('100'),
          'format': {'bold': true},
        },
      });
      expect(fill('A2'), '#FF0000');
      expect(display('A2')!.format.bold, isFalse);

      final ids = FormattingFeatures.of(
        s.editor,
      ).cf.rulesOf(s.sheetId).map((r) => r.id).toList();
      await s.run('sheets.cf.reorder', {
        'ruleId': ids[1],
        'beforeRuleId': ids[0],
      });
      expect(display('A2')!.format.bold, isTrue);
      expect(fill('A2'), isNull);
    });

    test('when a white-to-green scale applies then min is white and max '
        '#57BB8A (AC-F11)', () async {
      await s.run('sheets.cf.addRule', {
        'ranges': ['A1:A3'],
        'rule': CfPresets.colorScales().first.rule.toJson(),
      });
      expect(fill('A1'), '#FFFFFF');
      expect(fill('A3'), '#57BB8A');
    });

    test('when a data bar applies then the overlay carries the bar '
        'fractions', () async {
      await s.run('sheets.cf.addRule', {
        'ranges': ['A1:A3'],
        'rule': const CfDataBarRule().toJson(),
      });
      expect(display('A1')!.conditional!.dataBarFraction, 0);
      expect(display('A3')!.conditional!.dataBarFraction, 1);
    });

    test('when an icon set applies then the overlay names the icon', () async {
      await s.run('sheets.cf.addRule', {
        'ranges': ['A1:A3'],
        'rule': CfIconSetRule(
          set: IconSetKind.arrows3,
          thresholds: const [
            IconThreshold(CfThreshold(CfValueKind.percent, '67')),
            IconThreshold(CfThreshold(CfValueKind.percent, '33')),
          ],
        ).toJson(),
      });
      expect(display('A3')!.conditional!.iconSet, '3arrows');
      expect(display('A3')!.conditional!.iconIndex, 0);
      expect(display('A1')!.conditional!.iconIndex, 2);
    });

    test('when a rule has an invalid value then the command fails', () async {
      final r = await s.run('sheets.cf.addRule', {
        'ranges': ['A1:A3'],
        'rule': greaterThan(''),
      });
      expect(r.isOk, isFalse);
      expect(s.sheet.cfRules, isEmpty);
    });
  });

  group('Given amounts in column C', () {
    setUp(() async {
      for (var r = 2; r <= 4; r++) {
        await s.type('A$r', 'row $r');
        await s.type('C$r', '${r * 40}');
      }
    });

    test('when a custom formula =\$C2>100 applies to A2:F4 then whole rows '
        'highlight and follow edits of C (AC-F9)', () async {
      await s.run('sheets.cf.addRule', {
        'ranges': ['A2:F4'],
        'rule': {
          'v': 1,
          'type': 'boolean',
          'condition': {
            'type': 'customFormula',
            'values': [
              {'v': r'=$C2>100'},
            ],
          },
          'format': {'fillColor': '#B7E1CD'},
        },
      });
      // C2 = 80, C3 = 120, C4 = 160.
      expect(fill('A2'), isNull);
      expect(fill('A3'), '#B7E1CD');
      expect(fill('F4'), '#B7E1CD');

      await s.type('C2', '300');
      expect(fill('A2'), '#B7E1CD');
      expect(fill('E2'), '#B7E1CD');
    });

    test('when a draft is previewed then the grid shows it without writing '
        'a rule', () async {
      final cf = FormattingFeatures.of(s.editor).cf;
      cf.setDraft(
        CfDraft(
          sheetId: s.sheetId,
          ruleId: '~draft',
          sortKey: '~',
          ranges: [s.model.parseA1('C2:C4').rect],
          rule: CfBooleanRule(
            condition: Condition.of(ConditionType.notBlank),
            format: CellFormat({FormatAttr.fillColor: '#123456'}),
          ),
        ),
      );
      expect(fill('C2'), '#123456');
      expect(s.sheet.cfRules, isEmpty);
      cf.setDraft(null);
      expect(fill('C2'), isNull);
    });
  });
}
