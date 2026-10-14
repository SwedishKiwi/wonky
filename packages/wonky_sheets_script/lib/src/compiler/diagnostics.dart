import 'dart:convert';

/// Severity of a [ScriptDiagnostic].
enum DiagnosticSeverity {
  /// Prevents a build.
  error,

  /// Builds, but probably wrong.
  warning,

  /// Hint.
  info,
}

/// A compiler diagnostic (09 §9.2 `diagnosticsJson`).
final class ScriptDiagnostic {
  /// Creates a diagnostic.
  const ScriptDiagnostic({
    required this.severity,
    required this.code,
    required this.message,
    this.file,
    this.line,
    this.column,
    this.endLine,
    this.endColumn,
    this.fix,
  });

  /// Severity.
  final DiagnosticSeverity severity;

  /// Analyzer code or `wonky_*` lint code.
  final String code;

  /// Message.
  final String message;

  /// File name (`main.dart`).
  final String? file;

  /// 1-based position.
  final int? line;

  /// 1-based position.
  final int? column;

  /// 1-based end position.
  final int? endLine;

  /// 1-based end position.
  final int? endColumn;

  /// Suggested fix.
  final String? fix;

  /// Whether this is an error.
  bool get isError => severity == DiagnosticSeverity.error;

  /// JSON form.
  Map<String, Object?> toJson() => {
    'severity': severity.name,
    'code': code,
    'message': message,
    'file': ?file,
    'line': ?line,
    'column': ?column,
    'endLine': ?endLine,
    'endColumn': ?endColumn,
    'fix': ?fix,
  };

  /// From [toJson].
  static ScriptDiagnostic fromJson(Map<String, Object?> j) => ScriptDiagnostic(
    severity: DiagnosticSeverity.values.byName(j['severity']! as String),
    code: j['code']! as String,
    message: j['message']! as String,
    file: j['file'] as String?,
    line: j['line'] as int?,
    column: j['column'] as int?,
    endLine: j['endLine'] as int?,
    endColumn: j['endColumn'] as int?,
    fix: j['fix'] as String?,
  );

  /// Encodes a list (`diagnosticsJson`).
  static String encodeList(List<ScriptDiagnostic> list) =>
      jsonEncode([for (final d in list) d.toJson()]);

  /// Decodes `diagnosticsJson`.
  static List<ScriptDiagnostic> decodeList(String json) => [
    for (final d in jsonDecode(json) as List)
      fromJson((d as Map).cast<String, Object?>()),
  ];

  @override
  String toString() =>
      '${severity.name} ${file ?? ''}${line == null ? '' : ':$line:$column'} $message ($code)';
}
