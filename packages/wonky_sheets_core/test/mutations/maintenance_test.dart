import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';

import '../support/planner_harness.dart';

/// Deletes rows/columns the way a remote change arrives: without the planner's
/// own anchor repair.
void _remoteDelete(PlannerHarness h, String table, List<String> ids) =>
    h.model.applyChanges([
      for (final id in ids)
        RowChange(table: table, rowId: id, op: RowOp.delete),
    ]);

void main() {
  group('Given a pivot anchored at C5 (02 §8)', () {
    late PlannerHarness h;
    late SheetModel s;
    late String pivotId;
    setUp(() {
      h = PlannerHarness(WorkbookBuilder()..sheet('Sheet1', rows: 10, cols: 5));
      s = h.model.sheets.first;
      pivotId =
          h
                  .apply(
                    AddPivotTable(
                      s.id,
                      4,
                      2,
                      ResolvedRange(s.id, const GridRect(0, 0, 2, 1)),
                      '{}',
                    ),
                  )
                  .result['pivotId']
              as String? ??
          s.pivots.keys.single;
    });

    test(
      'when its anchor row is deleted remotely then it moves to the next surviving row',
      () {
        final next = s.rows.idAt(5);
        _remoteDelete(h, SheetsTables.sheetRow, [s.rows.idAt(4)]);
        final p = WorkbookMaintenance.plan(h.model, h.ctx);
        h.model.applyPlan(p);
        expect(s.pivots[pivotId]!.anchorRowId, next);
        expect(WorkbookMaintenance.plan(h.model, h.ctx).isEmpty, isTrue);
      },
    );

    test(
      'when its anchor row and the rows after it are deleted then it moves to the previous row',
      () {
        final prev = s.rows.idAt(3);
        _remoteDelete(h, SheetsTables.sheetRow, [
          for (var i = 4; i < 10; i++) s.rows.idAt(i),
        ]);
        h.model.applyPlan(WorkbookMaintenance.plan(h.model, h.ctx));
        expect(s.pivots[pivotId]!.anchorRowId, prev);
      },
    );

    test(
      'when its anchor column is deleted remotely then it moves to the next surviving column',
      () {
        final next = s.columns.idAt(3);
        _remoteDelete(h, SheetsTables.sheetColumn, [s.columns.idAt(2)]);
        h.model.applyPlan(WorkbookMaintenance.plan(h.model, h.ctx));
        expect(s.pivots[pivotId]!.anchorColId, next);
      },
    );

    test(
      'when the anchor row was never seen by this client then it falls back to the first row',
      () {
        h.model.applyChanges([
          RowChange.update(
            SheetsTables.pivotTable,
            pivotId,
            {'anchorRowId': s.pivots[pivotId]!.anchorRowId},
            {'anchorRowId': '00000000-0000-4000-8000-00000000beef'},
          ),
        ]);
        h.model.applyPlan(WorkbookMaintenance.plan(h.model, h.ctx));
        expect(s.pivots[pivotId]!.anchorRowId, s.rows.idAt(0));
      },
    );
  });

  group('Given an object anchored at B4 without a sort-key hint (08 §1.2)', () {
    late PlannerHarness h;
    late SheetModel s;
    late String objectId;
    setUp(() {
      h = PlannerHarness(WorkbookBuilder()..sheet('Sheet1', rows: 10, cols: 5));
      s = h.model.sheets.first;
      final anchor = ObjectAnchor(
        rowId: s.rows.idAt(3),
        colId: s.columns.idAt(1),
        dx: 4,
        dy: 2,
      );
      h.apply(
        AddObject(
          s.id,
          EmbeddedObjectKind.image,
          anchorJson: anchor.encode(),
          specJson: '{}',
        ),
      );
      objectId = s.objects.keys.single;
    });

    ObjectAnchor anchor() =>
        ObjectAnchor.tryParse(s.objects[objectId]!.anchorJson)!;

    test(
      'when its anchor row and column are deleted remotely then it re-anchors to the nearest survivors',
      () {
        final nextRow = s.rows.idAt(4);
        final nextCol = s.columns.idAt(2);
        _remoteDelete(h, SheetsTables.sheetRow, [s.rows.idAt(3)]);
        _remoteDelete(h, SheetsTables.sheetColumn, [s.columns.idAt(1)]);
        h.model.applyPlan(WorkbookMaintenance.plan(h.model, h.ctx));
        expect(anchor().rowId, nextRow);
        expect(anchor().colId, nextCol);
        expect(anchor().dx, 0);
        expect(AnchorMaintenance.plan(s), isEmpty);
        expect(WorkbookMaintenance.plan(h.model, h.ctx).isEmpty, isTrue);
      },
    );

    test('when the anchor has a sort-key hint then the hint wins', () {
      final hint = s.rows.sortKeyAt(7);
      h.model.applyChanges([
        RowChange.update(
          SheetsTables.embeddedObject,
          objectId,
          {'anchorJson': s.objects[objectId]!.anchorJson},
          {'anchorJson': anchor().copyWith(rowKey: hint).encode()},
        ),
      ]);
      final atHint = s.rows.idAt(7);
      _remoteDelete(h, SheetsTables.sheetRow, [s.rows.idAt(3)]);
      expect(AnchorMaintenance.plan(s)[objectId]!.rowId, atHint);
    });
  });

  group('Given groups with stale depths (07 §16.3)', () {
    test('when maintaining then depths are normalized idempotently', () {
      final h = PlannerHarness(
        WorkbookBuilder()..sheet('Sheet1', rows: 10, cols: 2),
      );
      final s = h.model.sheets.first;
      h.apply(
        GroupOperation(
          s.id,
          Dimension.rows,
          GroupAction.group,
          start: 1,
          end: 6,
        ),
      );
      h.apply(
        GroupOperation(
          s.id,
          Dimension.rows,
          GroupAction.group,
          start: 2,
          end: 3,
        ),
      );
      final inner = s.groups.values.firstWhere((g) => g.depth == 2).id;
      h.model.applyChanges([
        RowChange.update(
          SheetsTables.dimensionGroup,
          inner,
          {'depth': 2},
          {'depth': 5},
        ),
      ]);
      h.model.applyPlan(WorkbookMaintenance.plan(h.model, h.ctx));
      expect(s.groups[inner]!.depth, 2);
      expect(WorkbookMaintenance.plan(h.model, h.ctx).isEmpty, isTrue);
    });
  });
}
