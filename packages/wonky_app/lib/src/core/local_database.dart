import 'package:flutter/foundation.dart';
import 'package:sqlite_async/sqlite_async.dart';

import 'local_database_io.dart'
    if (dart.library.js_interop) 'local_database_web.dart'
    as platform;

export 'package:sqlite_async/sqlite_async.dart'
    show
        SqliteDatabase,
        SqliteConnection,
        SqliteReadContext,
        SqliteWriteContext,
        SqliteMigrations,
        SqliteMigration;

/// Opens the per-user local SQLite databases of suite 12
/// (`write_cache_<userId>.db`, …).
///
/// - Web: `sqlite_async` on `sqlite3.wasm` + `db_worker.js` (both in the
///   app's `web/` folder, versions in step with `sqlite_async`);
///   `WebSqlite.connectToRecommended` picks OPFS when available, else
///   IndexedDB.
/// - Desktop: a file in the application support directory (protected by
///   the OS account).
///
/// Tests pass [directory] (a temporary folder) so every test gets its own
/// file.
abstract final class LocalDatabases {
  /// Where desktop databases live (null on the web). Overridable for tests.
  static String? directoryOverride;

  /// Opens (creating if needed) the database [fileName] and runs
  /// [migrations].
  static Future<SqliteDatabase> open(
    String fileName, {
    SqliteMigrations? migrations,
    String? directory,
  }) async {
    final path = await platform.databasePath(
      fileName,
      directory ?? directoryOverride,
    );
    final db = SqliteDatabase(
      path: path,
      options: const SqliteOptions(
        // A local cache: favour latency over durability of the last
        // milliseconds (WAL + NORMAL is still crash-safe).
        synchronous: SqliteSynchronous.normal,
      ),
    );
    if (migrations != null) await migrations.migrate(db);
    return db;
  }

  /// Whether database files can be deleted (desktop). On the web, tables
  /// are truncated instead (suite 12: DB deletion is unsupported there).
  static bool get canDelete => !kIsWeb;

  /// Deletes the database file [fileName] (desktop only; no-op on the web).
  static Future<void> delete(String fileName, {String? directory}) =>
      platform.deleteDatabase(fileName, directory ?? directoryOverride);
}
