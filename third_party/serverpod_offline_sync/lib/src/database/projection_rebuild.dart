part of 'recorder.dart';

/// Settings of the foreign key projection rebuild that follows a change of
/// the synced schema (patch OS-9).
///
/// A registry change (a synced table or column added, dropped or retyped)
/// persists the spaces whose projection it can alter, together with the
/// change. Initialization returns without re-projecting them; a background
/// queue rebuilds them one space per transaction, one space at a time, and a
/// write or merge into a pending space rebuilds that space first. A failure
/// is logged and retried after [retryDelay] (doubling up to [maxRetryDelay]),
/// and a restart resumes from the persisted spaces.
abstract final class OfflineSyncProjectionRebuild {
  /// Delay between initialization and the first background rebuild, so the
  /// rebuild does not compete with startup work.
  static Duration startDelay = const Duration(seconds: 2);

  /// Pause between two spaces of the background rebuild.
  static Duration pause = const Duration(milliseconds: 20);

  /// Delay before the background rebuild retries after a failure.
  static Duration retryDelay = const Duration(seconds: 30);

  /// Upper bound of the doubling retry delay.
  static Duration maxRetryDelay = const Duration(minutes: 10);

  /// Reports progress and failures of the rebuild. Prints by default.
  static void Function(String message, [Object? error, StackTrace? stackTrace]) log =
      _print;

  /// Test hook run inside a space's rebuild transaction, before projecting:
  /// throwing aborts that space's rebuild as a crash would.
  @visibleForTesting
  static FutureOr<void> Function(int spaceId)? debugBeforeSpace;

  static void _print(String message, [Object? error, StackTrace? stackTrace]) {
    // The package has no logger; the host's stdout/console carries it.
    // ignore: avoid_print
    print(
      'serverpod_offline_sync: $message'
      '${error == null ? '' : ': $error'}'
      '${stackTrace == null ? '' : '\n$stackTrace'}',
    );
  }
}

/// The pending projection rebuilds of one [OfflineSyncDatabaseContext]
/// (patch OS-9).
///
/// Holds the spaces read from the registry marker at initialization and
/// runs them on the most recently attached recorder's database (on a server
/// every session wraps the same connection pool, so any recorder will do).
class _ProjectionRebuildQueue {
  _ProjectionRebuildQueue._();

  int? _markerId;
  final _pending = SplayTreeMap<int, Set<String>?>();
  final _inFlight = <int, Future<void>>{};
  CrdtMutationRecorder? _recorder;
  Timer? _timer;
  Future<void>? _run;
  var _failures = 0;
  var _stopped = false;

  /// The number of spaces still to rebuild.
  int get pendingCount => _pending.length;

  /// Whether the projection of [spaceId] still has to be rebuilt.
  bool isPending(int spaceId) => _pending.containsKey(spaceId);

  void _load({required int? markerId, required Map<int, Set<String>?> pending}) {
    _markerId = markerId;
    _pending
      ..clear()
      ..addAll(markerId == null ? const {} : pending);
    if (_pending.isNotEmpty) {
      OfflineSyncProjectionRebuild.log(
        'The synced schema changed: rebuilding the foreign key projection of '
        '${_pending.length} space(s) in the background',
      );
    }
  }

  /// Starts the background rebuild after [OfflineSyncProjectionRebuild.startDelay]
  /// unless it is running, scheduled or done.
  void attach(CrdtMutationRecorder recorder) {
    if (_stopped || _pending.isEmpty) return;
    _recorder = recorder;
    if (_run != null || _timer != null) return;
    _schedule(OfflineSyncProjectionRebuild.startDelay);
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      _start();
    });
  }

  Future<void> _start() => _run ??= _runPending().whenComplete(() => _run = null);

  /// Runs one pass over the pending rebuilds now, skipping a start delay or
  /// retry backoff, and completes when it ends. Failures are logged, not
  /// thrown; spaces that failed stay pending for the retry.
  Future<void> drain(CrdtMutationRecorder recorder) async {
    if (_stopped) return;
    _recorder ??= recorder;
    if (_pending.isNotEmpty) {
      _timer?.cancel();
      _timer = null;
      await _start();
    }
    await Future.wait([
      for (final future in _inFlight.values) future.catchError((Object _) {}),
    ]);
  }

  /// Stops the background rebuild and waits for the running space; pending
  /// spaces stay persisted for the next initialization.
  Future<void> stop() async {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
    await _run;
    await Future.wait([
      for (final future in _inFlight.values) future.catchError((Object _) {}),
    ]);
  }

  /// One pass over the pending spaces in id order, with bounded concurrency
  /// of one and a pause between spaces. Spaces that fail stay pending and
  /// the pass is retried after a backoff, so one failing space does not hold
  /// up the others.
  Future<void> _runPending() async {
    var failed = false;
    try {
      for (final spaceId in _pending.keys.toList()) {
        if (_stopped) return;
        final recorder = _recorder;
        if (recorder == null || !_pending.containsKey(spaceId)) continue;
        try {
          await _rebuild(spaceId, recorder);
        } on Object catch (error, stackTrace) {
          failed = true;
          OfflineSyncProjectionRebuild.log(
            'Rebuilding the foreign key projection of space $spaceId failed',
            error,
            stackTrace,
          );
        }
        await Future<void>.delayed(OfflineSyncProjectionRebuild.pause);
      }
    } on Object catch (error, stackTrace) {
      // Never let the background work fail the host.
      failed = true;
      OfflineSyncProjectionRebuild.log(
        'The foreign key projection rebuild failed',
        error,
        stackTrace,
      );
    }
    if (_stopped) return;
    if (_pending.isEmpty) {
      _failures = 0;
      OfflineSyncProjectionRebuild.log('The foreign key projection rebuild is done');
      return;
    }
    if (failed) _failures++;
    final delay = _retryDelay();
    OfflineSyncProjectionRebuild.log(
      '${_pending.length} space(s) still need a projection rebuild; '
      'retrying in ${delay.inSeconds} s',
    );
    _schedule(delay);
  }

  Duration _retryDelay() {
    final base = OfflineSyncProjectionRebuild.retryDelay;
    final max = OfflineSyncProjectionRebuild.maxRetryDelay;
    var delay = base;
    for (var i = 1; i < _failures && delay < max; i++) {
      delay *= 2;
    }
    return delay > max ? max : delay;
  }

  /// Rebuilds [spaceId] once, shared by the background pass and an access
  /// that needs the space first.
  Future<void> _rebuild(int spaceId, CrdtMutationRecorder recorder) {
    final markerId = _markerId;
    if (markerId == null || !_pending.containsKey(spaceId)) return Future.value();
    return _inFlight[spaceId] ??= () async {
      try {
        await recorder._rebuildPendingSpace(
          spaceId,
          _pending[spaceId],
          markerId: markerId,
        );
        _pending.remove(spaceId);
      } finally {
        _inFlight.remove(spaceId);
      }
    }();
  }
}
