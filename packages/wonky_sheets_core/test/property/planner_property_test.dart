@Tags(['property'])
library;

import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';

import '../support/planner_harness.dart';

const _texts = ['a', 'B', ' a ', 'x,y', 'Mon', 'Item 1', 'east', '1,2,3'];

PlannerHarness _harness(Random rnd) {
  final b = WorkbookBuilder()..sheet('Sheet1', rows: 12, cols: 6);
  for (var r = 0; r < 8; r++) {
    for (var c = 0; c < 4; c++) {
      if (rnd.nextInt(5) == 0) continue;
      final a1 = '${String.fromCharCode(65 + c)}${r + 1}';
      if (rnd.nextBool()) {
        b.value(a1, rnd.nextInt(4));
      } else {
        b.value(a1, _texts[rnd.nextInt(_texts.length)]);
      }
    }
  }
  b.set('E1', '=SUM(A1:A8)');
  b.set('E2', '=B2*2');
  return PlannerHarness(b, seed: rnd.nextInt(1 << 30));
}

GridRect _rect(Random rnd, SheetModel s, {int minRows = 1}) {
  final rows = s.rows.length;
  final cols = s.columns.length;
  final top = rnd.nextInt(rows - minRows + 1);
  final left = rnd.nextInt(cols);
  final bottom = top + minRows - 1 + rnd.nextInt(rows - top - minRows + 1);
  final right = left + rnd.nextInt(cols - left);
  return GridRect(top, left, bottom, right);
}

SheetsOperation _op(Random rnd, SheetModel s) {
  ResolvedRange range({int minRows = 1}) =>
      ResolvedRange(s.id, _rect(rnd, s, minRows: minRows));
  String col(GridRect r) => s.columns.idAt(r.left + rnd.nextInt(r.colCount));
  switch (rnd.nextInt(13)) {
    case 0:
      return SetCellInputs(
        sheetId: s.id,
        row: rnd.nextInt(s.rows.length),
        col: rnd.nextInt(s.columns.length),
        inputs: [
          [
            CellInput.user(
              rnd.nextBool()
                  ? '${rnd.nextInt(5)}'
                  : _texts[rnd.nextInt(_texts.length)],
            ),
          ],
        ],
      );
    case 1:
      final r = range(minRows: 2);
      return SortRange(r, [
        SortKeySpec(col(r.rect), ascending: rnd.nextBool()),
        if (rnd.nextBool()) SortKeySpec(col(r.rect)),
      ], hasHeader: rnd.nextBool());
    case 2:
      return RandomizeRange(range(minRows: 2));
    case 3:
      final r = range(minRows: 2);
      return RemoveDuplicates(
        r,
        hasHeader: rnd.nextBool(),
        colIds: rnd.nextBool() ? null : [col(r.rect)],
      );
    case 4:
      return TrimWhitespace([range()]);
    case 5:
      final r = range();
      return SplitTextToColumns(
        ResolvedRange(
          s.id,
          GridRect(r.rect.top, r.rect.left, r.rect.bottom, r.rect.left),
        ),
        separator: ',',
        force: true,
      );
    case 6:
      return FindReplace(
        find: ['a', 'east', '1', r'(\w)'][rnd.nextInt(4)],
        replacement: ['b', r'$1$1', ''][rnd.nextInt(3)],
        useRegex: rnd.nextBool(),
        matchCase: rnd.nextBool(),
      );
    case 7:
      final src = _rect(rnd, s);
      final down = rnd.nextBool();
      final room = down
          ? s.rows.length - 1 - src.bottom
          : s.columns.length - 1 - src.right;
      final grow = room == 0 ? 0 : 1 + rnd.nextInt(room);
      final target = down
          ? GridRect(src.top, src.left, src.bottom + grow, src.right)
          : GridRect(src.top, src.left, src.bottom, src.right + grow);
      return FillSeries(
        s.id,
        src,
        target,
        mode: rnd.nextBool() ? FillMode.auto : FillMode.copy,
      );
    case 8:
      return AdjustDecimals([range()], rnd.nextBool() ? 1 : -1);
    case 9:
      final a = rnd.nextInt(s.rows.length);
      final z = a + rnd.nextInt(s.rows.length - a);
      final action = [
        GroupAction.group,
        GroupAction.group,
        GroupAction.ungroup,
        GroupAction.collapseToLevel,
        GroupAction.collapseAll,
        GroupAction.expandAll,
      ][rnd.nextInt(6)];
      return GroupOperation(
        s.id,
        Dimension.rows,
        action,
        start: a,
        end: z,
        level: 1 + rnd.nextInt(3),
      );
    case 10:
      return InsertDimension(
        s.id,
        Dimension.rows,
        rnd.nextInt(s.rows.length),
        1,
      );
    case 11:
      return DeleteDimension(s.id, Dimension.rows, [
        s.rows.idAt(rnd.nextInt(s.rows.length)),
      ]);
    default:
      final r = rnd.nextInt(s.rows.length);
      final c = rnd.nextInt(s.columns.length - 1);
      return MergeCells([
        ResolvedRange(s.id, GridRect(r, c, r, c + 1)),
      ], force: true);
  }
}

void main() {
  group('Given random data-tool operation sequences', () {
    for (final seed in [11, 23, 37, 41, 59, 73, 97, 2026]) {
      test(
        'when each operation is undone then the previous state returns, and undoing all restores the start (seed $seed)',
        () {
          final rnd = Random(seed);
          final h = _harness(rnd);
          final initial = h.dump();
          for (var i = 0; i < 40; i++) {
            final s = h.model.sheets.first;
            if (s.rows.length < 3) break;
            final op = _op(rnd, s);
            final before = h.dump();
            MutationPlan p;
            try {
              p = h.apply(op);
            } on PlanException {
              expect(h.dump(), before, reason: 'refusals change nothing');
              continue;
            }
            h.undo();
            expect(
              h.dump(),
              before,
              reason: 'undo of ${op.runtimeType} (step $i, seed $seed)',
            );
            h.model.applyPlan(p);
            h.history.add(p);
          }
          while (h.history.isNotEmpty) {
            h.undo();
          }
          expect(h.dump(), initial, reason: 'seed $seed');
        },
      );
    }
  });
}
