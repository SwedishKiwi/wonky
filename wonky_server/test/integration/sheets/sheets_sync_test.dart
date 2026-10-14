// Each device runs in its own isolate and syncs over HTTP; under a full
// parallel `dart test` run a round trip can exceed the default 30 s.
@Tags(['integration'])
@Timeout(Duration(minutes: 2))
library;

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    show OfflineSyncSessionExtension, OfflineSyncSpaceRole;
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/platform/drive/templates/builtin_templates.dart';
import 'package:wonky_server/src/sheets/changelog/change_log_consumer.dart';
import 'package:wonky_server/src/sheets/sync/sync_db.dart';

import '../../support/sheets_device.dart';
import '../../support/test_drive.dart';
import '../../support/test_users.dart';
import '../../support/wonky_serverpod.dart';

void main() {
  withWonkyServerpod('Given Sheets devices syncing through sheetsSync.sync', (
    sessionBuilder,
    endpoints,
  ) {
    late Session server;

    setUpAll(() {
      server = sessionBuilder.build();
      installDeviceAuthentication(server);
    });

    /// A user with a device and a spreadsheet created the offline way:
    /// reserved space → CreateSpreadsheet written locally →
    /// registerSpreadsheet → sync.
    Future<(TestUser, SheetsDevice, UuidValue)> ownerWithSpreadsheet(
      String title,
    ) async {
      final owner = await TestUsers.create(sessionBuilder, name: 'Owner');
      final device = await SheetsDevice.open(server, owner.authUserId);
      final space = (await device.reserveSpaces(1)).single;
      await device.sync();
      await device.createSpreadsheet(space, title);
      await device.registerSpreadsheet(space, title);
      await device.sync();
      return (owner, device, space);
    }

    Future<DriveItemView> viewOf(TestUser user, UuidValue uuid) =>
        endpoints.drive.get(user.endpointSession, uuid);

    test('when spaces are reserved, then membership arrives with the next '
        'sync', () async {
      final user = await TestUsers.create(sessionBuilder);
      final device = await SheetsDevice.open(server, user.authUserId);

      final spaces = await device.reserveSpaces(3);

      expect(spaces, hasLength(3));
      expect(await device.isMember(spaces.first), isFalse);
      await device.sync();
      expect(await device.isMember(spaces.first), isTrue);
    });

    test('when a spreadsheet is created offline and registered, then the '
        'server has its rows, the drive item uses the space uuid and the '
        'change log is consumed', () async {
      final (owner, device, space) = await ownerWithSpreadsheet('Budget');

      final item = await viewOf(owner, space);
      expect(item.uuid, space);
      expect(item.contentRef, space);
      expect(item.name, 'Budget');
      final db = syncSessionOf(owner.session);
      expect((await Spreadsheet.db.findById(db, space))?.title, 'Budget');
      final sheets = await Sheet.db.find(
        db,
        where: (t) => t.spreadsheetId.equals(space),
      );
      expect(sheets.single.name, 'Sheet1');
      expect(
        await SheetRow.db.count(
          db,
          where: (t) => t.sheetId.equals(sheets.single.id),
        ),
        1000,
      );
      final logs = await ChangeLog.db.find(
        db,
        where: (t) => t.spreadsheetId.equals(space),
      );
      expect(logs, hasLength(1));
      final receipt = await SheetsChangeLogReceipt.db.findFirstRow(
        owner.session,
        where: (t) => t.changeLogId.equals(logs.single.id),
      );
      expect(receipt?.completedAt, isNotNull);
      final row = await DriveItem.db.findFirstRow(
        owner.session,
        where: (i) => i.uuid.equals(space),
      );
      expect(
        await ActivityEvent.db.count(
          owner.session,
          where: (t) =>
              t.itemId.equals(row!.id!) & t.type.equals(ActivityType.edited),
        ),
        1,
      );
    });

    test(
      'when registerSpreadsheet is called twice, then it is idempotent',
      () async {
        final (owner, device, space) = await ownerWithSpreadsheet('Twice');

        final again = await device.registerSpreadsheet(space, 'Twice');

        expect(again.uuid, space);
        expect(
          await DriveItem.db.count(
            owner.session,
            where: (t) => t.contentRef.equals(space),
          ),
          1,
        );
      },
    );

    test('when a space is not reserved for the caller, then registering it '
        'is forbidden', () async {
      final (_, _, space) = await ownerWithSpreadsheet('Mine');
      final other = await TestUsers.create(sessionBuilder, name: 'Other');
      final device = await SheetsDevice.open(server, other.authUserId);

      // The space is already registered: the existing item is returned only
      // to users with access.
      expect(
        () => device.registerSpreadsheet(space, 'Stolen'),
        throwsA(isA<SheetsDeviceException>()),
      );
      final own = (await device.reserveSpaces(1)).single;
      final third = await TestUsers.create(sessionBuilder);
      await expectLater(
        endpoints.drive.registerSpreadsheet(
          third.endpointSession,
          own,
          null,
          'Not yours',
        ),
        throwsA(anything),
      );
    });

    test('when an editor subscribes and edits a cell, then the owner\'s '
        'device receives it', () async {
      final (owner, ownerDevice, space) = await ownerWithSpreadsheet('Team');
      final editor = await TestUsers.create(sessionBuilder, name: 'Editor');
      final item = await viewOf(owner, space);
      await TestDrive.share(endpoints, item, owner, editor, AccessRole.editor);
      final editorDevice = await SheetsDevice.open(server, editor.authUserId);

      final sub = await editorDevice.subscribe(item.uuid);
      expect(sub.spaceUuid, space);
      expect(sub.canWrite, isTrue);
      expect(sub.role.name, AccessRole.editor.name);
      expect(sub.stats.sheetCount, 1);
      await editorDevice.sync();
      expect(await editorDevice.title(space), 'Team');

      await editorDevice.setCell(space, 0, 0, 'Hello');
      await ownerDevice.setCell(space, 0, 1, 'World');
      await editorDevice.sync();
      await ownerDevice.sync();
      await editorDevice.sync();

      expect(await ownerDevice.cell(space, 0, 0), 's:Hello');
      expect(await editorDevice.cell(space, 0, 1), 's:World');
      expect(await ownerDevice.lastMerged(), contains(space.uuid));
    });

    test('when the same cell is edited on two devices, then both converge '
        'to one value', () async {
      final (owner, ownerDevice, space) = await ownerWithSpreadsheet('Race');
      final second = await SheetsDevice.open(server, owner.authUserId);
      await second.sync();

      await ownerDevice.setCell(space, 2, 2, 'first');
      await second.setCell(space, 2, 2, 'second');
      await ownerDevice.sync();
      await second.sync();
      await ownerDevice.sync();

      final a = await ownerDevice.cell(space, 2, 2);
      expect(a, await second.cell(space, 2, 2));
      expect(['s:first', 's:second'], contains(a));
    });

    test('when sharing changes, then the space role is mirrored', () async {
      final (owner, _, space) = await ownerWithSpreadsheet('Roles');
      final bo = await TestUsers.create(sessionBuilder, name: 'Bo');
      final item = await viewOf(owner, space);
      await TestDrive.share(endpoints, item, owner, bo, AccessRole.viewer);
      final device = await SheetsDevice.open(server, bo.authUserId);

      final sub = await device.subscribe(item.uuid);
      await device.sync();

      expect(sub.canWrite, isFalse);
      expect(
        await server.offlineSync.spaces.roleOf(
          user: bo.authUserId,
          space: space,
        ),
        OfflineSyncSpaceRole.readOnly,
      );
      expect(
        () => device.setCell(space, 0, 0, 'nope'),
        throwsA(isA<SheetsDeviceException>()),
      );

      await endpoints.sharing.updateRole(
        owner.endpointSession,
        item.uuid,
        bo.id,
        AccessRole.editor,
      );
      expect(
        await server.offlineSync.spaces.roleOf(
          user: bo.authUserId,
          space: space,
        ),
        OfflineSyncSpaceRole.readWrite,
      );
      await device.sync();
      await device.setCell(space, 0, 0, 'now ok');
      await device.sync();

      await endpoints.sharing.remove(owner.endpointSession, item.uuid, bo.id);
      expect(
        await server.offlineSync.spaces.roleOf(
          user: bo.authUserId,
          space: space,
        ),
        isNull,
      );
      await device.sync();
      expect(await device.isMember(space), isFalse);
    });

    test('when a spreadsheet is renamed on a device, then the drive item is '
        'renamed, and a drive rename reaches the devices', () async {
      final (owner, device, space) = await ownerWithSpreadsheet('Before');

      await device.rename(space, 'After');
      await device.sync();
      expect((await viewOf(owner, space)).name, 'After');

      await endpoints.drive.rename(owner.endpointSession, space, 'Drive name');
      await device.sync();
      expect(await device.title(space), 'Drive name');
    });

    test('when a spreadsheet is created on the server, then its item uuid is '
        'the space and a device downloads it after subscribing', () async {
      final user = await TestUsers.create(sessionBuilder);
      final view = await endpoints.drive.createSpreadsheet(
        user.endpointSession,
        null,
        'Server made',
        null,
      );
      final device = await SheetsDevice.open(server, user.authUserId);

      expect(view.uuid, view.contentRef);
      final sub = await device.subscribe(view.uuid);
      await device.sync();

      expect(sub.alreadyMember, isTrue);
      expect(await device.title(view.uuid), 'Server made');
      expect(
        await device.rowCount(view.uuid),
        (sub.stats.rowCounts['spreadsheet'] ?? 0) +
            (sub.stats.rowCounts['sheet'] ?? 0) +
            (sub.stats.rowCounts['sheet_row'] ?? 0) +
            (sub.stats.rowCounts['sheet_column'] ?? 0) +
            (sub.stats.rowCounts['cell'] ?? 0),
      );
    });

    test('when a spreadsheet is created from a template and copied, then '
        'both download with their cells', () async {
      final user = await TestUsers.create(sessionBuilder);
      final view = await endpoints.drive.createSpreadsheet(
        user.endpointSession,
        null,
        'Budget',
        BuiltinTemplates.byKey('sheets.monthly-budget').uuid,
      );
      final copy = await endpoints.drive.copy(
        user.endpointSession,
        view.uuid,
        'Budget copy',
        null,
        false,
        false,
      );
      final device = await SheetsDevice.open(server, user.authUserId);

      await device.sync();

      expect(copy.uuid, copy.contentRef);
      expect(await device.title(view.uuid), 'Budget');
      expect(await device.title(copy.uuid), 'Budget copy');
      expect(await device.cell(view.uuid, 0, 0), isNotNull);
      expect(
        await device.cell(copy.uuid, 0, 0),
        await device.cell(view.uuid, 0, 0),
      );
    });

    test(
      'when an editor unsubscribes, then the space leaves the device',
      () async {
        final (owner, _, space) = await ownerWithSpreadsheet('Leave');
        final bo = await TestUsers.create(sessionBuilder, name: 'Bo');
        final item = await viewOf(owner, space);
        await TestDrive.share(endpoints, item, owner, bo, AccessRole.editor);
        final device = await SheetsDevice.open(server, bo.authUserId);
        await device.subscribe(item.uuid);
        await device.sync();
        expect(await device.isMember(space), isTrue);

        await endpoints.sheets.unsubscribe(bo.endpointSession, item.uuid);
        await device.sync();

        expect(await device.isMember(space), isFalse);
      },
    );

    test('when a shared spreadsheet is trashed, then collaborators lose the '
        'space and the owner keeps it', () async {
      final (owner, ownerDevice, space) = await ownerWithSpreadsheet('Trash');
      final bo = await TestUsers.create(sessionBuilder, name: 'Bo');
      final item = await viewOf(owner, space);
      await TestDrive.share(endpoints, item, owner, bo, AccessRole.editor);
      final device = await SheetsDevice.open(server, bo.authUserId);
      await device.subscribe(item.uuid);
      await device.sync();

      await endpoints.drive.trash(owner.endpointSession, [item.uuid]);
      await device.sync();
      await ownerDevice.sync();

      expect(await device.isMember(space), isFalse);
      expect(await ownerDevice.isMember(space), isTrue);
    });

    test('when local changes exist for a revoked space, then '
        'ensureSubscribed re-grants it while access remains', () async {
      final (owner, device, space) = await ownerWithSpreadsheet('Guard');
      final sub = await SpaceSubscription.db.findFirstRow(
        owner.session,
        where: (t) => t.spaceUuid.equals(space),
      );
      expect(sub, isNotNull);

      final granted = await endpoints.sheets.ensureSubscribed(
        owner.endpointSession,
        [space, const Uuid().v7obj()],
      );

      expect(granted, [space]);
    });
  });

  withWonkyServerpod('Given synced change log rows', (
    sessionBuilder,
    endpoints,
  ) {
    late Session server;

    setUpAll(() {
      server = sessionBuilder.build();
      installDeviceAuthentication(server);
    });

    test('when the consumer runs again (restart), then no row is consumed '
        'twice, and a claim that never completed is retried', () async {
      final owner = await TestUsers.create(sessionBuilder, name: 'Owner');
      final device = await SheetsDevice.open(server, owner.authUserId);
      final space = (await device.reserveSpaces(1)).single;
      await device.sync();
      await device.createSpreadsheet(space, 'Log');
      await device.setCell(space, 0, 0, 'a');
      await device.setCell(space, 0, 1, 'b');
      await device.sync();
      // Not registered yet: nothing is consumed.
      expect(
        await SheetsChangeLogReceipt.db.count(
          server,
          where: (t) => t.spaceUuid.equals(space),
        ),
        0,
      );

      await device.registerSpreadsheet(space, 'Log');
      expect(
        await SheetsChangeLogReceipt.db.count(
          server,
          where: (t) =>
              t.spaceUuid.equals(space) & t.completedAt.notEquals(null),
        ),
        3,
      );
      expect(await ChangeLogConsumer.processSpace(server, space), 0);

      // A server stopped between claiming and completing one row.
      final receipt = (await SheetsChangeLogReceipt.db.find(
        server,
        where: (t) => t.spaceUuid.equals(space),
      )).first;
      await SheetsChangeLogReceipt.db.updateRow(
        server,
        receipt.copyWith(
          completedAt: null,
          processedAt: DateTime.now().toUtc().subtract(
            ChangeLogConsumer.staleClaim + const Duration(minutes: 1),
          ),
        ),
      );
      expect(await ChangeLogConsumer.processSpace(server, space), 1);
      expect(await ChangeLogConsumer.processSpace(server, space), 0);
    });
  });
}
