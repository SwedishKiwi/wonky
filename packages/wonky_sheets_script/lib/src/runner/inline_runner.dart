import 'dart:async';

import '../guest/guest_bridge.dart';
import '../guest/guest_runtime.dart';
import '../host/script_host.dart';
import '../protocol/messages.dart';
import 'execution.dart';

/// Runs scripts in the calling isolate (09 §8.2.3, "main thread with
/// checkpoint-based time slicing").
///
/// This is the **web runtime** of the first release: the synchronous
/// SharedArrayBuffer bridge needs cross-origin isolation (COOP/COEP), which
/// the suite does not enable yet (it would break the Google sign-in popup
/// and third-party embeds). Instead the guest runs on the main thread, the
/// host answers synchronously, and patch DE-2 (`Runtime.onCheckpoint`)
/// enforces the time limit every 10,000 instructions. Consequences:
/// - the UI does not repaint while a script runs (bounded by the time limit);
/// - calls that wait for something asynchronous — `Ui.alert`/`prompt` and
///   `UrlFetchApp` — throw `UiUnavailableException` / `ScriptException`
///   (`unsupported`) with a hint to use *Run on server* for fetches;
/// - `Utilities.sleep` busy-waits.
///
/// Native hosts use `IsolateScriptRunner` (`package:wonky_sheets_script/native.dart`).
/// Tests use this runner for speed.
final class InlineScriptRunner implements ScriptRunner {
  /// Creates the runner.
  InlineScriptRunner();

  final _transport = _InlineTransport();
  late final GuestRuntime _guest = GuestRuntime(_transport);
  Future<void> _queue = Future.value();

  @override
  Future<GuestOutcome> runGuest(GuestRequest request, ScriptHost host) {
    final done = Completer<GuestOutcome>();
    _queue = _queue.then((_) async {
      _transport.host = host;
      host.asyncCallsAllowed = false;
      try {
        done.complete(await _guest.execute(request));
      } on Object catch (e, s) {
        done.completeError(e, s);
      } finally {
        _transport.host = null;
      }
    });
    return done.future;
  }

  @override
  Future<void> close() async {}
}

final class _InlineTransport implements GuestTransport {
  ScriptHost? host;

  ScriptHost get _host =>
      host ?? (throw StateError('No execution is running.'));

  @override
  HostReply call(HostCall call) {
    final reply = _host.handle(call);
    if (reply is HostReply) return reply;
    unawaited(reply.then((_) {}, onError: (Object _) {}));
    return HostReply.error(
      ScriptError(
        'unsupported',
        '${call.method} is not available in this browser runtime.',
      ),
    );
  }

  @override
  void log(ScriptLogLevel level, String message) => _host.log(level, message);

  @override
  void sleep(int milliseconds) {
    final w = Stopwatch()..start();
    while (w.elapsedMilliseconds < milliseconds) {}
  }
}
