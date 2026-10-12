import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

/// Whether the server is reachable (suite 03 §7): heartbeat every 15 s while
/// online, reconnect with backoff (1 s → 30 s, jitter) while offline.
///
/// Repositories report failures/successes so the state flips immediately
/// instead of waiting for the next heartbeat. [forceOffline] is the E2E test
/// hook (suite 15 §9).
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({
    required this._ping,
    Random? random,
    this.heartbeat = const Duration(seconds: 15),
  }) : _random = random ?? Random();

  final Future<void> Function() _ping;
  final Random _random;
  final Duration heartbeat;

  bool _online = true;
  bool _forcedOffline = false;
  DateTime? _lastConnectedAt;
  DateTime? _nextAttemptAt;
  int _failures = 0;
  Timer? _timer;
  bool _started = false;
  bool _checking = false;

  /// Whether the server is reachable.
  bool get online => _online && !_forcedOffline;

  DateTime? get lastConnectedAt => _lastConnectedAt;

  /// When the next reconnect attempt happens (offline only).
  DateTime? get nextAttemptAt => online ? null : _nextAttemptAt;

  bool get forcedOffline => _forcedOffline;

  /// Starts the heartbeat.
  void start() {
    if (_started) return;
    _started = true;
    unawaited(_check());
  }

  /// Checks now (the "Retry now" button).
  Future<void> reconnect() => _check();

  /// Simulates being offline (E2E / dev tools).
  void forceOffline(bool value) {
    if (_forcedOffline == value) return;
    _forcedOffline = value;
    notifyListeners();
    if (!value) unawaited(_check());
  }

  /// A call failed because the server was unreachable.
  void reportFailure() {
    if (!_online) return;
    _setOnline(false);
    _schedule();
  }

  /// A call succeeded.
  void reportSuccess() {
    _lastConnectedAt = clock.now();
    if (_online) return;
    _failures = 0;
    _setOnline(true);
    _schedule();
  }

  /// Backoff delay for the [n]th consecutive failure (1 s → 30 s, ±20 %).
  @visibleForTesting
  Duration backoff(int n) {
    final base = min(30.0, pow(2, max(0, n - 1)).toDouble());
    final jitter = 0.8 + _random.nextDouble() * 0.4;
    return Duration(milliseconds: (base * 1000 * jitter).round());
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      await _ping();
      _failures = 0;
      _lastConnectedAt = clock.now();
      _setOnline(true);
    } catch (_) {
      _failures++;
      _setOnline(false);
    } finally {
      _checking = false;
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (!_started) return;
    final delay = _online ? heartbeat : backoff(_failures);
    _nextAttemptAt = clock.now().add(delay);
    _timer = Timer(delay, () => unawaited(_check()));
    if (!_online) notifyListeners();
  }

  void _setOnline(bool value) {
    if (_online == value) return;
    _online = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
