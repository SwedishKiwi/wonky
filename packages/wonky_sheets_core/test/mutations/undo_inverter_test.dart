import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

class _Rows implements CurrentRowReader {
  _Rows(this.rows);
  final Map<String, Map<String, Object?>> rows;
  @override
  Map<String, Object?>? currentColumns(String table, String rowId) =>
      rows[rowId];
}

void main() {
  group('Given the undo of a cell insert (08 §3.3, Sheets 10 §10 #16)', () {
    const id = 'c1';
    final created = DateTime.utc(2026);
    final insert = RowChange.insert(SheetsTables.cell, id, {
      Cols.sheetId: 's',
      CellCols.rowId: 'r',
      CellCols.columnId: 'k',
      CellCols.content: 's:Anna',
      CellCols.numberFormat: '0.0',
      Cols.createdAt: created,
    });

    test('when nobody changed the cell then the undo deletes it', () {
      final inverse = SheetsUndo.invertChanges([
        insert,
      ], _Rows({id: insert.columnsAfter}));

      expect(inverse.single.op, RowOp.delete);
    });

    test('when someone else changed its value then the value is skipped and '
        'only the insert\'s untouched columns are cleared', () {
      final skipped = <String>[];
      final inverse = SheetsUndo.invertChanges(
        [insert],
        _Rows({
          id: {...insert.columnsAfter, CellCols.content: 's:Bo'},
        }),
        skipped: (_, _, column) => skipped.add(column),
      );

      expect(skipped, [CellCols.content]);
      expect(inverse.single.op, RowOp.update);
      expect(inverse.single.columnsAfter, {CellCols.numberFormat: null});
    });

    test('when someone else added a format then the cell is kept', () {
      final inverse = SheetsUndo.invertChanges(
        [insert],
        _Rows({
          id: {...insert.columnsAfter, CellCols.bold: true},
        }),
      );

      expect(inverse.single.columnsAfter, {
        CellCols.content: null,
        CellCols.numberFormat: null,
      });
    });
  });
}
