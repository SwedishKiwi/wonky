import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sheets_core/src/charts/scene/geometry.dart';
import 'package:wonky_sheets_core/src/objects/objects.dart';

import 'object_fixtures.dart';

void main() {
  group('Given a chart anchored at D4 + (5, 7) on a 10 × 5 sheet', () {
    late WorkbookBuilder b;
    late WorkbookModel m;
    late String sheetId;
    late SheetModel sheet;
    late ObjectAnchor anchor;
    const objectId = '00000000-0000-4000-8000-00000000c001';

    setUp(() {
      b = WorkbookBuilder();
      sheetId = b.sheet('Sheet1', rows: 10, cols: 5);
      m = b.build();
      sheet = m.sheet(sheetId)!;
      anchor = ObjectAnchor.atCell(
        3,
        3,
        dx: 5,
        dy: 7,
        width: 300,
        height: 200,
        rows: sheet.rows,
        columns: sheet.columns,
      );
      addObject(b, sheetId, objectId, anchor.encode());
      m = b.build();
      sheet = m.sheet(sheetId)!;
    });

    test('when nothing was deleted then no maintenance is planned', () {
      expect(anchor.reanchor(sheet.rows, sheet.columns), isNull);
      expect(AnchorMaintenance.plan(sheet), isEmpty);
    });

    test('when the anchor row is deleted then it re-anchors to the next surviving row', () {
      m.deleteRow(SheetsTables.sheetRow, b.rowId(3));

      final fixed = anchor.reanchor(sheet.rows, sheet.columns)!;

      expect(fixed.rowId, b.rowId(4));
      expect(fixed.colId, b.colId(3));
      expect((fixed.dx, fixed.dy), (0, 0));
      expect((fixed.width, fixed.height), (300, 200));
      expect(fixed.rowKey, sheet.rows.sortKeyOf(b.rowId(4)));
    });

    test('when the anchor row and the next rows are deleted then the next survivor is used', () {
      m
        ..deleteRow(SheetsTables.sheetRow, b.rowId(3))
        ..deleteRow(SheetsTables.sheetRow, b.rowId(4));

      expect(anchor.reanchor(sheet.rows, sheet.columns)!.rowId, b.rowId(5));
    });

    test('when the anchor column is the last one and deleted then the previous one is used', () {
      final last = ObjectAnchor.atCell(
        3,
        4,
        width: 300,
        height: 200,
        rows: sheet.rows,
        columns: sheet.columns,
      );
      m.deleteRow(SheetsTables.sheetColumn, b.colId(4));

      final fixed = last.reanchor(sheet.rows, sheet.columns)!;

      expect(fixed.colId, b.colId(3));
      expect(fixed.rowId, b.rowId(3));
    });

    test('when re-anchoring twice then the second pass is a no-op', () {
      m.deleteRow(SheetsTables.sheetRow, b.rowId(3));

      final fixed = anchor.reanchor(sheet.rows, sheet.columns)!;

      expect(fixed.reanchor(sheet.rows, sheet.columns), isNull);
    });

    test('when the anchor has no sortKey hint then it falls back to index 0', () {
      final noHint = ObjectAnchor(rowId: b.rowId(3), colId: b.colId(3), dx: 5, dy: 7);
      m.deleteRow(SheetsTables.sheetRow, b.rowId(3));

      expect(noHint.reanchor(sheet.rows, sheet.columns)!.rowId, b.rowId(0));
    });

    test('when planning maintenance then the object gets the re-anchored anchor', () {
      m.deleteRow(SheetsTables.sheetColumn, b.colId(3));

      final plan = AnchorMaintenance.plan(sheet);

      expect(plan.keys, [objectId]);
      expect(plan[objectId]!.colId, b.colId(4));
      expect(AnchorMaintenance.plan(sheet), plan);
    });

    test('when applying the planned changes then planning again finds nothing', () {
      m.deleteRow(SheetsTables.sheetRow, b.rowId(3));

      m.applyChanges(AnchorMaintenance.changes(sheet));

      expect(ObjectAnchor.tryParse(sheet.objects[objectId]!.anchorJson)!.rowId, b.rowId(4));
      expect(AnchorMaintenance.plan(sheet), isEmpty);
    });

    test('when inserting 10 rows of 30 px above then the chart moves down 300 px, same size', () {
      final before = anchor.rectIn(sheet.rows, sheet.columns)!;

      insertRowsBefore(m, sheetId, 2, 10, height: 30);

      expect(
        anchor.rectIn(sheet.rows, sheet.columns),
        ChartRect(before.left, before.top + 300, before.width, before.height),
      );
    });

    test('when inserting default-height rows below then the chart does not move', () {
      final before = anchor.rectIn(sheet.rows, sheet.columns)!;

      insertRowsBefore(m, sheetId, 5, 3);

      expect(anchor.rectIn(sheet.rows, sheet.columns), before);
    });
  });
}
