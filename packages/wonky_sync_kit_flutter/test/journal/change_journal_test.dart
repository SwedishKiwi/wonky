import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sync_kit/rows.dart';
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart';

import '../support/kit_harness.dart';

void main() {
  group('Given a replica with two files', () {
    late SyncReplica replica;
    late RecordingWriter writer;
    final open = space(0x201);
    final other = space(0x202);
    late int openKey;
    setUp(() async {
      replica = await openTestReplica();
      writer = RecordingWriter(replica);
      await createFile(replica, writer, open);
      await createFile(replica, writer, other);
      openKey = (await replica.spaceKey(open))!;
    });

    Future<void> rename(UuidValue file, String title) => writer.write(
      spaceId: file,
      changes: [
        RowChange.update('sheet', sheetId(file, 0).uuid, const {}, {
          'name': title,
        }),
      ],
      label: 'Rename',
      actorKind: 'user',
      sessionId: 's',
    );

    test('when the open file is tracked then only its later writes are '
        'journaled, by table', () async {
      await replica.journal.track(openKey);
      final cursor = await replica.journal.head();

      await rename(open, 'A');
      await rename(other, 'B');
      final changes = await replica.journal.changesSince(openKey, cursor);

      expect(changes.rows, {
        'sheet': {sheetId(open, 0)},
      });
      expect(changes.head, greaterThan(cursor));
      final otherKey = (await replica.spaceKey(other))!;
      expect(
        (await replica.journal.changesSince(otherKey, cursor)).isEmpty,
        isTrue,
      );
    });

    test('when the last tracker leaves then the space is no longer '
        'journaled', () async {
      await replica.journal.track(openKey);
      await replica.journal.track(openKey);
      await replica.journal.untrack(openKey);
      final cursor = await replica.journal.head();
      await rename(open, 'A');
      expect((await replica.journal.changesSince(openKey, cursor)).count, 1);

      await replica.journal.untrack(openKey);
      final after = await replica.journal.head();
      await rename(open, 'B');

      expect(
        (await replica.journal.changesSince(openKey, after)).isEmpty,
        isTrue,
      );
    });

    test('when pruned then positions stay monotonic', () async {
      await replica.journal.track(openKey);
      await rename(open, 'A');
      final head = await replica.journal.head();

      await replica.journal.prune(head);
      await rename(open, 'B');

      expect(await replica.journal.head(), greaterThan(head));
    });
  });
}
