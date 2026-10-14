import 'dart:io';
import 'dart:math' as math;

import 'package:wonky_sheets_script/native.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

/// The sandbox isolates of this server instance (Sheets 09 §8.8): a small
/// pool of [IsolateScriptRunner]s; each execution goes to the runner with
/// the fewest queued executions. Guests are recycled after 200 executions or
/// any timeout, and a watchdog stops executions when the process RSS exceeds
/// `maxRssBytes` (default 1,536 MB).
final class ScriptRunnerPool implements ScriptRunner {
  /// Creates a pool of [size] runners.
  ScriptRunnerPool({int size = 4, int? maxRssBytes})
    : _runners = [
        for (var i = 0; i < size; i++)
          IsolateScriptRunner(
            maxRssBytes: maxRssBytes ?? _defaultMaxRss(),
          ),
      ],
      _queued = List.filled(size, 0);

  static int _defaultMaxRss() {
    const limit = 1536 * 1024 * 1024;
    // At least 512 MB above the footprint at start (development servers
    // and tests run in big processes).
    return math.max(limit, ProcessInfo.currentRss + 512 * 1024 * 1024);
  }

  static ScriptRunnerPool? _instance;

  /// The pool of this instance (created on first use).
  static ScriptRunnerPool instance({int size = 4}) =>
      _instance ??= ScriptRunnerPool(size: size);

  /// Closes the shared pool (tests).
  static Future<void> reset() async {
    await _instance?.close();
    _instance = null;
  }

  final List<IsolateScriptRunner> _runners;
  final List<int> _queued;

  @override
  Future<GuestOutcome> runGuest(GuestRequest request, ScriptHost host) async {
    var best = 0;
    for (var i = 1; i < _runners.length; i++) {
      if (_queued[i] < _queued[best]) best = i;
    }
    _queued[best]++;
    try {
      return await _runners[best].runGuest(request, host);
    } finally {
      _queued[best]--;
    }
  }

  @override
  Future<void> close() async {
    for (final r in _runners) {
      await r.close();
    }
  }
}
