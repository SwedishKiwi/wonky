import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show Spreadsheet, UuidValue;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets/features/model/workbook_session.dart';
import 'package:wonky_sheets/features/sync/sheets_sync_controller.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import 'support/sync_harness.dart';

final userA = UuidValue.fromString('0190a000-0000-7000-8000-0000000000a1');

void main() {
  group('Given two devices of a user and a sync server', () {
    late FakeSheetsServer server;
    late FakeRemote remoteA;
    late FakeRemote remoteB;
    late FakeConnectivity netA;
    late SheetsSyncController a;
    late SheetsSyncController b;

    setUp(() async {
      server = await FakeSheetsServer.open();
      remoteA = FakeRemote(server, userA);
      remoteB = FakeRemote(server, userA);
      netA = FakeConnectivity();
      a = SheetsSyncController(
        replica: await openTestReplica(user: userA),
        remote: remoteA,
        connectivity: netA,
      );
      b = SheetsSyncController(
        replica: await openTestReplica(user: userA),
        remote: remoteB,
        connectivity: FakeConnectivity(),
      );
      addTearDown(a.stop);
      addTearDown(b.stop);
    });

    test('when reservations are refilled then three spaces are reserved and '
        'usable after the next sync', () async {
      await a.syncNow();
      await a.refillReservations();
      expect(await a.replica.reservations(), hasLength(3));
      expect(await a.replica.usableReservations(), isEmpty);

      await a.syncNow();

      expect(await a.replica.usableReservations(), hasLength(3));
    });

    test('when a spreadsheet is created offline then it syncs to the other '
        'device once online', () async {
      await a.syncNow();
      await a.refillReservations();
      await a.syncNow();
      netA.online.value = false;
      remoteA.offline = true;

      final space = await a.createLocalSpreadsheet(title: 'Offline made');
      expect(await a.replica.hasSpreadsheet(space), isTrue);
      expect(await a.replica.reservations(), hasLength(2));
      expect(await a.replica.dirtySpaces(), [space]);

      remoteA.offline = false;
      netA.online.value = true;
      await a.syncNow();
      await b.syncNow();

      expect(remoteA.ensureCalls.last, [space]);
      expect(await a.replica.dirtySpaces(), isEmpty);
      expect(
        (await Spreadsheet.db.findById(b.replica.session, space))?.title,
        'Offline made',
      );
    });

    test(
      'when no reservation is usable then offline creation is refused',
      () async {
        expect(
          () => a.createLocalSpreadsheet(title: 'x'),
          throwsA(isA<NoReservedSpaceException>()),
        );
      },
    );

    test('when a device edits a cell then the open session on the other '
        'device receives it through continuous sync', () async {
      await a.syncNow();
      await a.refillReservations();
      await a.syncNow();
      final space = await a.createLocalSpreadsheet(title: 'Live');
      await a.syncNow();
      await b.syncNow();
      final sa = a.openSession(
        itemUuid: space,
        spaceUuid: space,
        role: Role.owner,
      );
      final sb = b.openSession(
        itemUuid: space,
        spaceUuid: space,
        role: Role.owner,
      );
      addTearDown(sa.dispose);
      addTearDown(sb.dispose);
      await sa.opened;
      await sb.opened;
      expect(sb.loadState.value, isA<WorkbookReady>());
      a.start();
      b.start();

      final sheet = sa.model.sheets.single;
      sa.execute(
        SetCellInputs(
          sheetId: sheet.id,
          row: 0,
          col: 0,
          inputs: const [
            [CellInput.user('from A')],
          ],
        ),
      );
      await sa.flush();

      await eventually(
        () => sb.model.cellAt(sheet.id, 0, 0)?.content == 's:from A',
        timeout: const Duration(seconds: 20),
      );
      expect(sb.patches, greaterThan(0));
      expect(sb.fullReloads, 1);
    });

    test('when two devices create the same cell offline (value vs bold) '
        'then both columns survive on both devices', () async {
      await a.syncNow();
      await a.refillReservations();
      await a.syncNow();
      final space = await a.createLocalSpreadsheet(title: 'Concurrent');
      await a.syncNow();
      await b.syncNow();
      final ma = await reloadModel(a.replica, space);
      final sheet = ma.sheets.single.id;
      final set = const SheetsMutationPlanner().plan(
        SetCellInputs(
          sheetId: sheet,
          row: 4,
          col: 2,
          inputs: const [
            [CellInput.user('10')],
          ],
        ),
        ma,
        PlanContext(userId: userA.uuid, now: DateTime.utc(2026)),
      );
      await a.writer.write(
        spaceId: space,
        changes: set.changes,
        plan: set,
        label: set.label,
        actorKind: 'user',
        sessionId: 'a',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final mb = await reloadModel(b.replica, space);
      final bold = const SheetsMutationPlanner().plan(
        SetFormat(
          [ResolvedRange(sheet, const GridRect(4, 2, 4, 2))],
          const {FormatAttr.bold: true},
        ),
        mb,
        PlanContext(userId: userA.uuid, now: DateTime.utc(2026)),
      );
      await b.writer.write(
        spaceId: space,
        changes: bold.changes,
        plan: bold,
        label: bold.label,
        actorKind: 'user',
        sessionId: 'b',
      );

      await a.syncNow();
      await b.syncNow();
      await a.syncNow();

      for (final c in [a, b]) {
        final m = await reloadModel(c.replica, space);
        expect(m.cellAt(sheet, 4, 2)?.content, 'n:10');
        expect(m.explicitFormatChain(sheet, 4, 2).has(FormatAttr.bold), isTrue);
      }
    });

    test('when the device goes offline then the sync stream stops, and '
        'edits queue locally until it is back', () async {
      await a.syncNow();
      await a.refillReservations();
      await a.syncNow();
      final space = await a.createLocalSpreadsheet(title: 'Queue');
      await a.syncNow();
      a.start();
      await eventually(() => a.connected.value);

      netA.online.value = false;
      await eventually(() => !a.connected.value);
      final s = a.openSession(
        itemUuid: space,
        spaceUuid: space,
        role: Role.owner,
      );
      addTearDown(s.dispose);
      await s.opened;
      final sheet = s.model.sheets.single;
      s.execute(
        SetCellInputs(
          sheetId: sheet.id,
          row: 1,
          col: 1,
          inputs: const [
            [CellInput.user('queued')],
          ],
        ),
      );
      await s.flush();
      expect(await a.replica.dirtySpaces(), [space]);

      netA.online.value = true;
      await eventually(
        () async => (await a.replica.dirtySpaces()).isEmpty,
        timeout: const Duration(seconds: 20),
      );
      await b.syncNow();
      final m = await reloadModel(b.replica, space);
      expect(m.cellAt(m.sheets.single.id, 1, 1)?.content, 's:queued');
    });
  });
}
