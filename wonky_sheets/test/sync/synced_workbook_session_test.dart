import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart'
    show AccessRole, Cell, SpaceStats, SubscribeResult, UuidValue;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets/features/model/workbook_session.dart';
import 'package:wonky_sheets/features/sync/sheets_replica.dart';
import 'package:wonky_sheets/features/sync/sheets_writer.dart';
import 'package:wonky_sheets/features/sync/synced_workbook_session.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sync_models/ids.dart';
import 'package:wonky_ui/wonky_ui.dart' show SyncState;

import 'support/sync_harness.dart';

final space = UuidValue.fromString('0190a000-0000-7000-8000-0000000000c1');

SubscribeResult subscribed({bool alreadyMember = true, int totalRows = 1}) =>
    SubscribeResult(
      spaceUuid: space,
      role: AccessRole.editor,
      canWrite: true,
      alreadyMember: alreadyMember,
      stats: SpaceStats(
        spaceUuid: space,
        rowCounts: const {},
        totalRows: totalRows,
        sheetCount: 1,
        cellCount: 0,
        gridCells: 0,
      ),
    );

/// Writes [changes] into the replica as another device's merge would.
Future<void> remoteWrite(SheetsReplica replica, List<RowChange> changes) =>
    SheetsWriter(replica).write(
      spaceId: space,
      changes: changes,
      label: 'Remote',
      actorKind: 'user',
      sessionId: 'remote',
    );

/// A plan for [op] against the replica's current state.
Future<MutationPlan> planOnReplica(
  SheetsReplica replica,
  SheetsOperation Function(WorkbookModel m) op,
) async {
  final m = await reloadModel(replica, space);
  return const SheetsMutationPlanner().plan(
    op(m),
    m,
    PlanContext(userId: testUser.uuid, now: DateTime.utc(2026, 10, 2)),
  );
}

SetCellInputs setInput(WorkbookModel m, int row, int col, String text) =>
    SetCellInputs(
      sheetId: m.sheets.first.id,
      row: row,
      col: col,
      inputs: [
        [CellInput.user(text)],
      ],
    );

