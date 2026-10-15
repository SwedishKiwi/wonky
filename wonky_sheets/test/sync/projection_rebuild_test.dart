import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    show
        OfflineSyncClient,
        OfflineSyncDatabaseSession,
        OfflineSyncPeerMode,
        OfflineSyncProjectionRebuild;
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_sync_models/tables.dart';

/// Offline-sync patch OS-9: after a synced-schema (registry) change the
/// foreign key projection is rebuilt in the background, only for the spaces
/// holding rows of a changed table, resumably, and on demand before a write
/// or merge into a pending space (suite 12 §4). Two SQLite peers: an
/// authoritative "server" whose replica file is reopened to play a restart,
/// and a follower device; self-contained (no Sheets or Slides replica code).
///
/// A registry change is staged by editing the stored type identity of
/// `slide.sortKey` (reconciliation then rewrites it, as a retyped column
/// would), and a stale projection by hiding a visible row behind the
/// engine's back: a rebuild of that row's space makes it visible again.
final user = UuidValue.fromString('0190a000-0000-7000-8000-00000000a009');
final deckSpace = UuidValue.fromString('0190a000-0000-7000-8000-00000000d001');
final otherDeckSpace = UuidValue.fromString(
  '0190a000-0000-7000-8000-00000000d002',
);
final sheetSpace = UuidValue.fromString('0190a000-0000-7000-8000-00000000c001');
final slideId = UuidValue.fromString('0190a000-0000-7000-8000-00000000e001');
final sheetId = UuidValue.fromString('0190a000-0000-7000-8000-00000000e002');

String hexOf(UuidValue u) => [
  for (final b in Uint8List.fromList(u.toBytes()))
    b.toRadixString(16).padLeft(2, '0'),
].join();

/// A peer over the replica file at [path], syncing every synced table of
/// the generated client or, with [sheetsOnly], the release before Slides.
Future<OfflineSyncDatabaseSession> openPeer(
  String path, {
  UuidValue? as,
  bool sheetsOnly = false,
}) async {
  final client = Client('http://localhost:1/');
  final OfflineSyncDatabaseSession session;
  if (!sheetsOnly) {
    session = await client.createSyncSession(path, persistentUserId: as);
  } else {
    session = OfflineSyncDatabaseSession.wraps(
      await client.createSession(path),
      syncTables: [
        for (final table in syncTables)
          if (!SlidesSyncedTables.byName.containsKey(table.tableName)) table,
      ],
      persistentUserId: as,
    );
    await session.db.initialize();
  }
  addTearDown(session.close);
  return session;
}

Future<void> grant(OfflineSyncDatabaseSession server, UuidValue space) async {
  final db = server.db;
  await db.unsafeExecute(
    'INSERT OR IGNORE INTO "offline_sync_spaces" ("uuidSpaceId") '
    "VALUES (x'${hexOf(space)}')",
  );
  await db.unsafeExecute(
    'INSERT INTO "offline_sync_space_members" ("spaceId", "userUuid", "role") '
    "SELECT \"id\", x'${hexOf(user)}', 'readWrite' FROM "
    "\"offline_sync_spaces\" WHERE \"uuidSpaceId\" = x'${hexOf(space)}'",
  );
}

Future<void> writeDeck(
  OfflineSyncDatabaseSession server,
  UuidValue space, {
  UuidValue? slide,
}) => server.db.transactionForUser(user, (tx) async {
  await Deck.db.insertRow(
    server,
    Deck(id: space, title: 'Pitch', createdBy: user),
    transaction: tx,
  );
  await Slide.db.insertRow(
    server,
    Slide(id: slide, deckId: space, sortKey: 'a0'),
    transaction: tx,
  );
}, spaceId: space);

Future<void> writeSheet(OfflineSyncDatabaseSession server) =>
    server.db.transactionForUser(user, (tx) async {
      await Spreadsheet.db.insertRow(
        server,
        Spreadsheet(
          id: sheetSpace,
          title: 'Budget',
          locale: 'en_US',
          timeZone: 'UTC',
          themeJson: '{}',
          createdBy: user,
        ),
        transaction: tx,
      );
      await Sheet.db.insertRow(
        server,
        Sheet(
          id: sheetId,
          spreadsheetId: sheetSpace,
          name: 'Sheet1',
          sortKey: 'a0',
        ),
        transaction: tx,
      );
    }, spaceId: sheetSpace);

