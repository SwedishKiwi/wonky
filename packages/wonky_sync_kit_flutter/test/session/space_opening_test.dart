import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    show OfflineSyncSpaceRole;
import 'package:wonky_client/wonky_client.dart' show AccessRole;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart';

import '../support/kit_harness.dart';

void main() {
  group('Given the membership cache of a space', () {
    const cases = [
      (OfflineSyncSpaceRole.readWrite, Role.viewer, Role.editor),
      (OfflineSyncSpaceRole.readWrite, Role.commenter, Role.editor),
      (OfflineSyncSpaceRole.readWrite, Role.owner, null),
      (OfflineSyncSpaceRole.readOnly, Role.editor, Role.viewer),
      (OfflineSyncSpaceRole.readOnly, Role.owner, Role.viewer),
      (OfflineSyncSpaceRole.readOnly, Role.commenter, null),
    ];
    for (final (membership, current, expected) in cases) {
      test('when it says ${membership.name} for a ${current.name} then the '
          'role becomes ${expected?.name ?? 'unchanged'}', () {
        expect(SpaceOpening.roleFromMembership(membership, current), expected);
      });
    }
  });

  test(
    'Given drive access roles, when mapped then each has its suite role',
    () {
      expect(AccessRole.values.map(SpaceOpening.roleOf), [
        for (final r in AccessRole.values) Role.values.byName(r.name),
      ]);
    },
  );

  group('Given a file arriving on the device', () {
    late FakeHost host;
    final file = space(0x501);
    setUp(() async {
      final replica = await openTestReplica();
      host = FakeHost(replica, online: true);
    });

    test('when all its rows are there then waiting ends and progress was '
        'reported', () async {
      final progress = <double>[];
      final waiting = SpaceOpening.waitForSpace(
        host,
        file,
        subscribed(file, totalRows: 2).stats,
        rootTable: 'spreadsheet',
        settleTimeout: const Duration(seconds: 5),
        isDisposed: () => false,
        onProgress: progress.add,
      );

      await createFile(host.replica, host.writer, file);
      host.mergesController.add(file);
      await waiting;

      expect(progress.first, 0);
      expect(await host.replica.hasRoot(file), isTrue);
    });

    test(
      'when offline with nothing on the device then waiting gives up',
      () async {
        host.online.value = false;

        await SpaceOpening.waitForSpace(
          host,
          file,
          subscribed(file).stats,
          rootTable: 'spreadsheet',
          settleTimeout: const Duration(seconds: 5),
          isDisposed: () => false,
          onProgress: (_) {},
        );

        expect(await host.replica.hasRoot(file), isFalse);
      },
    );
  });
}
