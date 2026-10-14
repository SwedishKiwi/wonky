import 'dart:typed_data';

import 'values.dart';

/// A call from the guest (script) to the host (09 §8.2.2 `Call`).
///
/// [target] is a handle id (0 for global services), [method] a host method
/// such as `range.values` (see `HostMethods`), [args] plain values.
final class HostCall {
  /// Creates a call.
  const HostCall(this.target, this.method, this.args);

  /// Handle id; 0 = global.
  final int target;

  /// Host method name.
  final String method;

  /// Arguments (codec values).
  final List<Object?> args;

  /// Codec form.
  List<Object?> toWire() => [target, method, args];

  /// From the codec form.
  static HostCall fromWire(Object? wire) {
    final l = wire! as List<Object?>;
    return HostCall(l[0]! as int, l[1]! as String, (l[2]! as List).cast());
  }

  @override
  String toString() => 'HostCall($target, $method)';
}

/// The host's answer to a [HostCall] (09 §8.2.2 `Result`).
final class HostReply {
  /// A successful reply.
  const HostReply.ok(this.value) : error = null;

  /// A failed reply.
  const HostReply.error(ScriptError this.error) : value = null;

  /// The returned value (codec value).
  final Object? value;

  /// The error, if the call failed.
  final ScriptError? error;

  /// Whether the call failed.
  bool get isError => error != null;

  /// Codec form.
  List<Object?> toWire() => error == null
      ? [0, value]
      : [1, error!.code, error!.message, error!.statusCode];

  /// From the codec form.
  static HostReply fromWire(Object? wire) {
    final l = wire! as List<Object?>;
    if (l[0] == 0) return HostReply.ok(l[1]);
    return HostReply.error(
      ScriptError(l[1]! as String, l[2]! as String, statusCode: l[3] as int?),
    );
  }

  /// Encodes for a byte channel.
  Uint8List encode() => ValueCodec.encode(toWire());

  /// Decodes from a byte channel.
  static HostReply decode(Uint8List bytes) =>
      fromWire(ValueCodec.decode(bytes));
}

/// An error the host reports to the script. [code] selects the exception
/// class the API throws (`range` → `RangeException`, …; see the API source).
final class ScriptError implements Exception {
  /// Creates an error.
  const ScriptError(this.code, this.message, {this.statusCode});

  /// Error code: `range`, `permission_denied`, `scope_not_granted`,
  /// `ui_unavailable`, `quota_exceeded`, `offline`, `side_effect`,
  /// `url_fetch`, `invalid_argument`, `unsupported`, `not_found`, …
  final String code;

  /// Message shown to the script author.
  final String message;

  /// HTTP status for `url_fetch` errors.
  final int? statusCode;

  /// Invalid A1 notation, out of bounds or a deleted range.
  factory ScriptError.range(String message) => ScriptError('range', message);

  /// Role, protection or read-only context.
  factory ScriptError.permission(String message) =>
      ScriptError('permission_denied', message);

  /// A quota was exceeded.
  factory ScriptError.quota(String message) =>
      ScriptError('quota_exceeded', message);

  /// Bad argument from the script.
  factory ScriptError.invalid(String message) =>
      ScriptError('invalid_argument', message);

  @override
  String toString() => 'ScriptError($code): $message';
}

/// Log levels of `Logger` and captured `print` output.
enum ScriptLogLevel {
  /// `Logger.log`, `Logger.info`, `print`.
  info,

  /// `Logger.warn`.
  warn,

  /// `Logger.error`.
  error,

  /// System messages (truncation notices, limits).
  system,
}

/// One log line of an execution (09 §13.1 `logs`: JSON lines `{t, level, msg}`).
final class LogEntry {
  /// Creates an entry.
  const LogEntry(this.at, this.level, this.message);

  /// Time of the log call.
  final DateTime at;

  /// Level.
  final ScriptLogLevel level;

  /// Text.
  final String message;

  /// JSON form used in `ScriptExecution.logs`.
  Map<String, Object?> toJson() => {
    't': at.toUtc().toIso8601String(),
    'level': level.name,
    'msg': message,
  };

  /// From [toJson].
  static LogEntry fromJson(Map<String, Object?> json) => LogEntry(
    DateTime.parse(json['t']! as String),
    ScriptLogLevel.values.byName(json['level']! as String),
    json['msg']! as String,
  );
}
