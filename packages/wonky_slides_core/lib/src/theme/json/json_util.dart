/// JSON helpers and validation issues shared by the theme model (Slides 05 §2).
library;

import 'dart:convert';

/// A decoded JSON object.
typedef JsonMap = Map<String, Object?>;

/// Normalizes a JSON number so that integral doubles become `int` (the VM and
/// the web then encode them identically).
num normalizeJsonNumber(num value) {
  if (value is int) return value;
  final d = value.toDouble();
  if (d.isFinite && d == d.truncateToDouble() && d.abs() < 1e15) {
    return d.toInt();
  }
  return d;
}

/// Deep-copies a decoded JSON value into fresh mutable collections with
/// `String` keys, normalizing numbers ([normalizeJsonNumber]).
Object? deepCopyJson(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final e in value.entries) '${e.key}': deepCopyJson(e.value),
    };
  }
  if (value is List) return [for (final v in value) deepCopyJson(v)];
  if (value is num) return normalizeJsonNumber(value);
  return value;
}

/// Canonical JSON text of [value]: object keys sorted, numbers normalized.
/// Used for content hashes and equality of JSON columns.
String canonicalJson(Object? value) => jsonEncode(_canonical(value));

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = [for (final k in value.keys) '$k']..sort();
    return <String, Object?>{for (final k in keys) k: _canonical(value[k])};
  }
  if (value is List) return [for (final v in value) _canonical(v)];
  if (value is num) return normalizeJsonNumber(value);
  return value;
}

/// Deep equality of two decoded JSON values (numbers compared normalized).
bool jsonEquals(Object? a, Object? b) => canonicalJson(a) == canonicalJson(b);

/// A stable, platform-independent 64-bit content hash of [text] (two
/// 32-bit FNV-1a lanes; safe on the web), as 16 hex digits.
String stableHash(String text) {
  var h1 = 0x811c9dc5;
  var h2 = 0x01000193 ^ 0x5bd1e995;
  for (final unit in text.codeUnits) {
    h1 = ((h1 ^ unit) * 0x01000193) & 0xffffffff;
    h2 = ((h2 ^ (unit + 0x9e)) * 0x01000193) & 0xffffffff;
  }
  return h1.toRadixString(16).padLeft(8, '0') +
      h2.toRadixString(16).padLeft(8, '0');
}

/// Severity of a [ThemeIssue].
enum ThemeIssueSeverity {
  /// Blocks saving/importing the value.
  error,

  /// Describes a repair that was applied (dropped key, fallback, …).
  warning,
}

/// One validation finding at a JSON [path] (`colorsJson.light.bg1`).
final class ThemeIssue {
  /// Creates an issue.
  const ThemeIssue(this.severity, this.path, this.code, this.message);

  /// Error or warning.
  final ThemeIssueSeverity severity;

  /// Dotted JSON path (`textStylesJson.styles.title.size`).
  final String path;

  /// Stable machine code (`unknown_key`, `wrong_type`, `out_of_range`,
  /// `missing`, `unknown_font`, `unsupported_version`, …).
  final String code;

  /// Human-readable explanation.
  final String message;

  /// Whether this is an error.
  bool get isError => severity == ThemeIssueSeverity.error;

  /// MCP form `{path, code, message}`.
  JsonMap toJson() => {'path': path, 'code': code, 'message': message};

  @override
  bool operator ==(Object other) =>
      other is ThemeIssue &&
      other.severity == severity &&
      other.path == path &&
      other.code == code &&
      other.message == message;

  @override
  int get hashCode => Object.hash(severity, path, code, message);

  @override
  String toString() => '${severity.name} $path [$code]: $message';
}

/// Collects [ThemeIssue]s while parsing.
final class IssueSink {
  /// Creates an empty sink.
  IssueSink();

  /// Every issue in report order.
  final List<ThemeIssue> issues = [];

  /// The errors.
  List<ThemeIssue> get errors => [
    for (final i in issues)
      if (i.isError) i,
  ];

  /// The warnings.
  List<ThemeIssue> get warnings => [
    for (final i in issues)
      if (!i.isError) i,
  ];

  /// Whether any error was reported.
  bool get hasErrors => issues.any((i) => i.isError);

  /// Reports an error.
  void error(String path, String code, String message) =>
      issues.add(ThemeIssue(ThemeIssueSeverity.error, path, code, message));

  /// Reports a warning.
  void warn(String path, String code, String message) =>
      issues.add(ThemeIssue(ThemeIssueSeverity.warning, path, code, message));
}