/// The stored `crdt_data_rows.visibility` of row [id] (0–2 visible).
Future<int> visibilityOf(
  OfflineSyncDatabaseSession peer,
  String table,
  UuidValue id,
) async {
  final rows = await peer.db.unsafeQuery(
    'SELECT r."visibility" FROM "crdt_data_rows" r '
    'JOIN "crdt_schema_tables" t ON t."id" = r."tblId" '
    "WHERE t.\"name\" = '$table' AND r.\"uuidRowId\" = x'${hexOf(id)}'",
  );
  return rows.first.first! as int;
}

/// Hides row [id] without a tombstone: a projection that is out of date.
Future<void> hideBehindTheEnginesBack(
  OfflineSyncDatabaseSession peer,
  String table,
  UuidValue id,
) => peer.db.unsafeExecute(
  'UPDATE "crdt_data_rows" SET "visibility" = 5 '
  "WHERE \"uuidRowId\" = x'${hexOf(id)}' AND \"tblId\" = "
  "(SELECT \"id\" FROM \"crdt_schema_tables\" WHERE \"name\" = '$table')",
);

/// Stages a registry change of `slide` (a retyped `sortKey`).
Future<void> retypeSlideSortKey(OfflineSyncDatabaseSession peer) =>
    peer.db.unsafeExecute(
      'UPDATE "crdt_schema_columns" SET "dartType" = \'Object?\' '
      'WHERE "name" = \'sortKey\' AND "tblId" = '
      '(SELECT "id" FROM "crdt_schema_tables" WHERE "name" = \'slide\')',
    );

/// The persisted pending rebuilds (the registry marker's space rows).
Future<int> persistedPending(OfflineSyncDatabaseSession peer) async {
  final rows = await peer.db.unsafeQuery(
    'SELECT count(*) FROM "crdt_schema_columns" c '
    'JOIN "crdt_schema_tables" t ON t."id" = c."tblId" '
    "WHERE t.\"name\" = '#projection_rebuild'",
  );
  return rows.first.first! as int;
}

Future<int> spaceKey(OfflineSyncDatabaseSession peer, UuidValue space) async {
  final rows = await peer.db.unsafeQuery(
    'SELECT "id" FROM "offline_sync_spaces" '
    "WHERE \"uuidSpaceId\" = x'${hexOf(space)}'",
  );
  return rows.first.first! as int;
}

