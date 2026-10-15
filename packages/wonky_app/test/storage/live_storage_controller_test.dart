import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

const _mb = 1024 * 1024;

/// `LiveStorageController` (D-11, Drive 03 §3, §6): the usage from
/// `drive.storageUsage`, live `storageChanged` events, refreshes on drive
/// refreshes, the per-user offline cache and the `drive.checkRoom`
/// pre-check.
void main() {
  late MemoryStore cache;
  late StreamController<DriveChange> changes;
  late ValueNotifier<int> refreshSignal;
  late List<StorageUsage Function()> answers;
  late int fetches;
  late List<(int, UuidValue?)> checks;
  late LiveStorageController c;

  StorageUsage usage(int used) => FakeStorage.usageOf(used);

  setUp(() {
    cache = MemoryStore();
    changes = StreamController<DriveChange>.broadcast();
    refreshSignal = ValueNotifier(0);
    answers = [];
    fetches = 0;
    checks = [];
    c = LiveStorageController(
      fetch: () async {
        final i = fetches++;
        return answers[i < answers.length ? i : answers.length - 1]();
      },
      checkRoom: (bytes, itemUuid) async => checks.add((bytes, itemUuid)),
      cache: () => cache,
      refreshDelay: Duration.zero,
    );
  });

  tearDown(() async {
    c.dispose();
    await changes.close();
  });

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  group('Given a signed-in user', () {
    test('when the controller starts then it fetches the usage and caches '
        'it', () async {
      answers.add(() => usage(12 * _mb));

      await c.start(changes: changes.stream, refreshSignal: refreshSignal);

      expect(c.value?.bytesUsed, 12 * _mb);
      expect(c.stale, isFalse);
      final cached = await cache.read(LiveStorageController.cacheKey);
      expect((cached! as Map)['bytesUsed'], 12 * _mb);
    });

    test('when a storageChanged event arrives then the value follows it '
        'without a fetch', () async {
      answers.add(() => usage(46 * _mb));
      await c.start(changes: changes.stream);
      var notified = 0;
      c.addListener(() => notified++);

      changes.add(
        DriveChange(
          kind: DriveChangeKind.storageChanged,
          itemUuid: UuidValue.fromString(
            '00000000-0000-0000-0000-000000000000',
          ),
          storage: usage(10 * _mb),
        ),
      );
      await settle();

      expect(c.value?.bytesUsed, 10 * _mb);
      expect(fetches, 1);
      expect(notified, 1);
    });

    test(
      'when other drive events arrive then the value is unchanged',
      () async {
        answers.add(() => usage(5 * _mb));
        await c.start(changes: changes.stream);

        changes.add(
          DriveChange(
            kind: DriveChangeKind.trashed,
            itemUuid: UuidValue.fromString(
              '0190f2d0-0000-7000-8000-000000000001',
            ),
          ),
        );
        await settle();

        expect(c.value?.bytesUsed, 5 * _mb);
        expect(fetches, 1);
      },
    );

    test('when the drive refreshes (reconnect, empty trash) then the usage '
        'is fetched again', () async {
      answers
        ..add(() => usage(48 * _mb))
        ..add(() => usage(30 * _mb));
      await c.start(changes: changes.stream, refreshSignal: refreshSignal);

      refreshSignal.value++;
      await settle();

      expect(fetches, 2);
      expect(c.value?.bytesUsed, 30 * _mb);
    });

    test(
      'when an endpoint reports a usage then it replaces the value',
      () async {
        answers.add(() => usage(1 * _mb));
        await c.start(changes: changes.stream);

        c.report(usage(3 * _mb));

        expect(c.value?.bytesUsed, 3 * _mb);
      },
    );

    test('when a pre-check runs then drive.checkRoom gets the bytes and the '
        'item', () async {
      final item = UuidValue.fromString('0190f2d0-0000-7000-8000-000000000002');

      await c.checkRoom(2 * _mb, itemUuid: item);

      expect(checks, [(2 * _mb, item)]);
    });

    test('when the user signs out then the value is forgotten and events '
        'are ignored', () async {
      answers.add(() => usage(7 * _mb));
      await c.start(changes: changes.stream, refreshSignal: refreshSignal);

      c.stop();
      changes.add(
        DriveChange(
          kind: DriveChangeKind.storageChanged,
          itemUuid: UuidValue.fromString(
            '00000000-0000-0000-0000-000000000000',
          ),
          storage: usage(9 * _mb),
        ),
      );
      refreshSignal.value++;
      await settle();

      expect(c.value, isNull);
      expect(fetches, 1);
    });
  });

  group('Given a cached usage and no connection', () {
    setUp(() async {
      await cache.write(
        LiveStorageController.cacheKey,
        usage(45 * _mb).toJson(),
      );
      answers.add(() => throw const OfflineException('down'));
    });

    test('when the controller starts then the last known value shows, '
        'marked stale', () async {
      await c.start(changes: changes.stream);

      expect(c.value?.bytesUsed, 45 * _mb);
      expect(c.stale, isTrue);
    });

    test(
      'when the connection is back then the fresh value replaces it',
      () async {
        answers.add(() => usage(20 * _mb));
        await c.start(changes: changes.stream);

        await c.refresh();

        expect(c.value?.bytesUsed, 20 * _mb);
        expect(c.stale, isFalse);
      },
    );
  });
}
