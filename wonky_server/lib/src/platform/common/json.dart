import 'dart:convert';

/// Decodes a JSON object string; returns an empty map for invalid input.
Map<String, Object?> decodeObject(String? json) {
  if (json == null || json.isEmpty) return {};
  try {
    final value = jsonDecode(json);
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.cast<String, Object?>();
  } on FormatException {
    // Fall through.
  }
  return {};
}

/// Merges [patch] into [base] key by key; keys set to null in [patch] are
/// removed.
Map<String, Object?> mergeObjects(
  Map<String, Object?> base,
  Map<String, Object?> patch,
) {
  final result = Map<String, Object?>.of(base);
  patch.forEach((key, value) {
    if (value == null) {
      result.remove(key);
    } else {
      result[key] = value;
    }
  });
  return result;
}
