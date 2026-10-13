import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_write_core/wonky_write_core.dart'
    show DeltaUtils, WonkyOt;

import '../sync/sync_persistence.dart';

/// Schema of `write_cache_<userId>.db` (suite 12 §1.1). Local tables only,
/// never synced:
///
/// | Table | What |
/// |-------|------|
/// | `local_document` | Server snapshot + revision, metadata, role, drive item, pin, last opened |
/// | `local_document_op` | Server ops after the snapshot (op log, compacted into the snapshot) |
/// | `local_pending_op` | The durable outbox: content ops (in flight + 2 s chunks) and queued metadata changes |
/// | `local_undo_stack` | Best-effort undo/redo of the document, with the hash of the document it applies to |
/// | `local_pending_upload` | Images inserted while offline (bytes), retried with backoff |
final writeCacheMigrations = SqliteMigrations()
  ..add(
    SqliteMigration(1, (tx) async {
      await tx.execute('''
        CREATE TABLE local_document (
          document_uuid TEXT PRIMARY KEY NOT NULL,
          item_uuid TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL DEFAULT '',
          item_json TEXT,
          snapshot_json TEXT NOT NULL,
          snapshot_revision INTEGER NOT NULL,
          head_revision INTEGER NOT NULL,
          meta_json TEXT,
          role TEXT,
          theme_id TEXT,
          pinned INTEGER NOT NULL DEFAULT 0,
          last_opened_at INTEGER,
          updated_at INTEGER NOT NULL,
          size_bytes INTEGER NOT NULL DEFAULT 0
        )''');
      await tx.execute('''
        CREATE TABLE local_document_op (
          document_uuid TEXT NOT NULL,
          revision INTEGER NOT NULL,
          delta_json TEXT NOT NULL,
          PRIMARY KEY (document_uuid, revision)
        )''');
      await tx.execute('''
        CREATE TABLE local_pending_op (
          document_uuid TEXT NOT NULL,
          client_op_id TEXT NOT NULL,
          seq INTEGER NOT NULL,
          base_revision INTEGER NOT NULL,
          delta_json TEXT NOT NULL,
          kind TEXT NOT NULL,
          group_id TEXT,
          inflight INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          PRIMARY KEY (document_uuid, client_op_id)
        )''');
      await tx.execute(
        'CREATE INDEX local_pending_op_seq '
        'ON local_pending_op (document_uuid, seq)',
      );
      await tx.execute('''
        CREATE TABLE local_undo_stack (
          document_uuid TEXT PRIMARY KEY NOT NULL,
          stack_json TEXT NOT NULL,
          doc_hash TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )''');
      await tx.execute('''
        CREATE TABLE local_pending_upload (
          file_uuid TEXT PRIMARY KEY NOT NULL,
          item_uuid TEXT,
          bytes BLOB NOT NULL,
          mime_type TEXT NOT NULL,
          file_name TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          last_error TEXT
        )''');
    }),
  );

const _metaKind = 'meta';

/// A queued `document.updateMeta` (suite 12 §1.1 `LocalPendingOp`, kind
/// meta), replayed with the same `clientOpId` (idempotent).
@immutable
class PendingMetaOp {
  const PendingMetaOp({
    required this.clientOpId,
    required this.field,
    required this.valueJson,
    required this.createdAt,
  });

  final UuidValue clientOpId;
  final String field;
  final String valueJson;
  final DateTime createdAt;
}

