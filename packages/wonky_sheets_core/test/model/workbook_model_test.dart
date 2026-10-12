import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';

void main() {
  group('Given a built workbook with one sheet', () {
    late WorkbookBuilder b;
    late WorkbookModel m;
    setUp(() {
      b = WorkbookBuilder()..sheet('Sheet1', rows: 10, cols: 5);
      b
        ..value('A1', 1)
        ..value('B2', 'Hello')
        ..value('C3', true);
      m = b.build();
    });

    test('when reading cells by A1 then the contents are decoded', () {
      expect(contentAt(m, 'A1'), 'n:1');
      expect(cellAtA1(m, 'B2')!.decoded, const TextContent('Hello'));
      expect(cellAtA1(m, 'C3')!.decoded, const BoolContent(true));
      expect(cellAtA1(m, 'D4'), isNull);
    });

    test('when parsing A1 ranges then indices and flags are resolved', () {
      final r = m.parseA1('Sheet1!B2:C4');
      expect(r.rect, const GridRect(1, 1, 3, 2));
      expect(m.parseA1('B:C').wholeColumns, isTrue);
      expect(() => m.parseA1('Nope!A1'), throwsA(isA<InvalidRangeException>()));
      expect(() => m.parseA1('A100'), throwsA(isA<InvalidRangeException>()));
    });

    test('when deleting a row then its cells cascade and indices shift', () {
      final rowId = b.rowId(0);
      final batch = m.deleteRow(SheetsTables.sheetRow, rowId);
      expect(m.sheets.single.rows.length, 9);
      expect(contentAt(m, 'A1'), isNull);
      expect(cellAtA1(m, 'B1')!.decoded, const TextContent('Hello'));
      expect(batch.whereType<CellsChanged>().single.contentKeys, hasLength(1));
    });

    test('when an id-based range loses its end row then it shrinks via the sort key hint', () {
      final s = m.sheets.single;
      final g = s.gridRange(const GridRect(0, 0, 4, 0));
      m.deleteRow(SheetsTables.sheetRow, b.rowId(4));
      expect(s.resolve(g)!.rect, const GridRect(0, 0, 3, 0));
      m.deleteRow(SheetsTables.sheetRow, b.rowId(0));
      expect(s.resolve(g)!.rect, const GridRect(0, 0, 2, 0));
    });

    test('when exporting rows then reloading yields the same cells', () {
      final copy = WorkbookModel.fromRows(m.spreadsheetId, m.allRows());
      expect(contentAt(copy, 'B2'), 's:Hello');
      expect(copy.allRows().length, m.allRows().length);
    });

    test('when applying a plan and its undo then the state is restored', () {
      final cell = cellAtA1(m, 'A1')!;
      final plan = MutationPlan(
        label: 'Edit',
        summary: ChangeSummary(),
        changes: [
          RowChange.update(
            SheetsTables.cell,
            cell.id,
            {CellCols.content: 'n:1'},
            {CellCols.content: 'n:2'},
          ),
        ],
      );
      m.applyPlan(plan);
      expect(contentAt(m, 'A1'), 'n:2');
      m.applyChanges(UndoInverter.invert(plan, m));
      expect(contentAt(m, 'A1'), 'n:1');
    });

    test('when another user changed the column since then undo skips it', () {
      final cell = cellAtA1(m, 'A1')!;
      final plan = MutationPlan(
        label: 'Edit',
        summary: ChangeSummary(),
        changes: [
          RowChange.update(
            SheetsTables.cell,
            cell.id,
            {CellCols.content: 'n:1'},
            {CellCols.content: 'n:2'},
          ),
        ],
      );
      m.applyPlan(plan);
      m.upsertRow(SheetsTables.cell, cell.id, {CellCols.content: 'n:3'});
      final skipped = <String>[];
      final undo = UndoInverter.invert(plan, m, skipped: (t, id, c) => skipped.add(c));
      expect(undo, isEmpty);
      expect(skipped, [CellCols.content]);
    });
  });

  group('Given an axis index', () {
    test('when sizes are set then offsets and lookups agree', () {
      final a = AxisIndex(defaultSize: 20);
      a.load([
        for (var i = 0; i < 100; i++) ('id$i', 'a${i.toString().padLeft(3, '0')}', null, false),
      ]);
      expect(a.totalSize, 2000);
      a.upsert('id10', a.sortKeyAt(10), size: 100);
      expect(a.offsetOf(11), 20 * 10 + 100);
      expect(a.indexAtOffset(250), 10);
      a.setHiddenLayer('filter', {'id10', 'id11'});
      expect(a.sizeAt(10), 0);
      expect(a.indexAtOffset(205), 12);
      expect(a.visibleCount(0, 12), 11);
    });
  });

  group('Given a rect index', () {
    test('when querying points and rects then only covering entries are returned', () {
      final idx = RectIndex<String>([
        (const GridRect(0, 0, 9, 9), 'a'),
        (const GridRect(5, 5, 20, 6), 'b'),
        (const GridRect(30, 0, 40, 2), 'c'),
      ]);
      expect(idx.at(6, 5), ['a', 'b']);
      expect(idx.at(15, 6), ['b']);
      expect(idx.at(15, 7), isEmpty);
      expect(idx.intersecting(const GridRect(8, 0, 31, 0)), ['a', 'c']);
    });
  });
}
