import 'package:test/test.dart';

import 'package:wonky_sheets_core/src/io/print/cell_display.dart';

import '../support/core.dart';
import '../support/fake_hooks.dart';
import '../support/rule_fixtures.dart';

const display = FunctionDisplayText(_plain);
String _plain(CellValue v, String? f) => f == '0.00' && v is NumberValue
    ? v.number.toStringAsFixed(2)
    : ValueText.automatic(v);

void main() {
  group('Given a sheet with a strict dropdown, a warning number rule and '
      'checkboxes', () {
    late WorkbookBuilder b;
    late String sid;
    late WorkbookModel m;
    late DvEvaluator dv;

    setUp(() {
      b = WorkbookBuilder();
      sid = b.sheet('Sheet1', rows: 20, cols: 6);
      b.values('A1', [
        ['Open'],
        ['Nope'],
      ]);
      b.values('B1', [
        [5],
        [50],
      ]);
      b.values('C1', [
        [true],
        ['x'],
      ]);
      b.values('F1', [
        ['Red'],
        ['Green'],
        ['Red'],
        [null],
        ['Blue'],
      ]);
      addDvRule(
        b,
        sid,
        fid(1),
        [gridRange(b, sid, 0, 0, 9, 0)],
        '{"type":"oneOfList","options":[{"value":"Open","bg":"#D4EDBC",'
        '"fg":"#11734B"},{"value":"Closed"}]}',
        strict: true,
      );
      addDvRule(
        b,
        sid,
        fid(2),
        [gridRange(b, sid, 0, 1, 9, 1)],
        '{"type":"numberBetween","values":[{"v":"1"},{"v":"10"}]}',
        helpText: 'Pick 1 to 10',
      );
      addDvRule(b, sid, fid(3), [
        gridRange(b, sid, 0, 2, 9, 2),
      ], '{"type":"checkbox"}');
      addDvRule(
        b,
        sid,
        fid(4),
        [gridRange(b, sid, 0, 3, 9, 3)],
        '{"type":"oneOfRange","range":${gridRange(b, sid, 0, 5, 9, 5).encode()},'
        '"colors":{"Green":{"bg":"#00FF00"}}}',
        strict: true,
      );
      m = b.build();
      dv = DvEvaluator(m, ModelCellSource(m), display);
    });

    test('when a draft rule is previewed then it wins its cells and the '
        'edited rule disappears elsewhere', () {
      final sheet = m.sheet(sid)!;
      final draft = DvDraftPreview(
        record: DvRuleRecord(
          id: '~draft',
          sheetId: sid,
          rangesJson: '[${gridRange(b, sid, 0, 0, 1, 0).encode()}]',
          criteriaJson: '{"type":"checkbox"}',
        ),
        rects: const [GridRect(0, 0, 1, 0)],
        replacesRuleId: fid(1),
      );
      dv.draft = draft;

      expect(dv.ruleAt(sid, 0, 0)?.criteria, isA<DvCheckboxCriteria>());
      expect(dv.ruleAt(sid, 5, 0), isNull, reason: 'rest of the edited rule');
      expect(dv.ruleAt(sid, 0, 1)?.id, fid(2), reason: 'other rules stay');
      expect(draft.affects(sheet, 5, 0), isTrue);
      expect(draft.affects(sheet, 5, 4), isFalse);

      final display = CellDisplayResolver(
        m,
        ModelCellSource(m),
        dvDraft: draft,
      );
      expect(display.display(sid, 0, 0).widget.kind, CellWidgetKind.checkbox);
      expect(display.display(sid, 4, 0).widget.kind, CellWidgetKind.none);

      dv.draft = null;
      expect(dv.ruleAt(sid, 0, 0)?.id, fid(1));
    });

    test('when asking for the rule of a covered cell then it is parsed', () {
      final rule = dv.ruleAt(sid, 3, 0);

      expect(rule?.id, fid(1));
      expect(rule?.strict, isTrue);
      expect(rule?.criteria, isA<DvListCriteria>());
      expect(dv.ruleAt(sid, 15, 0), isNull);
    });

    test('when validating stored values then invalid cells are marked', () {
      expect(dv.validateCell(sid, 0, 0).valid, isTrue);
      expect(
        dv.validateCell(sid, 1, 0),
        const ValidationResult(
          false,
          'Input must be an item on the specified list',
        ),
      );
      expect(dv.validateCell(sid, 1, 1).message, 'Pick 1 to 10');
      expect(dv.validateCell(sid, 5, 0).valid, isTrue, reason: 'empty cell');
      expect(dv.validateCell(sid, 15, 4).valid, isTrue, reason: 'no rule');
    });

    test('when typing an unknown item into the strict dropdown then it is '
        'rejected with the dialog text', () {
      final check = dv.checkInput(
        sid,
        4,
        0,
        InputParser.instance.parse('Maybe'),
      );

      expect(check.verdict, DvInputVerdict.reject);
      expect(check.isCommitted, isFalse);
      expect(check.ruleId, fid(1));
      expect(
        check.dialogMessage(DvEvaluator.cellA1(4, 0)),
        'The data you entered in cell A5 violates the data validation rules '
        'set on this cell. Input must be an item on the specified list',
      );
    });

    test('when typing an invalid number into the warning rule then it is '
        'committed with a warning', () {
      final check = dv.checkInput(sid, 4, 1, InputParser.instance.parse('42'));

      expect(check.verdict, DvInputVerdict.warn);
      expect(check.isCommitted, isTrue);
      expect(check.isInvalid, isTrue);
      expect(check.message, 'Pick 1 to 10');
    });

    test('when typing a valid value or clearing then it is accepted', () {
      final parser = InputParser.instance;

      expect(
        dv.checkInput(sid, 4, 1, parser.parse('7')),
        DvInputCheck.accepted,
      );
      expect(
        dv.checkInput(sid, 4, 0, parser.parse('Closed')).verdict,
        DvInputVerdict.accept,
      );
      expect(
        dv.checkInput(sid, 4, 0, parser.parse('')).verdict,
        DvInputVerdict.accept,
      );
      expect(
        dv.checkInput(sid, 4, 5, parser.parse('anything')).verdict,
        DvInputVerdict.accept,
        reason: 'no rule',
      );
    });

    test('when typing a formula then its result decides, or it is accepted '
        'without one', () {
      final input = InputParser.instance.parse('=A1');

      expect(dv.checkInput(sid, 4, 0, input).verdict, DvInputVerdict.accept);
      expect(
        dv
            .checkInput(sid, 4, 0, input, formulaResult: const TextValue('Zzz'))
            .verdict,
        DvInputVerdict.reject,
      );
    });

    test('when reading dropdown items then list options keep their colors', () {
      expect(dv.dropdownItems(sid, 2, 0), [
        const DvItem(
          'Open',
          colors: DvChipColors(bg: '#D4EDBC', fg: '#11734B'),
        ),
        const DvItem('Closed'),
      ]);
      expect(
        dv.chipColorsAt(sid, 0, 0),
        const DvChipColors(bg: '#D4EDBC', fg: '#11734B'),
      );
      expect(dv.chipColorsAt(sid, 1, 0), isNull, reason: 'not an item');
      expect(dv.dropdownItems(sid, 0, 1), isEmpty, reason: 'number rule');
    });

    test('when the dropdown comes from a range then distinct values in range '
        'order are listed with the configured colors', () {
      expect(dv.dropdownItems(sid, 0, 3), [
        const DvItem('Red'),
        const DvItem('Green', colors: DvChipColors(bg: '#00FF00')),
        const DvItem('Blue'),
      ]);
      expect(
        dv.checkInput(sid, 0, 3, InputParser.instance.parse('Blue')).verdict,
        DvInputVerdict.accept,
      );
      expect(
        dv.checkInput(sid, 0, 3, InputParser.instance.parse('Pink')).verdict,
        DvInputVerdict.reject,
      );
    });

    test('when the source range changes then items refresh after '
        'invalidation', () {
      expect(dv.dropdownItems(sid, 0, 3), hasLength(3));
      m.upsertRow(
        SheetsTables.cell,
        SheetsIds.cellId(sid, b.rowId(3), b.colId(5)),
        {
          Cols.sheetId: sid,
          CellCols.rowId: b.rowId(3),
          CellCols.columnId: b.colId(5),
          CellCols.content: 's:Pink',
        },
      );

      dv.invalidate(ruleId: fid(4));

      expect(dv.dropdownItems(sid, 0, 3).map((i) => i.value), [
        'Red',
        'Green',
        'Pink',
        'Blue',
      ]);
    });

    test('when reading checkboxes then the state follows TRUE/FALSE', () {
      expect(dv.checkboxAt(sid, 0, 2)?.isCustom, isFalse);
      expect(dv.checkboxStateAt(sid, 0, 2), isTrue);
      expect(dv.checkboxStateAt(sid, 1, 2), isNull, reason: '"x" is neither');
      expect(dv.validateCell(sid, 1, 2).valid, isFalse);
      expect(dv.checkboxAt(sid, 0, 0), isNull, reason: 'dropdown rule');
    });
  });

  group('Given a custom-formula rule =B2>A2 on B2:B10', () {
    test(
      'when validating cells then each row is validated relative to itself',
      () {
        final b = WorkbookBuilder();
        final sid = b.sheet('Sheet1', rows: 20, cols: 4);
        b.values('A2', [
          [1, 5],
          [10, 5],
        ]);
        addDvRule(
          b,
          sid,
          fid(1),
          [gridRange(b, sid, 1, 1, 9, 1)],
          '{"type":"customFormula","values":[{"v":"=B2>A2"}]}',
          strict: true,
        );
        final m = b.build();
        final values = ModelCellSource(m);
        final dv = DvEvaluator(m, values, display, hooks: FakeHooks(values));

        expect(dv.validateCell(sid, 1, 1).valid, isTrue);
        expect(dv.validateCell(sid, 2, 1).valid, isFalse);
        expect(
          dv.validateCell(sid, 2, 1).message,
          'Input must satisfy the specified formula',
        );
      },
    );
  });
}