/// An image waiting for upload (suite 12 §1.1 `LocalPendingUpload`).
@immutable
class PendingUpload {
  const PendingUpload({
    required this.fileUuid,
    required this.itemUuid,
    required this.bytes,
    required this.mimeType,
    required this.fileName,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  final UuidValue fileUuid;
  final UuidValue? itemUuid;
  final Uint8List bytes;
  final String mimeType;
  final String fileName;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
}

/// A cached document as listed for eviction and the drive.
@immutable
class LocalDocumentSummary {
  const LocalDocumentSummary({
    required this.documentUuid,
    required this.itemUuid,
    required this.title,
    required this.pinned,
    required this.lastOpenedAt,
    required this.sizeBytes,
    required this.pendingOps,
  });

  final String documentUuid;
  final String itemUuid;
  final String title;
  final bool pinned;
  final DateTime? lastOpenedAt;
  final int sizeBytes;

  /// Local changes not yet on the server (content and metadata).
  final int pendingOps;
}

/// A document restored from the cache.
@immutable
class StoredDocument {
  const StoredDocument({
    required this.documentUuid,
    required this.itemUuid,
    required this.state,
    required this.item,
    required this.loggedOps,
    required this.storedOutbox,
    this.pinned = false,
  });

  final UuidValue documentUuid;
  final UuidValue itemUuid;

  /// Server document + outbox, ready for `DocumentSyncController.restore`.
  final SyncLocalState state;

  /// The drive item as last seen (offline title, role, parent).
  final DriveItemView? item;

  /// Rows in the op log (persistence bookkeeping).
  final int loggedOps;

  /// Stored outbox rows (client op id → signature).
  final Map<String, String> storedOutbox;
  final bool pinned;
}

/// Queries of `write_cache_<userId>.db`.
class WriteLocalStore {
  WriteLocalStore(this.db);

  final SqliteDatabase db;

  static int _ms(DateTime t) => t.millisecondsSinceEpoch;

  static DateTime? _time(Object? ms) =>
      ms is int ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true) : null;

  static Delta _delta(String json) =>
      Delta.fromJson(jsonDecode(json) as List<dynamic>);

  /// The signature of a stored outbox row (rows are rewritten only when it
  /// changes).
  static String signature(PendingOpRecord r, String deltaJson) =>
      '${r.seq}|${r.baseRevision}|${r.inflight ? 1 : 0}|$deltaJson';

  // ---------------------------------------------------------------------------
  // Documents.

  /// The cached document of drive item [itemUuid].
  Future<StoredDocument?> loadByItem(UuidValue itemUuid) async {
    final row = await db.getOptional(
      'SELECT * FROM local_document WHERE item_uuid = ?',
      [itemUuid.uuid],
    );
    if (row == null) return null;
    return _load(row);
  }

  /// The cached document [documentUuid].
  Future<StoredDocument?> loadDocument(UuidValue documentUuid) async {
    final row = await db.getOptional(
      'SELECT * FROM local_document WHERE document_uuid = ?',
      [documentUuid.uuid],
    );
    if (row == null) return null;
    return _load(row);
  }

  Future<StoredDocument?> _load(Map<String, Object?> row) async {
    final doc = row['document_uuid']! as String;
    try {
      var server = DeltaUtils.canonical(
        _delta(row['snapshot_json']! as String),
      );
      var revision = row['snapshot_revision']! as int;
      final ops = await db.getAll(
        'SELECT revision, delta_json FROM local_document_op '
        'WHERE document_uuid = ? AND revision > ? ORDER BY revision',
        [doc, revision],
      );
      for (final op in ops) {
        final r = op['revision']! as int;
        if (r != revision + 1) {
          throw StateError('Op log gap at revision ${revision + 1}');
        }
        server = WonkyOt.apply(server, _delta(op['delta_json']! as String));
        revision = r;
      }
      final pendingRows = await db.getAll(
        'SELECT * FROM local_pending_op WHERE document_uuid = ? AND kind != ? '
        'ORDER BY seq',
        [doc, _metaKind],
      );
      final outbox = <PendingOpRecord>[];
      final stored = <String, String>{};
      for (final p in pendingRows) {
        final json = p['delta_json']! as String;
        final record = PendingOpRecord(
          clientOpId: UuidValue.fromString(p['client_op_id']! as String),
          seq: p['seq']! as int,
          baseRevision: p['base_revision']! as int,
          delta: _delta(json),
          kind: DocumentOpKind.values.byName(p['kind']! as String),
          groupId: p['group_id'] as String?,
          createdAt: _time(p['created_at']) ?? clock.now(),
          inflight: p['inflight'] == 1,
        );
        stored[record.clientOpId.uuid] = signature(record, json);
        outbox.add(record);
      }
      if (outbox.any((r) => r.baseRevision != revision)) {
        throw StateError('Outbox does not match revision $revision');
      }
      if (outbox.isNotEmpty) {
        // Must apply; throws when the stored state is inconsistent.
        var local = server;
        for (final r in outbox) {
          local = WonkyOt.apply(local, r.delta);
        }
      }
      final metaJson = row['meta_json'] as String?;
      final itemJson = row['item_json'] as String?;
      final role = row['role'] as String?;
      return StoredDocument(
        documentUuid: UuidValue.fromString(doc),
        itemUuid: UuidValue.fromString(row['item_uuid']! as String),
        state: SyncLocalState(
          revision: revision,
          serverDocument: server,
          outbox: outbox,
          meta: metaJson == null
              ? null
              : DocumentMetaView.fromJson(
                  (jsonDecode(metaJson) as Map).cast<String, dynamic>(),
                ),
          role: role == null ? null : AccessRole.values.byName(role),
        ),
        item: itemJson == null
            ? null
            : DriveItemView.fromJson(
                (jsonDecode(itemJson) as Map).cast<String, dynamic>(),
              ),
        loggedOps: ops.length,
        storedOutbox: stored,
        pinned: row['pinned'] == 1,
      );
    } on Object catch (e) {
      // A corrupt cache entry must never block opening the document: drop
      // it (the document then opens from the server). Cannot happen with
      // transactional writes; logged for diagnosis.
      debugPrint('Discarding the cached copy of $doc: $e');
      await deleteDocument(doc, withOutbox: true);
      return null;
    }
  }

  /// Writes one consistent sync state (Write 03 §3.1): either a new
  /// snapshot ([compact]) or appended server [ops], plus the outbox diff.
  Future<void> writeSync({
    required String documentUuid,
    required String itemUuid,
    required SyncCapture capture,
    required List<(int, Delta)> ops,
    required bool compact,
    required Map<String, String> upserts,
    required Map<String, PendingOpRecord> records,
    required Set<String> deletes,
    required Map<String, String> deltaJson,
    bool replaceOutbox = false,
    DriveItemView? item,
  }) {
    final now = _ms(clock.now());
    final meta = capture.meta == null
        ? null
        : jsonEncode(capture.meta!.toJson());
    return db.writeTransaction((tx) async {
      if (compact) {
        final snapshot = jsonEncode(capture.serverDocument.toJson());
        await tx.execute(
          '''
          INSERT INTO local_document (document_uuid, item_uuid, title,
            item_json, pinned, last_opened_at, snapshot_json,
            snapshot_revision, head_revision, meta_json, role, theme_id,
            updated_at, size_bytes)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(document_uuid) DO UPDATE SET
            title = CASE WHEN excluded.item_json IS NULL
              THEN local_document.title ELSE excluded.title END,
            item_json = COALESCE(excluded.item_json, local_document.item_json),
            pinned = CASE WHEN excluded.item_json IS NULL
              THEN local_document.pinned ELSE excluded.pinned END,
            snapshot_json = excluded.snapshot_json,
            snapshot_revision = excluded.snapshot_revision,
            head_revision = excluded.head_revision,
            meta_json = excluded.meta_json,
            role = excluded.role,
            theme_id = excluded.theme_id,
            updated_at = excluded.updated_at,
            size_bytes = excluded.size_bytes''',
          [
            documentUuid,
            itemUuid,
            item?.name ?? '',
            item == null ? null : jsonEncode(item.toJson()),
            (item?.pinnedOffline ?? false) ? 1 : 0,
            now,
            snapshot,
            capture.revision,
            capture.revision,
            meta,
            capture.role?.name,
            capture.meta?.themeId?.uuid,
            now,
            snapshot.length,
          ],
        );
        await tx.execute(
          'DELETE FROM local_document_op WHERE document_uuid = ?',
          [documentUuid],
        );
      } else {
        if (ops.isNotEmpty) {
          await tx.executeBatch(
            'INSERT OR REPLACE INTO local_document_op '
            '(document_uuid, revision, delta_json) VALUES (?, ?, ?)',
            [
              for (final (rev, op) in ops)
                [documentUuid, rev, jsonEncode(op.toJson())],
            ],
          );
        }
        await tx.execute(
          'UPDATE local_document SET head_revision = ?, meta_json = ?, '
          'role = ?, theme_id = ?, updated_at = ? WHERE document_uuid = ?',
          [
            capture.revision,
            meta,
            capture.role?.name,
            capture.meta?.themeId?.uuid,
            now,
            documentUuid,
          ],
        );
      }
      if (replaceOutbox) {
        await tx.execute(
          'DELETE FROM local_pending_op WHERE document_uuid = ? AND kind != ?',
          [documentUuid, _metaKind],
        );
      } else if (deletes.isNotEmpty) {
        await tx.executeBatch(
          'DELETE FROM local_pending_op '
          'WHERE document_uuid = ? AND client_op_id = ?',
          [
            for (final id in deletes) [documentUuid, id],
          ],
        );
      }
      if (upserts.isNotEmpty) {
        await tx.executeBatch(
          'INSERT OR REPLACE INTO local_pending_op (document_uuid, '
          'client_op_id, seq, base_revision, delta_json, kind, group_id, '
          'inflight, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            for (final id in upserts.keys)
              [
                documentUuid,
                id,
                records[id]!.seq,
                records[id]!.baseRevision,
                deltaJson[id]!,
                records[id]!.kind.name,
                records[id]!.groupId,
                records[id]!.inflight ? 1 : 0,
                _ms(records[id]!.createdAt),
              ],
          ],
        );
      }
    });
  }

