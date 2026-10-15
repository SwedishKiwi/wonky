// Each device runs in its own isolate and syncs over HTTP.
@Tags(['integration'])
@Timeout(Duration(minutes: 2))
library;

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    show OfflineSyncDatabaseAccess, OfflineSyncSessionExtension;
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/platform/spaces/space_kinds.dart';
import 'package:wonky_server/src/platform/spaces/space_service.dart';
import 'package:wonky_server/src/sheets/spaces/spreadsheet_factory.dart';
import 'package:wonky_server/src/sheets/sync/sync_db.dart';

import '../../../support/sheets_device.dart';
import '../../../support/test_users.dart';
import '../../../support/wonky_serverpod.dart';

/// Space kinds (suite 12 §2.6) and the per-endpoint space filter of
/// offline-sync patch OS-8: `sheetsSync.sync` only syncs spreadsheet spaces
/// and the personal space, so a deck space never reaches a Sheets replica.
void main() {
  withWonkyServerpod('Given spaces of both kinds', (sessionBuilder, endpoints) {
    late Session server;

    setUpAll(() {
      server = sessionBuilder.build();
      installDeviceAuthentication(server);
    });

    /// A space of [kind] the user is a member of, holding a spreadsheet
    /// row and its sheets (the content does not matter to the filter).
    Future<UuidValue> filledSpace(TestUser user, SpaceKind kind) async {
      final space = await SpaceService.createSpace(
        server,
        user.actor,
        kind: kind,
      );
      await SpreadsheetFactory.write(
        server,
        spaceUuid: space,
        authorUuid: user.authUserId,
        title: kind.name,
      );
      return space;
    }

    Future<DriveItem> itemFor(
      TestUser owner,
      UuidValue space,
      DriveItemKind kind,
    ) => DriveItem.db.insertRow(
      server,
      DriveItem(
        uuid: space,
        kind: kind,
        name: kind.name,
        ownerId: owner.id,
        contentRef: space,
        createdAt: DateTime.now().toUtc(),
        createdById: owner.id,
        modifiedAt: DateTime.now().toUtc(),
      ),
    );

    test('when the user is a member of a deck space, then the Sheets replica '
        'never receives it, while spreadsheet spaces and the personal space '
        'sync', () async {
      final user = await TestUsers.create(sessionBuilder);
      final sheet = await filledSpace(user, SpaceKind.spreadsheet);
      final deck = await filledSpace(user, SpaceKind.deck);
      final device = await SheetsDevice.open(server, user.authUserId);

      await device.sync();

      expect(await device.isMember(user.authUserId), isTrue);
      expect(await device.isMember(sheet), isTrue);
      expect(await device.title(sheet), 'spreadsheet');
      expect(await device.isMember(deck), isFalse);
      expect(await device.rowCount(deck), 0);

      // Rows written later and a second round change nothing.
      final db = syncSessionOf(server);
      await db.offlineSyncDb.transactionForUser(
        user.authUserId,
        (tx) => Spreadsheet.db.updateById(
          db,
          deck,
          columnValues: (t) => [t.title('renamed')],
          transaction: tx,
        ),
        spaceId: deck,
      );
      await device.sync();
      expect(await device.title(deck), isNull);
      expect(await device.rowCount(deck), 0);
    });

    test('when deck spaces are reserved, then they never reach the Sheets '
        'replica; spreadsheet reservations do', () async {
      final user = await TestUsers.create(sessionBuilder);
      final device = await SheetsDevice.open(server, user.authUserId);

      final decks = await SpaceService.reserveSpaces(
        server,
        user.actor,
        2,
        kind: SpaceKind.deck,
      );
      final sheets = await device.reserveSpaces(1);
      await device.sync();

      expect(await device.isMember(sheets.single), isTrue);
      for (final deck in decks) {
        expect(await device.isMember(deck), isFalse);
      }
      final reservations = await SpaceReservation.db.find(
        server,
        where: (t) => t.userId.equals(user.id),
      );
      expect(
        {for (final r in reservations) r.spaceUuid.uuid: r.kind},
        {
          for (final d in decks) d.uuid: SpaceKind.deck,
          sheets.single.uuid: SpaceKind.spreadsheet,
        },
      );
    });

    test('when a space is registered as a presentation, then its drive item '
        'decides the kind over the reservation, and unrecorded spaces count '
        'as spreadsheets', () async {
      final user = await TestUsers.create(sessionBuilder);
      final reserved = (await SpaceService.reserveSpaces(
        server,
        user.actor,
        1,
      )).single;
      await itemFor(user, reserved, DriveItemKind.presentation);
      // A space created without a recorded kind (v1 style).
      final bare = await server.offlineSync.spaces.createFor(user.authUserId);

      final kinds = await SpaceKinds.recorded(server, [reserved, bare]);

      expect(kinds, {reserved.uuid: SpaceKind.deck});
      expect(await SpaceKinds.of(server, bare), SpaceKind.spreadsheet);
      final filter = SpaceKindFilter(server, SpaceKind.deck);
      expect(await filter([reserved, bare]), [reserved]);
      expect(await filter([reserved, bare]), [reserved]);
      // The recorded kind is cached; the unrecorded space is looked up again.
      expect(filter.lookups, 2);
      expect(await filter([reserved]), [reserved]);
      expect(filter.lookups, 2);
    });

    test('when a reservation of another kind is used, then registration is '
        'refused', () async {
      final user = await TestUsers.create(sessionBuilder);
      final deck = (await SpaceService.reserveSpaces(
        server,
        user.actor,
        1,
        kind: SpaceKind.deck,
      )).single;

      expect(
        () => SpaceService.useReservation(server, user.actor, deck),
        throwsA(isA<WonkyException>()),
      );
      expect(
        await SpaceService.useReservation(
          server,
          user.actor,
          deck,
          kind: SpaceKind.deck,
        ),
        isTrue,
      );
    });

    test('when subscriptions are recorded, then they carry the item\'s kind '
        'and eviction limits apply per kind', () async {
      final user = await TestUsers.create(sessionBuilder);
      final other = await TestUsers.create(sessionBuilder, name: 'Owner');
      final old = DateTime.now().toUtc().subtract(const Duration(days: 60));
      final limit = SpaceService.maxActiveSpaces(SpaceKind.deck);
      // limit + 1 old deck subscriptions (over the deck limit) and one old
      // spreadsheet subscription (well under the spreadsheet limit).
      final deckItems = <DriveItem>[];
      for (var i = 0; i <= limit; i++) {
        final space = await SpaceService.createSpace(
          server,
          other.actor,
          kind: SpaceKind.deck,
        );
        deckItems.add(
          await itemFor(other, space, DriveItemKind.presentation),
        );
      }
      final sheetSpace = await SpaceService.createSpace(
        server,
        other.actor,
        kind: SpaceKind.spreadsheet,
      );
      final sheetItem = await itemFor(
        other,
        sheetSpace,
        DriveItemKind.spreadsheet,
      );
      for (final item in [...deckItems, sheetItem]) {
        await SpaceService.touchSubscription(server, user.id, item);
      }
      await SpaceSubscription.db.updateWhere(
        server,
        columnValues: (t) => [t.lastUsedAt(old)],
        where: (t) => t.userId.equals(user.id),
      );
      final subs = await SpaceSubscription.db.find(
        server,
        where: (t) => t.userId.equals(user.id),
      );
      expect(
        subs.where((s) => s.kind == SpaceKind.deck),
        hasLength(limit + 1),
      );
      expect(
        subs.singleWhere((s) => s.kind == SpaceKind.spreadsheet).spaceUuid,
        sheetSpace,
      );

      await SpaceService.evictInactive(server);

      final left = await SpaceSubscription.db.find(
        server,
        where: (t) => t.userId.equals(user.id),
      );
      expect(left.where((s) => s.kind == SpaceKind.deck), hasLength(limit));
      expect(left.where((s) => s.kind == SpaceKind.spreadsheet), hasLength(1));
    });
  });
}
