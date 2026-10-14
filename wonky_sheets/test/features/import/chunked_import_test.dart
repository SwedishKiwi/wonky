import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/import/import_pipeline.dart';
import 'package:wonky_sheets/features/import_export/progress_dialog.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../support/sheets_harness.dart';

/// Imports into the open spreadsheet are planned and applied in chunks
/// (`IrToRowsPlanner.planChunked`, Sheets 11 §3.5).
void main() {
  late SheetsHarness s;

  setUp(() {
    s = SheetsHarness.open();
    importChunkCells = 3;
  });
  tearDown(() {
    importChunkCells = IrImportChunks.defaultChunkCells;
    return s.dispose();
  });

  final csv = [for (var r = 1; r <= 8; r++) '$r,item $r,=A$r*2'].join('\n');

  test('Given a CSV of many chunks, when imported as a new sheet, then every '
      'cell arrives and one undo removes the whole import', () async {
    final r = await s.run('sheets.file.import', {
      'fileName': 'many.csv',
      'text': csv,
      'options': {'location': 'insertSheets'},
    });
    expect(r.isOk, isTrue, reason: r.message);
    expect(s.editor.activeSheet!.name, 'many');
    expect(s.text('B8'), 'item 8');
    expect(s.text('C8'), '16');
    expect(lastImportReport.value?.cellCount, 24);

    await s.undo();
    expect([for (final sh in s.model.sheets) sh.name], ['Sheet1']);
  });

  test('Given an import in progress, when it is cancelled, then the chunks '
      'applied so far are reverted', () async {
    await s.type('A1', 'keep');
    const options = ImportOptions(
      location: ImportLocation.replaceAtCell,
      cell: 'A1',
    );
    final parsed = await parseImportFile(
      ImportFileData(
        name: 'many.csv',
        bytes: Uint8List.fromList(utf8.encode(csv)),
      ),
      options,
      spreadsheetLocale: 'en_US',
    );
    final progress = IoProgress()..cancelled = true;
    await expectLater(
      applyImport(
        s.editor,
        null,
        parsed,
        options,
        fileName: 'many.csv',
        progress: progress,
      ),
      throwsA(isA<IoCancelled>()),
    );
    expect(s.text('A1'), 'keep');
    expect(s.text('B2'), '');
  });
}
