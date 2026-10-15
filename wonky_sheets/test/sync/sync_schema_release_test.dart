import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    show OfflineSyncEngine;
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_sync_models/tables.dart';

/// Lock-step guard of the synced schema (suite 01 §7, Slides 12 §1): the
/// generated client's `syncTablesHash` — the one this app's replica sends in
/// the sync handshake — is the recorded release, which the server checks too
/// (`wonky_server/test/unit/sync/sync_schema_release_test.dart`). The Slides
/// tables of S-1 are in every replica; the Sheets table set ignores them.
void main() {
  test('Given the generated client, when hashing its synced tables then it '
      'is the recorded release ${SyncSchemaRelease.name}', () {
    expect(
      OfflineSyncEngine.computeSyncTablesHash(
        syncTables,
        tableDefinitions: Protocol().getTargetTableDefinitions(),
      ),
      SyncSchemaRelease.syncTablesHash,
    );
    expect({
      for (final t in syncTables) t.tableName,
    }, containsAll(SlidesSyncedTables.byName.keys));
  });
}
