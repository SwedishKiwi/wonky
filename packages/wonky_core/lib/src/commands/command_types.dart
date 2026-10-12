import 'json_schema.dart';

/// Stable, dot-separated command id. Never rename once shipped (MCP clients
/// depend on it). Convention: `<app|shell>.<area>.<action>`, e.g.
/// `write.format.bold`, `sheets.rows.insertAbove`, `shell.drive.newFolder`.
extension type const CommandId(String value) {
  /// The namespace (`shell`, `write`, `sheets`).
  String get namespace {
    final dot = value.indexOf('.');
    return dot < 0 ? value : value.substring(0, dot);
  }

  /// Whether the id is well-formed (`a.b[.c…]`, camelCase segments).
  bool get isValid =>
      RegExp(r'^[a-z][a-zA-Z0-9]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$').hasMatch(value);
}

/// Where a command invocation came from (suite 08 §1).
enum InvocationSource {
  menu,
  toolbar,
  shortcut,
  contextMenu,
  palette,
  mcp,
  ai,
  script,

  /// Any other in-app control (header buttons, drive list, dialogs).
  ui;

  /// Whether the invocation was made by an agent rather than the human.
  bool get isAgent =>
      this == InvocationSource.mcp ||
      this == InvocationSource.ai ||
      this == InvocationSource.script;
}

/// Typed command arguments. Implementations serialize back to JSON so that
/// invocations can be logged, replayed and reported to MCP.
abstract class CommandArgs {
  const CommandArgs();

  /// The JSON form of these arguments.
  Map<String, Object?> toJson();
}

/// Arguments of a command that takes none.
class NoArgs extends CommandArgs {
  const NoArgs();

  /// Shared instance.
  static const instance = NoArgs();

  @override
  Map<String, Object?> toJson() => const {};

  @override
  bool operator ==(Object other) => other is NoArgs;

  @override
  int get hashCode => 0;
}

/// Untyped arguments: a validated JSON map with typed accessors.
class JsonArgs extends CommandArgs {
  const JsonArgs([this.values = const {}]);

  /// The raw values.
  final Map<String, Object?> values;

  /// A string value, or [fallback].
  String? string(String key, [String? fallback]) {
    final v = values[key];
    return v is String ? v : fallback;
  }

  /// A required string value.
  String requireString(String key) {
    final v = values[key];
    if (v is String) return v;
    throw InvalidCommandArgs([JsonSchemaViolation('\$.$key', 'required')]);
  }

  /// An int value, or [fallback].
  int? integer(String key, [int? fallback]) {
    final v = values[key];
    return v is num ? v.toInt() : fallback;
  }

  /// A bool value, or [fallback].
  bool? boolean(String key, [bool? fallback]) {
    final v = values[key];
    return v is bool ? v : fallback;
  }

  /// A list of strings (empty when missing).
  List<String> strings(String key) {
    final v = values[key];
    return v is List
        ? [
            for (final e in v)
              if (e is String) e,
          ]
        : const [];
  }

  @override
  Map<String, Object?> toJson() => values;

  @override
  bool operator ==(Object other) =>
      other is JsonArgs && _mapEquals(other.values, values);

  @override
  int get hashCode => Object.hashAllUnordered(
    values.entries.map((e) => Object.hash(e.key, e.value)),
  );
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
  }
  return true;
}

/// The outcome of a command execution; serialized back to MCP callers.
class CommandResult {
  const CommandResult._(this.status, this.data, this.message);

  /// Succeeded, with optional JSON-serializable [data].
  const CommandResult.ok([Object? data, String? message])
    : this._(CommandStatus.ok, data, message);

  /// The user (or a dialog) cancelled; nothing changed.
  const CommandResult.cancelled([String? message])
    : this._(CommandStatus.cancelled, null, message);

  /// The command ran but failed with a user-facing [message].
  const CommandResult.failed(String message, [Object? data])
    : this._(CommandStatus.failed, data, message);

  final CommandStatus status;
  final Object? data;
  final String? message;

  bool get isOk => status == CommandStatus.ok;

  Map<String, Object?> toJson() => {
    'status': status.name,
    if (data != null) 'data': data,
    if (message != null) 'message': message,
  };

  @override
  String toString() => 'CommandResult(${status.name}, $data, $message)';
}

/// See [CommandResult].
enum CommandStatus { ok, cancelled, failed }

/// Base class of dispatcher errors.
sealed class CommandException implements Exception {
  const CommandException();

  /// Machine-readable code (MCP `{code}` payload).
  String get code;

  String get message;

  @override
  String toString() => '$code: $message';
}

/// No command is registered under [id].
class UnknownCommand extends CommandException {
  const UnknownCommand(this.id);
  final CommandId id;
  @override
  String get code => 'unknown_command';
  @override
  String get message => 'Unknown command ${id.value}';
}

/// The arguments did not match the command's schema.
class InvalidCommandArgs extends CommandException {
  const InvalidCommandArgs(this.violations);
  final List<JsonSchemaViolation> violations;
  @override
  String get code => 'invalid_args';
  @override
  String get message => violations.join('; ');
}

/// The caller's role is below the command's required role.
class CommandForbidden extends CommandException {
  const CommandForbidden(this.id, this.reason);
  final CommandId id;
  final String reason;
  @override
  String get code => 'forbidden';
  @override
  String get message => reason;
}

/// The command is currently disabled.
class CommandDisabled extends CommandException {
  const CommandDisabled(this.id, [this.reason]);
  final CommandId id;
  final String? reason;
  @override
  String get code => 'disabled';
  @override
  String get message => reason ?? '${id.value} is not available right now';
}
