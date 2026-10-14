import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';
import 'package:wonky_sync_models/ids.dart';

import '../support/io_support.dart';

void main() {
  group('Given a model with values, formulas and formats', () {
    late WorkbookModel model;
    late WorkbookDocument doc;
    setUp(() {
      final ids = SequentialIdGenerator();
      final b = WorkbookBuilder(ids: ids)
        ..sheet('Data', rows: 20, cols: 5)
        ..value('A1', 2)
        ..value('A2', 3)
        ..set('B1', null, format: {FormatAttr.bold: true})
        ..value('C1', 'text', format: {FormatAttr.textColor: '#FF0000'})
        ..set('D1', 'b:1', note: 'A note')
        ..sheet('Other', rows: 10, cols: 3)
        ..value('A1', 'x');
      model = b.build();
      final data = model.sheetByName('Data')!;
      // Formulas need the ids of the model: write them through the hooks.
      final hooks = EngineFormulaHooks(model);
      String stored(String a1, int r, int c) =>
          hooks.toStored(a1, sheetId: data.id, row: r, col: c);
      model.upsertRow(
        SheetsTables.cell,
        SheetsIds.cellId(data.id, data.rows.idAt(2), data.columns.idAt(0)),
        {
          Cols.sheetId: data.id,
          CellCols.rowId: data.rows.idAt(2),
          CellCols.columnId: data.columns.idAt(0),
          CellCols.content: stored('=SUM(A1:A2)', 2, 0),
          CellCols.numberFormat: '0.00',
        },
      );
      model.upsertRow(
        SheetsTables.cell,
        SheetsIds.cellId(data.id, data.rows.idAt(4), data.columns.idAt(0)),
        {
          Cols.sheetId: data.id,
          CellCols.rowId: data.rows.idAt(4),
          CellCols.columnId: data.columns.idAt(0),
          CellCols.content: stored('=SEQUENCE(3)', 4, 0),
        },
      );
      model.upsertRow(
        SheetsTables.cell,
        SheetsIds.cellId(data.id, data.rows.idAt(4), data.columns.idAt(2)),
        {
          Cols.sheetId: data.id,
          CellCols.rowId: data.rows.idAt(4),
          CellCols.columnId: data.columns.idAt(2),
          CellCols.content: stored('=Other!A1&"!"', 4, 2),
        },
      );
      doc = irOf(model);
    });

    IrSheet data() => doc.sheetByName('Data')!;

    test('when converting then the sheets and their order are kept', () {
      expect([for (final s in doc.sheets) s.name], ['Data', 'Other']);
      expect(doc.title, 'Test');
    });

    test('when converting then literal values become IR values', () {
      expect(data().cells.get(0, 0)!.value, const IrNumber(2));
      expect(data().cells.get(0, 3)!.value, const IrBool(true));
      expect(data().cells.get(0, 3)!.note, 'A note');
    });

    test('when converting then formulas are A1 text with cached values', () {
      final c = data().cells.get(2, 0)!;
      expect(c.formulaA1, 'SUM(A1:A2)');
      expect(c.value, const IrNumber(5));
      expect(doc.formatOf(c).attrs[FormatAttr.numberFormat], '0.00');
    });

    test('when converting then cross-sheet references keep the sheet name', () {
      final c = data().cells.get(4, 2)!;
      expect(c.formulaA1, 'Other!A1&"!"');
      expect(c.value, const IrText('x!'));
    });

    test('when converting a spilling formula then it is a dynamic array', () {
      final c = data().cells.get(4, 0)!;
      expect(c.formulaKind, IrFormulaKind.dynamicArray);
      expect(c.arrayRef, const GridRect(4, 0, 6, 0));
      expect(data().cells.get(6, 0)!.value, const IrNumber(3));
      expect(data().cells.get(6, 0)!.formulaA1, isNull);
    });

    test('when converting then format-only cells keep their format', () {
      final c = data().cells.get(0, 1)!;
      expect(c.value, isNull);
      expect(doc.formatOf(c).attrs[FormatAttr.bold], isTrue);
    });

    test(
      'when converting without values then formulas have no cached value',
      () {
        final d = ModelToIr.convert(model);
        expect(d.sheetByName('Data')!.cells.get(2, 0)!.value, isNull);
        expect(d.sheetByName('Data')!.cells.get(5, 0), isNull);
      },
    );

    test('when converting selected sheets then only those are exported', () {
      final d = ModelToIr.convert(
        model,
        sheetIds: [model.sheetByName('Other')!.id],
      );
      expect([for (final s in d.sheets) s.name], ['Other']);
    });
  });

  group('Given a model built from an imported document', () {
    late WorkbookModel model;
    late WorkbookDocument back;
    setUp(() {
      final s =
          irSheet('Rules', [
              ['Status', 'Amount'],
              ['Open', 10],
              ['Closed', 20],
            ])
            ..frozenRows = 1
            ..tabColor = '#FF0000'
            ..showGridlines = false;
      final lists = irSheet('Lists', [
        ['Open'],
        ['Closed'],
      ]);
      s.rows[5] = const IrDim(outlineLevel: 1, hidden: true);
      s.rows[6] = const IrDim(outlineLevel: 1, hidden: true);
      s.rows[7] = const IrDim(collapsed: true);
      s.columns[1] = const IrDim(size: 140);
      s.merges.add(const GridRect(9, 0, 9, 1));
      s.validations.add(
        IrDataValidation(
          ranges: [IrRange(1, 0, 2, 0)],
          criteria: {'type': 'oneOfRange', 'range': r'Lists!$A$1:$A$2'},
          displayStyle: 'arrow',
          extras: {'prompt': 'Pick'},
        ),
      );
      s.conditionalFormats.add(
        IrConditionalFormat(
          ranges: [IrRange(1, 1, 2, 1)],
          rule: {
            'v': 1,
            'type': 'boolean',
            'condition': {
              'type': 'customFormula',
              'values': [
                {'v': r'=$B2>15'},
              ],
            },
            'format': {'bold': true},
          },
          extras: {
            'xlsx': {'type': 'top10', 'rank': 3},
          },
        ),
      );
      s.autoFilter = IrFilter(
        range: IrRange(0, 0, 2, 1),
        criteria: {
          1: {
            'condition': {
              'type': 'customFormula',
              'values': [
                {'v': '=B2>5'},
              ],
            },
          },
        },
        sort: [
          {'col': 1, 'ascending': false},
        ],
      );
      s.cells.set(8, 0, const IrCell(value: IrText('Go'), link: '#Lists!A2'));
      s.print = {
        'orientation': 'landscape',
        'repeatRows': {'start': 0, 'end': 0},
        'pageBreaks': {
          'rows': [2],
          'cols': <int>[],
        },
        'printArea': 'A1:B3',
      };
      final doc = irDoc([s, lists])
        ..namedRanges.addAll([
          IrNamedRange(
            name: 'Statuses',
            sheet: 'Lists',
            range: IrRange(0, 0, 1, 0),
          ),
          const IrNamedRange(name: 'Rate', formulaA1: 'Lists!A1&"x"'),
        ]);
      final r = importNew(doc);
      model = r.model;
      back = irOf(model);
    });

    IrSheet rules() => back.sheetByName('Rules')!;

    test('when converting back then sheet settings are kept', () {
      expect(rules().frozenRows, 1);
      expect(rules().tabColor, '#FF0000');
      expect(rules().showGridlines, isFalse);
      expect(rules().columns[1]!.size, 140);
    });

    test('when converting back then groups become outline levels', () {
      expect(rules().rows[5]!.outlineLevel, 1);
      expect(rules().rows[5]!.hidden, isTrue);
      expect(rules().rows[7]!.collapsed, isTrue);
    });

    test('when converting back then merges are index rectangles', () {
      expect(rules().merges, [const GridRect(9, 0, 9, 1)]);
    });

    test('when converting back then dropdown ranges are A1 text', () {
      final v = rules().validations.single;
      expect(v.criteria, {'type': 'oneOfRange', 'range': r'Lists!$A$1:$A$2'});
      expect(v.extras, {'prompt': 'Pick'});
      expect(v.ranges, [IrRange(1, 0, 2, 0)]);
    });

    test('when converting back then rule formulas are A1 at the range', () {
      final cf = rules().conditionalFormats.single;
      expect(((cf.rule['condition'] as Map)['values'] as List).single, {
        'v': r'=$B2>15',
      });
      expect(cf.extras, {
        'xlsx': {'type': 'top10', 'rank': 3},
      });
    });

    test('when converting back then filter criteria use column offsets', () {
      final f = rules().autoFilter!;
      expect(f.range, IrRange(0, 0, 2, 1));
      expect(
        jsonEncode(f.criteria[1]),
        jsonEncode({
          'condition': {
            'type': 'customFormula',
            'values': [
              {'v': '=B2>5'},
            ],
          },
        }),
      );
      expect(f.sort, [
        {'col': 1, 'ascending': false},
      ]);
    });

    test('when converting back then internal links name the sheet', () {
      expect(rules().cells.get(8, 0)!.link, '#Lists!A2');
    });

    test('when converting back then print settings use indices', () {
      expect(rules().print, {
        'orientation': 'landscape',
        'repeatRows': {'start': 0, 'end': 0},
        'pageBreaks': {
          'rows': [2],
          'cols': <int>[],
        },
        'printArea': 'A1:B3',
      });
    });

    test('when converting back then named ranges and formulas are A1', () {
      final names = {for (final n in back.namedRanges) n.name: n};
      expect(names['Statuses']!.sheet, 'Lists');
      expect(names['Statuses']!.range, IrRange(0, 0, 1, 0));
      expect(names['Rate']!.formulaA1, 'Lists!A1&"x"');
    });
  });

  group('Given model features without an IR equivalent', () {
    test('when converting then the export report lists them', () {
      final ids = SequentialIdGenerator();
      final b = WorkbookBuilder(ids: ids)..sheet('S', rows: 5, cols: 5);
      final sheetId = b.sheetId('S');
      b.row(SheetsTables.filterView, ids.newId(), {
        Cols.sheetId: sheetId,
        Cols.name: 'Mine',
        Cols.rangeJson: jsonEncode({'s': sheetId}),
        'criteriaJson': '{}',
        Cols.createdBy: kTestUser,
      });
      b.row(SheetsTables.banding, ids.newId(), {
        Cols.sheetId: sheetId,
        Cols.rangeJson: jsonEncode({'s': sheetId}),
        'styleJson': '{}',
      });
      final doc = ModelToIr.convert(b.build());
      expect(
        [for (final w in doc.warnings) w.message],
        [
          'The filter views of this sheet were not exported',
          'The alternating colors of this sheet were not exported',
        ],
      );
    });
  });
}
