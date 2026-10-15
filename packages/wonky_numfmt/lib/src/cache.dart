import 'dart:collection';

import 'ast.dart';
import 'formatted_value.dart';
import 'parser.dart';

/// LRU caches of the number formatter (06 §5.11): pattern → AST (2,000
/// entries) and (pattern, locale, value) → [FormattedValue] (50,000 entries).
final class NumberFormatCache {
  /// Creates a cache.
  NumberFormatCache({this.astCapacity = 2000, this.valueCapacity = 50000});

  /// Maximum number of cached ASTs.
  final int astCapacity;

  /// Maximum number of cached formatted values.
  final int valueCapacity;

  // Value is the AST, or a FormatParseError for invalid patterns.
  final LinkedHashMap<String, Object> _asts = LinkedHashMap();
  final LinkedHashMap<(String, String, Object), FormattedValue> _values =
      LinkedHashMap();

  /// Number of cached ASTs.
  int get astCount => _asts.length;

  /// Number of cached formatted values.
  int get valueCount => _values.length;

  /// The AST of [pattern] (parsed on miss), or null when it is invalid.
  NumberFormatAst? ast(String pattern) {
    var entry = _asts.remove(pattern);
    if (entry == null) {
      try {
        entry = NumberFormatParser.parse(pattern);
      } on FormatParseError catch (e) {
        entry = e;
      }
      if (_asts.length >= astCapacity) _asts.remove(_asts.keys.first);
    }
    _asts[pattern] = entry;
    return entry is NumberFormatAst ? entry : null;
  }

  /// The parse error of [pattern], or null when it is valid.
  FormatParseError? error(String pattern) {
    ast(pattern);
    final e = _asts[pattern];
    return e is FormatParseError ? e : null;
  }

  /// Cached value for ([pattern], [locale], [valueKey]), or null.
  FormattedValue? lookup(String pattern, String locale, Object valueKey) {
    final key = (pattern, locale, valueKey);
    final hit = _values.remove(key);
    if (hit != null) _values[key] = hit;
    return hit;
  }

  /// Stores a formatted value.
  void store(
    String pattern,
    String locale,
    Object valueKey,
    FormattedValue value,
  ) {
    final key = (pattern, locale, valueKey);
    _values.remove(key);
    if (_values.length >= valueCapacity) _values.remove(_values.keys.first);
    _values[key] = value;
  }

  /// Clears formatted values (e.g. after a locale change).
  void clearValues() => _values.clear();

  /// Clears everything.
  void clear() {
    _asts.clear();
    _values.clear();
  }
}
