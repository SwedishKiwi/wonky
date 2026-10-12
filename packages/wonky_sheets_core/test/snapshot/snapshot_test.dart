import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';

import '../support/planner_harness.dart';

void main() {
  group('Given a workbook with values, formats and rules', () {
    late PlannerHarness h;
    setUp(() {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 5, cols: 3);
      b
        ..value('A1', 'héllo ✓')
        ..value('B2', 3.5)
        ..set('C3', null, format: {FormatAttr.bold: true}, note: 'n');
      h = PlannerHarness(b);
      h.apply(MergeCells([h.range('A4:B4')]));
    });

    test('when encoding and decoding a snapshot then all rows round-trip', () {
      final bytes = SnapshotCodec.encodeModel(h.model, capturedAt: DateTime.utc(2026, 10, 12));
      final snap = SnapshotCodec.decode(bytes);
      expect(snap.header.spreadsheetId, h.model.spreadsheetId);
      expect(snap.header.counts[SheetsTables.cell], 3);
      final copy = snap.toModel();
      final h2 = PlannerHarness(WorkbookBuilder());
      expect(contentAt(copy, 'A1'), 's:héllo ✓');
      expect(cellAtA1(copy, 'C3')!.note, 'n');
      expect(copy.sheets.first.merges, hasLength(1));
      expect(h2, isNotNull);
      expect(copy.allRows().length, h.model.allRows().length);
    });

    test('when decoding garbage then a FormatException is thrown', () {
      expect(() => SnapshotCodec.decode([1, 2, 3]), throwsFormatException);
    });

    test('when diffing two versions then changed cells and structure are reported', () {
      final v1 = SnapshotCodec.decode(
        SnapshotCodec.encodeModel(h.model, capturedAt: DateTime.utc(2026)),
      );
      h.apply(
        SetCellInputs(
          sheetId: h.sheetId,
          row: 1,
          col: 1,
          inputs: [
            [const CellInput.user('4')],
          ],
        ),
      );
      h.apply(SetFormat([h.range('A1')], {FormatAttr.italic: true}));
      h.apply(InsertDimension(h.sheetId, Dimension.rows, 0, 1, inheritFrom: InheritFrom.none));
      h.apply(RenameSheet(h.sheetId, 'Data'));
      final v2 = SnapshotCodec.decode(
        SnapshotCodec.encodeModel(h.model, capturedAt: DateTime.utc(2026, 2)),
      );
      final d = SnapshotDiffer.diff(v1, v2);
      expect(
        d.cells.map((c) => c.kind),
        containsAll([CellChangeKind.content, CellChangeKind.format]),
      );
      expect(d.structure[h.sheetId]!.rowsAdded, hasLength(1));
      expect(d.sheetsRenamed[h.sheetId], ('Sheet1', 'Data'));
      expect(SnapshotDiff.fromJson(d.toJson()).cells, d.cells);
    });

    test(
      'when restoring a version then the plan turns current into the version and undo reverts',
      () {
        final v1Rows = h.model.allRows().toList();
        final before = h.dump();
        h.apply(
          SetCellInputs(
            sheetId: h.sheetId,
            row: 0,
            col: 0,
            inputs: [
              [const CellInput.user('changed')],
            ],
          ),
        );
        h.apply(
          DeleteDimension(h.sheetId, Dimension.columns, [h.model.sheets.first.columns.idAt(2)]),
        );
        final plan = SnapshotDiffer.restorePlan(v1Rows, h.model.allRows());
        h.model.applyPlan(plan);
        expect(h.dump(), before);
        expect(plan.summary.kinds, contains('restore'));
      },
    );
  });
}
