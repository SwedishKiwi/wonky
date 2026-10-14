@Tags(['slow'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

/// 03 §17: the grid scrolls a 1M-cell sheet (100k × 10, sparse store)
/// painting only the visible window.
void main() {
  testWidgets('Given a sheet with 1,000,000 cells when scrolling 60 frames '
      'then each frame paints quickly and only visible cells are resolved', (
    tester,
  ) async {
    final s = SheetsHarness.open();
    addTearDown(s.dispose);
    const rows = 100000;
    const cols = 10;
    s.session.execute(
      DeleteDimension(
        s.sheetId,
        Dimension.columns,
        s.sheet.columns.ids.skip(cols).toList(),
      ),
    );
    s.session.execute(
      InsertDimension(
        s.sheetId,
        Dimension.rows,
        s.sheet.rows.length,
        rows - s.sheet.rows.length,
      ),
    );
    final sheet = s.sheet;
    final rowIds = sheet.rows.ids;
    final colIds = sheet.columns.ids;
    final changes = <RowChange>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final id = 'c-$r-$c';
        changes.add(
          RowChange.insert(SheetsTables.cell, id, {
            Cols.sheetId: sheet.id,
            CellCols.rowId: rowIds[r],
            CellCols.columnId: colIds[c],
            CellCols.content: c.isEven ? 'n:${r * c + 0.5}' : 's:Item $r',
          }),
        );
      }
    }
    s.model.applyChanges(changes);
    expect(sheet.cells.count, rows * cols);

    await pumpSheets(tester, s);
    final frames = <int>[];
    final sw = Stopwatch();
    for (var i = 0; i < 60; i++) {
      s.editor.scroll.scrollBy(0, 400);
      sw
        ..reset()
        ..start();
      await tester.pump(const Duration(milliseconds: 16));
      frames.add(sw.elapsedMicroseconds);
    }
    frames.sort();
    final median = frames[frames.length ~/ 2];
    final p95 = frames[(frames.length * 0.95).floor()];
    // ignore: avoid_print
    print('1M cells scroll: median ${median / 1000} ms, p95 ${p95 / 1000} ms');
    // Generous bounds for CI machines; the desktop target is ≤ 8 ms.
    expect(median, lessThan(60000));
    expect(s.editor.scroll.y, greaterThan(0));
    // Only the visible window was resolved, not the whole sheet.
    expect(s.editor.textCache.length, lessThan(20000));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