  /// Creates the cache entry of a document created on this device (empty
  /// server document at revision 0, suite 12 §1.2) with [initial] content
  /// as its first pending op.
  Future<void> createLocalDocument({
    required UuidValue documentUuid,
    required DriveItemView item,
    required UuidValue clientOpId,
    Delta? initial,
  }) {
    final now = _ms(clock.now());
    final empty = jsonEncode((Delta()..insert('\n')).toJson());
    return db.writeTransaction((tx) async {
      await tx.execute(
        '''
        INSERT OR IGNORE INTO local_document (document_uuid, item_uuid, title,
          item_json, snapshot_json, snapshot_revision, head_revision, role,
          last_opened_at, updated_at, size_bytes, pinned)
        VALUES (?, ?, ?, ?, ?, 0, 0, ?, ?, ?, ?, 0)''',
        [
          documentUuid.uuid,
          item.uuid.uuid,
          item.name,
          jsonEncode(item.toJson()),
          empty,
          AccessRole.owner.name,
          now,
          now,
          empty.length,
        ],
      );
      if (initial != null) {
        final change = DeltaUtils.canonical(
          (Delta()..insert('\n')).diff(DeltaUtils.canonical(initial)),
        );
        if (!DeltaUtils.isNoop(change)) {
          await tx.execute(
            'INSERT OR REPLACE INTO local_pending_op (document_uuid, '
            'client_op_id, seq, base_revision, delta_json, kind, inflight, '
            'created_at) VALUES (?, ?, 0, 0, ?, ?, 0, ?)',
            [
              documentUuid.uuid,
              clientOpId.uuid,
              jsonEncode(change.toJson()),
              DocumentOpKind.content.name,
              now,
            ],
          );
        }
      }
    });
  }

