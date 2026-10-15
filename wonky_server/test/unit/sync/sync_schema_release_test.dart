import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    show OfflineSyncEngine;
import 'package:test/test.dart';
import 'package:wonky_server/src/generated/protocol.dart' as gen;
import 'package:wonky_server/src/generated/sync_tables.dart';
import 'package:wonky_server/src/sheets/versions/sheets_version_provider.dart';
import 'package:wonky_sync_models/tables.dart';

/// Lock-step guard of the synced schema (suite 01 §7, Slides 12 §1): the
/// server's `syncTablesHash` is the recorded release. The Sheets client
/// checks the same constant (`wonky_sheets/test/sync/
/// sync_schema_release_test.dart`), so client and server agree. When a
/// synced model changes on purpose, bump `SyncSchemaRelease` and record the
/// release in specs/wonky_slides/02-data-model.md §14.1.
void main() {
  test('Given the generated synced tables, when hashing the schema then it '
      'is the recorded release ${SyncSchemaRelease.name}', () {
    expect(
      SheetsVersionProvider.syncTablesHashOf(),
      SyncSchemaRelease.syncTablesHash,
    );
  });

  test('Given the server sync tables, when listing them then they are the '
      'Sheets and Slides tables of the shared package', () {
    expect(
      {for (final t in syncTables) t.tableName},
      {...SyncedTables.byName.keys, ...SlidesSyncedTables.byName.keys},
    );
    expect(
      OfflineSyncEngine.computeSyncTablesHash(
        syncTables,
        tableDefinitions: gen.Protocol().getTargetTableDefinitions(),
      ),
      SyncSchemaRelease.syncTablesHash,
    );
  });
}
