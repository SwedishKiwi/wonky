import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart' show MemoryStore;
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sheets/features/sync/sheets_sync_controller.dart';
import 'package:wonky_sheets/features/sync/sheets_writer.dart';
import 'package:wonky_sheets_core/model.dart';

import 'support/sync_harness.dart';

final userA = UuidValue.fromString('0190a000-0000-7000-8000-0000000000a1');

void main() {
  late FakeSheetsServer server;
  late FakeRemote remote;

  setUp(() async {
    server = await FakeSheetsServer.open();
    remote = FakeRemote(server, userA);
  });

  Future<SheetsSyncController> device({
    int? cellCap,
    Map<String, DateTime> opened = const {},
    MemoryStore? store,
  }) async {
    final c = SheetsSyncController(
      replica: await openTestReplica(user: userA),
      remote: remote,
      connectivity: FakeConnectivity(),
      cellCap: cellCap,
      lastOpened: () async => opened,
      maintenanceStore: store,
    );
    addTearDown(c.stop);
    return c;
  }

  /// Rows of [space] stored on [c]'s disk (visible or hidden).
  Future<int> storedRows(SheetsSyncController c, UuidValue space) async {
    final key = await c.replica.spaceKey(space);
    if (key == null) return 0;
    final r = await c.replica.db.unsafeQuery(
      'SELECT (SELECT count(*) FROM "cell" WHERE "spaceId" = $key) + '
      '(SELECT count(*) FROM "spreadsheet" WHERE "spaceId" = $key)',
    );
    return r.first[0]! as int;
  }

  /// A spreadsheet with [cells] filled cells, created on [c] and synced.
  Future<UuidValue> spreadsheet(SheetsSyncController c, int cells) async {
    await c.refillReservations();
    await c.syncNow();
    final space = await c.createLocalSpreadsheet(title: 'S$cells');
    final model = await reloadModel(c.replica, space);
    final plan = const SheetsMutationPlanner().plan(
      SetCellInputs(
        sheetId: model.sheets.single.id,
        row: 0,
        col: 0,
        inputs: [
          for (var r = 0; r < cells ~/ 2; r++)
            [CellInput.user('a$r'), CellInput.user('b$r')],
        ],
      ),
      model,
      PlanContext(userId: userA.uuid, now: DateTime.utc(2026, 10, 3)),
    );
    await SheetsWriter(c.replica).write(
      spaceId: space,
      changes: plan.changes,
      plan: plan,
      label: plan.label,
      actorKind: 'user',
      sessionId: 'test',
    );
    await c.syncNow();
    return space;
  }

  test('Given a spreadsheet the device is no longer a member of, when the '
      'hidden spaces are purged then its rows are gone, and a new grant '
      'downloads it completely again', () async {
    final a = await device();
    final space = await spreadsheet(a, 20);
    final before = canonical(await reloadModel(a.replica, space));

    await server.revoke(userA, space);
    await a.syncNow();
    final purged = await a.purgeHiddenSpaces();

    expect(purged, [space]);
    expect(await storedRows(a, space), 0);
    expect((await a.replica.cellCountsBySpace())[space], isNull);

    await server.grant(userA, space);
    await a.syncNow();
    await a.syncNow();

    expect(canonical(await reloadModel(a.replica, space)), before);
  });

  test('Given hidden spaces with unsynced writes, when purging then they '
      'are kept', () async {
    final a = await device();
    final space = await spreadsheet(a, 4);
    await server.revoke(userA, space);
    await a.syncNow();
    await a.replica.markDirty(space);

    expect(await a.purgeHiddenSpaces(), isEmpty);
    expect(await storedRows(a, space), greaterThan(0));
  });

  test('Given the weekly purge ran recently, when maintenance runs then it '
      'does not purge again until a week has passed', () async {
    final store = MemoryStore();
    final a = await device(store: store);
    final space = await spreadsheet(a, 4);
    await a.runMaintenance();
    await server.revoke(userA, space);
    await a.syncNow();

    await a.runMaintenance();
    expect(await storedRows(a, space), greaterThan(0));

    await store.write(
      'sheets.lastPurge',
      DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
    );
    await a.runMaintenance();
    expect(await storedRows(a, space), 0);
  });

  test('Given a cell cap, when the device holds more cells then the '
      'spreadsheets opened least recently leave it; owned ones stay and are '
      'not asked again', () async {
    final opened = <String, DateTime>{};
    final a = await device(cellCap: 85, opened: opened);
    final owned = await spreadsheet(a, 40);
    final old = await spreadsheet(a, 40);
    final recent = await spreadsheet(a, 40);
    opened[owned.uuid] = DateTime(2026, 1, 1);
    opened[old.uuid] = DateTime(2026, 2, 1);
    opened[recent.uuid] = DateTime(2026, 10, 1);
    remote.owned.add(owned);

    await a.enforceCellCap();
    expect(remote.unsubscribeCalls, [owned]);
    await a.syncNow();
    await a.enforceCellCap();
    expect(remote.unsubscribeCalls, [owned, old]);
    await a.syncNow();
    await a.purgeHiddenSpaces();

    final counts = await a.replica.cellCountsBySpace();
    expect(counts.keys, unorderedEquals([owned, recent]));
    await a.enforceCellCap();
    expect(remote.unsubscribeCalls, [owned, old]);
  });
}
