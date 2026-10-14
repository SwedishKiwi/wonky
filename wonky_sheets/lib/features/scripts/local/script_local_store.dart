import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';

/// A saved version of a script file in the local history (09 §14.3,
/// `LocalScriptHistory`).
@immutable
class ScriptHistoryEntry {
  const ScriptHistoryEntry({
    required this.fileId,
    required this.savedAt,
    required this.source,
    this.note = '',
  });

  final String fileId;
  final DateTime savedAt;
  final String source;

  /// Why the version was kept (`saved`, `discarded`, `overwritten`).
  final String note;
}

/// An unsaved editor draft (09 §14.3: persisted every 2 s so a reload or a
/// crash loses nothing).
@immutable
class ScriptDraft {
  const ScriptDraft({
    required this.fileId,
    required this.text,
    required this.baseHash,
    this.baseText = '',
  });

  final String fileId;
  final String text;

  /// Content hash the draft was based on (conflict check after a reload).
  final String baseHash;

  /// The saved source the draft was based on (base of *Merge*).
  final String baseText;
}

/// Device-local script data of the signed-in user (09 §19 A-09-7): the
/// bytecode cache (`LocalBlobCache`), the executions waiting for upload
/// (`LocalScriptExecutionLog`), the local history (`LocalScriptHistory`)
/// and unsaved drafts. SQLite `sheets_scripts_<user>.db` (OPFS/IndexedDB on
/// the web); [MemoryScriptLocalStore] in tests.
abstract class ScriptLocalStore {
  /// Bytecode of the build [hash], or null.
  Future<Uint8List?> bytecode(String hash);

  /// Caches the bytecode of [hash] (the oldest beyond [maxBytecodes] are
  /// dropped).
  Future<void> putBytecode(String hash, Uint8List bytes);

  /// Queues executions of [spreadsheet] (JSON maps) for upload.
  Future<void> queueExecutions(
    String spreadsheet,
    List<Map<String, Object?>> rows,
  );

  /// Queued executions of [spreadsheet], oldest first: `(id, row)`.
  Future<List<(int, Map<String, Object?>)>> pendingExecutions(
    String spreadsheet, {
    int limit = 200,
  });

  /// Removes uploaded executions.
  Future<void> removeExecutions(List<int> ids);

  /// Keeps a version of [fileId] (at most [maxHistory] per file).
  Future<void> addHistory(ScriptHistoryEntry entry);

  /// Versions of [fileId], newest first.
  Future<List<ScriptHistoryEntry>> history(String fileId);

  /// Replaces the drafts of [spreadsheet].
  Future<void> saveDrafts(String spreadsheet, List<ScriptDraft> drafts);

  /// The drafts of [spreadsheet].
  Future<List<ScriptDraft>> drafts(String spreadsheet);

  Future<void> close();

  static const maxBytecodes = 12;
  static const maxHistory = 20;
  static const maxQueuedExecutions = 1000;

  // ------------------------------------------------------- per user

  static final Expando<_Install> _installs = Expando('ScriptLocalStore');

  /// Opens the store of [userUuid] (tests override it).
  static Future<ScriptLocalStore> Function(String userUuid) opener =
      _openSqlite;

  static Future<ScriptLocalStore> _openSqlite(String user) async =>
      SqliteScriptLocalStore(
        await LocalDatabases.open(
          'sheets_scripts_$user.db',
          migrations: scriptLocalMigrations,
        ),
      );

  /// The store of the signed-in user of [services] (null when signed out
  /// or the database cannot be opened, e.g. in widget tests without
  /// SQLite).
  static Future<ScriptLocalStore?> of(ShellServices services) {
    final user = services.me?.uuid.uuid;
    if (user == null) return Future.value();
    final inst = _installs[services];
    if (inst != null && inst.user == user) return inst.store;
    final next = _Install(user, () async {
      try {
        return await opener(user);
      } on Object catch (e) {
        debugPrint('Opening the local script store failed: $e');
        return null;
      }
    }());
    _installs[services] = next;
    if (inst != null) {
      unawaited(inst.store.then((s) => s?.close()));
    }
    return next.store;
  }

  /// Uses [store] for [services] (widget tests).
  @visibleForTesting
  static void install(ShellServices services, ScriptLocalStore store) {
    _installs[services] = _Install(
      services.me?.uuid.uuid ?? '',
      Future.value(store),
    );
  }
}

class _Install {
  _Install(this.user, this.store);
  final String user;
  final Future<ScriptLocalStore?> store;
}

