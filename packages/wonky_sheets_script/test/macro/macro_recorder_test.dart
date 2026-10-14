import 'package:test/test.dart';
import 'package:wonky_sheets_core/wonky_sheets_core.dart';
import 'package:wonky_sheets_script/testing.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

/// Macro recorder: operations → Dart code that compiles and replays (09 §15).
void main() {
  WorkbookModel workbook() => scriptWorkbook((b) {
    b.sheet('Sheet1', rows: 20, cols: 8);
    b.values('A1', [
      [1, 2, 3],
    ]);
    b.sheet('Sheet2', rows: 5, cols: 5);
  });

  List<SheetsOperation> recordedOps(String sheetId, int row) => [
    SetFormat(
      [ResolvedRange(sheetId, GridRect(row, 0, row, 4))],
      {FormatAttr.bold: true},
    ),
    SetFormat(
      [ResolvedRange(sheetId, GridRect(row, 0, row, 4))],
      {FormatAttr.fillColor: '#D9EAD3'},
    ),
    SetCellInputs(
      sheetId: sheetId,
      row: row,
      col: 5,
      inputs: const [
        [CellInput.user('Total'), CellInput.user('=SUM(A1:C1)')],
      ],
    ),
    SetFrozen(sheetId, rows: 1),
    const RemoveBasicFilter('nope'),
  ];

  MacroRecorder record(WorkbookModel model, MacroReferenceMode mode) {
    final sheetId = model.sheets.first.id;
    final recorder = MacroRecorder(
      context: MacroContext(
        mode: mode,
        sheetId: sheetId,
        anchor: const GridRect(0, 0, 0, 0),
      ),
    );
    for (final op in recordedOps(sheetId, 0)) {
      recorder.record(
        op,
        model,
        label: op is RemoveBasicFilter ? 'Remove filter' : null,
      );
    }
    return recorder;
  }

  group('Given a recording in relative mode', () {
    test('when saved then the generated function matches the spec example', () {
      final recorder = record(workbook(), MacroReferenceMode.relative);
      final name = MacroRecorder.functionNameFor('Format header', {'onOpen'});
      final source = recorder.functionSource(
        name,
        'Format header',
        DateTime.utc(2026, 10, 12),
      );
      expect(name, 'formatHeader');
      expect(source, '''
/// Macro "Format header" (recorded 2026-10-12).
void formatHeader() {
  final sheet = SpreadsheetApp.activeSheet;
  final active = SpreadsheetApp.activeRange;
  active.offset(0, 0, 1, 5).fontWeight = 'bold';
  active.offset(0, 0, 1, 5).background = "#D9EAD3";
  active.offset(0, 5, 1, 2).values = [["Total", "=SUM(A1:C1)"]];
  sheet.frozenRows = 1;
  // Not recorded: Remove filter
}
''');
    });

    test(
      'when replayed on another selection then it does the same there',
      () async {
        final recorder = record(workbook(), MacroReferenceMode.relative);
        final file = MacroRecorder.appendTo(
          null,
          recorder.functionSource(
            'formatHeader',
            'Format header',
            DateTime.utc(2026),
          ),
        );
        final program = compileScript({
          'macros.dart': file,
          'main.dart': "import 'macros.dart';\n",
        });
        final model = workbook();
        final bench = ScriptTestBench(model);
        final sheetId = model.sheets.first.id;
        final r = await bench.run(
          program,
          'formatHeader',
          kind: ExecutionKind.macro,
          selection: ScriptSelection(
            sheetId: sheetId,
            ranges: const [GridRect(2, 1, 2, 1)],
          ),
        );
        expect(r.status, ExecutionStatus.completed, reason: '${r.error}');
        final formats = EffectiveFormatResolver(model);
        expect(formats.resolve(sheetId, 2, 1).bold, isTrue);
        expect(formats.resolve(sheetId, 2, 5).bold, isTrue);
        expect(formats.resolve(sheetId, 0, 1).bold, isFalse);
        expect(bench.value('G3'), 'Total');
        expect(bench.value('H3'), 6);
        expect(model.sheet(sheetId)!.record!.frozenRows, 1);
      },
    );
  });

  group('Given a recording in absolute mode', () {
    test('when generated then ranges are A1 notation', () {
      final recorder = record(workbook(), MacroReferenceMode.absolute);
      expect(
        recorder.statements.first,
        "sheet.getRange(\"A1:E1\").fontWeight = 'bold';",
      );
    });

    test(
      'when an operation targets another sheet then it is addressed by name',
      () {
        final model = workbook();
        final recorder = MacroRecorder(
          context: MacroContext(
            mode: MacroReferenceMode.absolute,
            sheetId: model.sheets.first.id,
            anchor: const GridRect(0, 0, 0, 0),
          ),
        );
        recorder.record(SetNote(model.sheets[1].id, 1, 1, 'hi'), model);
        expect(
          recorder.statements.single,
          'SpreadsheetApp.active.sheetByName("Sheet2")!.getRange("B2").note = "hi";',
        );
      },
    );
  });

  test('macro function names are unique and valid', () {
    expect(MacroRecorder.functionNameFor('Macro 1', {}), 'macro1');
    expect(MacroRecorder.functionNameFor('1st', {}), 'macro1st');
    expect(
      MacroRecorder.functionNameFor('Format header', {'formatHeader'}),
      'formatHeader2',
    );
    expect(MacroRecorder.functionNameFor('', {}), 'macro');
  });
}
