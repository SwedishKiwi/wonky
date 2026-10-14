import 'dart:async';
import 'dart:collection';

import 'package:clock/clock.dart';

/// `LockService` backend (09 §6.12). Keys name the lock scope
/// (`doc:<spreadsheet>`, `user:<spreadsheet>:<user>`); [owner] is the
/// execution (its host).
abstract interface class ScriptLockProvider {
  /// Acquires [key] for [owner] within [timeout]; returns whether it did.
  /// Re-acquiring a held lock succeeds at once.
  FutureOr<bool> acquire(String key, Object owner, Duration timeout);

  /// Whether [owner] holds [key].
  bool holds(String key, Object owner);

  /// Releases [key] if [owner] holds it.
  void release(String key, Object owner);
}

/// Locks of client executions: one window runs one execution at a time, so
/// every lock is granted (09 §6.12 "client returns a no-op lock").
final class NoopScriptLocks implements ScriptLockProvider {
  /// Creates the provider.
  NoopScriptLocks();

  @override
  bool acquire(String key, Object owner, Duration timeout) {
    _heldOf(owner).add(key);
    return true;
  }

  final _owners = Expando<Set<String>>();

  Set<String> _heldOf(Object owner) => _owners[owner] ??= <String>{};

  @override
  bool holds(String key, Object owner) => _heldOf(owner).contains(key);

  @override
  void release(String key, Object owner) => _heldOf(owner).remove(key);
}

/// In-process mutual exclusion for server executions: one holder per key,
/// waiters are served in order; a waiter gives up after its timeout.
final class MemoryScriptLocks implements ScriptLockProvider {
  /// Creates the provider.
  MemoryScriptLocks();

  /// The process-wide locks of the server.
  static final MemoryScriptLocks shared = MemoryScriptLocks();

  final Map<String, Object> _holders = {};
  final Map<String, Queue<_Waiter>> _waiters = {};

  @override
  FutureOr<bool> acquire(String key, Object owner, Duration timeout) {
    final holder = _holders[key];
    if (holder == null) {
      _holders[key] = owner;
      return true;
    }
    if (identical(holder, owner)) return true;
    if (timeout <= Duration.zero) return false;
    final w = _Waiter(owner);
    (_waiters[key] ??= Queue()).add(w);
    w.timer = Timer(timeout, () {
      _waiters[key]?.remove(w);
      if (!w.done.isCompleted) w.done.complete(false);
    });
    return w.done.future;
  }

  @override
  bool holds(String key, Object owner) => identical(_holders[key], owner);

  @override
  void release(String key, Object owner) {
    if (!identical(_holders[key], owner)) return;
    _holders.remove(key);
    final q = _waiters[key];
    while (q != null && q.isNotEmpty) {
      final next = q.removeFirst();
      if (next.done.isCompleted) continue;
      next.timer?.cancel();
      _holders[key] = next.owner;
      next.done.complete(true);
      break;
    }
    if (q != null && q.isEmpty) _waiters.remove(key);
  }

  /// Number of held locks (tests).
  int get heldCount => _holders.length;
}

final class _Waiter {
  _Waiter(this.owner);
  final Object owner;
  final done = Completer<bool>();
  Timer? timer;
}

/// `CacheService` backend (09 §6.12): string values with a time to live.
abstract interface class ScriptCacheStore {
  /// The value of [key], or null when missing or expired.
  String? get(String key);

  /// Stores [value] for [ttl].
  void put(String key, String value, Duration ttl);

  /// Removes [key].
  void remove(String key);
}

/// In-memory [ScriptCacheStore] with a size cap (least recently written
/// entries are evicted first).
final class MemoryScriptCache implements ScriptCacheStore {
  /// Creates a cache of at most [maxEntries] values.
  MemoryScriptCache({this.maxEntries = 20000, Clock? clock})
    : _clock = clock ?? const Clock();

  /// The process-wide cache (server, and the app's windows).
  static final MemoryScriptCache shared = MemoryScriptCache();

  /// Longest time to live (6 hours).
  static const maxTtl = Duration(hours: 6);

  /// Largest value (100 KB of UTF-16 code units).
  static const maxValueLength = 100 * 1024;

  /// Entry cap.
  final int maxEntries;
  final Clock _clock;

  // ignore: prefer_collection_literals
  final LinkedHashMap<String, (String, DateTime)> _entries = LinkedHashMap();

  @override
  String? get(String key) {
    final e = _entries[key];
    if (e == null) return null;
    if (!_clock.now().isBefore(e.$2)) {
      _entries.remove(key);
      return null;
    }
    return e.$1;
  }

  @override
  void put(String key, String value, Duration ttl) {
    final t = ttl > maxTtl ? maxTtl : ttl;
    _entries.remove(key);
    if (t <= Duration.zero) return;
    _entries[key] = (value, _clock.now().add(t));
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  @override
  void remove(String key) => _entries.remove(key);

  /// Number of stored entries, expired ones included (tests).
  int get length => _entries.length;
}
