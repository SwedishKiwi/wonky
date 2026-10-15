import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart';

import '../support/kit_harness.dart';

void main() {
  group('Given a replica', () {
    late SyncReplica replica;
    late RecordingWriter writer;
    setUp(() async {
      replica = await openTestReplica();
      writer = RecordingWriter(replica);
    });

    test('when spaces are reserved then they become usable once their '
        'membership arrives, oldest first, and can be used up', () async {
      await replica.addReservations([space(1), space(2)]);
      await replica.addReservations([space(1)]);
      expect(await replica.reservedSpaces(), [space(1), space(2)]);
      expect(await replica.usableReservations(), isEmpty);

      await grantLocally(replica, space(2));
      await grantLocally(replica, space(1));
      await replica.removeReservation(space(1));

      expect(await replica.usableReservations(), [space(2)]);
    });

    test('when a file is written then its root row, row counts and the '
        'per-space counts are visible', () async {
      await createFile(replica, writer, space(3), children: 2);

      expect(await replica.hasRoot(space(3)), isTrue);
      expect(await replica.hasRoot(space(4)), isFalse);
      expect(await replica.rootIds(), {space(3)});
      expect(await replica.rowCounts(space(3)), {'spreadsheet': 1, 'sheet': 2});
      expect(await replica.rowCountsBySpace('sheet'), {space(3): 2});
    });

    test('when loading a space then model rows come in dependency order and '
        'skipped tables are left out', () async {
      await createFile(replica, writer, space(5), children: 2);
      final key = (await replica.spaceKey(space(5)))!;
      var reported = 0;

      final all = await replica.loadSpace(
        key,
        pageSize: 1,
        onPage: (n) => reported = n,
      );
      final noChildren = await replica.loadSpace(key, skipTables: {'sheet'});

      expect(all.map((r) => r.$1), ['spreadsheet', 'sheet', 'sheet']);
      expect(reported, 3);
      expect(noChildren.map((r) => r.$1), ['spreadsheet']);
    });

    test(
      'when dirty marks are cleared up to a time then later marks stay',
      () async {
        await replica.markDirty(space(6));
        await replica.markDirty(replica.userUuid);
        final marked = DateTime.now();
        expect(await replica.dirtySpaces(), [space(6)]);

        await replica.clearDirty([space(6)], marked);

        expect(await replica.dirtySpaces(), isEmpty);
      },
    );

    test('when the user loses a space then it is hidden and purging deletes '
        'its rows', () async {
      await createFile(replica, writer, space(7));
      await revokeLocally(replica, space(7));

      final hidden = await replica.hiddenSpaces();
      expect(hidden.map((h) => h.$2), [space(7)]);
      await replica.purgeSpace(hidden.single.$1);

      expect(await replica.rowCounts(space(7)), isEmpty);
      expect(await replica.hasRoot(space(7)), isFalse);
    });

    test('when every table is cleared then nothing is left', () async {
      await createFile(replica, writer, space(8));
      await replica.addReservations([space(9)]);

      await replica.clearAllTables();

      expect(await replica.rootIds(), isEmpty);
      expect(await replica.reservedSpaces(), isEmpty);
    });
  });
}
