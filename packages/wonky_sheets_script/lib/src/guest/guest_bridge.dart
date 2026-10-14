import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/stdlib/core.dart';

import '../protocol/messages.dart';
import 'boxing.dart';

/// How the guest reaches its host (09 §8.2.1): synchronously.
abstract interface class GuestTransport {
  /// Sends [call] and blocks until the host replies.
  HostReply call(HostCall call);

  /// Fire-and-forget log line.
  void log(ScriptLogLevel level, String message);

  /// Blocks for [milliseconds] (`Utilities.sleep`).
  void sleep(int milliseconds);
}

/// Thrown inside the guest to abort an execution; not catchable by scripts
/// (it is a native exception, see patch DE-2).
final class ScriptAbort implements UncatchableException {
  /// Creates the abort.
  const ScriptAbort(this.status, this.message);

  /// `timedOut`, `quotaExceeded` or `cancelled`.
  final String status;

  /// Message for the execution log.
  final String message;

  @override
  String toString() => message;
}

/// Methods the guest buffers and sends as one write batch (09 §8.2.4):
/// cell-sized writes that are typically called in loops. They return
/// nothing, so their errors (permissions, protected ranges, invalid colors)
/// surface on the next call that reaches the host or when the function
/// returns. 2-D writes (`values`, `formulas`, `notes`, `setBackgrounds`…)
/// are sent immediately so dimension errors are thrown where they happen.
const bufferedHostMethods = {
  'range.setValue',
  'range.setFormula',
  'range.setNote',
  'range.setFormat',
  'range.setBorder',
  'range.clear',
  'sheet.appendRow',
};

/// Guest side of the bridge: implements the `wonkyHostCall` /
/// `wonkyHostError` bridge functions for one execution.
final class GuestBridge {
  /// Creates the bridge for one execution.
  GuestBridge(
    this.transport, {
    this.maxBridgedValues = 5000000,
    this.writeBatchCells = 10000,
    this.maxSleepMs = 5000,
  }) {
    boxing = GuestBoxing(onBoxed: _countBoxed);
  }

  /// Channel to the host.
  final GuestTransport transport;

  /// Bridged value limit (09 §10).
  final int maxBridgedValues;

  /// Buffered cells before a flush.
  final int writeBatchCells;

  /// `Utilities.sleep` per call.
  final int maxSleepMs;

  /// Boxing with counters.
  late final GuestBoxing boxing;

  /// Values boxed so far.
  int bridgedValues = 0;

  /// Host calls made (including buffered ones).
  int calls = 0;

  final _buffer = <List<Object?>>[];
  int _bufferedCells = 0;
  ScriptError? _error;

  void _countBoxed(int n) {
    bridgedValues += n;
    if (bridgedValues > maxBridgedValues) {
      throw ScriptAbort(
        'quotaExceeded',
        'Too much data held by the script (more than $maxBridgedValues '
            'values).',
      );
    }
  }

  /// `wonkyHostCall(int target, String method, List<Object?> args)`.
  $Value? hostCall(Runtime runtime, $Value? target, List<$Value?> args) {
    calls++;
    final t = args[0]!.$value as int;
    final method = args[1]!.$value as String;
    final List<Object?> a;
    try {
      a = (GuestBoxing.unbox(args[2]) as List?) ?? const [];
    } on UnsupportedValueError catch (e) {
      _error = ScriptError.invalid(e.toString());
      return const $null();
    }
    _error = null;
    if (method == 'log') {
      final level = switch (a[0]) {
        'warn' => ScriptLogLevel.warn,
        'error' => ScriptLogLevel.error,
        _ => ScriptLogLevel.info,
      };
      transport.log(level, '${a[1]}');
      return const $null();
    }
    if (method == 'util.sleep') {
      final ms = (a[0] as num?)?.toInt() ?? 0;
      if (ms < 0 || ms > maxSleepMs) {
        _error = ScriptError.invalid(
          'Utilities.sleep takes 0..$maxSleepMs milliseconds.',
        );
        return const $null();
      }
      flush();
      if (_error != null) return const $null();
      transport.sleep(ms);
      return const $null();
    }
    if (bufferedHostMethods.contains(method)) {
      _buffer.add([t, method, a]);
      _bufferedCells += _cellCount(a);
      if (_bufferedCells >= writeBatchCells) flush();
      return const $null();
    }
    flush();
    if (_error != null) return const $null();
    final reply = transport.call(HostCall(t, method, a));
    if (reply.isError) {
      _error = reply.error;
      return const $null();
    }
    return boxing.box(reply.value);
  }

  /// `wonkyHostError()`: the error of the last call, cleared on read.
  $Value? hostError(Runtime runtime, $Value? target, List<$Value?> args) {
    final e = _error;
    _error = null;
    if (e == null) return const $null();
    return $List.wrap(<$Value>[
      $String(e.code),
      $String(e.message),
      if (e.statusCode != null) $int(e.statusCode!),
    ]);
  }

  static int _cellCount(List<Object?> args) {
    var n = 1;
    for (final a in args) {
      if (a is List && a.isNotEmpty && a.first is List) {
        n = a.length * (a.first as List).length;
      }
    }
    return n;
  }

  /// Sends buffered writes. An error is kept for the next call.
  void flush() {
    if (_buffer.isEmpty) return;
    final batch = List<Object?>.of(_buffer);
    _buffer.clear();
    _bufferedCells = 0;
    final reply = transport.call(HostCall(0, 'batch', [batch]));
    if (reply.isError) _error = reply.error;
  }

  /// Flushes at the end of an execution; returns a pending write error.
  ScriptError? finish() {
    flush();
    final e = _error;
    _error = null;
    return e;
  }
}
