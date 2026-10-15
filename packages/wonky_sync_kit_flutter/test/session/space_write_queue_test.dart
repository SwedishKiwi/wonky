import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sync_kit/rows.dart';
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart';
import 'package:wonky_ui/wonky_ui.dart' show SyncState;

import '../support/kit_harness.dart';

void main() {
  group('Given a write queue on a granted space', () {
    late SyncReplica replica;
    late RecordingWriter writer;
    late SpaceWriteQueue queue;
    final file = space(0x301);
    final failures = <Object>[];
    var stored = 0;
    setUp(() async {
      failures.clear();
      stored = 0;
      replica = await openTestReplica();
      writer = RecordingWriter(replica);
      await grantLocally(replica, file);
      queue = SpaceWriteQueue(
        writer: writer,
        spaceUuid: file,
        sessionId: 'q',
        onStored: () => stored++,
        onFailed: failures.add,
      );
    });

    test('when two writes are queued then they are pending and saving until '
        'stored in order, then saved', () async {
      queue.enqueue([rootRow(file)], label: 'Create', actorKind: 'user');
      queue.enqueue([childRow(file, 0)], label: 'Add', actorKind: 'user');

      expect(queue.pendingChanges, 2);
      expect(queue.pendingOverlay.map((c) => c.table), [
        'spreadsheet',
        'sheet',
      ]);
      expect(queue.status(online: true).state, SyncState.saving);

      await queue.flush();

      expect(queue.pendingChanges, 0);
      expect(writer.logs.map((l) => l.label), ['Create', 'Add']);
      expect(stored, 2);
      expect(queue.status(online: true).state, SyncState.saved);
      expect(queue.status(online: false).state, SyncState.offline);
    });

    test('when a write fails then the error is reported and shown', () async {
      queue.enqueue(
        [RowChange.insert('no_such_table', file.uuid, const {})],
        label: 'Broken',
        actorKind: 'user',
      );

      await queue.flush();

      expect(failures, hasLength(1));
      expect(queue.status(online: true).state, SyncState.error);
      expect(queue.pendingChanges, 0);
    });
  });
}
