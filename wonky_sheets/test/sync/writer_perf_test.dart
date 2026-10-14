@Tags(['slow'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sheets/features/sync/sheets_writer.dart';
import 'package:wonky_sheets_core/model.dart';

import 'support/replica_harness.dart';

final space = UuidValue.fromString('0190a000-0000-7000-8000-0000000000e1');

/// Local writer throughput (Sheets 13 §7.5): new cells written in blocks of
/// 5,000 into a growing table, then 5,000 value updates. `BLOCKS` (default
/// 20 = 100k cells) scales it; `BLOCKS=200` is the 1M-cell import.
void main() {
  test('Given a growing spreadsheet, when blocks of new cells and then updates '
      'are written, then each cell takes well under 0.3 ms', () async {
    final blocks = int.parse(Platform.environment['BLOCKS'] ?? '20');
    final rows = blocks * 500;
    const cols = 10;
    final replica = await openTestReplica();
    final create = await createSpreadsheet(
      replica,
      space,
      rows: rows,
      columns: cols,
    );
    final model = WorkbookModel(spreadsheetId: space.uuid)..applyPlan(create);
    final sheet = model.sheets.single;
    Future<int> write(String prefix, int fromRow, int count) async {
      final plan = const SheetsMutationPlanner().plan(
        SetCellInputs(
          sheetId: sheet.id,
          row: fromRow,
          col: 0,
          inputs: [
            for (var r = 0; r < count; r++)
              [for (var c = 0; c < cols; c++) CellInput.user('$prefix$r.$c')],
          ],
        ),
        model,
        PlanContext(userId: testUser.uuid, now: DateTime.utc(2026, 10, 1)),
      );
      model.applyPlan(plan);
      final watch = Stopwatch()..start();
      await SheetsWriter(replica).write(
        spaceId: space,
        changes: plan.changes,
        plan: plan,
        label: plan.label,
        actorKind: 'user',
        sessionId: 'perf',
      );
      return watch.elapsedMilliseconds;
    }

    var total = 0;
    for (var b = 0; b < blocks; b++) {
      total += await write('i$b', b * 500, 500);
    }
    final updates = await write('u', 0, 500);
    final cells = rows * cols;
    // ignore: avoid_print
    print(
      '$cells new cells in $total ms '
      '(${(total * 1000 / cells).toStringAsFixed(1)} µs/cell), '
      '5000 updates in $updates ms',
    );
    expect(total, lessThan(cells * 0.3));
    expect(updates, lessThan(5000 * 0.3));
  }, timeout: const Timeout(Duration(minutes: 30)));

  test(
    'Given an empty sheet, when 100k cells are pasted, then the plan reaches '
    'the model in under 2 s (13 §7.5)',
    () {
      final model = WorkbookModel(spreadsheetId: space.uuid)
        ..applyPlan(
          const SheetsMutationPlanner().plan(
            CreateSpreadsheet(
              spreadsheetId: space.uuid,
              title: 'Paste',
              rows: 10000,
              columns: 10,
            ),
            WorkbookModel(spreadsheetId: space.uuid),
            PlanContext(userId: testUser.uuid, now: DateTime.utc(2026)),
          ),
        );
      final sheet = model.sheets.single;
      final watch = Stopwatch()..start();
      final plan = const SheetsMutationPlanner().plan(
        SetCellInputs(
          sheetId: sheet.id,
          row: 0,
          col: 0,
          inputs: [
            for (var r = 0; r < 10000; r++)
              [for (var c = 0; c < 10; c++) CellInput.user('$r.$c')],
          ],
        ),
        model,
        PlanContext(userId: testUser.uuid, now: DateTime.utc(2026)),
      );
      final planned = watch.elapsedMilliseconds;
      model.applyPlan(plan);
      final ms = watch.elapsedMilliseconds;
      // ignore: avoid_print
      print('100k-cell paste planned in $planned ms, applied after $ms ms');
      expect(model.cellAt(sheet.id, 9999, 9)?.content, 'n:9999.9');
      expect(ms, lessThan(2000));
    },
  );
}