final scriptLocalMigrations = SqliteMigrations()
  ..add(
    SqliteMigration(1, (tx) async {
      await tx.execute('''
        CREATE TABLE local_blob_cache (
          key TEXT PRIMARY KEY NOT NULL,
          mime TEXT NOT NULL,
          bytes BLOB NOT NULL,
          created_at INTEGER NOT NULL
        )''');
      await tx.execute('''
        CREATE TABLE local_script_execution_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          spreadsheet TEXT NOT NULL,
          json TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )''');
      await tx.execute(
        'CREATE INDEX local_script_execution_log_ss '
        'ON local_script_execution_log (spreadsheet, id)',
      );
      await tx.execute('''
        CREATE TABLE local_script_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          file_id TEXT NOT NULL,
          saved_at INTEGER NOT NULL,
          source TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT ''
        )''');
      await tx.execute(
        'CREATE INDEX local_script_history_file '
        'ON local_script_history (file_id, saved_at)',
      );
      await tx.execute('''
        CREATE TABLE local_script_draft (
          spreadsheet TEXT NOT NULL,
          file_id TEXT NOT NULL,
          text TEXT NOT NULL,
          base_hash TEXT NOT NULL,
          base_text TEXT NOT NULL DEFAULT '',
          saved_at INTEGER NOT NULL,
          PRIMARY KEY (spreadsheet, file_id)
        )''');
    }),
  );

/// [ScriptLocalStore] on SQLite.
class SqliteScriptLocalStore implements ScriptLocalStore {
  SqliteScriptLocalStore(this.db);

  final SqliteDatabase db;

  static const _bytecodeMime = 'application/x-wonky-script-bytecode';

  int get _now => clock.now().millisecondsSinceEpoch;

  @override
  Future<Uint8List?> bytecode(String hash) async {
    final r = await db.getOptional(
      'SELECT bytes FROM local_blob_cache WHERE key = ?',
      ['script:$hash'],
    );
    return switch (r?['bytes']) {
      final Uint8List b => b,
      final List<int> b => Uint8List.fromList(b),
      _ => null,
    };
  }

  @override
  Future<void> putBytecode(String hash, Uint8List bytes) =>
      db.writeTransaction((tx) async {
        await tx.execute(
          'INSERT OR REPLACE INTO local_blob_cache (key, mime, bytes, '
          'created_at) VALUES (?, ?, ?, ?)',
          ['script:$hash', _bytecodeMime, bytes, _now],
        );
        await tx.execute(
          'DELETE FROM local_blob_cache WHERE mime = ? AND key NOT IN '
          '(SELECT key FROM local_blob_cache WHERE mime = ? '
          'ORDER BY created_at DESC LIMIT ?)',
          [_bytecodeMime, _bytecodeMime, ScriptLocalStore.maxBytecodes],
        );
      });

  @override
  Future<void> queueExecutions(
    String spreadsheet,
    List<Map<String, Object?>> rows,
  ) => db.writeTransaction((tx) async {
    for (final r in rows) {
      await tx.execute(
        'INSERT INTO local_script_execution_log (spreadsheet, json, '
        'created_at) VALUES (?, ?, ?)',
        [spreadsheet, jsonEncodeRow(r), _now],
      );
    }
    await tx.execute(
      'DELETE FROM local_script_execution_log WHERE spreadsheet = ? AND id '
      'NOT IN (SELECT id FROM local_script_execution_log WHERE spreadsheet '
      '= ? ORDER BY id DESC LIMIT ?)',
      [spreadsheet, spreadsheet, ScriptLocalStore.maxQueuedExecutions],
    );
  });

  @override
  Future<List<(int, Map<String, Object?>)>> pendingExecutions(
    String spreadsheet, {
    int limit = 200,
  }) async {
    final rows = await db.getAll(
      'SELECT id, json FROM local_script_execution_log WHERE spreadsheet = ? '
      'ORDER BY id LIMIT ?',
      [spreadsheet, limit],
    );
    return [
      for (final r in rows)
        if (jsonDecodeRow(r['json']! as String) case final m?)
          (r['id']! as int, m),
    ];
  }

  @override
  Future<void> removeExecutions(List<int> ids) async {
    if (ids.isEmpty) return;
    await db.execute(
      'DELETE FROM local_script_execution_log WHERE id IN '
      '(${List.filled(ids.length, '?').join(',')})',
      ids,
    );
  }

  @override
  Future<void> addHistory(ScriptHistoryEntry e) =>
      db.writeTransaction((tx) async {
        final last = await tx.getOptional(
          'SELECT source FROM local_script_history WHERE file_id = ? '
          'ORDER BY saved_at DESC, id DESC LIMIT 1',
          [e.fileId],
        );
        if (last?['source'] == e.source) return;
        await tx.execute(
          'INSERT INTO local_script_history (file_id, saved_at, source, '
          'note) VALUES (?, ?, ?, ?)',
          [e.fileId, e.savedAt.millisecondsSinceEpoch, e.source, e.note],
        );
        await tx.execute(
          'DELETE FROM local_script_history WHERE file_id = ? AND id NOT IN '
          '(SELECT id FROM local_script_history WHERE file_id = ? '
          'ORDER BY saved_at DESC, id DESC LIMIT ?)',
          [e.fileId, e.fileId, ScriptLocalStore.maxHistory],
        );
      });

