import 'dart:typed_data';

import 'package:wonky_app/wonky_app.dart';

import 'upload_task.dart';

/// The persistent upload queue (Drive 02 §4.1): each queue change is
/// written here first, so a reload restores the panel and continues the
/// uploads.
abstract class UploadStore {
  /// Every stored task, oldest first.
  Future<List<UploadTask>> load();

  /// Adds [task] with its [bytes] (null = held in memory only, the task is
  /// `volatile`).
  Future<void> add(UploadTask task, Uint8List? bytes);

  /// Writes the state of [task] (not the bytes).
  Future<void> update(UploadTask task);

  /// The stored bytes of task [id] (null when not stored).
  Future<Uint8List?> bytes(String id);

  /// Drops the bytes of task [id] (finished uploads keep only their row).
  Future<void> dropBytes(String id);

  /// Removes task [id].
  Future<void> remove(String id);

  /// Closes the store.
  Future<void> close();
}

/// Schema of the Drive app's local database `drive_<userId>.db` (suite 12
/// §1.1): `local_pending_upload` with the v2 columns of Drive 02 §4.1
/// (`purpose`, `item_uuid`/`file_uuid`, `parent_uuid`, `file_name`,
/// `size_bytes`, `mime_type`, `last_modified`, `bytes`, `source_path`,
/// `state`, `attempts`, `last_error`, `received_bytes`) plus the queue's
/// own bookkeeping (`batch_id`, `parent_name`, `volatile`, `error_kind`,
/// `result_json`).
final driveLocalMigrations = SqliteMigrations()
  ..add(
    SqliteMigration(1, (tx) async {
      await tx.execute('''
        CREATE TABLE local_pending_upload (
          id TEXT PRIMARY KEY NOT NULL,
          purpose TEXT NOT NULL DEFAULT 'driveFile',
          batch_id TEXT NOT NULL,
          item_uuid TEXT NOT NULL,
          file_uuid TEXT NOT NULL,
          parent_uuid TEXT,
          parent_name TEXT,
          file_name TEXT NOT NULL,
          size_bytes INTEGER NOT NULL,
          mime_type TEXT,
          last_modified INTEGER,
          bytes BLOB,
          source_path TEXT,
          volatile INTEGER NOT NULL DEFAULT 0,
          state TEXT NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          last_error TEXT,
          error_kind TEXT,
          received_bytes INTEGER NOT NULL DEFAULT 0,
          result_json TEXT,
          created_at INTEGER NOT NULL
        )''');
      await tx.execute(
        'CREATE INDEX local_pending_upload_created '
        'ON local_pending_upload (created_at)',
      );
    }),
  );

/// The local database file of the Drive app for the user [userUuid].
String driveDatabaseName(String userUuid) => 'drive_$userUuid.db';

/// [UploadStore] on SQLite (`sqlite_async`; OPFS or IndexedDB on the web).
class SqliteUploadStore implements UploadStore {
  SqliteUploadStore(this.db);

  /// Opens `drive_<userId>.db` with [LocalDatabases.open].
  static Future<SqliteUploadStore> open(
    String userUuid, {
    String? directory,
  }) async => SqliteUploadStore(
    await LocalDatabases.open(
      driveDatabaseName(userUuid),
      migrations: driveLocalMigrations,
      directory: directory,
    ),
  );

  final SqliteDatabase db;

  static const _columns =
      'id, purpose, batch_id, item_uuid, file_uuid, parent_uuid, '
      'parent_name, file_name, size_bytes, mime_type, last_modified, '
      'volatile, state, attempts, last_error, error_kind, received_bytes, '
      'result_json, created_at';

  @override
  Future<List<UploadTask>> load() async {
    final rows = await db.getAll(
      'SELECT $_columns FROM local_pending_upload '
      "WHERE purpose = 'driveFile' ORDER BY created_at, rowid",
    );
    return [for (final r in rows) UploadTask.fromRow(r)];
  }

  @override
  Future<void> add(UploadTask task, Uint8List? bytes) async {
    final row = task.toRow();
    final cols = [...row.keys, 'bytes'];
    await db.execute(
      'INSERT OR REPLACE INTO local_pending_upload (${cols.join(', ')}) '
      'VALUES (${List.filled(cols.length, '?').join(', ')})',
      [...row.values, bytes],
    );
  }

  @override
  Future<void> update(UploadTask task) async {
    final row = task.toRow()..remove('id');
    await db.execute(
      'UPDATE local_pending_upload SET '
      '${row.keys.map((k) => '$k = ?').join(', ')} WHERE id = ?',
      [...row.values, task.id],
    );
  }

  @override
  Future<Uint8List?> bytes(String id) async {
    final row = await db.getOptional(
      'SELECT bytes FROM local_pending_upload WHERE id = ?',
      [id],
    );
    final b = row?['bytes'];
    return switch (b) {
      final Uint8List u => u,
      final List<int> l => Uint8List.fromList(l),
      _ => null,
    };
  }

  @override
  Future<void> dropBytes(String id) => db.execute(
    'UPDATE local_pending_upload SET bytes = NULL WHERE id = ?',
    [id],
  );

  @override
  Future<void> remove(String id) =>
      db.execute('DELETE FROM local_pending_upload WHERE id = ?', [id]);

  @override
  Future<void> close() => db.close();
}

/// [UploadStore] in memory (tests; and the fallback when the local
/// database can't be opened — uploads then don't survive a reload).
class MemoryUploadStore implements UploadStore {
  final Map<String, Map<String, Object?>> rows = {};
  final Map<String, Uint8List> _bytes = {};
  bool closed = false;

  @override
  Future<List<UploadTask>> load() async {
    final list = rows.values.toList()
      ..sort(
        (a, b) => (a['created_at']! as int).compareTo(b['created_at']! as int),
      );
    return [for (final r in list) UploadTask.fromRow(r)];
  }

  @override
  Future<void> add(UploadTask task, Uint8List? bytes) async {
    rows[task.id] = task.toRow();
    if (bytes != null) _bytes[task.id] = bytes;
  }

  @override
  Future<void> update(UploadTask task) async {
    if (rows.containsKey(task.id)) rows[task.id] = task.toRow();
  }

  @override
  Future<Uint8List?> bytes(String id) async => _bytes[id];

  @override
  Future<void> dropBytes(String id) async => _bytes.remove(id);

  @override
  Future<void> remove(String id) async {
    rows.remove(id);
    _bytes.remove(id);
  }

  @override
  Future<void> close() async => closed = true;

  /// Whether bytes of [id] are stored (tests).
  bool hasBytes(String id) => _bytes.containsKey(id);
}
