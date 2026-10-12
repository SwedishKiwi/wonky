import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';

/// A stream kept alive by [StreamSupervisor].
class SupervisedStream {
  SupervisedStream._(this.key, this._supervisor);

  final String key;
  final StreamSupervisor _supervisor;

  /// Stops supervising and cancels the subscription.
  Future<void> cancel() => _supervisor.cancel(key);
}

class _Entry {
  _Entry(this.open, this.onData, this.onError, this.onConnected);

  final Stream<dynamic> Function() open;
  final void Function(dynamic) onData;
  final void Function(Object error)? onError;
  final VoidCallback? onConnected;
  StreamSubscription<dynamic>? sub;
  Timer? retry;
  int failures = 0;
}

/// Re-establishes long-lived streams (document sessions, presence, drive
/// watch, comments, notifications, UI bridge) when they end or error, with
/// backoff 1 s → 30 s plus jitter, and immediately when connectivity returns
/// (suite 03 §7).
class StreamSupervisor {
  StreamSupervisor(this.connectivity, {Random? random})
    : _random = random ?? Random() {
    connectivity.addListener(_onConnectivity);
  }

  final ConnectivityService connectivity;
  final Random _random;
  final Map<String, _Entry> _entries = {};
  bool _wasOnline = true;

  /// Starts (or replaces) the stream [key].
  SupervisedStream supervise<T>(
    String key,
    Stream<T> Function() open,
    void Function(T event) onData, {
    void Function(Object error)? onError,
    VoidCallback? onConnected,
  }) {
    _entries.remove(key)?.let(_dispose);
    final entry = _Entry(open, (e) => onData(e as T), onError, onConnected);
    _entries[key] = entry;
    _connect(key, entry);
    return SupervisedStream._(key, this);
  }

  /// Whether [key] is supervised.
  bool isActive(String key) => _entries.containsKey(key);

  Future<void> cancel(String key) async {
    final e = _entries.remove(key);
    if (e != null) await _dispose(e);
  }

  /// Cancels everything (sign-out).
  Future<void> cancelAll() async {
    final all = [..._entries.values];
    _entries.clear();
    for (final e in all) {
      await _dispose(e);
    }
  }

  Future<void> _dispose(_Entry e) async {
    e.retry?.cancel();
    await e.sub?.cancel();
  }

  void _connect(String key, _Entry e) {
    e.retry?.cancel();
    if (!connectivity.online) return; // resumes on reconnect
    try {
      var first = true;
      e.sub = e.open().listen(
        (data) {
          if (first) {
            first = false;
            e.failures = 0;
          }
          e.onData(data);
        },
        onError: (Object err) {
          e.onError?.call(err);
          _scheduleRetry(key, e);
        },
        onDone: () => _scheduleRetry(key, e),
        cancelOnError: true,
      );
      e.onConnected?.call();
    } catch (err) {
      e.onError?.call(err);
      _scheduleRetry(key, e);
    }
  }

  void _scheduleRetry(String key, _Entry e) {
    if (_entries[key] != e) return;
    e.failures++;
    final seconds = min(30, pow(2, e.failures - 1).toInt());
    final ms = (seconds * 1000 * (0.8 + _random.nextDouble() * 0.4)).round();
    e.retry?.cancel();
    e.retry = Timer(Duration(milliseconds: ms), () {
      if (_entries[key] == e) _connect(key, e);
    });
  }

  void _onConnectivity() {
    final online = connectivity.online;
    if (online && !_wasOnline) {
      for (final entry in _entries.entries) {
        entry.value.sub?.cancel();
        entry.value.failures = 0;
        _connect(entry.key, entry.value);
      }
    }
    _wasOnline = online;
  }

  void dispose() {
    connectivity.removeListener(_onConnectivity);
    unawaited(cancelAll());
  }
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
