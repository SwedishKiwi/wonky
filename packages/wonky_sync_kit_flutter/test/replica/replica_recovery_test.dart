import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart';

import '../support/kit_harness.dart';

void main() {
  test(
    'Given a replica with a dirty and a synced file, when it is read for '
    'recovery then only the dirty file comes back with its visible rows',
    () async {
      final dir = await Directory.systemTemp.createTemp('wonky_sync_kit_rec_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/kit.db';
      final replica = await openTestReplica(path: path);
      final writer = RecordingWriter(replica);
      await createFile(replica, writer, space(1), children: 2);
      await createFile(replica, writer, space(2));
      await replica.clearDirty([space(2)], DateTime.now());
      await replica.close();

      final spaces = await ReplicaRecoveryReader.read(path, testTables);

      expect(spaces!.single.spaceUuid, space(1).uuid);
      expect(spaces.single.rows.map((r) => r.$1), [
        'spreadsheet',
        'sheet',
        'sheet',
      ]);
      expect(spaces.single.valueOf('spreadsheet', 'title'), 'Test');
      expect(
        spaces.single.valueOf('spreadsheet', 'createdAt'),
        DateTime.utc(2026, 10, 15),
      );
    },
  );

  test('Given no replica file, when it is read for recovery then there is '
      'nothing', () async {
    expect(
      await ReplicaRecoveryReader.read('/nonexistent/kit.db', testTables),
      isNull,
    );
  });
}
