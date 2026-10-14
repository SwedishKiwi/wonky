import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/engine_bridge/model_cell_source.dart';
import 'package:wonky_sheets_core/src/format/attributes.dart';
import 'package:wonky_sheets_core/src/model/grid_range.dart';
import 'package:wonky_sheets_core/src/pivot/pivot.dart';
import 'package:wonky_sheets_core/src/testing/workbook_builder.dart';

import 'support/pivot_fixtures.dart';

void main() {
  group('Given a sheet with a header row and three data rows', () {
    late WorkbookBuilder b;
    late String sid;
    setUp(() {
      b = WorkbookBuilder();
      sid = b.sheet('Sheet1', rows: 50, cols: 5);
      b.values('A1', [
        ['Region', null, 'Revenue'],
        ['East', 'x', 10],
        ['West', 'y', 20],
        ['East', 'z', 30],
      ]);
      b.value('C2', 10, format: {FormatAttr.numberFormat: r'"$"0'});
    });

    test('when snapshotting A1:C4 then headers, values and formats are '
        'captured', () {
      final m = b.build();
      final range = m
          .sheet(sid)!
          .resolve(
            GridRange(
              sheetId: sid,
              r1: b.rowId(0),
              r2: b.rowId(3),
              c1: b.colId(0),
              c2: b.colId(2),
            ),
          )!;

      final t = SourceTable.fromModel(
        m,
        ModelCellSource(m),
        range,
        plainDisplay,
      );

      expect(t.rowCount, 3);
      expect(t.columns.map((c) => c.header), ['Region', 'Column B', 'Revenue']);
      expect(t.column(b.colId(2))!.numberFormat, r'"$"0');
      expect(t.column(b.colId(2))!.values.last, const NumberValue(30));
      expect(t.sheetRow(0), 1);
      expect(t.indexOf(b.colId(1)), 1);
    });

    test('when the source is whole columns then it is clamped to the used '
        'rows and the pivot computes', () {
      final m = b.build();
      final range = m
          .sheet(sid)!
          .resolve(GridRange(sheetId: sid, c1: b.colId(0), c2: b.colId(2)))!;
      final t = SourceTable.fromModel(
        m,
        ModelCellSource(m),
        range,
        plainDisplay,
      );

      final grid = PivotLayout.build(
        const PivotEngine().compute(
          PivotSpec(
            rows: [field(b.colId(0))],
            values: [PivotValueSpec(source: b.colId(2))],
          ),
          t,
          PivotContext(),
        ),
      );

      expect(t.rowCount, 3);
      expect(
        grid.toValues(),
        table([
          ['Region', 'SUM of Revenue'],
          ['East', 40],
          ['West', 20],
          ['Grand Total', 60],
        ]),
      );
      expect(grid.cellAt(1, 1)!.numberFormat, r'"$"0');
    });
  });

  group('Given literal rows', () {
    test('when a row is short then missing cells are blank and empty headers '
        'are named after the column', () {
      final t = SourceTable.fromRows(
        colIds: const ['a', 'b'],
        headers: const ['A', ''],
        rows: const [
          [NumberValue(1)],
        ],
        display: plainDisplay,
        left: 2,
      );

      expect(t.column('b')!.values.single, CellValue.empty);
      expect(t.column('b')!.header, 'Column D');
      expect(t.range.right, 3);
    });
  });
}