void main() {
  late Directory dir;
  late String serverPath;
  late List<int> rebuilt;
  late List<String> logs;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('wonky_os9_');
    serverPath = '${dir.path}/server.db';
    rebuilt = [];
    logs = [];
    OfflineSyncProjectionRebuild.startDelay = const Duration(hours: 1);
    OfflineSyncProjectionRebuild.pause = Duration.zero;
    OfflineSyncProjectionRebuild.retryDelay = const Duration(hours: 1);
    OfflineSyncProjectionRebuild.debugBeforeSpace = rebuilt.add;
    OfflineSyncProjectionRebuild.log = (message, [error, stackTrace]) =>
        logs.add(error == null ? message : '$message: $error');
  });

  tearDown(() async {
    OfflineSyncProjectionRebuild.startDelay = const Duration(seconds: 2);
    OfflineSyncProjectionRebuild.pause = const Duration(milliseconds: 20);
    OfflineSyncProjectionRebuild.retryDelay = const Duration(seconds: 30);
    OfflineSyncProjectionRebuild.debugBeforeSpace = null;
    // The sessions close in their own tear-downs (registered later, so they
    // run first).
    await dir.delete(recursive: true);
  });

  /// A server replica with a deck space and a spreadsheet space, both with
  /// a stale (hidden) row, and a staged registry change of `slide`; the
  /// returned peer is the reopened ("restarted") replica.
  Future<OfflineSyncDatabaseSession> restartAfterSlideChange() async {
    final before = await openPeer(serverPath);
    await grant(before, deckSpace);
    await grant(before, sheetSpace);
    await writeDeck(before, deckSpace, slide: slideId);
    await writeSheet(before);
    await hideBehindTheEnginesBack(before, 'slide', slideId);
    await hideBehindTheEnginesBack(before, 'sheet', sheetId);
    await retypeSlideSortKey(before);
    await before.close();
    return openPeer(serverPath);
  }

  group('Given a synced-schema change of the slide table', () {
    test('when the replica restarts, then initialization returns before the '
        'rebuild and the pending space is persisted', () async {
      final server = await restartAfterSlideChange();

      expect(server.db.pendingProjectionRebuilds, 1);
      expect(await persistedPending(server), 1);
      expect(rebuilt, isEmpty);
      // Still the stale projection: nothing was re-projected at startup.
      expect(await visibilityOf(server, 'slide', slideId), 5);
    });

    test('when the background rebuild runs, then only the space with slide '
        'rows is re-projected and the marker is cleared', () async {
      final done = Completer<void>();
      OfflineSyncProjectionRebuild.log = (message, [error, stackTrace]) {
        logs.add(message);
        if (message.contains('done')) done.complete();
      };
      OfflineSyncProjectionRebuild.startDelay = Duration.zero;
      final server = await restartAfterSlideChange();

      await done.future.timeout(const Duration(seconds: 30));

      expect(server.db.pendingProjectionRebuilds, 0);
      expect(rebuilt, [await spaceKey(server, deckSpace)]);
      expect(await visibilityOf(server, 'slide', slideId), lessThan(3));
      // The spreadsheet space holds no slide rows: not rebuilt, so the
      // staged staleness is still there.
      expect(await visibilityOf(server, 'sheet', sheetId), 5);
      expect(await persistedPending(server), 0);
      expect(logs.last, contains('done'));
    });

    test('when a rebuild crashes mid-way, then the space stays pending, is '
        'retried, and a restart resumes it', () async {
      final server = await restartAfterSlideChange();
      OfflineSyncProjectionRebuild.debugBeforeSpace = (spaceId) =>
          throw StateError('crash in space $spaceId');

      await server.db.drainProjectionRebuild();

      expect(server.db.pendingProjectionRebuilds, 1);
      expect(await persistedPending(server), 1);
      expect(await visibilityOf(server, 'slide', slideId), 5);
      expect(logs, contains(contains('crash in space')));
      expect(logs.last, contains('retrying'));

      await server.close();
      OfflineSyncProjectionRebuild.debugBeforeSpace = rebuilt.add;
      final restarted = await openPeer(serverPath);
      expect(restarted.db.pendingProjectionRebuilds, 1);

      await restarted.db.drainProjectionRebuild();

      expect(restarted.db.pendingProjectionRebuilds, 0);
      expect(await persistedPending(restarted), 0);
      expect(await visibilityOf(restarted, 'slide', slideId), lessThan(3));
    });

    test('when a write acts in the pending space, then the space is '
        're-projected first and no longer pending', () async {
      final server = await restartAfterSlideChange();
      await grant(server, otherDeckSpace);

      // Another deck space: not pending, nothing to rebuild.
      await writeDeck(server, otherDeckSpace);
      expect(rebuilt, isEmpty);
      expect(server.db.pendingProjectionRebuilds, 1);

      await server.db.transactionForUser(
        user,
        (tx) => Slide.db.insertRow(
          server,
          Slide(deckId: deckSpace, sortKey: 'a1'),
          transaction: tx,
        ),
        spaceId: deckSpace,
      );

      expect(rebuilt, [await spaceKey(server, deckSpace)]);
      expect(server.db.pendingProjectionRebuilds, 0);
      expect(await persistedPending(server), 0);
      expect(await visibilityOf(server, 'slide', slideId), lessThan(3));
    });

    test('when a device syncs and writes into the pending space, then the '
        'merge re-projects it first and both peers converge', () async {
      final server = await restartAfterSlideChange();
      final device = await openPeer('${dir.path}/device.db', as: user);
      Future<void> sync() => OfflineSyncClient(
        ({required changes, required once}) => server.db.sync(
          inbound: changes,
          mode: OfflineSyncPeerMode.authoritative,
          userId: user,
          once: once,
        ),
      ).syncOnce(device);

      await sync();
      final added = UuidValue.fromString(
        '0190a000-0000-7000-8000-00000000e003',
      );
      await device.db.transactionForUser(
        user,
        (tx) => Slide.db.insertRow(
          device,
          Slide(id: added, deckId: deckSpace, sortKey: 'a1'),
          transaction: tx,
        ),
        spaceId: deckSpace,
      );
      await sync();

      expect(server.db.pendingProjectionRebuilds, 0);
      expect(await visibilityOf(server, 'slide', added), lessThan(3));
      expect(await visibilityOf(server, 'slide', slideId), lessThan(3));
      expect(await visibilityOf(device, 'slide', added), lessThan(3));
    });
  });

  test('Given new synced tables without rows, when the replica restarts with '
      'them, then no space needs a rebuild', () async {
    final before = await openPeer(serverPath, sheetsOnly: true);
    await grant(before, sheetSpace);
    await writeSheet(before);
    await before.close();

    final server = await openPeer(serverPath);

    expect(server.db.pendingProjectionRebuilds, 0);
    expect(await persistedPending(server), 0);
    expect(logs, isEmpty);
  });
}