  /// Records that [item] was opened (or seen): drive item, title, pin and
  /// last-opened time of its cache entry.
  Future<void> touch(
    UuidValue documentUuid,
    DriveItemView item, {
    bool opened = false,
  }) => db.execute(
    'UPDATE local_document SET item_json = ?, title = ?, pinned = ?'
    '${opened ? ', last_opened_at = ?' : ''} WHERE document_uuid = ?',
    [
      jsonEncode(item.toJson()),
      item.name,
      item.pinnedOffline ? 1 : 0,
      if (opened) _ms(clock.now()),
      documentUuid.uuid,
    ],
  );

  /// Marks [documentUuid] opened now.
  Future<void> markOpened(UuidValue documentUuid) => db.execute(
    'UPDATE local_document SET last_opened_at = ? WHERE document_uuid = ?',
    [_ms(clock.now()), documentUuid.uuid],
  );

  /// Sets the pin of the cache entry of drive item [itemUuid].
  Future<void> setPinned(UuidValue itemUuid, bool pinned) => db.execute(
    'UPDATE local_document SET pinned = ? WHERE item_uuid = ?',
    [pinned ? 1 : 0, itemUuid.uuid],
  );

  /// Stores a downloaded server snapshot (prefetch of pinned documents).
  /// Leaves an entry with pending changes alone.
  Future<void> putSnapshot({
    required UuidValue documentUuid,
    required DriveItemView item,
    required Delta document,
    required int revision,
    DocumentMetaView? meta,
  }) {
    final snapshot = jsonEncode(DeltaUtils.canonical(document).toJson());
    final now = _ms(clock.now());
    return db.writeTransaction((tx) async {
      final pending = await tx.get(
        'SELECT COUNT(*) AS n FROM local_pending_op WHERE document_uuid = ?',
        [documentUuid.uuid],
      );
      final existing = await tx.getOptional(
        'SELECT head_revision FROM local_document WHERE document_uuid = ?',
        [documentUuid.uuid],
      );
      if (existing != null &&
          ((pending['n']! as int) > 0 ||
              (existing['head_revision']! as int) >= revision)) {
        await tx.execute(
          'UPDATE local_document SET item_json = ?, title = ?, pinned = ? '
          'WHERE document_uuid = ?',
          [
            jsonEncode(item.toJson()),
            item.name,
            item.pinnedOffline ? 1 : 0,
            documentUuid.uuid,
          ],
        );
        return;
      }
      await tx.execute(
        'DELETE FROM local_document_op WHERE document_uuid = ?',
        [documentUuid.uuid],
      );
      await tx.execute(
        '''
        INSERT INTO local_document (document_uuid, item_uuid, title,
          item_json, snapshot_json, snapshot_revision, head_revision,
          meta_json, role, theme_id, pinned, updated_at, size_bytes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(document_uuid) DO UPDATE SET
          title = excluded.title,
          item_json = excluded.item_json,
          snapshot_json = excluded.snapshot_json,
          snapshot_revision = excluded.snapshot_revision,
          head_revision = excluded.head_revision,
          meta_json = COALESCE(excluded.meta_json, local_document.meta_json),
          role = excluded.role,
          theme_id = COALESCE(excluded.theme_id, local_document.theme_id),
          pinned = excluded.pinned,
          updated_at = excluded.updated_at,
          size_bytes = excluded.size_bytes''',
        [
          documentUuid.uuid,
          item.uuid.uuid,
          item.name,
          jsonEncode(item.toJson()),
          snapshot,
          revision,
          revision,
          meta == null ? null : jsonEncode(meta.toJson()),
          item.role.name,
          meta?.themeId?.uuid,
          item.pinnedOffline ? 1 : 0,
          now,
          snapshot.length,
        ],
      );
    });
  }