  @override
  Future<List<ScriptHistoryEntry>> history(String fileId) async => [
    for (final r in await db.getAll(
      'SELECT * FROM local_script_history WHERE file_id = ? '
      'ORDER BY saved_at DESC, id DESC',
      [fileId],
    ))
      ScriptHistoryEntry(
        fileId: fileId,
        savedAt: DateTime.fromMillisecondsSinceEpoch(r['saved_at']! as int),
        source: r['source']! as String,
        note: r['note'] as String? ?? '',
      ),
  ];

  @override
  Future<void> saveDrafts(String spreadsheet, List<ScriptDraft> drafts) =>
      db.writeTransaction((tx) async {
        await tx.execute(
          'DELETE FROM local_script_draft WHERE spreadsheet = ?',
          [spreadsheet],
        );
        for (final d in drafts) {
          await tx.execute(
            'INSERT INTO local_script_draft (spreadsheet, file_id, text, '
            'base_hash, base_text, saved_at) VALUES (?, ?, ?, ?, ?, ?)',
            [spreadsheet, d.fileId, d.text, d.baseHash, d.baseText, _now],
          );
        }
      });

  @override
  Future<List<ScriptDraft>> drafts(String spreadsheet) async => [
    for (final r in await db.getAll(
      'SELECT * FROM local_script_draft WHERE spreadsheet = ?',
      [spreadsheet],
    ))
      ScriptDraft(
        fileId: r['file_id']! as String,
        text: r['text']! as String,
        baseHash: r['base_hash']! as String,
        baseText: r['base_text'] as String? ?? '',
      ),
  ];

  @override
  Future<void> close() => db.close();
}

/// In-memory [ScriptLocalStore] (tests; fallback without SQLite).
class MemoryScriptLocalStore implements ScriptLocalStore {
  final Map<String, Uint8List> blobs = {};
  final List<(int, String, Map<String, Object?>)> executions = [];
  final Map<String, List<ScriptHistoryEntry>> histories = {};
  final Map<String, List<ScriptDraft>> draftsBySpreadsheet = {};
  int _nextId = 1;

  @override
  Future<Uint8List?> bytecode(String hash) async => blobs[hash];

  @override
  Future<void> putBytecode(String hash, Uint8List bytes) async {
    blobs.remove(hash);
    blobs[hash] = bytes;
    while (blobs.length > ScriptLocalStore.maxBytecodes) {
      blobs.remove(blobs.keys.first);
    }
  }

  @override
  Future<void> queueExecutions(
    String spreadsheet,
    List<Map<String, Object?>> rows,
  ) async {
    for (final r in rows) {
      executions.add((_nextId++, spreadsheet, r));
    }
  }

  @override
  Future<List<(int, Map<String, Object?>)>> pendingExecutions(
    String spreadsheet, {
    int limit = 200,
  }) async => [
    for (final e in executions.where((e) => e.$2 == spreadsheet).take(limit))
      (e.$1, e.$3),
  ];

  @override
  Future<void> removeExecutions(List<int> ids) async =>
      executions.removeWhere((e) => ids.contains(e.$1));

  @override
  Future<void> addHistory(ScriptHistoryEntry entry) async {
    final l = histories.putIfAbsent(entry.fileId, () => []);
    if (l.isNotEmpty && l.first.source == entry.source) return;
    l.insert(0, entry);
    if (l.length > ScriptLocalStore.maxHistory) l.removeLast();
  }

  @override
  Future<List<ScriptHistoryEntry>> history(String fileId) async =>
      List.of(histories[fileId] ?? const []);

  @override
  Future<void> saveDrafts(String spreadsheet, List<ScriptDraft> drafts) async =>
      draftsBySpreadsheet[spreadsheet] = List.of(drafts);

  @override
  Future<List<ScriptDraft>> drafts(String spreadsheet) async =>
      List.of(draftsBySpreadsheet[spreadsheet] ?? const []);

  @override
  Future<void> close() async {}
}

/// JSON of a queued execution row.
String jsonEncodeRow(Map<String, Object?> row) => _json.encode(row);

/// The row of [json], or null when it is malformed.
Map<String, Object?>? jsonDecodeRow(String json) {
  try {
    final v = _json.decode(json);
    return v is Map ? v.cast<String, Object?>() : null;
  } on FormatException {
    return null;
  }
}

const _json = JsonCodec();
