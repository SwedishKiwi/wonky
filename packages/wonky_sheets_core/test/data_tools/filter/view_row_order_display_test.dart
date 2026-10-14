import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';

void main() {
  group('Given data rows 1–5 of a sheet sorted for display (07 §4.4)', () {
    late WorkbookModel model;
    late SheetModel sheet;
    late ViewRowOrder order;
    setUp(() {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 10, cols: 2);
      b.values('A1', [
        ['Name'],
        ['d'],
        ['b'],
        ['e'],
        ['a'],
        ['c'],
      ]);
      model = b.build();
      sheet = model.sheets.first;
      order = ViewRowOrder.forRows(
        sheet,
        ModelCellSource(model),
        const GridRect(1, 0, 5, 1),
        [(sheet.columns.idAt(0), true)],
      )!;
    });

    test('when mapping rows then display shows a..e and rows outside map to '
        'themselves', () {
      expect([for (var d = 1; d <= 5; d++) order.modelRow(d)], [4, 2, 5, 1, 3]);
      expect(order.modelRow(0), 0);
      expect(order.displayRow(7), 7);
      expect(order.contains(5), isTrue);
      expect(order.contains(6), isFalse);
    });

    test('when a display range is split into model runs then they are '
        'contiguous in both orders, in display order', () {
      expect(order.modelRuns(1, 5), [(4, 4), (2, 2), (5, 5), (1, 1), (3, 3)]);
      expect(order.modelRuns(0, 0), [(0, 0)]);
      expect(order.modelRuns(5, 7), [(3, 3), (6, 7)]);
    });

    test('when rows have sizes and one is hidden then display offsets and '
        'hit testing follow the display order', () {
      final rows = sheet.rows;
      rows.setAutoSize(rows.idAt(4), 50); // "a" shows first, 50 px tall.
      rows.setHiddenLayer('test', {rows.idAt(2)}); // "b" hidden.
      order.invalidateOffsets();
      final h = rows.sizeAt(0);
      expect(order.displayOffset(rows, 1), h);
      expect(order.displayOffset(rows, 2), h + 50);
      // Display row 2 is "b" (hidden): row 3 starts at the same offset.
      expect(order.displayOffset(rows, 3), h + 50);
      expect(order.displayAtOffset(rows, h + 10), 1);
      expect(order.displayAtOffset(rows, h + 51), 3);
      expect(order.displayOffset(rows, 6), rows.offsetOf(6));
      expect(order.nextVisibleDisplay(rows, 1, 1), 3);
      expect(order.nextVisibleDisplay(rows, 3, -1), 1);
    });

    test('when the rows can\'t be sorted then there is no order', () {
      expect(
        ViewRowOrder.forRows(
          sheet,
          ModelCellSource(model),
          const GridRect(1, 0, 1, 1),
          [(sheet.columns.idAt(0), true)],
        ),
        isNull,
      );
      expect(
        ViewRowOrder.forRows(
          sheet,
          ModelCellSource(model),
          const GridRect(1, 0, 5, 1),
          const [('gone', true)],
        ),
        isNull,
      );
    });

    test('when copying with a row order then the payload rows follow it and '
        'remember their source rows', () {
      final content = ClipboardEncoder.copy(
        model,
        ResolvedRange(sheet.id, const GridRect(1, 0, 5, 0)),
        ModelCellSource(model),
        clipId: 'c',
        rowOrder: [for (var d = 1; d <= 5; d++) order.modelRow(d)],
      );
      expect(content.tsv.trim().split(RegExp(r'\r?\n')), [
        'a',
        'b',
        'c',
        'd',
        'e',
      ]);
      expect(content.payload.rowIndices, [4, 2, 5, 1, 3]);
    });
  });
}
