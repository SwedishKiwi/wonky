/// Small JSON helpers shared by the theme model.
library;

/// A decoded JSON object.
typedef JsonMap = Map<String, Object?>;

/// Formats [value] for theme JSON and length strings so that the output is
/// identical on the Dart VM and on the web: integral values are written
/// without a fraction (`2`, not `2.0`), others with the shortest
/// round-trippable representation.
String formatThemeNumber(num value) {
  if (value is int) return value.toString();
  final d = value.toDouble();
  if (d.isFinite && d == d.truncateToDouble() && d.abs() < 1e15) {
    return d.toInt().toString();
  }
  return d.toString();
}

/// Normalizes a JSON number so that integral doubles become `int` (VM and
/// web encode them identically then).
num normalizeJsonNumber(num value) {
  if (value is int) return value;
  final d = value.toDouble();
  if (d.isFinite && d == d.truncateToDouble() && d.abs() < 1e15) {
    return d.toInt();
  }
  return d;
}

/// Deep-copies a decoded JSON value into fresh mutable collections with
/// `String` keys. Non-JSON values are returned unchanged.
Object? deepCopyJson(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final e in value.entries) '${e.key}': deepCopyJson(e.value),
    };
  }
  if (value is List) return [for (final v in value) deepCopyJson(v)];
  return value;
}

/// An enum with a stable JSON spelling.
abstract interface class JsonEnum {
  /// The JSON spelling of this value.
  String get json;
}

/// Looks up the value of [values] whose [JsonEnum.json] equals [json].
T? enumFromJson<T extends JsonEnum>(List<T> values, Object? json) {
  if (json is! String) return null;
  for (final v in values) {
    if (v.json == json) return v;
  }
  return null;
}
