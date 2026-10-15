@Tags(['integration'])
library;

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/platform/spaces/space_service.dart';
import 'package:wonky_server/src/sheets/spaces/spreadsheet_factory.dart';

import '../../support/test_users.dart';
import '../../support/wonky_serverpod.dart';

/// Offline-sync patch OS-9 on PostgreSQL: a synced-schema (registry) change
/// persists the spaces whose foreign key projection it can alter with the
/// change, initialization returns without re-projecting them, a write into
/// a pending space re-projects it first (under the node lock), and the
/// background queue finishes the rest (suite 12 §4). The SQLite engine
/// tests are in `wonky_sheets/test/sync/projection_rebuild_test.dart`.
///
/// A fresh `OfflineSyncDatabaseSession.wraps` has a fresh schema context,
/// so it plays a restarted server; the registry change is staged by editing
/// the stored type identity of `slide.sortKey` (reconciliation rewrites it),
/// a stale projection by hiding a visible row behind the engine's back.
void main() {
  withWonkyServerpod('Given a deck space and a spreadsheet space', (
    sessionBuilder,
    endpoints,
  ) {
    late Session server;
    late TestUser anna;
    late UuidValue deck;
    late UuidValue spreadsheet;
    late UuidValue slide;
    late UuidValue sheet;

    Future<int> visibility(String table, UuidValue id) async {
      final rows = await server.db.unsafeQuery(
        'SELECT r."visibility" FROM "crdt_data_rows" r '
        'JOIN "crdt_schema_tables" t ON t."id" = r."tblId" '
        "WHERE t.\"name\" = '$table' AND r.\"uuidRowId\" = '${id.uuid}'",
      );
      return rows.first.first! as int;
    }

    Future<void> setVisibility(
      String table,
      UuidValue id,
      int value,
    ) => server.db.unsafeExecute(
      'UPDATE "crdt_data_rows" SET "visibility" = $value '
      "WHERE \"uuidRowId\" = '${id.uuid}' AND \"tblId\" = "
      "(SELECT \"id\" FROM \"crdt_schema_tables\" WHERE \"name\" = '$table')",
    );

    /// The persisted marker rows of [space]: `{seed tables}` or none.
    Future<List<String>> markerOf(UuidValue space) async {
      final rows = await server.db.unsafeQuery(
        'SELECT c."dartType" FROM "crdt_schema_columns" c '
        'JOIN "crdt_schema_tables" t ON t."id" = c."tblId" '
        'JOIN "offline_sync_spaces" s '
        "ON c.\"name\" = 'space:' || s.\"id\" "
        "WHERE t.\"name\" = '#projection_rebuild' "
        "AND s.\"uuidSpaceId\" = '${space.uuid}'",
      );
      return [for (final row in rows) row.first! as String];
    }

    setUp(() async {
      server = sessionBuilder.build();
      // Test sessions bypass the database interceptor, so each wrap below
      // gets its own schema context (a "restart").
      expect(server.db, isNot(isA<OfflineSyncDatabase>()));
      OfflineSyncProjectionRebuild.startDelay = const Duration(hours: 1);
      OfflineSyncProjectionRebuild.retryDelay = const Duration(hours: 1);
      OfflineSyncProjectionRebuild.pause = Duration.zero;
      OfflineSyncProjectionRebuild.log = (message, [error, stackTrace]) {};

      anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      deck = await SpaceService.createSpace(
        server,
        anna.actor,
        kind: SpaceKind.deck,
      );
      spreadsheet = await SpaceService.createSpace(
        server,
        anna.actor,
        kind: SpaceKind.spreadsheet,
      );
      final before = OfflineSyncDatabaseSession.wraps(
        server,
        syncTables: syncTables,
      );
      slide = await before.db.transactionForUser(
        anna.authUserId,
        (tx) async {
          await Deck.db.insertRow(
            before,
            Deck(id: deck, title: 'Pitch', createdBy: anna.authUserId),
            transaction: tx,
          );
          final row = await Slide.db.insertRow(
            before,
            Slide(deckId: deck, sortKey: 'a0'),
            transaction: tx,
          );
          return row.id;
        },
        spaceId: deck,
      );
      await SpreadsheetFactory.write(
        server,
        spaceUuid: spreadsheet,
        authorUuid: anna.authUserId,
        title: 'Budget',
      );
      final sheets = await server.db.unsafeQuery(
        'SELECT "id" FROM "sheet" WHERE "spreadsheetId" = '
        "'${spreadsheet.uuid}'",
      );
      sheet = UuidValue.fromString(sheets.first.first.toString());

      await setVisibility('slide', slide, 5);
      await setVisibility('sheet', sheet, 5);
      await server.db.unsafeExecute(
        'UPDATE "crdt_schema_columns" SET "dartType" = \'Object?\' '
        'WHERE "name" = \'sortKey\' AND "tblId" = '
        '(SELECT "id" FROM "crdt_schema_tables" WHERE "name" = \'slide\')',
      );
    });

    tearDown(() async {
      OfflineSyncProjectionRebuild.startDelay = const Duration(seconds: 2);
      OfflineSyncProjectionRebuild.retryDelay = const Duration(seconds: 30);
      OfflineSyncProjectionRebuild.pause = const Duration(milliseconds: 20);
      // The database is not rolled back between tests.
      await setVisibility('sheet', sheet, 0);
    });

    test('when the server restarts with the changed slide table, then only '
        'the deck space is persisted as pending and nothing is re-projected '
        'at startup', () async {
      final restarted = OfflineSyncDatabaseSession.wraps(
        server,
        syncTables: syncTables,
      );
      await restarted.db.initialize();
      addTearDown(() async {
        await restarted.db.drainProjectionRebuild();
        await restarted.db.stopProjectionRebuild();
      });

      expect(restarted.db.pendingProjectionRebuilds, greaterThanOrEqualTo(1));
      expect(await markerOf(deck), ['slide']);
      expect(await markerOf(spreadsheet), isEmpty);
      expect(await visibility('slide', slide), 5);
    });

    test('when a write acts in the pending deck space, then the space is '
        're-projected first, and the background queue finishes the rest '
        'without touching the spreadsheet space', () async {
      final restarted = OfflineSyncDatabaseSession.wraps(
        server,
        syncTables: syncTables,
      );
      await restarted.db.initialize();
      addTearDown(restarted.db.stopProjectionRebuild);

      await restarted.db.transactionForUser(
        anna.authUserId,
        (tx) => Slide.db.insertRow(
          restarted,
          Slide(deckId: deck, sortKey: 'a1'),
          transaction: tx,
        ),
        spaceId: deck,
      );

      expect(await markerOf(deck), isEmpty);
      expect(await visibility('slide', slide), lessThan(3));

      await restarted.db.drainProjectionRebuild();

      expect(restarted.db.pendingProjectionRebuilds, 0);
      expect(await visibility('sheet', sheet), 5);
    });
  });
}
