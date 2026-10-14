import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sync_models/ids.dart';

import '../support/io_support.dart';

/// An existing spreadsheet with values and a bold cell on `Sheet1`.
WorkbookModel _existing(IdGenerator ids) =>
    (WorkbookBuilder(ids: ids)
          ..sheet('Sheet1', rows: 10, cols: 5)
          ..value('A1', 1)
          ..value('A2', 2)
          ..value('C3', 'keep', format: {FormatAttr.bold: true})
          ..value('B4', 'old'))
        .build();

WorkbookDocument _doc() {
  final data = irSheet('Data', [
    for (var r = 0; r < 12; r++)
      [r, 'text $r', '=A${r + 1}*2', if (r.isEven) null else true],
  ]);
  data.merges.add(const GridRect(14, 0, 15, 1));
  return irDoc([
    data,
    irSheet('Totals', [
      ['=SUM(Data!A1:A12)', '=Data!B3'],
    ]),
  ], title: 'Chunks');
}

/// Applies [chunks] to [model] completely; returns every plan.
List<MutationPlan> _drain(IrImportChunks chunks, WorkbookModel model) {
  final plans = [chunks.head];
  model.applyPlan(chunks.head);
  for (var p = chunks.next(); p != null; p = chunks.next()) {
    model.applyPlan(p);
    plans.add(p);
  }
  return plans;
}

void main() {
  group('Given a document planned at once and in chunks', () {
    test('when imported as new sheets then the chunked rows equal the '
        'planned rows, and the report counts every cell', () {
      final a = WorkbookModel(spreadsheetId: 'ss');
      final eager = IrToRowsPlanner.plan(
        _doc(),
        a,
        ioContext(SeededIdGenerator(3)),
      );
      a.applyPlan(eager.plan);

      final b = WorkbookModel(spreadsheetId: 'ss');
      final chunks = IrToRowsPlanner.planChunked(
        _doc(),
        b,
        ioContext(SeededIdGenerator(3)),
        chunkCells: 7,
      );
      expect(
        chunks.head.changes.where((c) => c.table == SheetsTables.cell),
        isEmpty,
      );
      expect(chunks.totalCells, 12 * 4 - 6 + 2);
      final plans = _drain(chunks, b);

      expect(plans.length, greaterThan(5));
      expect(chunks.isDone, isTrue);
      expect(chunks.progress, 1);
      expect(chunks.next(), isNull);
      expect(rowsSnapshot(b), rowsSnapshot(a));
      expect(
        [for (final p in plans) ...p.changes].length,
        eager.plan.changes.length,
      );
      expect(
        [for (final s in chunks.report.sheets) s.cells],
        [for (final s in eager.report.sheets) s.cells],
      );
      expect(chunks.sheetIds, eager.sheetIds);
      expect(valueAt(b, 'Totals!A1'), valueAt(a, 'Totals!A1'));
    });

    test('when replacing at a cell of an existing sheet then the chunks equal '
        'the plan, and their inverses restore the sheet (one undo step)', () {
      final ids = SeededIdGenerator(5);
      final a = _existing(ids);
      final b = _existing(SeededIdGenerator(5));
      final before = rowsSnapshot(b);
      final doc = irDoc([
        irSheet('Data', [
          [7, null, 'x'],
          [null, '=A1+1', null],
        ]),
      ]);
      const options = ImportOptions(
        location: ImportLocation.replaceAtCell,
        cell: 'A1',
      );
      final eager = IrToRowsPlanner.plan(
        doc,
        a,
        ioContext(SeededIdGenerator(9)),
        options: options,
      );
      a.applyPlan(eager.plan);

      final chunks = IrToRowsPlanner.planChunked(
        irDoc([
          irSheet('Data', [
            [7, null, 'x'],
            [null, '=A1+1', null],
          ]),
        ]),
        b,
        ioContext(SeededIdGenerator(9)),
        options: options,
        chunkCells: 1,
      );
      final plans = _drain(chunks, b);
      expect(rowsSnapshot(b), rowsSnapshot(a));
      expect(contentAt(b, 'A2'), isNull, reason: 'cleared by the import');
      expect(contentAt(b, 'B4'), 's:old');

      for (final p in plans.reversed) {
        b.applyPlan(p.inverse());
      }
      expect(rowsSnapshot(b), before);
    });
  });
}
