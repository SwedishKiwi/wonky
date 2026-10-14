import 'dart:async';
import 'dart:io' show ProcessInfo, sleep;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:native_synchronization/mailbox.dart';
import 'package:native_synchronization/sendable.dart';

import '../guest/guest_bridge.dart';
import '../guest/guest_runtime.dart';
import '../host/script_host.dart';
import '../protocol/messages.dart';
import 'execution.dart';

/// Runs scripts in sandbox isolates with a synchronous `Mailbox` channel
/// (09 §8.2.1; desktop and server).
///
/// The guest isolate owns the dart_eval `Runtime`. It sends each call to the
/// host through a `SendPort` and blocks on a `Mailbox` until the host puts the
/// reply, so the script API is synchronous while the host (and the app's UI)
/// stays responsive. A watchdog kills the isolate when the time limit is
/// exceeded (UI waits excluded) or the process RSS crosses [maxRssBytes].
///
/// One runner = one guest at a time (executions are queued); create several
/// runners for a pool (pure guest, UI guest, 09 §8.8).
final class IsolateScriptRunner implements ScriptRunner {
  /// Creates a runner. [maxRssBytes] enables the memory watchdog;
  /// [recycleAfter] restarts the guest after that many executions.
  IsolateScriptRunner({
    this.maxRssBytes,
    this.recycleAfter = 200,
    this.watchdogInterval = const Duration(milliseconds: 20),
  });

  /// RSS limit of the whole process; null disables the check.
  final int? maxRssBytes;

  /// Executions per guest isolate before it is recycled.
  final int recycleAfter;

  /// How often the watchdog checks time and memory.
  final Duration watchdogInterval;

  _Guest? _guest;
  Future<void> _queue = Future.value();
  bool _closed = false;

  /// Executions that ended with a kill (timeouts, memory).
  int kills = 0;

  @override
  Future<GuestOutcome> runGuest(GuestRequest request, ScriptHost host) {
    final done = Completer<GuestOutcome>();
    _queue = _queue.then((_) async {
      try {
        done.complete(await _run(request, host));
      } on Object catch (e, s) {
        done.completeError(e, s);
      }
    });
    return done.future;
  }

  Future<GuestOutcome> _run(GuestRequest request, ScriptHost host) async {
    if (_closed) throw StateError('The runner is closed.');
    var guest = _guest;
    if (guest == null || guest.executions >= recycleAfter) {
      guest?.kill();
      guest = _guest = await _Guest.spawn();
    }
    final outcome = await guest.execute(
      guest.builds.contains(request.buildHash)
          ? request.withoutBytecode()
          : request,
      host,
      maxRssBytes: maxRssBytes,
      watchdogInterval: watchdogInterval,
    );
    if (!guest.dead &&
        (outcome.status == ExecutionStatus.timedOut ||
            outcome.status == ExecutionStatus.quotaExceeded)) {
      // Guests are recycled after any timeout (09 §8.8).
      guest.kill();
    }
    if (guest.dead) {
      kills++;
      _guest = null;
    } else {
      guest.builds.add(request.buildHash);
      if (guest.builds.length > 2) guest.builds.remove(guest.builds.first);
    }
    return outcome;
  }

  /// Stops the current execution, if any (`sheets.script.stop`).
  void cancel() =>
      _guest?.abort(ExecutionStatus.cancelled, 'The execution was stopped.');

  @override
  Future<void> close() async {
    _closed = true;
    await _queue;
    _guest?.kill();
    _guest = null;
  }
}

final class _Guest {
  _Guest._(this.isolate, this.mailbox, this.port, this.events, this.toGuest);

  final Isolate isolate;
  final Mailbox mailbox;
  final ReceivePort port;
  final StreamIterator<Object?> events;
  final SendPort toGuest;
  final Set<String> builds = <String>{};
  int executions = 0;
  bool dead = false;

  Completer<GuestOutcome>? _current;
  Timer? _watchdog;

  static Future<_Guest> spawn() async {
    final mailbox = Mailbox();
    final port = ReceivePort();
    final isolate = await Isolate.spawn(
      _guestMain,
      [port.sendPort, mailbox.asSendable],
      errorsAreFatal: true,
      onError: port.sendPort,
      onExit: port.sendPort,
      debugName: 'wonky-script-guest',
    );
    final events = StreamIterator<Object?>(port);
    if (!await events.moveNext()) throw StateError('Guest did not start.');
    final ready = events.current! as List<Object?>;
    return _Guest._(isolate, mailbox, port, events, ready[1]! as SendPort);
  }

  void kill() {
    if (dead) return;
    dead = true;
    _watchdog?.cancel();
    // Close the mailbox first: a guest blocked in `take()` (native wait)
    // cannot be interrupted by Isolate.kill; closing wakes it with an error.
    try {
      mailbox.close();
    } on Object {
      // Already closed.
    }
    isolate.kill(priority: Isolate.immediate);
    port.close();
  }

