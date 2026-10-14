@Tags(['property'])
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets/features/sync/sheets_replica.dart';
import 'package:wonky_sheets/features/sync/sheets_writer.dart';
import 'package:wonky_sheets/features/sync/synced_workbook_session.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../sync/support/sync_harness.dart';

/// Property (Sheets 13 WS-S3 acceptance): after any sequence of remote
/// merges and local edits, the incrementally patched model equals a full
/// reload of the replica.
void main() {
  final seeds = Platform.environment['WONKY_SEED'] != null
      ? [int.parse(Platform.environment['WONKY_SEED']!)]
      : const [1, 2, 3, 4, 5];
  final runs = int.tryParse(Platform.environment['WONKY_PROPERTY_RUNS'] ?? '');
  final steps = runs ?? 40;
  final space = UuidValue.fromString('0190a000-0000-7000-8000-0000000000d1');

  for (final seed in seeds) {
    test('when remote merges and local edits interleave (seed $seed) then '
        'the patched model equals a full reload', () async {
      final random = Random(seed);
      final replica = await openTestReplica();
      final host = FakeSessionHost(replica);
      await createSpreadsheet(replica, space, rows: 20, columns: 8);
      final session = SyncedWorkbookSession.open(
        host,
        itemUuid: space,
        spaceUuid: space,
        role: Role.editor,
      );
      addTearDown(session.dispose);
      await session.opened;
      final remoteWriter = SheetsWriter(replica);
      var clock = DateTime.utc(2026, 10, 1);

      SheetsOperation randomOp(WorkbookModel m) {
        final sheet = m.sheets.first;
        final rows = sheet.rows.length;
        final cols = sheet.columns.length;
        int r() => random.nextInt(min(rows, 12));
        int c() => random.nextInt(min(cols, 6));
        ResolvedRange rect() {
          final top = r();
          final left = c();
          return ResolvedRange(
            sheet.id,
            GridRect(
              top,
              left,
              min(rows - 1, top + random.nextInt(3)),
              min(cols - 1, left + random.nextInt(3)),
            ),
          );
        }

        switch (random.nextInt(7)) {
          case 0:
          case 1:
            return SetCellInputs(
              sheetId: sheet.id,
              row: r(),
              col: c(),
              inputs: [
                [
                  CellInput.user(
                    random.nextBool()
                        ? '${random.nextInt(1000)}'
                        : 'v${random.nextInt(50)}',
                  ),
                ],
              ],
            );
          case 2:
            return ClearRanges([rect()]);
          case 3:
            return SetFormat(
              [rect()],
              {
                FormatAttr.bold: random.nextBool(),
                if (random.nextBool()) FormatAttr.fillColor: '#ffcc00',
              },
            );
          case 4:
            return InsertDimension(
              sheet.id,
              random.nextBool() ? Dimension.rows : Dimension.columns,
              random.nextInt(min(rows, 12)),
              1 + random.nextInt(2),
            );
          case 5:
            return DeleteDimension(sheet.id, Dimension.rows, [
              sheet.rows.idAt(r()),
            ]);
          default:
            return SetCellInputs(
              sheetId: sheet.id,
              row: r(),
              col: c(),
              inputs: [
                [CellInput.user('=${random.nextInt(9)}+1')],
              ],
            );
        }
      }

      for (var step = 0; step < steps; step++) {
        clock = clock.add(const Duration(seconds: 1));
        if (random.nextInt(3) == 0) {
          // A local edit through the session (optimistic + queued).
          try {
            session.execute(randomOp(session.model));
          } on PlanException {
            // Some random ops are invalid (e.g. deleting the last row).
          }
        } else {
          // Another device's change merged into the replica.
          final m = await reloadModel(replica, space);
          final MutationPlan plan;
          try {
            plan = const SheetsMutationPlanner().plan(
              randomOp(m),
              m,
              PlanContext(userId: 'remote-user', now: clock),
            );
          } on PlanException {
            continue;
          }
          if (plan.isEmpty) continue;
          await remoteWriter.write(
            spaceId: space,
            changes: plan.changes,
            plan: plan,
            label: plan.label,
            actorKind: 'user',
            sessionId: 'remote',
          );
          host.mergesController.add(space);
        }
        if (random.nextInt(4) == 0) await session.ingestRemote();
      }
      await session.flush();
      await session.ingestRemote();

      final reloaded = await reloadModel(replica, space);
      expect(
        canonical(session.model),
        canonical(reloaded),
        reason: 'seed $seed',
      );
      expect(session.fullReloads, 1, reason: 'incremental only (seed $seed)');
      expect(session.patches, greaterThan(0));
    });
  }

  test('when nothing changed then ingestion reads nothing', () async {
    final replica = await openTestReplica();
    final host = FakeSessionHost(replica);
    await createSpreadsheet(replica, space);
    final session = SyncedWorkbookSession.open(
      host,
      itemUuid: space,
      spaceUuid: space,
    );
    addTearDown(session.dispose);
    await session.opened;
    final cursor = session.cursor;

    await session.ingestRemote();

    expect(session.cursor, cursor);
    expect(session.patches, 0);
    expect(
      SheetsReplica.modelTables.map((t) => t.name),
      isNot(contains('change_log')),
    );
  });
}
