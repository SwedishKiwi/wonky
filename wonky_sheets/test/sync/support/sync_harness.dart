import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    show
        OfflineSyncClient,
        OfflineSyncDatabaseSession,
        OfflineSyncPeerMode,
        OfflineSyncTransport;
import 'package:wonky_app/wonky_app.dart' show OfflineException;
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_sheets/features/sync/sheets_remote.dart';
import 'package:wonky_sheets/features/sync/sheets_sync_controller.dart';
import 'package:wonky_sheets/features/sync/sheets_replica.dart';
import 'package:wonky_sheets/features/sync/sheets_session_host.dart';
import 'package:wonky_sheets/features/sync/sheets_writer.dart';

import 'replica_harness.dart';

export 'replica_harness.dart';

/// A [SheetsSessionHost] on a local replica without a server.
class FakeSessionHost implements SheetsSessionHost {
  FakeSessionHost(this.replica, {bool online = false})
    : writer = SheetsWriter(replica),
      online = ValueNotifier(online);

  @override
  final SheetsReplica replica;

  @override
  final SheetsWriter writer;

  @override
  final ValueNotifier<bool> online;

  @override
  String get sessionId => 'test-session';

  final StreamController<UuidValue> mergesController =
      StreamController.broadcast();

  @override
  Stream<UuidValue> get merges => mergesController.stream;

  /// What `subscribe` returns (null = throws offline).
  SubscribeResult? subscribeResult;
  int subscribeCalls = 0;
  int kicks = 0;

  @override
  Future<SubscribeResult> subscribe(UuidValue itemUuid) async {
    subscribeCalls++;
    final r = subscribeResult;
    if (r == null || !online.value) throw const SheetsOfflineException();
    return r;
  }

  @override
  Future<SpaceStats> spaceStats(UuidValue itemUuid) async =>
      subscribeResult?.stats ?? (throw const SheetsOfflineException());

  @override
  void kick() => kicks++;

  @override
  void journalCursorsChanged() {}
}

/// Polls [condition] (real async work: SQLite runs in a worker).
Future<void> eventually(
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met in $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// An in-process "server": an authoritative offline-sync peer on its own
/// SQLite file. Devices sync with it through [transport] like they do with
/// `sheetsSync.sync`; membership is granted with [grant].
class FakeSheetsServer {
  FakeSheetsServer._(this.session);

  static Future<FakeSheetsServer> open() async {
    final dir = await Directory.systemTemp.createTemp('wonky_sheets_server_');
    final session = await Client(
      'http://localhost:1/',
    ).createSyncSession('${dir.path}/server.db');
    addTearDown(() async {
      await session.close();
      await dir.delete(recursive: true);
    });
    return FakeSheetsServer._(session);
  }

  final OfflineSyncDatabaseSession session;

  /// Grants [user] membership of [space].
  Future<void> grant(
    UuidValue user,
    UuidValue space, {
    String role = 'readWrite',
  }) async {
    final db = session.db;
    await db.initialize();
    await db.unsafeExecute(
      'INSERT OR IGNORE INTO "offline_sync_spaces" ("uuidSpaceId") '
      "VALUES (x'${hexOf(space)}')",
    );
    // Update in place, insert only when missing: a sync cycle running
    // between a DELETE and an INSERT would see the membership gone (the real
    // server's grant is an atomic upsert).
    final spaceId =
        "(SELECT \"id\" FROM \"offline_sync_spaces\" WHERE \"uuidSpaceId\" = "
        "x'${hexOf(space)}')";
    await db.unsafeExecute(
      'UPDATE "offline_sync_space_members" SET "role" = \'$role\' WHERE '
      "\"userUuid\" = x'${hexOf(user)}' AND \"spaceId\" = $spaceId",
    );
    await db.unsafeExecute(
      'INSERT INTO "offline_sync_space_members" ("spaceId", "userUuid", "role") '
      "SELECT $spaceId, x'${hexOf(user)}', '$role' WHERE NOT EXISTS ("
      'SELECT 1 FROM "offline_sync_space_members" WHERE '
      "\"userUuid\" = x'${hexOf(user)}' AND \"spaceId\" = $spaceId)",
    );
  }

  /// Removes [user]'s membership of [space].
  Future<void> revoke(UuidValue user, UuidValue space) =>
      session.db.unsafeExecute(
        'DELETE FROM "offline_sync_space_members" WHERE "userUuid" = '
        "x'${hexOf(user)}' AND \"spaceId\" = (SELECT \"id\" FROM "
        "\"offline_sync_spaces\" WHERE \"uuidSpaceId\" = x'${hexOf(space)}')",
      );

  /// The stream transport of [user].
  OfflineSyncTransport transport(UuidValue user) =>
      ({required changes, required once}) => session.db.sync(
        inbound: changes,
        mode: OfflineSyncPeerMode.authoritative,
        userId: user,
        once: once,
      );
}

/// [SheetsRemote] on a [FakeSheetsServer]. [offline] makes every call fail
/// like a network error.
class FakeRemote implements SheetsRemote {
  FakeRemote(this.server, this.user)
    : sync = OfflineSyncClient(
        ({required changes, required once}) =>
            server.transport(user)(changes: changes, once: once),
      );

  final FakeSheetsServer server;
  final UuidValue user;

  @override
  final OfflineSyncClient sync;

  bool offline = false;
  final List<List<UuidValue>> ensureCalls = [];
  int _next = 0x100;

  void _check() {
    if (offline) throw const OfflineException('fake offline');
  }

  @override
  Future<List<UuidValue>> reserveSpaces(int count) async {
    _check();
    final out = <UuidValue>[];
    for (var i = 0; i < count; i++) {
      final space = UuidValue.fromString(
        '0190a000-0000-7000-8000-${(_next++).toRadixString(16).padLeft(12, '0')}',
      );
      await server.grant(user, space);
      out.add(space);
    }
    return out;
  }

  @override
  Future<SubscribeResult> subscribe(UuidValue itemUuid) async {
    _check();
    await server.grant(user, itemUuid);
    return SubscribeResult(
      spaceUuid: itemUuid,
      role: AccessRole.editor,
      canWrite: true,
      alreadyMember: false,
      stats: SpaceStats(
        spaceUuid: itemUuid,
        rowCounts: const {},
        totalRows: 1,
        sheetCount: 1,
        cellCount: 0,
        gridCells: 0,
      ),
    );
  }

  @override
  Future<SpaceStats> spaceStats(UuidValue itemUuid) async =>
      (await subscribe(itemUuid)).stats;

  @override
  Future<List<UuidValue>> ensureSubscribed(List<UuidValue> spaces) async {
    _check();
    ensureCalls.add(spaces);
    return spaces;
  }

  /// Spaces whose `unsubscribe` keeps the membership (owned).
  final Set<UuidValue> owned = {};
  final List<UuidValue> unsubscribeCalls = [];

  @override
  Future<void> unsubscribe(UuidValue itemUuid) async {
    _check();
    unsubscribeCalls.add(itemUuid);
    if (!owned.contains(itemUuid)) await server.revoke(user, itemUuid);
  }
}

/// [SheetsConnectivity] for tests.
class FakeConnectivity implements SheetsConnectivity {
  FakeConnectivity({bool online = true}) : online = ValueNotifier(online);

  @override
  final ValueNotifier<bool> online;

  @override
  void reportFailure() => online.value = false;

  @override
  void reportSuccess() {}
}
