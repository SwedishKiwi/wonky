import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

import 'write_local_store.dart';

/// Images inserted while offline (suite 12 §1.1 `LocalPendingUpload`).
///
/// The bytes are stored before the upload starts, so a document can
/// reference `wonky-file://<fileUuid>` right away, render the image from the
/// local bytes (also after a reload) and upload it whenever the server is
/// reachable. Uploads are idempotent on the client-generated `fileUuid`;
/// failures are retried with exponential backoff (2 s → 10 min), at most
/// [maxAttempts] times per app start.
class PendingUploads {
  PendingUploads({
    required this.store,
    required this.files,
    required this.connectivity,
    this.onChanged,
    this.maxAttempts = 12,
  });

  final WriteLocalStore store;
  final FileRepository files;
  final ConnectivityService connectivity;
  final VoidCallback? onChanged;
  final int maxAttempts;

  final _completed = StreamController<UuidValue>.broadcast();

  /// Files whose upload finished (image services clear their placeholder).
  Stream<UuidValue> get completed => _completed.stream;

  final _refused = StreamController<UuidValue>.broadcast();

  /// Files the server refused because the storage quota is full (Drive 03
  /// §6.3): they stay on this device, are not retried automatically and
  /// show "Not uploaded — out of storage" until [retry] or [cancel].
  Stream<UuidValue> get refused => _refused.stream;

  final Set<String> _outOfStorage = {};

  /// Whether the server refused [fileUuid] on quota (see [refused]).
  bool isOutOfStorage(UuidValue fileUuid) =>
      _outOfStorage.contains(fileUuid.uuid);

  /// Tries a refused upload again (*Retry* on the placeholder).
  void retry(UuidValue fileUuid) {
    final id = fileUuid.uuid;
    _outOfStorage.remove(id);
    _attempts[id] = 0;
    _notBefore.remove(id);
    _kick();
  }

  /// Marks [fileUuid] as refused on quota (also used by the image services
  /// for their own uploads).
  void markOutOfStorage(UuidValue fileUuid) {
    if (!_known.contains(fileUuid.uuid)) return;
    _outOfStorage.add(fileUuid.uuid);
    if (!_refused.isClosed) _refused.add(fileUuid);
    onChanged?.call();
  }

  final Map<String, Uint8List> _bytes = {};
  final Set<String> _known = {};
  final Set<String> _claimed = {};
  final Set<String> _storing = {};
  final Map<String, int> _attempts = {};
  final Map<String, DateTime> _notBefore = {};
  Timer? _timer;
  bool _running = false;
  bool _started = false;
  bool _disposed = false;

  /// Files waiting for upload.
  int get length => _known.length;

  /// Whether [fileUuid] waits for upload on this device.
  bool contains(UuidValue fileUuid) => _known.contains(fileUuid.uuid);

  /// Loads the queue and starts uploading.
  void start() {
    if (_started) return;
    _started = true;
    connectivity.addListener(_onConnectivity);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      for (final u in await store.uploads()) {
        _known.add(u.fileUuid.uuid);
        _attempts[u.fileUuid.uuid] = 0;
      }
    } on Object catch (e) {
      debugPrint('Reading pending uploads failed: $e');
    }
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
    required UuidValue fileUuid,
    UuidValue? itemUuid,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
  }) async {
    _bytes[fileUuid.uuid] = bytes;
    _known.add(fileUuid.uuid);
    // Not uploaded by the queue before its row is stored (a run reading the
    // row too early would forget it).
    _storing.add(fileUuid.uuid);
    try {
      await store.addUpload(
        PendingUpload(
          fileUuid: fileUuid,
          itemUuid: itemUuid,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
          createdAt: clock.now(),
        ),
      );
    } finally {
      _storing.remove(fileUuid.uuid);
    }
    onChanged?.call();
    _kick();
  }

  /// The local bytes of a pending upload (renders the image offline).
  Future<Uint8List?> bytesOf(UuidValue fileUuid) async {
    final cached = _bytes[fileUuid.uuid];
    if (cached != null) return cached;
    if (!_known.contains(fileUuid.uuid)) return null;
    final u = await store.upload(fileUuid);
    if (u == null) return null;
    return _bytes[fileUuid.uuid] = u.bytes;
  }

  /// The image services upload [fileUuid] themselves (with progress); the
  /// queue leaves it alone until [release].
  void claim(UuidValue fileUuid) => _claimed.add(fileUuid.uuid);

  void release(UuidValue fileUuid) {
    _claimed.remove(fileUuid.uuid);
    _kick();
  }

  /// [fileUuid] is on the server.
  Future<void> complete(UuidValue fileUuid) async {
    _claimed.remove(fileUuid.uuid);
    _known.remove(fileUuid.uuid);
    _bytes.remove(fileUuid.uuid);
    _attempts.remove(fileUuid.uuid);
    _outOfStorage.remove(fileUuid.uuid);
    try {
      await store.deleteUpload(fileUuid);
    } on Object catch (e) {
      debugPrint('Removing a finished upload failed: $e');
    }
    if (!_completed.isClosed) _completed.add(fileUuid);
    onChanged?.call();
  }

  /// Forgets an upload (the image was removed before it was uploaded).
  Future<void> cancel(UuidValue fileUuid) => complete(fileUuid);

  Future<void> clear() async {
    _known.clear();
    _bytes.clear();
    _attempts.clear();
    _notBefore.clear();
    _outOfStorage.clear();
  }

  void _kick() {
    if (_disposed || _running || !connectivity.online) return;
    _timer?.cancel();
    _timer = null;
    unawaited(_run());
  }

  Future<void> _run() async {
    _running = true;
    try {
      while (!_disposed && connectivity.online) {
        final now = clock.now();
        final next = _known.where((id) {
          if (_claimed.contains(id) || _storing.contains(id)) return false;
          if (_outOfStorage.contains(id)) return false;
          if ((_attempts[id] ?? 0) >= maxAttempts) return false;
          final nb = _notBefore[id];
          return nb == null || !nb.isAfter(now);
        }).firstOrNull;
        if (next == null) break;
        await _upload(UuidValue.fromString(next));
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
            !_claimed.contains(e.key) &&
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

  Future<void> _upload(UuidValue fileUuid) async {
    final id = fileUuid.uuid;
    final u = await store.upload(fileUuid);
    if (u == null) {
      _known.remove(id);
      return;
    }
    try {
      await files.upload(
        fileUuid: u.fileUuid,
        itemUuid: u.itemUuid,
        fileName: u.fileName,
        mimeType: u.mimeType,
        bytes: u.bytes,
      );
      await complete(fileUuid);
    } catch (e) {
      if (QuotaErrorPresenter.isQuotaExceeded(e)) {
        // Out of storage: kept on this device until Retry / Remove.
        try {
          await store.recordUploadFailure(fileUuid, '$e');
        } catch (_) {}
        markOutOfStorage(fileUuid);
        return;
      }
      final n = (_attempts[id] ?? 0) + 1;
      _attempts[id] = n;
      final seconds = min(600, 2 * pow(2, n - 1).toInt());
      _notBefore[id] = clock.now().add(Duration(seconds: seconds));
      try {
        await store.recordUploadFailure(fileUuid, '$e');
      } catch (_) {}
      if (isOfflineError(e)) connectivity.reportFailure();
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(_completed.close());
    unawaited(_refused.close());
    _timer?.cancel();
    connectivity.removeListener(_onConnectivity);
  }
}
