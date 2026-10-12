/// Severity of an import/export warning (11 §2.3).
enum ImportSeverity { info, warning, error }

/// One warning of an import or export report.
final class ImportWarning {
  /// Creates a warning.
  const ImportWarning({
    required this.code,
    required this.message,
    this.severity = ImportSeverity.warning,
    this.sheet,
    this.range,
    this.count = 1,
  });

  /// Stable machine-readable code (`unsupportedFunction`, `patternFill`, …).
  final String code;

  /// Human-readable message.
  final String message;
  final ImportSeverity severity;

  /// Sheet name, if sheet-specific.
  final String? sheet;

  /// First affected cell/range (A1), if known.
  final String? range;

  /// Number of occurrences merged into this warning.
  final int count;

  /// Copy with another count.
  ImportWarning withCount(int count) =>
      ImportWarning(code: code, message: message, severity: severity, sheet: sheet, range: range, count: count);

  /// JSON.
  Map<String, Object?> toJson() => {
    'severity': severity.name,
    'code': code,
    'message': message,
    if (sheet != null) 'sheet': sheet,
    if (range != null) 'range': range,
    'count': count,
  };

  @override
  String toString() => '${severity.name}: $message${count > 1 ? ' ($count)' : ''}';
}

/// Accumulates warnings, merging repeats of the same (code, sheet, message)
/// into one entry with a count.
final class ImportWarnings extends Iterable<ImportWarning> {
  /// Creates an empty list.
  ImportWarnings();

  final List<ImportWarning> _list = [];
  final Map<(String, String?, String), int> _index = {};

  /// Adds (or counts) a warning.
  void add(
    String code,
    String message, {
    ImportSeverity severity = ImportSeverity.warning,
    String? sheet,
    String? range,
    int count = 1,
  }) {
    final key = (code, sheet, message);
    final i = _index[key];
    if (i != null) {
      _list[i] = _list[i].withCount(_list[i].count + count);
      return;
    }
    _index[key] = _list.length;
    _list.add(
      ImportWarning(code: code, message: message, severity: severity, sheet: sheet, range: range, count: count),
    );
  }

  /// Adds every warning of [other].
  void addAll(Iterable<ImportWarning> other) {
    for (final w in other) {
      add(w.code, w.message, severity: w.severity, sheet: w.sheet, range: w.range, count: w.count);
    }
  }

  /// Warnings with [code].
  Iterable<ImportWarning> withCode(String code) => _list.where((w) => w.code == code);

  @override
  Iterator<ImportWarning> get iterator => _list.iterator;

  @override
  int get length => _list.length;
}