void main() {
  group('Given a spreadsheet on the device', () {
    late SheetsReplica replica;
    late FakeSessionHost host;

    setUp(() async {
      replica = await openTestReplica();
      host = FakeSessionHost(replica);
      await createSpreadsheet(replica, space, title: 'Plan');
    });

    Future<SyncedWorkbookSession> open() async {
      final s = SyncedWorkbookSession.open(
        host,
        itemUuid: space,
        spaceUuid: space,
        role: Role.editor,
      );
      addTearDown(s.dispose);
      await s.opened;
      return s;
    }

    test('when opened offline then it is ready from the replica', () async {
      final s = await open();

      expect(s.loadState.value, isA<WorkbookReady>());
      expect(s.model.spreadsheet.title, 'Plan');
      expect(s.model.sheets.single.rows.length, 50);
      expect(s.syncStatus.value.state, SyncState.offline);
      expect(host.subscribeCalls, 0);
    });

    test('when opened online then it subscribes and takes the role from the '
        'result', () async {
      host.online.value = true;
      host.subscribeResult = subscribed();

      final s = await open();

      expect(host.subscribeCalls, 1);
      expect(s.role.value, Role.editor);
      expect(s.loadState.value, isA<WorkbookReady>());
    });

    test('when a cell is typed then the model updates at once and the cell '
        'row is stored after flush', () async {
      final s = await open();

      final plan = s.execute(setInput(s.model, 2, 3, 'Hello'));
      final sheet = s.model.sheets.single;
      expect(s.model.cellAt(sheet.id, 2, 3)?.content, 's:Hello');
      expect(s.syncStatus.value.state, SyncState.saving);
      await s.flush();

      final id = SheetsIds.cellId(
        sheet.id,
        sheet.rows.idAt(2),
        sheet.columns.idAt(3),
      );
      expect(
        (await Cell.db.findById(
          replica.session,
          UuidValue.fromString(id),
        ))?.content,
        's:Hello',
      );
      expect(plan.changes, isNotEmpty);
      expect(s.syncStatus.value.state, SyncState.offline);
    });

    test('when another device changes a cell then the merge patches the '
        'model and emits a remote batch', () async {
      final s = await open();
      final batches = <WorkbookChangeBatch>[];
      s.remoteBatches.listen(batches.add);
      final remote = await planOnReplica(
        replica,
        (m) => setInput(m, 0, 0, 'Hi'),
      );

      await remoteWrite(replica, remote.changes);
      host.mergesController.add(space);
      await s.ingestRemote();

      final sheet = s.model.sheets.single;
      expect(s.model.cellAt(sheet.id, 0, 0)?.content, 's:Hi');
      expect(batches, isNotEmpty);
      expect(s.fullReloads, 1);
    });

    test('when the device\'s own writes are ingested then no remote batch '
        'is emitted', () async {
      final s = await open();
      final batches = <WorkbookChangeBatch>[];
      s.remoteBatches.listen(batches.add);

      s.execute(setInput(s.model, 1, 1, 'mine'));
      await s.flush();
      await s.ingestRemote();

      expect(batches, isEmpty);
    });

    test('when a remote change arrives while a local edit is queued then the '
        'local edit is kept', () async {
      final s = await open();
      final remote = await planOnReplica(
        replica,
        (m) => setInput(m, 4, 4, 'theirs'),
      );
      await remoteWrite(replica, remote.changes);

      s.execute(setInput(s.model, 4, 4, 'mine'));
      await s.ingestRemote();

      final sheet = s.model.sheets.single;
      expect(s.model.cellAt(sheet.id, 4, 4)?.content, 's:mine');
      await s.flush();
      await s.ingestRemote();
      expect(s.model.cellAt(sheet.id, 4, 4)?.content, 's:mine');
    });

    test(
      'when rows are deleted remotely then their cells leave the model',
      () async {
        final s = await open();
        s.execute(setInput(s.model, 5, 0, 'gone soon'));
        await s.flush();
        final rowId = s.model.sheets.single.rows.idAt(5);
        final remote = await planOnReplica(
          replica,
          (m) => DeleteDimension(m.sheets.first.id, Dimension.rows, [rowId]),
        );

        await remoteWrite(replica, remote.changes);
        await s.ingestRemote();

        final sheet = s.model.sheets.single;
        expect(sheet.rows.length, 49);
        expect(sheet.rows.indexOf(rowId), -1);
        expect(
          s.model.allRows().where((r) => r.$2[CellCols.rowId] == rowId),
          isEmpty,
        );
      },
    );

    test('when the membership is removed then the session becomes '
        'unavailable', () async {
      final s = await open();

      await revokeLocally(replica, space);
      host.mergesController.add(space);
      await s.ingestRemote();

      expect(s.loadState.value, isA<WorkbookUnavailable>());
    });

    test(
      'when the space turns read-only then the role drops to viewer',
      () async {
        final s = await open();

        await grantLocally(replica, space, role: 'readOnly');
        await s.ingestRemote();

        expect(s.role.value, Role.viewer);
        expect(s.canEdit, isFalse);
      },
    );

    test(
      'when a write fails then the model is reloaded from the replica',
      () async {
        final s = await open();
        await grantLocally(replica, space, role: 'readOnly');

        s.execute(setInput(s.model, 0, 0, 'rejected'));
        await s.flush();
        await s.ingestRemote();

        final sheet = s.model.sheets.single;
        expect(s.model.cellAt(sheet.id, 0, 0), isNull);
        expect(s.syncStatus.value.state, SyncState.error);
      },
    );
  });

  group('Given a spreadsheet that is not on the device', () {
    late SheetsReplica replica;
    late FakeSessionHost host;

    setUp(() async {
      replica = await openTestReplica();
      host = FakeSessionHost(replica);
    });

    test('when opened offline then it is unavailable, and it opens by itself '
        'when the connection returns', () async {
      final s = SyncedWorkbookSession.open(
        host,
        itemUuid: space,
        spaceUuid: space,
        settleTimeout: Duration.zero,
      );
      addTearDown(s.dispose);
      await s.opened;
      expect(
        s.loadState.value,
        isA<WorkbookUnavailable>().having((u) => u.offline, 'offline', true),
      );

      // The next sync delivers the space.
      await createSpreadsheet(replica, space, title: 'Arrived');
      host.subscribeResult = subscribed();
      host.online.value = true;
      await s.opened;

      expect(s.loadState.value, isA<WorkbookReady>());
      expect(s.model.spreadsheet.title, 'Arrived');
    });

    test('when opened online then it waits for the download and reports '
        'progress', () async {
      host.online.value = true;
      host.subscribeResult = subscribed(alreadyMember: false, totalRows: 10);
      final states = <WorkbookLoadState>[];
      final s = SyncedWorkbookSession.open(
        host,
        itemUuid: space,
        spaceUuid: space,
        settleTimeout: const Duration(seconds: 30),
      );
      addTearDown(s.dispose);
      s.loadState.addListener(() => states.add(s.loadState.value));

      await createSpreadsheet(replica, space, rows: 5, columns: 3);
      host.mergesController.add(space);
      await s.opened;

      expect(host.kicks, greaterThan(0));
      expect(s.loadState.value, isA<WorkbookReady>());
      expect(s.model.sheets.single.rows.length, 5);
    });
  });
}
