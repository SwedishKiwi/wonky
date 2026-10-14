import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets/features/cell_editor/cell_editor_controller.dart';
import 'package:wonky_sheets/features/data_validation/dv_controller.dart';
import 'package:wonky_sheets/features/data_validation/dv_draft.dart';
import 'package:wonky_sheets/features/data_validation/dv_panel_state.dart';
import 'package:wonky_sheets/features/in_cell/cell_features.dart';
import 'package:wonky_sheets/l10n/sheets_l10n.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../support/sheets_harness.dart';

Map<String, Object?> _list(List<String> items) => {
  'type': 'oneOfList',
  'options': [
    for (final (i, v) in items.indexed)
      {'value': v, ...DvChipPalette.at(i).toJson()},
  ],
};

void main() {
  late SheetsHarness s;
  late DataValidationController dv;

  setUp(() {
    s = SheetsHarness.open();
    attachCellFeatures(s.editor);
    dv = DataValidationController.of(s.editor);
  });
  tearDown(() => s.dispose());

  (int, int) rc(String a1) {
    final r = s.model.parseA1(a1, contextSheetId: s.sheetId).rect;
    return (r.top, r.left);
  }

  bool invalid(String a1) {
    final (r, c) = rc(a1);
    return dv.isInvalid(s.sheetId, r, c);
  }

  CellDisplay? display(String a1) {
    final (r, c) = rc(a1);
    return s.editor.cells.displayAt(s.sheetId, r, c);
  }

  group('Given a dropdown rule with three colored options on A2:A10', () {
    setUp(() async {
      await s.run('sheets.dv.saveRule', {
        'ranges': ['A2:A10'],
        'criteria': _list(['Open', 'Closed', 'Blocked']),
      });
    });

    test(
      'when a cell holds an item then it renders as a colored chip',
      () async {
        await s.type('A3', 'Closed');

        final d = display('A3')!;
        expect(d.widget.kind, CellWidgetKind.dropdownChip);
        expect(d.widget.chipFill, DvChipPalette.at(1).bg);
      },
    );

    test('when typing an unknown value then it is kept and marked invalid '
        '(warning rule)', () async {
      await s.type('A4', 'Maybe');

      expect(s.text('A4'), 'Maybe');
      expect(invalid('A4'), isTrue);
      expect(invalid('A3'), isFalse);
    });

    test('when undoing the rule then the cells have no dropdown', () async {
      await s.undo();

      expect(s.sheet.dvRules, isEmpty);
      await s.redo();
      expect(s.sheet.dvRules, hasLength(1));
    });

    test('when the dropdown items are asked then they come in order', () {
      final (r, c) = rc('A5');

      final items = dv.evaluator.dropdownItems(s.sheetId, r, c);

      expect(items.map((i) => i.value), ['Open', 'Closed', 'Blocked']);
    });
  });

  group('Given a strict number rule (1–10) on B2:B9', () {
    setUp(() async {
      await s.run('sheets.dv.saveRule', {
        'ranges': ['B2:B9'],
        'criteria': {
          'type': 'numberBetween',
          'values': [
            {'v': '1'},
            {'v': '10'},
          ],
        },
        'strict': true,
      });
    });

    test('when typing 50 then the input is rejected', () async {
      final r = await s.h.invoke('sheets.cell.setInput', {
        'a1': 'B3',
        'input': '50',
      }, InvocationSource.mcp);

      expect(r.status, CommandStatus.failed);
      expect(r.message, startsWith('validation'));
      expect(s.content('B3'), isNull);
    });

    test('when a typed formula evaluates outside the rule then it is '
        'rejected on commit', () async {
      final r = await s.h.invoke('sheets.cell.setInput', {
        'a1': 'B3',
        'input': '=40+10',
      }, InvocationSource.mcp);

      expect(r.status, CommandStatus.failed);
      expect(r.message, startsWith('validation'));
      expect(s.content('B3'), isNull);
    });

    test('when a typed formula evaluates inside the rule then it is '
        'written', () async {
      await s.type('B3', '=2+3');

      expect(s.text('B3'), '5');
    });

    test('when typing 5 then it is written', () async {
      await s.type('B3', '5');

      expect(s.text('B3'), '5');
    });

    test('when the cell editor commits an invalid value then the editor '
        'stays open', () async {
      await s.select('B4');
      s.editor.editor.begin(initialText: '99', mode: EditMode.enter);

      final ok = await s.editor.editor.commit();

      expect(ok, isFalse);
      expect(s.editor.editor.isEditing, isTrue);
      expect(s.content('B4'), isNull);
      s.editor.editor.cancel();
    });

    test('when pasting values (not typing) then the value is kept and marked '
        'invalid', () async {
      await s.type('C1', '50');
      await s.select('C1');
      await s.run('sheets.edit.copy');
      await s.select('B5');
      await s.run('sheets.edit.pasteSpecial', {'mode': 'values'});

      expect(s.text('B5'), '50');
      expect(invalid('B5'), isTrue);
    });
  });

  group('Given checkboxes inserted on A1:A10 with A3 = x', () {
    setUp(() async {
      await s.type('A3', 'x');
      await s.select('A1:A10');
      await s.run('sheets.insert.checkbox');
    });

    test('then empty cells are unchecked and A3 is invalid', () {
      expect(display('A1')!.widget.kind, CellWidgetKind.checkbox);
      expect(display('A1')!.widget.checked, isFalse);
      expect(s.content('A1'), 'b:0');
      expect(invalid('A3'), isTrue);
    });

    test('when toggling the selection then all are checked in one step, '
        'then all unchecked', () async {
      await s.select('A1:A2');
      final steps = s.h.undoLabels.length;

      await s.run('sheets.dv.toggleCheckbox');
      expect(display('A1')!.widget.checked, isTrue);
      expect(display('A2')!.widget.checked, isTrue);
      expect(s.h.undoLabels.length, steps + 1);

      await s.run('sheets.dv.toggleCheckbox');
      expect(display('A1')!.widget.checked, isFalse);

      await s.undo();
      expect(display('A2')!.widget.checked, isTrue);
    });
  });

  test('Given custom checkbox values when toggling then the custom value is '
      'written', () async {
    await s.select('D1');
    await s.run('sheets.insert.checkbox', {
      'checked': 'Yes',
      'unchecked': 'No',
    });

    await s.run('sheets.dv.toggleCheckbox', {
      'cells': ['D1'],
    });

    expect(s.text('D1'), 'Yes');
  });

  test('Given a rule on A1:A10 when a new rule covers A4:A6 then the old one '
      'is split, and undo restores it', () async {
    await s.run('sheets.dv.saveRule', {
      'ranges': ['A1:A10'],
      'criteria': {'type': 'checkbox'},
    });
    await s.run('sheets.dv.saveRule', {
      'ranges': ['A4:A6'],
      'criteria': _list(['a']),
    });

    final rects = {
      for (final id in s.sheet.dvRules.keys)
        id: s.sheet.ruleRects(RuleKind.dataValidation, id).map((r) => r.a1),
    };
    expect(rects.values.expand((x) => x).toSet(), {'A1:A3', 'A7:A10', 'A4:A6'});

    await s.undo();
    expect(s.sheet.dvRules, hasLength(1));
    expect(
      s.sheet
          .ruleRects(RuleKind.dataValidation, s.sheet.dvRules.keys.single)
          .single
          .a1,
      'A1:A10',
    );
  });

  test('Given a rule when removing all in the selection then the cells have '
      'no rule', () async {
    await s.run('sheets.dv.saveRule', {
      'ranges': ['A1:A3'],
      'criteria': {'type': 'checkbox'},
    });
    await s.select('A1:A3');

    await s.run('sheets.dv.clearRange');

    expect(s.sheet.dvRules, isEmpty);
  });

  test('Given values when converting to a dropdown then the items are the '
      'distinct values with palette colors', () async {
    await s.type('C1', 'Red');
    await s.type('C2', 'Blue');
    await s.type('C3', 'Red');
    await s.select('C1:C3');

    await s.run('sheets.insert.dropdown', {'fromValues': true});

    final rule = s.sheet.dvRules.values.single;
    final c = DvCriteria.tryParse(rule.criteriaJson)! as DvListCriteria;
    expect(c.options.map((o) => o.value), ['Red', 'Blue']);
    expect(c.options.first.colors, DvChipPalette.at(0));
  });

  test('Given a custom formula rule when the draft of the rule is rebuilt '
      'then it shows the formula in A1 and saves the same criteria', () async {
    await s.run('sheets.dv.saveRule', {
      'ranges': ['B2:B100'],
      'criteria': {
        'type': 'customFormula',
        'values': [
          {
            'v': s.editor.hooks.toStored(
              '=B2>A2',
              sheetId: s.sheetId,
              row: 1,
              col: 1,
              locale: 'en_US',
            ),
          },
        ],
      },
    });
    final rule = s.sheet.dvRules.values.single;
    final panel = DvPanelState.of(s.editor);

    expect(panel.edit(s.sheetId, rule.id), isTrue);
    final draft = panel.draft!;
    expect(draft.kind, DvKind.customFormula);
    expect(draft.values.first, '=B2>A2');
    expect(draft.criteriaError(sheetsL10nEnglish), isNull);

    await s.type('A3', '1');
    await s.type('B3', '0');
    await s.type('A4', '1');
    await s.type('B4', '2');
    expect(invalid('B3'), isTrue);
    expect(invalid('B4'), isFalse);
  });

  test('Given a dropdown rule when the panel previews a checkbox draft over '
      'it then the grid shows the draft until the preview ends', () async {
    await s.run('sheets.dv.saveRule', {
      'ranges': ['A2:A10'],
      'criteria': _list(['Open']),
    });
    final ruleId = s.sheet.dvRules.keys.single;
    expect(display('A3')!.widget.kind, CellWidgetKind.dropdownChip);

    dv.setDraft(
      DvDraftPreview(
        record: DvRuleRecord(
          id: '~draft',
          sheetId: s.sheetId,
          rangesJson: GridRange.encodeList([
            s.sheet.gridRange(s.model.parseA1('A2:A4').rect),
          ]),
          criteriaJson: '{"type":"checkbox"}',
        ),
        rects: [s.model.parseA1('A2:A4').rect],
        replacesRuleId: ruleId,
      ),
    );

    expect(display('A3')!.widget.kind, CellWidgetKind.checkbox);
    expect(
      display('A8')?.widget.kind ?? CellWidgetKind.none,
      CellWidgetKind.none,
    );
    expect(s.sheet.dvRules.values.single.criteriaJson, contains('oneOfList'));

    dv.setDraft(null);
    expect(display('A3')!.widget.kind, CellWidgetKind.dropdownChip);
  });

  test('Given a rule when it is hovered in the panel then its ranges are '
      'highlighted on the grid', () async {
    await s.run('sheets.dv.saveRule', {
      'ranges': ['B2:B5'],
      'criteria': {'type': 'checkbox'},
    });
    final id = s.sheet.dvRules.keys.single;

    dv.hoverRule(s.sheetId, id);
    expect(dv.highlight.value?.single.a1, 'B2:B5');

    dv.hoverRule(s.sheetId, null);
    expect(dv.highlight.value, isNull);
  });

  test('Given the DV panel command with a selection without rule then a new '
      'draft starts for the selection', () async {
    await s.select('C2:C5');

    await s.run('sheets.dv.openPanel');

    final d = DvPanelState.of(s.editor).draft!;
    expect(d.isNew, isTrue);
    expect(d.rangesText, 'C2:C5');
  });
}
