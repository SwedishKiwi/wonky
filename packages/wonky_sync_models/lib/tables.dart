/// Generic, name-based access to the synced tables (column maps ⇄ generated
/// ORM classes): Sheets' [SyncedTables] and Slides' [SlidesSyncedTables],
/// shared by the server writers, the apps' writers and test devices; and the
/// current synced schema release ([SyncSchemaRelease]).
library;

export 'src/tables/slides_synced_tables.dart';
export 'src/tables/sync_schema_release.dart';
export 'src/tables/synced_tables.dart';
