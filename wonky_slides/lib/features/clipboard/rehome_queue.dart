import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_slides_core/copy.dart' show FileRehome;

/// One file copy of a cross-deck or cross-app paste (03 §12.3, A-03-3):
/// the uploaded file [sourceFileUuid] is copied into [targetItemUuid] as
/// [newFileUuid] (already written into the pasted rows).
@immutable
class RehomeJob {
  const RehomeJob({
    required this.sourceFileUuid,
    required this.newFileUuid,
    required this.targetItemUuid,
  });

  final String sourceFileUuid;
  final String newFileUuid;
  final String targetItemUuid;

  Map<String, Object?> toJson() => {
    'source': sourceFileUuid,
    'copy': newFileUuid,
    'target': targetItemUuid,
  };

  static RehomeJob? fromJson(Object? j) {
    if (j is! Map) return null;
    final s = j['source'], c = j['copy'], t = j['target'];
    if (s is! String || c is! String || t is! String) return null;
    return RehomeJob(sourceFileUuid: s, newFileUuid: c, targetItemUuid: t);
  }
}

/// Copies files with `FileEndpoint.copyToItem` (tests replace it).
typedef RehomeCopier = Future<void> Function(RehomeJob job);

/// The re-homing queue of pasted files (Slides 03 §12.3, 04 §5.8, plan
/// risk R9): a paste into another deck writes the new file uuids into the
/// pasted rows at once and queues one `file.copyToItem` per file. The
/// queue lives in the user's local store (it survives a reload and works
/// offline), runs whenever the server is reachable, and retries with
/// exponential backoff (2 s → 10 min) — the target deck may not be
/// registered yet (created offline) or the source still uploading. While a
/// copy is pending the image renders from its source ([sourceOf]). A quota
/// refusal keeps the job ("Not uploaded — out of storage", like refused
/// uploads, Drive 03 §6.3) until [retry] or [cancel]. Copies are
/// idempotent on the new uuid, so a job repeated after a crash is
/// harmless. One queue per signed-in user ([install]).
class SlidesRehomeQueue extends ChangeNotifier {
  SlidesRehomeQueue({
    required this.store,
    required this.copier,
    required this.connectivity,
    this.maxAttempts = 12,
    this.onQuotaRefused,
  });

  /// Key of the jobs in the user's local store.
  static const storeKey = 'slides.rehome';

  final LocalStore store;
  final RehomeCopier copier;
  final ConnectivityService connectivity;
  final int maxAttempts;

  /// Called once per refused copy with the server's error.
  final void Function(Object error)? onQuotaRefused;

  final Map<String, RehomeJob> _jobs = {};
  final Map<String, int> _attempts = {};
  final Map<String, DateTime> _notBefore = {};
  final Set<String> _outOfStorage = {};
  final _completed = StreamController<String>.broadcast();
  Timer? _timer;
  bool _running = false;
  bool _disposed = false;
  Future<void>? _runFuture;
  late final Future<void> _loaded = _load();

  /// New file uuids whose copy finished.
  Stream<String> get completed => _completed.stream;

  /// Pending copies.
  int get length => _jobs.length;

  /// The pending jobs (tests, diagnostics).
  List<RehomeJob> get jobs => List.unmodifiable(_jobs.values);

  /// Whether the copy [newFileUuid] is still pending.
  bool contains(String newFileUuid) => _jobs.containsKey(newFileUuid);

  /// The source of a pending copy: the image renders from it meanwhile.
  String? sourceOf(String newFileUuid) => _jobs[newFileUuid]?.sourceFileUuid;

  /// Whether the server refused the copy for storage.
  bool isOutOfStorage(String newFileUuid) =>
      _outOfStorage.contains(newFileUuid);

  /// Loads the queue and starts copying.
  Future<void> start() {
    connectivity.addListener(_onConnectivity);
    return _loaded;
  }

  Future<void> _load() async {
    try {
      final raw = await store.read(storeKey);
      if (raw is List) {
        for (final j in raw) {
          final job = RehomeJob.fromJson(j);
          if (job != null) _jobs.putIfAbsent(job.newFileUuid, () => job);
        }
      }
    } on Object catch (e) {
      debugPrint('Reading the Slides re-homing queue failed: $e');
    }
    if (_jobs.isNotEmpty) notifyListeners();
    _kick();
  }

  Future<void> _save() async {
    try {
      await store.write(storeKey, [for (final j in _jobs.values) j.toJson()]);
    } on Object catch (e) {
      debugPrint('Storing the Slides re-homing queue failed: $e');
    }
  }