  /// Every cached document.
  Future<List<LocalDocumentSummary>> list() async {
    final rows = await db.getAll('''
      SELECT d.document_uuid, d.item_uuid, d.title, d.pinned,
        d.last_opened_at, d.size_bytes,
        (SELECT COUNT(*) FROM local_pending_op p
          WHERE p.document_uuid = d.document_uuid) AS pending
      FROM local_document d''');
    return [
      for (final r in rows)
        LocalDocumentSummary(
          documentUuid: r['document_uuid']! as String,
          itemUuid: r['item_uuid']! as String,
          title: r['title']! as String,
          pinned: r['pinned'] == 1,
          lastOpenedAt: _time(r['last_opened_at']),
          sizeBytes: r['size_bytes']! as int,
          pendingOps: r['pending']! as int,
        ),
    ];
  }

  /// Documents with an outbox (content or metadata).
  Future<List<String>> documentsWithPendingOps() async {
    final rows = await db.getAll(
      'SELECT DISTINCT document_uuid FROM local_pending_op',
    );
    return [for (final r in rows) r['document_uuid']! as String];
  }

  /// Removes a cached document (eviction). Its outbox is kept unless
  /// [withOutbox].
  Future<void> deleteDocument(String documentUuid, {bool withOutbox = false}) =>
      db.writeTransaction((tx) async {
        for (final t in [
          'local_document_op',
          'local_document',
          'local_undo_stack',
          if (withOutbox) 'local_pending_op',
        ]) {
          await tx.execute('DELETE FROM $t WHERE document_uuid = ?', [
            documentUuid,
          ]);
        }
      });