/// Reads typed fields of one JSON object, reporting problems to a sink.
///
/// Keys not in `known` are reported as `unknown_key` warnings (and are not
/// part of the parsed value, so they are dropped on write — 05 §2).
final class JsonReader {
  /// Wraps [map] found at [path]; reports unknown keys (minus [known]) now.
  JsonReader(this.map, this.path, this.sink, {required Set<String> known}) {
    for (final key in map.keys) {
      if (!known.contains(key)) {
        sink.warn(_at(key), 'unknown_key', 'Unknown key "$key" was dropped.');
      }
    }
  }

  /// Interprets [value] at [path] as an object; reports `wrong_type` and
  /// returns `null` otherwise.
  static JsonReader? object(
    Object? value,
    String path,
    IssueSink sink, {
    required Set<String> known,
    bool required = true,
  }) {
    if (value == null) {
      if (required) sink.error(path, 'missing', 'A value is required.');
      return null;
    }
    if (value is! Map) {
      sink.error(path, 'wrong_type', 'Expected an object.');
      return null;
    }
    return JsonReader(
      value.map((k, v) => MapEntry('$k', v)),
      path,
      sink,
      known: known,
    );
  }

  /// The object being read.
  final JsonMap map;

  /// Its JSON path.
  final String path;

  /// Where problems go.
  final IssueSink sink;

  String _at(String key) => path.isEmpty ? key : '$path.$key';

  /// The path of [key] inside this object.
  String at(String key) => _at(key);

  /// Whether [key] is present with a non-null value.
  bool has(String key) => map[key] != null;

  /// A string field; `allowed` restricts the values (`out_of_range`).
  String? string(
    String key, {
    bool required = false,
    Set<String>? allowed,
    String? fallback,
  }) {
    final v = map[key];
    if (v == null) {
      if (required) sink.error(_at(key), 'missing', 'A value is required.');
      return fallback;
    }
    if (v is! String) {
      sink.error(_at(key), 'wrong_type', 'Expected a string.');
      return fallback;
    }
    if (allowed != null && !allowed.contains(v)) {
      sink.error(
        _at(key),
        'out_of_range',
        '"$v" is not one of ${allowed.join(', ')}.',
      );
      return fallback;
    }
    return v;
  }

  /// A number field within `[min, max]`.
  double? number(
    String key, {
    bool required = false,
    double? min,
    double? max,
    double? fallback,
  }) {
    final v = map[key];
    if (v == null) {
      if (required) sink.error(_at(key), 'missing', 'A value is required.');
      return fallback;
    }
    if (v is! num || !v.isFinite) {
      sink.error(_at(key), 'wrong_type', 'Expected a number.');
      return fallback;
    }
    final d = v.toDouble();
    if ((min != null && d < min) || (max != null && d > max)) {
      sink.error(
        _at(key),
        'out_of_range',
        '$v is outside ${min ?? '-∞'}…${max ?? '∞'}.',
      );
      return fallback;
    }
    return d;
  }

  /// An integer field within `[min, max]`.
  int? integer(String key, {bool required = false, int? min, int? max}) {
    final d = number(
      key,
      required: required,
      min: min?.toDouble(),
      max: max?.toDouble(),
    );
    if (d == null) return null;
    if (d != d.roundToDouble()) {
      sink.error(_at(key), 'wrong_type', 'Expected an integer.');
      return null;
    }
    return d.toInt();
  }

  /// A boolean field.
  bool? boolean(String key, {bool required = false, bool? fallback}) {
    final v = map[key];
    if (v == null) {
      if (required) sink.error(_at(key), 'missing', 'A value is required.');
      return fallback;
    }
    if (v is! bool) {
      sink.error(_at(key), 'wrong_type', 'Expected true or false.');
      return fallback;
    }
    return v;
  }

  /// A list field.
  List<Object?>? list(String key, {bool required = false}) {
    final v = map[key];
    if (v == null) {
      if (required) sink.error(_at(key), 'missing', 'A value is required.');
      return null;
    }
    if (v is! List) {
      sink.error(_at(key), 'wrong_type', 'Expected a list.');
      return null;
    }
    return v;
  }

  /// A nested object field read with [known] keys.
  JsonReader? child(
    String key, {
    required Set<String> known,
    bool required = false,
  }) => JsonReader.object(
    map[key],
    _at(key),
    sink,
    known: known,
    required: required,
  );

  /// Reports the `"v"` version field: missing → warning (treated as 1),
  /// anything but 1 → error.
  void version({bool required = false}) {
    final v = map['v'];
    if (v == null) {
      if (required) {
        sink.warn(_at('v'), 'missing', 'Missing "v"; treated as version 1.');
      }
      return;
    }
    if (v != 1) {
      sink.error(_at('v'), 'unsupported_version', 'Unsupported version $v.');
    }
  }
}

/// Puts `value` into [out] under [key] when it is not null (numbers
/// normalized).
void putIfNotNull(JsonMap out, String key, Object? value) {
  if (value == null) return;
  out[key] = value is num ? normalizeJsonNumber(value) : value;
}
