import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    show
        OfflineSyncClient,
        OfflineSyncDatabaseSession,
        OfflineSyncPeerMode,
        OfflineSyncSpaceFilter,
        OfflineSyncSpaceMembership;
import 'package:wonky_client/wonky_client.dart';

/// Offline-sync patch OS-8: an authoritative peer's `spaceFilter` decides
/// which shared member spaces a sync session cycles (the server's
/// `sheetsSync` keeps spreadsheet spaces, `slidesSync` deck spaces; suite 12
/// §2.6). Two SQLite peers: an authoritative "server" and a follower device,
/// self-contained (no Sheets replica code), so the test exercises the
/// engine only.
final user = UuidValue.fromString('0190a000-0000-7000-8000-00000000a001');
final sheetSpace = UuidValue.fromString('0190a000-0000-7000-8000-00000000b001');
final deckSpace = UuidValue.fromString('0190a000-0000-7000-8000-00000000b002');
final lateSpace = UuidValue.fromString('0190a000-0000-7000-8000-00000000b003');

String hexOf(UuidValue u) => [
  for (final b in Uint8List.fromList(u.toBytes()))
    b.toRadixString(16).padLeft(2, '0'),
].join();

Future<OfflineSyncDatabaseSession> openPeer(
  String name, {
  UuidValue? as,
}) async {
  final dir = await Directory.systemTemp.createTemp('wonky_os8_$name');
  final session = await Client(
    'http://localhost:1/',
  ).createSyncSession('${dir.path}/$name.db', persistentUserId: as);
  addTearDown(() async {
    await session.close();
    await dir.delete(recursive: true);
  });
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

/// Writes a spreadsheet row into [space] on the server.
Future<void> writeRow(
  OfflineSyncDatabaseSession server,
  UuidValue space,
  String title,
) => server.db.transactionForUser(
  user,
  (tx) => Spreadsheet.db.insertRow(
    server,
    Spreadsheet(
      id: space,
      title: title,
      locale: 'en_US',
      timeZone: 'UTC',
      themeJson: '{}',
      createdBy: user,
    ),
    transaction: tx,
  ),
  spaceId: space,
);

/// Rows of [space] stored on [peer] (raw, ignoring visibility).
Future<int> storedRows(OfflineSyncDatabaseSession peer, UuidValue space) async {
  final rows = await peer.db.unsafeQuery(
    'SELECT count(*) FROM "spreadsheet" WHERE "id" = x\'${hexOf(space)}\'',
  );
  return rows.first.first! as int;
}

Future<bool> isMember(OfflineSyncDatabaseSession peer, UuidValue space) async =>
    await OfflineSyncSpaceMembership.roleOf(
      peer,
      userUuid: user,
      spaceUuid: space,
    ) !=
    null;

void main() {
  late OfflineSyncDatabaseSession server;
  late OfflineSyncDatabaseSession device;
  late List<List<String>> filterCalls;
  late Set<String> decks;

  /// Keeps every space that is not a "deck" (as `sheetsSync` does).
  late OfflineSyncSpaceFilter sheetsFilter;

  Future<void> sync({OfflineSyncSpaceFilter? filter}) => OfflineSyncClient(
    ({required changes, required once}) => server.db.sync(
      inbound: changes,
      mode: OfflineSyncPeerMode.authoritative,
      userId: user,
      once: once,
      spaceFilter: filter,
    ),
  ).syncOnce(device);

  setUp(() async {
    server = await openPeer('server');
    device = await openPeer('device', as: user);
    filterCalls = [];
    decks = {deckSpace.uuid};
    sheetsFilter = (spaces) {
      filterCalls.add([for (final s in spaces) s.uuid]);
      return spaces.where((s) => !decks.contains(s.uuid));
    };
    await grant(server, sheetSpace);
    await grant(server, deckSpace);
    await writeRow(server, sheetSpace, 'Budget');
    await writeRow(server, deckSpace, 'Pitch');
  });

  group('Given a user who is a member of a spreadsheet and a deck space', () {
    test('when the sync filters out the deck, then the device never receives '
        'it and keeps the spreadsheet and the personal space', () async {
      await sync(filter: sheetsFilter);
      await sync(filter: sheetsFilter);

      expect(await isMember(device, sheetSpace), isTrue);
      expect(await storedRows(device, sheetSpace), 1);
      expect(await isMember(device, user), isTrue);
      expect(await isMember(device, deckSpace), isFalse);
      expect(await storedRows(device, deckSpace), 0);
      // The filter only sees shared spaces, never the personal space.
      expect(filterCalls, isNotEmpty);
      for (final call in filterCalls) {
        expect(call, isNot(contains(user.uuid)));
        expect(call, containsAll([sheetSpace.uuid, deckSpace.uuid]));
      }
    });

    test('when no filter is given, then every member space syncs '
        '(unpatched behavior)', () async {
      await sync();

      expect(await storedRows(device, sheetSpace), 1);
      expect(await storedRows(device, deckSpace), 1);
    });

    test('when a membership is granted later, then the filter decides on it '
        'in the next session', () async {
      await sync(filter: sheetsFilter);
      await grant(server, lateSpace);
      await writeRow(server, lateSpace, 'Late');
      decks.add(lateSpace.uuid);

      await sync(filter: sheetsFilter);

      expect(filterCalls.last, contains(lateSpace.uuid));
      expect(await storedRows(device, lateSpace), 0);
      expect(await storedRows(device, sheetSpace), 1);
    });

    test('when the filter drops a space that was synced before, then the '
        'device loses its membership', () async {
      decks.clear();
      await sync(filter: sheetsFilter);
      expect(await isMember(device, deckSpace), isTrue);

      decks.add(deckSpace.uuid);
      await sync(filter: sheetsFilter);

      expect(await isMember(device, deckSpace), isFalse);
      expect(await isMember(device, sheetSpace), isTrue);
    });

    test('when a follower passes a filter, then the sync is refused', () {
      expect(
        () => device.db
            .sync(
              inbound: const Stream.empty(),
              mode: OfflineSyncPeerMode.follower,
              spaceFilter: sheetsFilter,
            )
            .drain<void>(),
        throwsArgumentError,
      );
    });
  });
}
