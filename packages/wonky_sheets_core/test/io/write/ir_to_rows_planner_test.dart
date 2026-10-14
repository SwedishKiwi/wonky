import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';
import 'package:wonky_sync_models/ids.dart';

import '../support/io_support.dart';

/// An existing spreadsheet with `Sheet1` (A1 = 1, A2 = 2) and `Data`.
WorkbookModel _existing(IdGenerator ids) {
  final b = WorkbookBuilder(ids: ids)
    ..sheet('Sheet1', rows: 10, cols: 5)
    ..value('A1', 1)
    ..value('A2', 2)
    ..value('C3', 'keep', format: {FormatAttr.bold: true})
    ..sheet('Data', rows: 10, cols: 5)
    ..value('A1', 'old');
  return b.build();
}

IrImportResult _plan(
  WorkbookDocument doc,
  WorkbookModel model,
  IdGenerator ids, {
  ImportLocation location = ImportLocation.insertSheets,
  String? activeSheet,
  String? cell,
  int maxCells = 1000000,
  String? fileName,
}) => IrToRowsPlanner.plan(
  doc,
  model,
  ioContext(ids, maxCells: maxCells),
  options: ImportOptions(location: location, cell: cell),
  activeSheetId: activeSheet == null
      ? null
      : model.sheetByName(activeSheet)!.id,
  fileName: fileName,
);