  // ---------------------------------------------------------------------------
  // Metadata outbox.

  Future<void> addMetaOp(UuidValue documentUuid, PendingMetaOp op) =>
      db.execute(
        'INSERT OR REPLACE INTO local_pending_op (document_uuid, '
        'client_op_id, seq, base_revision, delta_json, kind, inflight, '
        'created_at) VALUES (?, ?, ?, 0, ?, ?, 0, ?)',
        [
          documentUuid.uuid,
          op.clientOpId.uuid,
          _ms(op.createdAt),
          jsonEncode({'field': op.field, 'valueJson': op.valueJson}),
          _metaKind,
          _ms(op.createdAt),
        ],
      );

  Future<List<PendingMetaOp>> metaOps(UuidValue documentUuid) async {
    final rows = await db.getAll(
      'SELECT * FROM local_pending_op WHERE document_uuid = ? AND kind = ? '
      'ORDER BY seq',
      [documentUuid.uuid, _metaKind],
    );
    return [
      for (final r in rows)
        () {
          final j = jsonDecode(r['delta_json']! as String) as Map;
          return PendingMetaOp(
            clientOpId: UuidValue.fromString(r['client_op_id']! as String),
            field: j['field'] as String,
            valueJson: j['valueJson'] as String,
            createdAt: _time(r['created_at']) ?? clock.now(),
          );
        }(),
    ];
  }

  Future<void> deleteMetaOp(UuidValue documentUuid, UuidValue clientOpId) =>
      db.execute(
        'DELETE FROM local_pending_op WHERE document_uuid = ? '
        'AND client_op_id = ?',
        [documentUuid.uuid, clientOpId.uuid],
      );

  // ---------------------------------------------------------------------------
  // Undo.

  Future<void> saveUndo(String documentUuid, String json, String docHash) =>
      db.execute(
        'INSERT OR REPLACE INTO local_undo_stack (document_uuid, stack_json, '
        'doc_hash, updated_at) VALUES (?, ?, ?, ?)',
        [documentUuid, json, docHash, _ms(clock.now())],
      );

  Future<(String json, String hash)?> loadUndo(String documentUuid) async {
    final r = await db.getOptional(
      'SELECT stack_json, doc_hash FROM local_undo_stack '
      'WHERE document_uuid = ?',
      [documentUuid],
    );
    if (r == null) return null;
    return (r['stack_json']! as String, r['doc_hash']! as String);
  }

