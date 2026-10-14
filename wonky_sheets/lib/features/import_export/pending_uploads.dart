import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show StoredFileKind, UuidValue;

/// Schema of `sheets_uploads_<userId>.db` (suite 12 §1.1
/// `LocalPendingUpload`): image files of this device that are not on the
/// server yet (imported XLSX images, inserted images), and the recently
/// imported files (*Recent uploads*). Local only.
final sheetsUploadMigrations = SqliteMigrations()
  ..add(
    SqliteMigration(1, (tx) async {
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
  )
  ..add(
    SqliteMigration(2, (tx) async {
      await tx.execute('''
        CREATE TABLE local_recent_import (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL,
          size INTEGER NOT NULL,
          bytes BLOB NOT NULL,
          imported_at INTEGER NOT NULL
        )''');
    }),
  );

/// A file imported on this device (*Recent uploads* of the import dialog,
/// 11 §2.1).
@immutable
class RecentImport {
  const RecentImport({
    required this.id,
    required this.name,
    required this.size,
    required this.importedAt,
  });

  final String id;
  final String name;
  final int size;
  final DateTime importedAt;
}

/// One queued upload.
@immutable
class SheetsPendingUpload {
  const SheetsPendingUpload({
    required this.fileUuid,
    required this.bytes,
    required this.mimeType,
    required this.fileName,
    this.itemUuid,
  });

  final String fileUuid;
  final String? itemUuid;
  final Uint8List bytes;
  final String mimeType;
  final String fileName;
}

/// Where queued uploads are kept (SQLite; a map in tests).
abstract class SheetsUploadStore {
  Future<void> put(SheetsPendingUpload u);
  Future<SheetsPendingUpload?> get(String fileUuid);
  Future<List<String>> ids();
  Future<void> remove(String fileUuid);
  Future<void> recordFailure(String fileUuid, String error);

  /// Recent imports, newest first (without bytes).
  Future<List<RecentImport>> recent();
  Future<Uint8List?> recentBytes(String id);

  /// Stores [bytes] as a recent import and keeps the newest [keep].
  Future<void> putRecent(RecentImport r, Uint8List bytes, {int keep = 8});
  Future<void> close();
}

/// [SheetsUploadStore] on the per-user SQLite database.
class SqliteSheetsUploadStore implements SheetsUploadStore {
  SqliteSheetsUploadStore(this.db);

  final SqliteDatabase db;

  @override
  Future<void> put(SheetsPendingUpload u) => db.execute(
    'INSERT OR REPLACE INTO local_pending_upload (file_uuid, item_uuid, '
    'bytes, mime_type, file_name, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    [
      u.fileUuid,
      u.itemUuid,
      u.bytes,
      u.mimeType,
      u.fileName,
      clock.now().millisecondsSinceEpoch,
    ],
  );

  @override
  Future<SheetsPendingUpload?> get(String fileUuid) async {
    final r = await db.getOptional(
      'SELECT * FROM local_pending_upload WHERE file_uuid = ?',
      [fileUuid],
    );
    if (r == null) return null;
    return SheetsPendingUpload(
      fileUuid: r['file_uuid']! as String,
      itemUuid: r['item_uuid'] as String?,
      bytes: switch (r['bytes']) {
        final Uint8List b => b,
        final List<int> b => Uint8List.fromList(b),
        _ => Uint8List(0),
      },
      mimeType: r['mime_type']! as String,
      fileName: r['file_name']! as String,
    );
  }

  @override
  Future<List<String>> ids() async => [
    for (final r in await db.getAll(
      'SELECT file_uuid FROM local_pending_upload ORDER BY created_at',
    ))
      r['file_uuid']! as String,
  ];

  @override
  Future<void> remove(String fileUuid) => db.execute(
    'DELETE FROM local_pending_upload WHERE file_uuid = ?',
    [fileUuid],
  );

  @override
  Future<void> recordFailure(String fileUuid, String error) => db.execute(
    'UPDATE local_pending_upload SET attempts = attempts + 1, '
    'last_error = ? WHERE file_uuid = ?',
    [error, fileUuid],
  );

  @override
  Future<List<RecentImport>> recent() async => [
    for (final r in await db.getAll(
      'SELECT id, name, size, imported_at FROM local_recent_import '
      'ORDER BY imported_at DESC',
    ))
      RecentImport(
        id: r['id']! as String,
        name: r['name']! as String,
        size: r['size']! as int,
        importedAt: DateTime.fromMillisecondsSinceEpoch(
          r['imported_at']! as int,
        ),
      ),
  ];

  @override
  Future<Uint8List?> recentBytes(String id) async {
    final r = await db.getOptional(
      'SELECT bytes FROM local_recent_import WHERE id = ?',
      [id],
    );
    return switch (r?['bytes']) {
      final Uint8List b => b,
      final List<int> b => Uint8List.fromList(b),
      _ => null,
    };
  }

  @override
  Future<void> putRecent(RecentImport r, Uint8List bytes, {int keep = 8}) =>
      db.writeTransaction((tx) async {
        await tx.execute(
          'DELETE FROM local_recent_import WHERE name = ? AND size = ?',
          [r.name, r.size],
        );
        await tx.execute(
          'INSERT OR REPLACE INTO local_recent_import (id, name, size, bytes, '
          'imported_at) VALUES (?, ?, ?, ?, ?)',
          [r.id, r.name, r.size, bytes, r.importedAt.millisecondsSinceEpoch],
        );
        await tx.execute(
          'DELETE FROM local_recent_import WHERE id NOT IN (SELECT id FROM '
          'local_recent_import ORDER BY imported_at DESC LIMIT ?)',
          [keep],
        );
      });

  @override
  Future<void> close() => db.close();
}

/// [SheetsUploadStore] in memory (tests).
class MemorySheetsUploadStore implements SheetsUploadStore {
  final Map<String, SheetsPendingUpload> rows = {};

  @override
  Future<void> put(SheetsPendingUpload u) async => rows[u.fileUuid] = u;

  @override
  Future<SheetsPendingUpload?> get(String fileUuid) async => rows[fileUuid];

  @override
  Future<List<String>> ids() async => rows.keys.toList();

  @override
  Future<void> remove(String fileUuid) async => rows.remove(fileUuid);

  @override
  Future<void> recordFailure(String fileUuid, String error) async {}

  final List<(RecentImport, Uint8List)> recents = [];

  @override
  Future<List<RecentImport>> recent() async => [
    for (final (r, _) in recents) r,
  ];

  @override
  Future<Uint8List?> recentBytes(String id) async {
    for (final (r, b) in recents) {
      if (r.id == id) return b;
    }
    return null;
  }

  @override
  Future<void> putRecent(
    RecentImport r,
    Uint8List bytes, {
    int keep = 8,
  }) async {
    recents.removeWhere((e) => e.$1.name == r.name && e.$1.size == r.size);
    recents.insert(0, (r, bytes));
    if (recents.length > keep) recents.removeRange(keep, recents.length);
  }

  @override
  Future<void> close() async {}
}

/// Durable image uploads of Sheets (suite 12 §1.1 `LocalPendingUpload`,
/// like Write's images): the bytes are stored on the device before the
/// upload starts, so a spreadsheet can reference `wonky-file://<uuid>` at
/// once, show the image from the local bytes (also offline and after a
/// reload) and upload it whenever the server is reachable. Uploads are
/// idempotent on the client-generated file uuid; failures retry with
/// exponential backoff (2 s → 10 min), at most [maxAttempts] times per app
/// start. One queue per signed-in user ([install] at command registration).
class SheetsPendingUploads extends ChangeNotifier {
  SheetsPendingUploads({
    required this.store,
    required this.files,
    required this.connectivity,
    this.maxAttempts = 12,
  });

  final SheetsUploadStore store;
  final FileRepository files;
  final ConnectivityService connectivity;
  final int maxAttempts;

  final _completed = StreamController<String>.broadcast();

  /// File uuids whose upload finished.
  Stream<String> get completed => _completed.stream;

  final Map<String, Uint8List> _bytes = {};
  final Set<String> _known = {};
  final Map<String, int> _attempts = {};
  final Map<String, DateTime> _notBefore = {};
  Timer? _timer;
  bool _running = false;
  bool _disposed = false;
  late final Future<void> _loaded = _load();

  /// Files waiting for upload.
  int get length => _known.length;

  /// Whether [fileUuid] waits for upload on this device.
  bool contains(String fileUuid) => _known.contains(fileUuid);

  /// Loads the queue and starts uploading.
  Future<void> start() {
    connectivity.addListener(_onConnectivity);
    return _loaded;
  }

  Future<void> _load() async {
    try {
      for (final id in await store.ids()) {
        _known.add(id);
      }
    } on Object catch (e) {
      debugPrint('Reading pending uploads failed: $e');
    }
    if (_known.isNotEmpty) notifyListeners();
    _kick();
  }

  void _onConnectivity() {
    if (connectivity.online) {
      _notBefore.clear();
      _kick();
    }
  }

  /// Stores [bytes] durably; the upload follows when possible.
  Future<void> add({
    required String fileUuid,
    String? itemUuid,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
  }) async {
    _bytes[fileUuid] = bytes;
    _known.add(fileUuid);
    try {
      await store.put(
        SheetsPendingUpload(
          fileUuid: fileUuid,
          itemUuid: itemUuid,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
      );
    } on Object catch (e) {
      // Still uploads from memory in this session.
      debugPrint('Storing a pending upload failed: $e');
    }
    notifyListeners();
    _kick();
  }

  /// The local bytes of a pending upload (renders and exports the image
  /// offline).
  Future<Uint8List?> bytesOf(String fileUuid) async {
    final cached = _bytes[fileUuid];
    if (cached != null) return cached;
    await _loaded;
    if (!_known.contains(fileUuid)) return null;
    final u = await store.get(fileUuid);
    if (u == null) return null;
    return _bytes[fileUuid] = u.bytes;
  }

  Future<void> _complete(String fileUuid) async {
    _known.remove(fileUuid);
    _bytes.remove(fileUuid);
    _attempts.remove(fileUuid);
    _notBefore.remove(fileUuid);
    try {
      await store.remove(fileUuid);
    } on Object catch (e) {
      debugPrint('Removing a finished upload failed: $e');
    }
    if (!_completed.isClosed) _completed.add(fileUuid);
    if (!_disposed) notifyListeners();
  }

  /// Files above this size are not kept as recent imports.
  static const maxRecentBytes = 10 * 1024 * 1024;

  /// Remembers an imported file for *Recent uploads* (small files only).
  Future<void> recordRecentImport(String name, Uint8List bytes) async {
    if (bytes.length > maxRecentBytes) return;
    try {
      await store.putRecent(
        RecentImport(
          id: '${clock.now().microsecondsSinceEpoch}',
          name: name,
          size: bytes.length,
          importedAt: clock.now(),
        ),
        bytes,
      );
    } on Object catch (e) {
      debugPrint('Storing a recent import failed: $e');
    }
  }

  /// Recent imports of this device, newest first.
  Future<List<RecentImport>> recentImports() async {
    try {
      return await store.recent();
    } on Object catch (e) {
      debugPrint('Reading recent imports failed: $e');
      return const [];
    }
  }

  /// The bytes of a recent import.
  Future<Uint8List?> recentImportBytes(String id) => store.recentBytes(id);

  /// Uploads now if online (tests, reconnect).
  Future<void> flush() async {
    await _loaded;
    _timer?.cancel();
    final running = _runFuture;
    if (running != null) await running;
    if (_disposed || !connectivity.online) return;
    await (_runFuture = _run());
  }

  Future<void>? _runFuture;

  void _kick() {
    if (_disposed || _running || !connectivity.online) return;
    _timer?.cancel();
    _timer = null;
    _runFuture = _run();
  }

  Future<void> _run() async {
    _running = true;
    try {
      while (!_disposed && connectivity.online) {
        final now = clock.now();
        final next = _known.where((id) {
          if ((_attempts[id] ?? 0) >= maxAttempts) return false;
          final nb = _notBefore[id];
          return nb == null || !nb.isAfter(now);
        }).firstOrNull;
        if (next == null) break;
        await _upload(next);
      }
    } finally {
      _running = false;
      _scheduleNext();
    }
  }

  void _scheduleNext() {
    if (_disposed || _notBefore.isEmpty || !connectivity.online) return;
    final waiting = [
      for (final e in _notBefore.entries)
        if (_known.contains(e.key) && (_attempts[e.key] ?? 0) < maxAttempts)
          e.value,
    ];
    if (waiting.isEmpty) return;
    final at = waiting.reduce((a, b) => a.isBefore(b) ? a : b);
    var delay = at.difference(clock.now());
    if (delay.isNegative) delay = Duration.zero;
    _timer?.cancel();
    _timer = Timer(delay, _kick);
  }

  Future<void> _upload(String id) async {
    final SheetsPendingUpload? u;
    try {
      u = await store.get(id);
    } on Object catch (e) {
      debugPrint('Reading a pending upload failed: $e');
      _attempts[id] = maxAttempts;
      return;
    }
    final bytes = u?.bytes ?? _bytes[id];
    if (u == null && bytes == null) {
      _known.remove(id);
      return;
    }
    try {
      final item = u?.itemUuid;
      await files.upload(
        fileUuid: UuidValue.withValidation(id),
        itemUuid: item == null ? null : UuidValue.withValidation(item),
        fileName: u?.fileName ?? 'image',
        mimeType: u?.mimeType ?? 'application/octet-stream',
        bytes: bytes!,
        kind: StoredFileKind.image,
      );
      await _complete(id);
    } catch (e) {
      final n = (_attempts[id] ?? 0) + 1;
      _attempts[id] = n;
      final seconds = min(600, 2 * pow(2, n - 1).toInt());
      _notBefore[id] = clock.now().add(Duration(seconds: seconds));
      try {
        await store.recordFailure(id, '$e');
      } catch (_) {}
      if (isOfflineError(e)) connectivity.reportFailure();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_completed.close());
    _timer?.cancel();
    connectivity.removeListener(_onConnectivity);
    unawaited(store.close());
    super.dispose();
  }

  // ------------------------------------------------------- per user

  static final Expando<_Installation> _installs = Expando(
    'SheetsPendingUploads',
  );

  /// `sheets_uploads_<userId>.db`.
  static String fileNameFor(String userUuid) => 'sheets_uploads_$userUuid.db';

  /// Opens the signed-in user's queue now and whenever the user changes
  /// (idempotent). [openStore] overrides the SQLite store (tests).
  static void install(
    ShellServices services, {
    Future<SheetsUploadStore> Function(String userUuid)? openStore,
  }) {
    if (_installs[services] != null) return;
    final inst = _Installation(
      services,
      openStore ??
          (user) async => SqliteSheetsUploadStore(
            await LocalDatabases.open(
              fileNameFor(user),
              migrations: sheetsUploadMigrations,
            ),
          ),
    );
    _installs[services] = inst;
    services.currentUser.addListener(inst.onUser);
    inst.onUser();
  }

  /// Installs [queue] for [services] without a user (widget tests).
  @visibleForTesting
  static void installQueue(ShellServices services, SheetsPendingUploads queue) {
    _installs[services] = _Installation(services, (_) async => queue.store)
      ..queue = queue
      ..opening = Future<void>.value();
  }

  /// The signed-in user's queue (null while opening, signed out or not
  /// installed).
  static SheetsPendingUploads? of(ShellServices services) =>
      _installs[services]?.queue;

  /// The queue once open (null when unavailable).
  static Future<SheetsPendingUploads?> ready(ShellServices services) async {
    final inst = _installs[services];
    if (inst == null) return null;
    await inst.opening;
    return inst.queue;
  }
}

class _Installation {
  _Installation(this.s, this.openStore);

  final ShellServices s;
  final Future<SheetsUploadStore> Function(String userUuid) openStore;
  String? user;
  SheetsPendingUploads? queue;
  Future<void>? opening;

  void onUser() {
    final me = s.me;
    final next = me?.uuid.uuid;
    if (next == user) return;
    user = next;
    queue?.dispose();
    queue = null;
    if (next == null) return;
    opening = () async {
      try {
        final store = await openStore(next);
        if (user != next) {
          await store.close();
          return;
        }
        final q = SheetsPendingUploads(
          store: store,
          files: s.repositories.files,
          connectivity: s.connectivity,
        );
        queue = q;
        await q.start();
      } on Object catch (e) {
        debugPrint('Opening the Sheets upload queue failed: $e');
      }
    }();
  }
}