void main() {
  group('Given an empty model and a two-sheet document', () {
    late WorkbookModel model;
    late IrImportResult result;
    setUp(() {
      final doc = irDoc([
        irSheet('Data', [
          [1, '=A1*2'],
          [2, '=A2*2'],
          ['=SUM(A1:A2)', "='Q3 plan'!A1&\"!\""],
        ]),
        irSheet('Q3 plan', [
          ['hi', '=Data!A1+Data!A2'],
        ]),
      ], title: 'Budget');
      final r = importNew(doc);
      model = r.model;
      result = r.result;
    });

    test(
      'when planning a new spreadsheet then the spreadsheet row is written',
      () {
        expect(model.hasSpreadsheetRow, isTrue);
        expect(model.spreadsheet.title, 'Budget');
        expect(model.spreadsheet.locale, 'en_US');
      },
    );

    test('when planning then sheets keep their order and names', () {
      expect([for (final s in model.sheets) s.name], ['Data', 'Q3 plan']);
      expect(result.sheetIds, [for (final s in model.sheets) s.id]);
    });

    test('when planning then new grids are 1000 rows by 26 columns', () {
      final s = model.sheets.first;
      expect((s.rows.length, s.columns.length), (1000, 26));
    });

    test('when planning then values are stored in the content encoding', () {
      expect(contentAt(model, 'Data!A1'), 'n:1');
      expect(contentAt(model, "'Q3 plan'!A1"), 's:hi');
    });

    test('when planning then formulas are stored with id references', () {
      final stored = contentAt(model, 'Data!B1')!;
      expect(stored, startsWith('='));
      expect(stored, isNot(contains('A1')));
      expect(formulaAt(model, 'Data!B1'), '=A1*2');
    });

    test(
      'when planning then cross-sheet formulas resolve to the new sheets',
      () {
        expect(formulaAt(model, "'Q3 plan'!B1"), '=Data!A1+Data!A2');
        expect(valueAt(model, "'Q3 plan'!B1"), const NumberValue(3));
        expect(valueAt(model, 'Data!B3'), const TextValue('hi!'));
      },
    );

    test('when planning then the report counts the written cells', () {
      expect(result.report.cellCount, 8);
      expect(result.report.summary, 'Imported 2 sheets, 8 cells');
      expect(
        [for (final s in result.report.sheets) (s.name, s.cells)],
        [('Data', 6), ('Q3 plan', 2)],
      );
    });

    test('when planning then the plan is labeled as an import', () {
      expect(result.plan.label, 'Import');
      expect(result.plan.summary.kinds, contains(ChangeKinds.import));
    });

    test('when planning then the change detail lists the written cells', () {
      final cells = result.plan.detail!['cells']! as List;
      expect(cells, hasLength(8));
    });
  });

  group('Given a document with more than 5,000 rows', () {
    test('when planning then the plan splits into writer chunks', () {
      final s = IrSheet('Big');
      for (var r = 0; r < 6000; r++) {
        s.cells.set(r, 0, IrCell(value: IrNumber(r.toDouble())));
      }
      final r = importNew(irDoc([s]));
      expect(r.result.plan.chunks.length, greaterThan(1));
      expect(
        r.result.plan.chunks.every((c) => c.length <= MutationPlan.chunkSize),
        isTrue,
      );
      expect(r.model.sheets.single.rows.length, 6001);
      expect(r.result.plan.detail, isNull);
    });
  });

  group('Given an existing spreadsheet with Sheet1 and Data', () {
    late SequentialIdGenerator ids;
    late WorkbookModel model;
    late String before;
    setUp(() {
      ids = SequentialIdGenerator();
      model = _existing(ids);
      before = rowsSnapshot(model);
    });

    WorkbookDocument doc() => irDoc([
      irSheet('Data', [
        [10, '=Data!A1*2'],
      ]),
      irSheet('New', [
        ['=Data!A1+1'],
      ]),
    ]);

    test('when inserting sheets then name conflicts get a number', () {
      model.applyPlan(_plan(doc(), model, ids, activeSheet: 'Sheet1').plan);
      expect(
        [for (final s in model.sheets) s.name],
        ['Sheet1', 'Data (2)', 'New', 'Data'],
      );
    });

    test('when inserting sheets then formulas follow the renamed sheet', () {
      model.applyPlan(_plan(doc(), model, ids, activeSheet: 'Sheet1').plan);
      expect(formulaAt(model, "'Data (2)'!B1"), '=A1*2');
      expect(formulaAt(model, 'New!A1'), "='Data (2)'!A1+1");
      expect(valueAt(model, 'New!A1'), const NumberValue(11));
    });

    test('when inserting sheets then the report lists the rename', () {
      final r = _plan(doc(), model, ids);
      expect(r.report.warnings.map((w) => w.code), contains('sheetRenamed'));
    });

    test('when undoing the insert then the spreadsheet is unchanged', () {
      final r = _plan(doc(), model, ids, fileName: 'orders.xlsx');
      model.applyPlan(r.plan);
      expect(r.plan.label, 'Import orders.xlsx');
      model.applyChanges(UndoInverter.invert(r.plan, model));
      expect(rowsSnapshot(model), before);
    });

    test('when replacing the spreadsheet then only imported sheets remain', () {
      model.applyPlan(
        _plan(
          doc(),
          model,
          ids,
          location: ImportLocation.replaceSpreadsheet,
        ).plan,
      );
      expect([for (final s in model.sheets) s.name], ['Data', 'New']);
      expect(valueAt(model, 'New!A1'), const NumberValue(11));
    });

    test(
      'when undoing a spreadsheet replacement then the old sheets return',
      () {
        final r = _plan(
          doc(),
          model,
          ids,
          location: ImportLocation.replaceSpreadsheet,
        );
        model.applyPlan(r.plan);
        model.applyChanges(UndoInverter.invert(r.plan, model));
        expect(rowsSnapshot(model), before);
      },
    );
  });

  group('Given an active sheet with content and a CSV document', () {
    late SequentialIdGenerator ids;
    late WorkbookModel model;
    late String before;
    final csv = irDoc([
      irSheet('orders', [
        ['Order', 'Amount'],
        [1001, 12.5],
        [1002, null],
      ]),
    ]);
    setUp(() {
      ids = SequentialIdGenerator();
      model = _existing(ids);
      before = rowsSnapshot(model);
    });

    test('when replacing the sheet then old content and formats are gone', () {
      model.applyPlan(
        _plan(
          csv,
          model,
          ids,
          location: ImportLocation.replaceSheet,
          activeSheet: 'Sheet1',
        ).plan,
      );
      expect(contentAt(model, 'Sheet1!A1'), 's:Order');
      expect(contentAt(model, 'Sheet1!B2'), 'n:12.5');
      expect(cellAtA1(model, 'Sheet1!C3'), isNull);
      expect(model.sheetByName('Sheet1')!.rows.length, 1000);
    });

    test('when appending then rows go after the last row with content', () {
      model.applyPlan(
        _plan(
          csv,
          model,
          ids,
          location: ImportLocation.append,
          activeSheet: 'Sheet1',
        ).plan,
      );
      expect(contentAt(model, 'Sheet1!A2'), 'n:2');
      expect(contentAt(model, 'Sheet1!A4'), 's:Order');
      expect(contentAt(model, 'Sheet1!A6'), 'n:1002');
      expect(contentAt(model, 'Sheet1!C3'), 's:keep');
    });

    test('when replacing at a cell then the grid grows as needed', () {
      model.applyPlan(
        _plan(
          csv,
          model,
          ids,
          location: ImportLocation.replaceAtCell,
          activeSheet: 'Sheet1',
          cell: 'D9',
        ).plan,
      );
      final s = model.sheetByName('Sheet1')!;
      expect((s.rows.length, s.columns.length), (11, 5));
      expect(contentAt(model, 'Sheet1!E10'), 'n:12.5');
    });

    test('when replacing at a cell then empty fields clear the old content', () {
      model.applyPlan(
        _plan(
          csv,
          model,
          ids,
          location: ImportLocation.replaceAtCell,
          activeSheet: 'Sheet1',
          cell: 'B1',
        ).plan,
      );
      // The data rectangle is B1:C3; C3 had "keep" and the CSV field is empty.
      expect(contentAt(model, 'Sheet1!C3'), isNull);
      expect(
        cellAtA1(model, 'Sheet1!C3')!.format[FormatAttr.bold],
        isTrue,
        reason: 'formats of the target are kept',
      );
    });

    for (final location in [
      ImportLocation.replaceSheet,
      ImportLocation.append,
      ImportLocation.replaceAtCell,
    ]) {
      test('when undoing ${location.name} then the sheet is unchanged', () {
        final r = _plan(
          csv,
          model,
          ids,
          location: location,
          activeSheet: 'Sheet1',
          cell: 'E9',
        );
        model.applyPlan(r.plan);
        model.applyChanges(UndoInverter.invert(r.plan, model));
        expect(rowsSnapshot(model), before);
      });
    }

    test('when the target sheet is missing then planning fails', () {
      expect(
        () => IrToRowsPlanner.plan(
          csv,
          model,
          ioContext(ids),
          options: const ImportOptions(location: ImportLocation.append),
          activeSheetId: '00000000-0000-4000-8000-00000000ffff',
        ),
        throwsA(
          isA<PlanException>().having((e) => e.code, 'code', 'not_found'),
        ),
      );
    });
  });

  group('Given the cell limit', () {
    IrSheet sized(String name, int rows, int cols) {
      final s = IrSheet(name);
      s.cells.set(rows - 1, cols - 1, const IrCell(value: IrNumber(1)));
      return s;
    }

    test(
      'when the padded grid fits then new sheets get the default padding',
      () {
        final r = IrToRowsPlanner.estimate(
          irDoc([sized('A', 10, 3)]),
          WorkbookModel(spreadsheetId: SequentialIdGenerator().newId()),
        );
        expect(r.cells, 1000 * 26);
        expect(r.exceedsLimit, isFalse);
      },
    );

    test(
      'when padding would exceed the limit then sheets are sized tightly',
      () {
        final r = importNew(irDoc([sized('A', 1100, 20)]), maxCells: 25000);
        final s = r.model.sheets.single;
        expect((s.rows.length, s.columns.length), (1100, 20));
        expect(
          r.result.report.warnings.map((w) => w.code),
          contains('gridTrimmed'),
        );
      },
    );

    test('when the data itself exceeds the limit then planning fails', () {
      final doc = irDoc([sized('A', 800, 800), sized('B', 800, 800)]);
      expect(
        () => importNew(doc),
        throwsA(
          isA<PlanException>()
              .having((e) => e.code, 'code', 'cell_limit_exceeded')
              .having((e) => e.details['cells'], 'cells', 1280000),
        ),
      );
    });

    test(
      'when estimating an oversized import then the dialog message is set',
      () {
        final e = IrToRowsPlanner.estimate(
          irDoc([sized('A', 1000, 1400)]),
          WorkbookModel(spreadsheetId: SequentialIdGenerator().newId()),
        );
        expect(e.exceedsLimit, isTrue);
        expect(
          e.message,
          'This import would make the spreadsheet 1.4 million cells; '
          'the limit is 1 million.',
        );
      },
    );
  });

  group('Given formats in the document', () {
    test(
      'when 90 % of a column shares a format then it becomes the default',
      () {
        final doc = irDoc([IrSheet('S')]);
        final bold = doc.formats.internAttrs(
          CellFormat({FormatAttr.bold: true, FormatAttr.fillColor: '#FFFF00'}),
        );
        final other = doc.formats.internAttrs(
          CellFormat({FormatAttr.bold: false, FormatAttr.italic: true}),
        );
        final s = doc.sheets.single;
        for (var r = 0; r < 10; r++) {
          s.cells.set(r, 0, IrCell(value: IrNumber(r * 1.0), format: bold));
        }
        s.cells.set(10, 0, IrCell(value: const IrNumber(99), format: other));
        final m = importNew(doc).model;
        final sheet = m.sheets.single;
        final col = sheet.columnRecords[sheet.columns.idAt(0)]!;
        expect(col.format.toMap(), {'bold': true});
        final a1 = cellAtA1(m, 'A1')!;
        expect(a1.format.toMap(), {'fillColor': '#FFFF00'});
        expect(cellAtA1(m, 'A11')!.format[FormatAttr.bold], isFalse);
      },
    );

    test(
      'when the sheet has a default format then Sheet.formatJson is set',
      () {
        final doc = irDoc([
          irSheet('S', [
            [1],
          ]),
        ]);
        doc.sheets.single.defaultFormat = doc.formats.internAttrs(
          CellFormat({FormatAttr.fontFamily: 'Lato'}),
        );
        final m = importNew(doc).model;
        expect(
          CellFormat.fromJson(m.sheets.single.record!.formatJson).toMap(),
          {'fontFamily': 'Lato'},
        );
      },
    );

    test('when inserting into a spreadsheet then theme colors of the file are '
        'resolved', () {
      final ids = SequentialIdGenerator();
      final model = _existing(ids);
      final doc = irDoc([IrSheet('Themed')])
        ..theme = const IrTheme(colors: {'accent1': '#123456'});
      doc.sheets.single.cells.set(
        0,
        0,
        IrCell(
          value: const IrText('x'),
          format: doc.formats.internAttrs(
            CellFormat({FormatAttr.fillColor: 'theme:accent1'}),
          ),
        ),
      );
      model.applyPlan(_plan(doc, model, ids).plan);
      expect(
        cellAtA1(model, 'Themed!A1')!.format[FormatAttr.fillColor],
        '#123456',
      );
    });

    test(
      'when creating a spreadsheet then the file theme becomes its theme',
      () {
        final doc =
            irDoc([
                irSheet('S', [
                  [1],
                ]),
              ])
              ..theme = const IrTheme(
                name: 'Office',
                colors: {'accent1': '#123456'},
              );
        final m = importNew(doc).model;
        expect(m.theme.colors['accent1'], '#123456');
      },
    );

    test(
      'when a row has a size and a hidden flag then the row record has them',
      () {
        final s = irSheet('S', [
          [1],
        ]);
        s.rows[2] = const IrDim(size: 40, hidden: true);
        s.columns[1] = const IrDim(size: 150);
        final m = importNew(irDoc([s])).model;
        final sheet = m.sheets.single;
        expect(sheet.rows.explicitSizeAt(2), 40);
        expect(sheet.rows.isUserHidden(2), isTrue);
        expect(sheet.columns.explicitSizeAt(1), 150);
      },
    );

    test('when rows have outline levels then groups are created', () {
      final s = irSheet('S', [
        [1],
      ]);
      for (var r = 2; r <= 5; r++) {
        s.rows[r] = IrDim(outlineLevel: r == 3 || r == 4 ? 2 : 1, hidden: true);
      }
      s.rows[6] = const IrDim(collapsed: true);
      final m = importNew(irDoc([s])).model;
      final sheet = m.sheets.single;
      final groups = [
        for (final g in sheet.groups.values)
          (
            sheet.rows.indexOf(g.startId),
            sheet.rows.indexOf(g.endId),
            g.depth,
            g.collapsed,
          ),
      ]..sort((a, b) => a.$3.compareTo(b.$3));
      expect(groups, [(2, 5, 1, true), (3, 4, 2, false)]);
      expect(
        sheet.rows.isUserHidden(3),
        isFalse,
        reason: 'collapsed groups hide their rows themselves',
      );
    });
  });

  group('Given rules, names, links and objects', () {
    late WorkbookModel model;
    late IrImportResult result;
    setUp(() {
      final s = irSheet('Rules', [
        ['Status', 'Amount'],
        ['Open', 10],
        ['Closed', 20],
      ]);
      final lists = irSheet('Lists', [
        ['Open'],
        ['Closed'],
      ]);
      s.merges.add(const GridRect(4, 0, 5, 1));
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
        ),
      );
      s.autoFilter = IrFilter(
        range: IrRange(0, 0, 2, 1),
        criteria: {
          1: {
            'hiddenValues': ['10'],
          },
        },
        sort: [
          {'col': 1, 'ascending': false},
        ],
      );
      s.cells.set(7, 0, const IrCell(value: IrText('Go'), link: '#Lists!A2'));
      s.cells.set(
        7,
        1,
        const IrCell(value: IrText('Web'), link: 'https://x.y'),
      );
      s.images.add(
        IrImage(
          bytes: Uint8List.fromList([1, 2, 3]),
          anchor: const IrAnchor(row: 9, col: 1, width: 40, height: 30),
          altText: 'logo',
        ),
      );
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
          const IrNamedRange(name: 'Rate.2024', formulaA1: '0.19'),
        ]);
      final r = importNew(doc);
      model = r.model;
      result = r.result;
    });

    SheetModel rules() => model.sheetByName('Rules')!;

    test('when planning then merges use id ranges', () {
      final m = rules().merges.values.single;
      expect(
        rules().resolve(GridRange.tryParse(m.rangeJson)!)!.rect.a1,
        'A5:B6',
      );
    });

    test('when planning then dropdown ranges point to the other sheet', () {
      final dv = rules().dvRules.values.single;
      final c = jsonDecode(dv.criteriaJson) as Map;
      final g = GridRange.tryParse(c['range'])!;
      expect(g.sheetId, model.sheetByName('Lists')!.id);
      expect(c['ext'], {'prompt': 'Pick'});
      expect(dv.displayStyle, 'arrow');
    });

    test(
      'when planning then rule formulas are stored relative to the range',
      () {
        final cf = rules().cfRules.values.single;
        final rule = jsonDecode(cf.ruleJson) as Map;
        final stored = (rule['condition'] as Map)['values'][0]['v'] as String;
        expect(
          EngineFormulaHooks(
            model,
          ).toA1(stored, sheetId: rules().id, row: 1, col: 1),
          r'=$B2>15',
        );
      },
    );

    test('when planning then filter criteria are keyed by column id', () {
      final f = rules().basicFilter!;
      final colB = rules().columns.idAt(1);
      expect(jsonDecode(f.criteriaJson), {
        colB: {
          'hiddenValues': ['10'],
        },
      });
      expect(jsonDecode(f.sortJson!), [
        {'colId': colB, 'ascending': false},
      ]);
    });

    test('when planning then internal links point to the sheet id', () {
      expect(
        cellAtA1(model, 'Rules!A8')!.format[FormatAttr.linkUrl],
        '#sheet=${model.sheetByName('Lists')!.id}&range=A2',
      );
      expect(
        cellAtA1(model, 'Rules!B8')!.format[FormatAttr.linkUrl],
        'https://x.y',
      );
    });

    test('when planning then images are queued for upload', () {
      final upload = result.imageUploads.single;
      expect(upload.bytes, [1, 2, 3]);
      final o = rules().objects.values.single;
      expect(o.kind, EmbeddedObjectKind.image);
      expect(o.specJson, contains(upload.fileUuid));
      expect(o.altText, 'logo');
    });

    test('when planning then invalid names are renamed', () {
      expect([for (final n in model.namedRanges) n.name]..sort(), [
        'Rate_2024',
        'Statuses',
      ]);
      expect(
        result.report.warnings.map((w) => w.code),
        contains('nameRenamed'),
      );
    });

    test('when planning then print settings use row ids', () {
      final p = jsonDecode(rules().record!.printSettingsJson!) as Map;
      expect(p['orientation'], 'landscape');
      expect(p['repeatRows'], {
        'start': rules().rows.idAt(0),
        'end': rules().rows.idAt(0),
      });
      expect((p['pageBreaks'] as Map)['rows'], [rules().rows.idAt(2)]);
      expect(GridRange.tryParse(p['printArea'])!.sheetId, rules().id);
    });
  });

  group('Given cached values inside an array formula range', () {
    test('when planning then only the anchor is written', () {
      final s = IrSheet('S');
      s.cells
        ..set(
          0,
          0,
          const IrCell(
            formulaA1: 'SEQUENCE(3)',
            formulaKind: IrFormulaKind.dynamicArray,
            arrayRef: GridRect(0, 0, 2, 0),
            value: IrNumber(1),
          ),
        )
        ..set(1, 0, const IrCell(value: IrNumber(2)))
        ..set(2, 0, const IrCell(value: IrNumber(3)));
      final m = importNew(irDoc([s])).model;
      expect(contentAt(m, 'A2'), isNull);
      final engine = ModelEngineBinding.create(m).engine;
      final id = m.sheets.single.id;
      expect(
        engine.computedAt(id, 0, 0).spill?.rect,
        const GridRect(0, 0, 2, 0),
      );
      expect(
        engine.computedAt(id, 2, 0).value.toCellValue(),
        const NumberValue(3),
      );
    });
  });

  group('Given import options JSON', () {
    test('when parsing then the values are typed', () {
      final o = ImportOptions.fromJson({
        'location': 'replaceAtCell',
        'cell': 'B4',
        'separator': ';',
        'encoding': 'windows-1252',
        'locale': 'de_DE',
        'convert': false,
        'sheets': ['Orders'],
        'unsupportedFormulas': 'text',
      });
      expect(o.location, ImportLocation.replaceAtCell);
      expect(o.startCell, (3, 1));
      expect(o.separator, ';');
      expect(o.encoding, TextEncoding.windows1252);
      expect(o.convert, isFalse);
      expect(o.unsupportedFormulas, UnsupportedFormulaMode.text);
      expect(ImportOptions.fromJson(o.toJson()).toJson(), o.toJson());
    });

    test('when values are "auto" then detection is used', () {
      final o = ImportOptions.fromJson({
        'separator': 'auto',
        'encoding': 'auto',
      });
      expect(o.separator, isNull);
      expect(o.encoding, isNull);
      expect(o.location, ImportLocation.createNew);
    });
  });

  group('Given an import report', () {
    test('when copying the report then warnings are TSV rows', () {
      final r = ImportReport(
        sheets: const [
          ImportSheetReport(
            name: 'A',
            sheetId: 's',
            rows: 1000,
            columns: 26,
            cells: 182113,
          ),
        ],
        warnings: const [
          ImportWarning(
            code: 'unsupportedFunction',
            message: '12 cells used unsupported function CUBEVALUE',
            sheet: 'A',
            count: 12,
          ),
        ],
      );
      expect(r.summary, 'Imported 1 sheet, 182,113 cells — 1 warning');
      expect(
        r.toTsv(),
        'Severity\tSheet\tRange\tMessage\tCount\n'
        'warning\tA\t\t12 cells used unsupported function CUBEVALUE\t12\n',
      );
    });
  });
}
