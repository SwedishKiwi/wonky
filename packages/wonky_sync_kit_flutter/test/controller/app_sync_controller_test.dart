import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    show OfflineSyncClient;
import 'package:wonky_app/wonky_app.dart' show OfflineException;
import 'package:wonky_client/wonky_client.dart'
    show SpaceStats, SubscribeResult, UuidValue;
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart';

import '../support/kit_harness.dart';

/// Space calls without a server; the sync stream is never started here.
class _Remote implements SyncRemote {
  _Remote(this.replica);

  final SyncReplica replica;
  bool offline = false;
  final List<UuidValue> unsubscribed = [];
  int _next = 0x900;

  @override
  final OfflineSyncClient sync = OfflineSyncClient(
    ({required changes, required once}) => throw UnimplementedError(),
  );

  void _check() {
    if (offline) throw const OfflineException('fake offline');
  }

  @override
  Future<List<UuidValue>> reserveSpaces(int count) async {
    _check();
    return [for (var i = 0; i < count; i++) space(_next++)];
  }

  @override
  Future<SubscribeResult> subscribe(UuidValue itemUuid) async {
    _check();
    return subscribed(itemUuid);
  }

  @override
  Future<SpaceStats> spaceStats(UuidValue itemUuid) async {
    _check();
    return subscribed(itemUuid).stats;
  }

  @override
  Future<List<UuidValue>> ensureSubscribed(List<UuidValue> spaces) async =>
      spaces;

  @override
  Future<void> unsubscribe(UuidValue itemUuid) async {
    _check();
    unsubscribed.add(itemUuid);
    await revokeLocally(replica, itemUuid);
  }
}

typedef _Controller =
    AppSyncController<SyncReplica, RecordingWriter, HostedSpaceSession>;

void main() {
  late SyncReplica replica;
  late _Remote remote;
  late FakeConnectivity connectivity;

  _Controller controller({
    DeviceRowCap? rowCap,
    Map<String, DateTime>? opened,
  }) {
    final c = _Controller(
      replica: replica,
      writer: RecordingWriter(replica),
      remote: remote,
      connectivity: connectivity,
      name: 'test',
      rowCap: rowCap,
      lastOpened: opened == null ? null : () async => opened,
      random: Random(1),
    );
    addTearDown(c.stop);
    return c;
  }

  setUp(() async {
    replica = await openTestReplica();
    remote = _Remote(replica);
    connectivity = FakeConnectivity();
  });

  group('Given a device without reservations', () {
    test('when creating a file then it needs the connection', () async {
      final c = controller();

      expect(
        c.createInReservedSpace((_) async {}),
        throwsA(isA<NoReservedSpaceException>()),
      );
    });

    test('when the pool is refilled then three spaces are reserved and a '
        'cycle is asked for', () async {
      final c = controller();

      await c.refillReservations();

      expect(await replica.reservedSpaces(), hasLength(3));
    });

    test('when refilling offline then the failure is reported', () async {
      final c = controller();
      remote.offline = true;

      await c.refillReservations();

      expect(await replica.reservedSpaces(), isEmpty);
      expect(connectivity.failures, 1);
    });
  });

  test('Given a usable reservation, when a file is created then it is '
      'written into that space and the reservation is used up', () async {
    final c = controller();
    await c.refillReservations();
    final first = (await replica.reservedSpaces()).first;
    await grantLocally(replica, first);

    final created = await c.createInReservedSpace(
      (s) => c.writer.write(
        spaceId: s,
        changes: [rootRow(s)],
        label: 'Create',
        actorKind: 'user',
        sessionId: c.sessionId,
      ),
    );

    expect(created, first);
    expect(await replica.hasRoot(first), isTrue);
    expect(await replica.reservedSpaces(), isNot(contains(first)));
  });

  group('Given three files on a device capped at four child rows', () {
    setUp(() async {
      final writer = RecordingWriter(replica);
      await createFile(replica, writer, space(1), children: 2);
      await createFile(replica, writer, space(2), children: 2);
      await createFile(replica, writer, space(3), children: 2);
      await replica.clearDirty([space(1), space(2), space(3)], DateTime.now());
    });

    test('when the cap is enforced then the least recently opened file '
        'leaves the device', () async {
      final c = controller(
        rowCap: const DeviceRowCap(table: 'sheet', maxRows: 4),
        opened: {
          space(1).uuid: DateTime.utc(2026, 3),
          space(2).uuid: DateTime.utc(2026, 1),
          space(3).uuid: DateTime.utc(2026, 2),
        },
      );

      await c.enforceRowCap();
      final purged = await c.purgeHiddenSpaces();

      expect(remote.unsubscribed, [space(2)]);
      expect(c.evicted, [space(2)]);
      expect(purged, [space(2)]);
      expect(await replica.hasRoot(space(2)), isFalse);
    });

    test('when a hidden file still has unsynced writes then it is not '
        'purged', () async {
      final c = controller();
      await revokeLocally(replica, space(1));
      await replica.markDirty(space(1));

      expect(await c.purgeHiddenSpaces(), isEmpty);
      expect(await replica.rowCounts(space(1)), isNotEmpty);
    });
  });

  group('Given the controller offline', () {
    test('when subscribing then it fails as offline', () async {
      connectivity.online.value = false;
      final c = controller();

      expect(c.subscribe(space(1)), throwsA(isA<SyncOfflineException>()));
    });

    test('when backing off then the delay doubles up to 30 s with jitter', () {
      final c = controller();

      expect(c.backoff(1).inMilliseconds, inInclusiveRange(800, 1200));
      expect(c.backoff(3).inMilliseconds, inInclusiveRange(3200, 4800));
      expect(c.backoff(10).inMilliseconds, inInclusiveRange(24000, 36000));
    });
  });
}