  // ---------------------------------------------------------------------------
  // Uploads.

  Future<void> addUpload(PendingUpload u) => db.execute(
    'INSERT OR REPLACE INTO local_pending_upload (file_uuid, item_uuid, '
    'bytes, mime_type, file_name, created_at, attempts, last_error) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    [
      u.fileUuid.uuid,
      u.itemUuid?.uuid,
      u.bytes,
      u.mimeType,
      u.fileName,
      _ms(u.createdAt),
      u.attempts,
      u.lastError,
    ],
  );

  PendingUpload _upload(Map<String, Object?> r) => PendingUpload(
    fileUuid: UuidValue.fromString(r['file_uuid']! as String),
    itemUuid: r['item_uuid'] == null
        ? null
        : UuidValue.fromString(r['item_uuid']! as String),
    bytes: switch (r['bytes']) {
      final Uint8List b => b,
      final List<int> b => Uint8List.fromList(b),
      _ => Uint8List(0),
    },
    mimeType: r['mime_type']! as String,
    fileName: r['file_name']! as String,
    createdAt: _time(r['created_at']) ?? clock.now(),
    attempts: r['attempts']! as int,
    lastError: r['last_error'] as String?,
  );

  Future<List<PendingUpload>> uploads() async => [
    for (final r in await db.getAll(
      'SELECT * FROM local_pending_upload ORDER BY created_at',
    ))
      _upload(r),
  ];

  Future<PendingUpload?> upload(UuidValue fileUuid) async {
    final r = await db.getOptional(
      'SELECT * FROM local_pending_upload WHERE file_uuid = ?',
      [fileUuid.uuid],
    );
    return r == null ? null : _upload(r);
  }

  Future<void> recordUploadFailure(UuidValue fileUuid, String error) =>
      db.execute(
        'UPDATE local_pending_upload SET attempts = attempts + 1, '
        'last_error = ? WHERE file_uuid = ?',
        [error, fileUuid.uuid],
      );

  Future<void> deleteUpload(UuidValue fileUuid) => db.execute(
    'DELETE FROM local_pending_upload WHERE file_uuid = ?',
    [fileUuid.uuid],
  );

  // ---------------------------------------------------------------------------
  // Usage and clearing.

  Future<({int documents, int pinned, int pendingDocs, int uploads, int bytes})>
  usage() async {
    final r = await db.get('''
      SELECT
        (SELECT COUNT(*) FROM local_document) AS documents,
        (SELECT COUNT(*) FROM local_document WHERE pinned = 1) AS pinned,
        (SELECT COUNT(DISTINCT document_uuid) FROM local_pending_op)
          AS pending_docs,
        (SELECT COUNT(*) FROM local_pending_upload) AS uploads,
        (SELECT COALESCE(SUM(size_bytes), 0) FROM local_document) +
        (SELECT COALESCE(SUM(LENGTH(delta_json)), 0) FROM local_document_op) +
        (SELECT COALESCE(SUM(LENGTH(delta_json)), 0) FROM local_pending_op) +
        (SELECT COALESCE(SUM(LENGTH(bytes)), 0) FROM local_pending_upload)
          AS bytes''');
    return (
      documents: r['documents']! as int,
      pinned: r['pinned']! as int,
      pendingDocs: r['pending_docs']! as int,
      uploads: r['uploads']! as int,
      bytes: r['bytes']! as int,
    );
  }

  /// Truncates every table (Clear local data; on the web the database
  /// itself cannot be deleted).
  Future<void> clear() => db.writeTransaction((tx) async {
    for (final t in const [
      'local_document',
      'local_document_op',
      'local_pending_op',
      'local_undo_stack',
      'local_pending_upload',
    ]) {
      await tx.execute('DELETE FROM $t');
    }
  });
}
