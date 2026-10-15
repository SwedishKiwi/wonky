import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show StoredFileKind, UuidValue;

/// Schema of `slides_uploads_<userId>.db` (suite 12 §1.1
/// `LocalPendingUpload`): images inserted on this device that are not on
/// the server yet. Local only.
final slidesUploadMigrations = SqliteMigrations()
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
  );

/// One queued upload.
@immutable
class SlidesPendingUpload {
  const SlidesPendingUpload({
    required this.fileUuid,
    required this.bytes,
    required this.mimeType,
    required this.fileName,
    this.itemUuid,
  });

  final String fileUuid;

  /// The deck's drive item (the upload is attached to it and counted
  /// against its owner's quota, Drive 03 §6.3).
  final String? itemUuid;
  final Uint8List bytes;
  final String mimeType;
  final String fileName;
}

/// Where queued uploads are kept (SQLite; a map in tests).
abstract class SlidesUploadStore {
  Future<void> put(SlidesPendingUpload u);
  Future<SlidesPendingUpload?> get(String fileUuid);
  Future<List<String>> ids();
  Future<void> remove(String fileUuid);
  Future<void> recordFailure(String fileUuid, String error);
  Future<void> close();
}

/// [SlidesUploadStore] on the per-user SQLite database.
class SqliteSlidesUploadStore implements SlidesUploadStore {
  SqliteSlidesUploadStore(this.db);

  final SqliteDatabase db;

