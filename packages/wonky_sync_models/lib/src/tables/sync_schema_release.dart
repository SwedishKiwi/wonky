/// The current synced schema release (suite 01 §7, Slides 12 §1): every
/// `database: sync` model of this package, shared by all apps.
///
/// The offline-sync engine refuses peers whose `syncTablesHash` differs, so
/// the server, the generated client and every app change together. A change
/// to any synced model (a table, column, type, nullability, default, index or
/// foreign key) changes the hash: the guard tests (server
/// `test/unit/sync/sync_schema_release_test.dart`, Sheets
/// `test/sync/sync_schema_release_test.dart`) then fail until [name] and
/// [syncTablesHash] are bumped here and the release is recorded in
/// specs/wonky_slides/02-data-model.md §14.1.
abstract final class SyncSchemaRelease {
  /// Release name: S-1 = the Sheets tables + the Slides tables of M9. The
  /// Sheets-only schema before it hashed to
  /// `1a5f0730-2976-5ef7-b870-dbdc1b965fa5:8faad583-3b96-5cb4-a39e-5b141d5f9b15`.
  static const String name = 'S-1';

  /// `OfflineSyncEngine.computeSyncTablesHash` of the release.
  static const String syncTablesHash =
      'b54df85b-b26f-5da7-aa12-d8761b0c27cc:'
      '588b3c43-b2f7-5c93-a691-bb5704e6ffe8';
}