  void _onConnectivity() {
    if (connectivity.online) {
      _notBefore.clear();
      _kick();
    }
  }

  /// Queues [copies] into [targetItemUuid] (durably, then copies when
  /// possible).
  Future<void> add(List<FileRehome> copies, String targetItemUuid) async {
    if (copies.isEmpty) return;
    await _loaded;
    for (final c in copies) {
      _jobs[c.newFileUuid] = RehomeJob(
        sourceFileUuid: c.sourceFileUuid,
        newFileUuid: c.newFileUuid,
        targetItemUuid: targetItemUuid,
      );
    }
    await _save();
    if (!_disposed) notifyListeners();
    _kick();
  }

  /// Tries a copy refused for storage again (*Retry*).
  void retry(String newFileUuid) {
    if (!_outOfStorage.remove(newFileUuid)) return;
    _attempts[newFileUuid] = 0;
    _notBefore.remove(newFileUuid);
    notifyListeners();
    _kick();
  }

  /// Forgets a pending copy (*Remove* on its image).
  Future<void> cancel(String newFileUuid) => _complete(newFileUuid);

  Future<void> _complete(String id) async {
    if (_jobs.remove(id) == null) return;
    _outOfStorage.remove(id);
    _attempts.remove(id);
    _notBefore.remove(id);
    await _save();
    if (!_completed.isClosed) _completed.add(id);
    if (!_disposed) notifyListeners();
  }

  /// Copies now if online (tests, reconnect).
  Future<void> flush() async {
    await _loaded;
    _timer?.cancel();
    final running = _runFuture;
    if (running != null) await running;
    if (_disposed || !connectivity.online) return;
    await (_runFuture = _run());
  }

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
        final next = _jobs.keys.where((id) {
          if (_outOfStorage.contains(id)) return false;
          if ((_attempts[id] ?? 0) >= maxAttempts) return false;
          final nb = _notBefore[id];
          return nb == null || !nb.isAfter(now);
        }).firstOrNull;
        if (next == null) break;
        await _copy(next);
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
        if (_jobs.containsKey(e.key) &&
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

  Future<void> _copy(String id) async {
    final job = _jobs[id];
    if (job == null) return;
    try {
      await copier(job);
      await _complete(id);
    } catch (e) {
      if (QuotaErrorPresenter.isQuotaExceeded(e)) {
        _outOfStorage.add(id);
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
      if (isOfflineError(e)) connectivity.reportFailure();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_completed.close());
    _timer?.cancel();
    connectivity.removeListener(_onConnectivity);
    super.dispose();
  }

  // ------------------------------------------------------- per user

  static final Expando<_Installation> _installs = Expando('SlidesRehomeQueue');

  /// Opens the signed-in user's queue now and whenever the user changes
  /// (idempotent). The jobs live in the user's scope of the device store.
  static void install(ShellServices services) {
    if (_installs[services] != null) return;
    final inst = _Installation(services);
    _installs[services] = inst;
    services.currentUser.addListener(inst.onUser);
    inst.onUser();
  }

  /// Installs [queue] for [services] without a user (tests).
  @visibleForTesting
  static void installQueue(ShellServices services, SlidesRehomeQueue queue) {
    _installs[services] = _Installation(services)..queue = queue;
  }

  /// The signed-in user's queue (null when signed out or not installed).
  static SlidesRehomeQueue? of(ShellServices services) =>
      _installs[services]?.queue;

  /// `file.copyToItem` on the server.
  static RehomeCopier serverCopier(ShellServices s) => (job) async {
    final client = s.client;
    if (client == null) throw StateError('offline');
    await client.file.copyToItem(
      UuidValue.withValidation(job.sourceFileUuid),
      UuidValue.withValidation(job.newFileUuid),
      UuidValue.withValidation(job.targetItemUuid),
    );
  };
}

class _Installation {
  _Installation(this.s);

  final ShellServices s;
  String? user;
  SlidesRehomeQueue? queue;

  void onUser() {
    final next = s.me?.uuid.uuid;
    if (next == user) return;
    user = next;
    queue?.dispose();
    queue = null;
    if (next == null) return;
    final q = SlidesRehomeQueue(
      store: s.deviceStore.scoped('user.$next.'),
      copier: SlidesRehomeQueue.serverCopier(s),
      connectivity: s.connectivity,
      onQuotaRefused: (e) =>
          s.quotaErrors.present(e, reason: QuotaReasons.image),
    );
    queue = q;
    unawaited(q.start());
  }
}