  @override
  Future<void> put(SlidesPendingUpload u) => db.execute(
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
  Future<SlidesPendingUpload?> get(String fileUuid) async {
    final r = await db.getOptional(
      'SELECT * FROM local_pending_upload WHERE file_uuid = ?',
      [fileUuid],
    );
    if (r == null) return null;
    return SlidesPendingUpload(
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
  Future<void> close() => db.close();
}

/// [SlidesUploadStore] in memory (tests, and when SQLite can't be opened).
class MemorySlidesUploadStore implements SlidesUploadStore {
  final Map<String, SlidesPendingUpload> rows = {};

  @override
  Future<void> put(SlidesPendingUpload u) async => rows[u.fileUuid] = u;

  @override
  Future<SlidesPendingUpload?> get(String fileUuid) async => rows[fileUuid];

  @override
  Future<List<String>> ids() async => rows.keys.toList();

  @override
  Future<void> remove(String fileUuid) async => rows.remove(fileUuid);

  @override
  Future<void> recordFailure(String fileUuid, String error) async {}

  @override
  Future<void> close() async {}
}

/// Durable image uploads of Slides (suite 12 §1.1 `LocalPendingUpload`,
/// the pattern of Write's and Sheets' image queues, 03 §6.5.1): the bytes
/// are stored on the device before the upload starts, so an image element
/// references `wonky-file://<uuid>` at once, renders from the local bytes
/// (also offline and after a reload) and uploads whenever the server is
/// reachable. Uploads are idempotent on the client-generated file uuid;
/// failures retry with exponential backoff (2 s → 10 min), at most
/// [maxAttempts] times per app start. A quota refusal keeps the bytes on
/// the device ("Not uploaded — out of storage", Drive 03 §6.3) until
/// [retry] or [cancel]. One queue per signed-in user ([install]).
class SlidesPendingUploads extends ChangeNotifier {
  SlidesPendingUploads({
    required this.store,
    required this.files,
    required this.connectivity,
    this.maxAttempts = 12,
    this.onQuotaRefused,
  });

  final SlidesUploadStore store;
  final FileRepository files;
  final ConnectivityService connectivity;
  final int maxAttempts;

  /// Called once per refused upload with the server's error (the *Out of
  /// storage* dialog).
  final void Function(Object error)? onQuotaRefused;

  final _completed = StreamController<String>.broadcast();

  /// File uuids whose upload finished.
  Stream<String> get completed => _completed.stream;

  final Map<String, Uint8List> _bytes = {};
  final Set<String> _known = {};
  final Map<String, int> _attempts = {};
  final Map<String, DateTime> _notBefore = {};
  final Set<String> _outOfStorage = {};
  Timer? _timer;
  bool _running = false;
  bool _disposed = false;
  late final Future<void> _loaded = _load();

  /// Files waiting for upload.
  int get length => _known.length;

  /// Whether [fileUuid] waits for upload on this device.
  bool contains(String fileUuid) => _known.contains(fileUuid);

  /// Whether the server refused [fileUuid] because the storage quota is
  /// full: it stays on this device and isn't retried on its own.
  bool isOutOfStorage(String fileUuid) => _outOfStorage.contains(fileUuid);

  /// Tries a refused upload again (*Retry*).
  void retry(String fileUuid) {
    if (!_outOfStorage.remove(fileUuid)) return;
    _attempts[fileUuid] = 0;
    _notBefore.remove(fileUuid);
    notifyListeners();
    _kick();
  }

  /// Forgets a pending upload (*Remove* on a refused image).
  Future<void> cancel(String fileUuid) => _complete(fileUuid);

  /// Loads the queue and starts uploading.
  Future<void> start() {
    connectivity.addListener(_onConnectivity);
    return _loaded;
  }

  Future<void> _load() async {
    try {
      _known.addAll(await store.ids());
    } on Object catch (e) {
      debugPrint('Reading pending Slides uploads failed: $e');
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
        SlidesPendingUpload(
          fileUuid: fileUuid,
          itemUuid: itemUuid,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
      );
    } on Object catch (e) {
      // Still uploads from memory in this session.
      debugPrint('Storing a pending Slides upload failed: $e');
    }
    notifyListeners();
    _kick();
  }

  /// The local bytes of a pending upload (renders the image offline).
  Future<Uint8List?> bytesOf(String fileUuid) async {
    final cached = _bytes[fileUuid];
    if (cached != null) return cached;
    await _loaded;
    if (!_known.contains(fileUuid)) return null;
    final u = await store.get(fileUuid);
    if (u == null) return null;
    return _bytes[fileUuid] = u.bytes;
  }

  /// The bytes of [fileUuid] if they are in memory.
  Uint8List? cachedBytesOf(String fileUuid) => _bytes[fileUuid];

  Future<void> _complete(String fileUuid) async {
    _known.remove(fileUuid);
    _outOfStorage.remove(fileUuid);
    _bytes.remove(fileUuid);
    _attempts.remove(fileUuid);
    _notBefore.remove(fileUuid);
    try {
      await store.remove(fileUuid);
    } on Object catch (e) {
      debugPrint('Removing a finished Slides upload failed: $e');
    }
    if (!_completed.isClosed) _completed.add(fileUuid);
    if (!_disposed) notifyListeners();
  }

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
          if (_outOfStorage.contains(id)) return false;
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
        if (_known.contains(e.key) &&
            !_outOfStorage.contains(e.key) &&
            (_attempts[e.key] ?? 0) < maxAttempts)
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
    final SlidesPendingUpload? u;
    try {
      u = await store.get(id);
    } on Object catch (e) {
      debugPrint('Reading a pending Slides upload failed: $e');
      _attempts[id] = maxAttempts;
      return;
    }
    final bytes = u?.bytes ?? _bytes[id];
    if (bytes == null) {
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
        bytes: bytes,
        kind: StoredFileKind.image,
      );
      await _complete(id);
    } catch (e) {
      if (QuotaErrorPresenter.isQuotaExceeded(e)) {
        _outOfStorage.add(id);
        try {
          await store.recordFailure(id, '$e');
        } catch (_) {}
        if (!_disposed) {
          notifyListeners();
          onQuotaRefused?.call(e);
        }
        return;
      }
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
    'SlidesPendingUploads',
  );

  /// `slides_uploads_<userId>.db`.
  static String fileNameFor(String userUuid) => 'slides_uploads_$userUuid.db';

  /// Opens the signed-in user's queue now and whenever the user changes
  /// (idempotent). [openStore] overrides the SQLite store (tests).
  static void install(
    ShellServices services, {
    Future<SlidesUploadStore> Function(String userUuid)? openStore,
  }) {
    if (_installs[services] != null) return;
    final inst = _Installation(
      services,
      openStore ??
          (user) async => SqliteSlidesUploadStore(
            await LocalDatabases.open(
              fileNameFor(user),
              migrations: slidesUploadMigrations,
            ),
          ),
    );
    _installs[services] = inst;
    services.currentUser.addListener(inst.onUser);
    inst.onUser();
  }

  /// Installs [queue] for [services] without a user (widget tests).
  @visibleForTesting
  static void installQueue(ShellServices services, SlidesPendingUploads queue) {
    _installs[services] = _Installation(services, (_) async => queue.store)
      ..queue = queue
      ..opening = Future<void>.value();
  }

  /// The signed-in user's queue (null while opening, signed out or not
  /// installed).
  static SlidesPendingUploads? of(ShellServices services) =>
      _installs[services]?.queue;

  /// The queue once open (null when unavailable).
  static Future<SlidesPendingUploads?> ready(ShellServices services) async {
    final inst = _installs[services];
    if (inst == null) return null;
    await inst.opening;
    return inst.queue;
  }
}

class _Installation {
  _Installation(this.s, this.openStore);

  final ShellServices s;
  final Future<SlidesUploadStore> Function(String userUuid) openStore;
  String? user;
  SlidesPendingUploads? queue;
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
      SlidesUploadStore store;
      try {
        store = await openStore(next);
      } on Object catch (e) {
        // No SQLite (unsupported browser): uploads still work for this
        // session from memory.
        debugPrint('Opening the Slides upload queue failed: $e');
        store = MemorySlidesUploadStore();
      }
      if (user != next) {
        await store.close();
        return;
      }
      final q = SlidesPendingUploads(
        store: store,
        files: s.repositories.files,
        connectivity: s.connectivity,
        onQuotaRefused: (e) =>
            s.quotaErrors.present(e, reason: QuotaReasons.image),
      );
      queue = q;
      await q.start();
    }();
  }
}
