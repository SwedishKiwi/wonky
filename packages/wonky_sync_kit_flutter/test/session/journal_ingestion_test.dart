import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sync_kit/rows.dart';
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart';

import '../support/kit_harness.dart';

void main() {
  group('Given an open file whose space is journaled', () {
    late SyncReplica replica;
    late FakeHost host;
    late JournalIngestion ingestion;
    final file = space(0x401);
    final applied = <Map<String, Set<UuidValue>>>[];
    final reloads = <int>[];
    var disposed = false;
    setUp(() async {
      applied.clear();
      reloads.clear();
      disposed = false;
      replica = await openTestReplica();
      host = FakeHost(replica);
      await createFile(replica, host.writer, file);
      final key = (await replica.spaceKey(file))!;
      await replica.journal.track(key);
      ingestion =
          JournalIngestion(
              host: host,
              modelTables: testTables.modelTableNames,
              applyRows: (changed, rows) => applied.add(changed),
              reloadRows: (all) => reloads.add(all.length),
              isDisposed: () => disposed,
            )
            ..spaceKey = key
            ..cursor = await replica.journal.head();
    });

    Future<void> renameChild(String name) => host.writer.write(
      spaceId: file,
      changes: [
        RowChange.update('sheet', sheetId(file, 0).uuid, const {}, {
          'name': name,
        }),
      ],
      label: 'Rename',
      actorKind: 'user',
      sessionId: 'other',
    );

    test('when rows change then ingesting hands exactly them over and '
        'advances the cursor', () async {
      final before = ingestion.cursor;
      await renameChild('Renamed');

      await ingestion.ingest();

      expect(applied.single, {
        'sheet': {sheetId(file, 0)},
      });
      expect(ingestion.cursor, greaterThan(before!));
      expect(host.cursorChanges, greaterThan(0));
    });

    test('when nothing changed then ingesting does nothing', () async {
      await ingestion.ingest();

      expect(applied, isEmpty);
    });

    test(
      'when a reload is needed then the whole space is handed over',
      () async {
        ingestion.needsReload = true;

        await ingestion.ingest();

        expect(reloads, [2]);
        expect(ingestion.needsReload, isFalse);
      },
    );

    test(
      'when applying keeps failing then ingesting gives up after '
      '${JournalIngestion.maxAttempts} attempts and the next call retries',
      () async {
        var attempts = 0;
        var failing = true;
        final flaky =
            JournalIngestion(
                host: host,
                modelTables: testTables.modelTableNames,
                applyRows: (changed, rows) {},
                reloadRows: (all) {
                  attempts++;
                  if (failing) throw StateError('broken row');
                  reloads.add(all.length);
                },
                isDisposed: () => disposed,
              )
              ..spaceKey = ingestion.spaceKey
              ..cursor = ingestion.cursor
              ..needsReload = true;

        await flaky.ingest();

        expect(attempts, JournalIngestion.maxAttempts);
        expect(flaky.needsReload, isTrue);

        failing = false;
        await flaky.ingest();

        expect(reloads, [2]);
        expect(flaky.needsReload, isFalse);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('when the session is disposed then nothing is ingested', () async {
      await renameChild('Late');
      disposed = true;

      await ingestion.ingest();

      expect(applied, isEmpty);
    });
  });
}