  void abort(ExecutionStatus status, String message) {
    final c = _current;
    if (c == null || c.isCompleted) return;
    c.complete(
      GuestOutcome(
        status: status,
        error: ScriptFailure(
          type: switch (status) {
            ExecutionStatus.timedOut => 'ExecutionTimeoutException',
            ExecutionStatus.quotaExceeded => 'QuotaExceededException',
            _ => 'ScriptException',
          },
          message: message,
        ),
      ),
    );
    kill();
  }

  Future<GuestOutcome> execute(
    GuestRequest request,
    ScriptHost host, {
    int? maxRssBytes,
    required Duration watchdogInterval,
  }) async {
    executions++;
    final done = _current = Completer<GuestOutcome>();
    final watch = Stopwatch()..start();
    var paused = Duration.zero;
    DateTime? pausedSince;
    _watchdog = Timer.periodic(watchdogInterval, (_) {
      final since = pausedSince;
      final activeMs =
          (watch.elapsed -
                  paused -
                  (since == null
                      ? Duration.zero
                      : DateTime.now().difference(since)))
              .inMilliseconds;
      if (activeMs > request.timeoutMs + 250) {
        abort(
          ExecutionStatus.timedOut,
          'Exceeded maximum execution time (${request.timeoutMs ~/ 1000} s).',
        );
        return;
      }
      if (maxRssBytes != null && ProcessInfo.currentRss > maxRssBytes) {
        abort(
          ExecutionStatus.quotaExceeded,
          'The script used too much memory and was stopped.',
        );
      }
    });
    toGuest.send(['execute', request.toWire()]);
    try {
      while (!done.isCompleted && await events.moveNext()) {
        final msg = events.current;
        if (msg is! List || msg.isEmpty) {
          // onExit (null) or an uncaught error ([error, stack]).
          if (!done.isCompleted) {
            dead = true;
            done.complete(
              GuestOutcome(
                status: ExecutionStatus.failed,
                error: ScriptFailure(
                  type: 'GuestCrash',
                  message: 'The script sandbox stopped unexpectedly: $msg',
                ),
              ),
            );
          }
          break;
        }
        switch (msg[0]) {
          case 'call':
            final call = HostCall.fromWire(msg[1]);
            final waitsForUser =
                call.method == 'ui.alert' || call.method == 'ui.prompt';
            if (waitsForUser) pausedSince = DateTime.now();
            final reply = await host.handle(call);
            if (waitsForUser && pausedSince != null) {
              paused += DateTime.now().difference(pausedSince);
              pausedSince = null;
            }
            if (done.isCompleted) break;
            mailbox.put(reply.encode());
          case 'log':
            host.log(ScriptLogLevel.values[msg[1]! as int], msg[2]! as String);
          case 'done':
            if (!done.isCompleted) {
              done.complete(
                GuestOutcome.fromWire((msg[1]! as Map).cast<String, Object?>()),
              );
            }
          default:
            // A remote error report: [message, stack].
            if (msg.length == 2 && msg[0] is String && !done.isCompleted) {
              dead = true;
              done.complete(
                GuestOutcome(
                  status: ExecutionStatus.failed,
                  error: ScriptFailure(
                    type: 'GuestCrash',
                    message: '${msg[0]}',
                  ),
                ),
              );
            }
        }
      }
    } finally {
      _watchdog?.cancel();
      _current = null;
    }
    if (!done.isCompleted) {
      dead = true;
      done.complete(
        const GuestOutcome(
          status: ExecutionStatus.failed,
          error: ScriptFailure(
            type: 'GuestCrash',
            message: 'The script sandbox stopped unexpectedly.',
          ),
        ),
      );
    }
    return done.future;
  }
}

// ---------------------------------------------------------------------------
// Guest isolate.
// ---------------------------------------------------------------------------

void _guestMain(List<Object?> init) {
  final hostPort = init[0]! as SendPort;
  final mailbox = (init[1]! as Sendable<Mailbox>).materialize();
  final transport = _MailboxTransport(hostPort, mailbox);
  final runtime = GuestRuntime(transport);
  final port = ReceivePort();
  hostPort.send(['ready', port.sendPort]);
  port.listen((msg) async {
    final m = msg as List<Object?>;
    if (m[0] == 'execute') {
      final req = GuestRequest.fromWire((m[1]! as Map).cast<String, Object?>());
      final outcome = await runtime.execute(req);
      hostPort.send(['done', outcome.toWire()]);
    }
  });
}

final class _MailboxTransport implements GuestTransport {
  _MailboxTransport(this.hostPort, this.mailbox);

  final SendPort hostPort;
  final Mailbox mailbox;

  @override
  HostReply call(HostCall call) {
    hostPort.send(['call', call.toWire()]);
    final Uint8List bytes;
    try {
      bytes = mailbox.take();
    } on StateError {
      // The host closed the mailbox: the execution was stopped.
      throw const ScriptAbort('cancelled', 'The execution was stopped.');
    }
    return HostReply.decode(bytes);
  }

  @override
  void log(ScriptLogLevel level, String message) =>
      hostPort.send(['log', level.index, message]);

  @override
  void sleep(int milliseconds) => _sleep(milliseconds);
}

void _sleep(int ms) => sleep(Duration(milliseconds: ms));
