/// Property paths for `write.theme.setProperty` (06 §11) and RFC 7396 JSON
/// merge patches for `write.update_theme` (06 §12).
library;

import '../model/catalog.dart';
import '../model/color_ref.dart';
import '../model/json_util.dart';
import '../model/properties.dart';
import '../model/syntax_token.dart';
import '../model/values.dart';
import '../resolve/base_theme.dart';

/// Thrown for a path that does not name a theme property.
final class ThemePathException implements Exception {
  /// Creates the exception.
  const ThemePathException(this.path, this.message);

  /// The offending path.
  final String path;

  /// Explanation.
  final String message;

  @override
  String toString() => 'ThemePathException("$path"): $message';
}

/// Dotted property paths into theme JSON, e.g. `elements.h2.fontSize`,
/// `palette.accent`, `dark.palette.text`, `page.headerFooter.fontSize`,
/// `elements.task.checkedText.opacity`, `syntax.keyword.color`,
/// `fonts.body`, `name`.
///
/// Paths are checked against the schema-v1 catalog; values are not (run
/// `WriteThemeValidator` on the result). All operations are pure: they
/// return a modified deep copy.
abstract final class ThemePropertyPath {
  /// Qualifies [path] for [variant]: for [ThemeVariant.dark], `palette.*`,
  /// `elements.*` and `syntax.*` become `dark.palette.*`, … . Paths that
  /// already start with `dark.` are returned unchanged.
  ///
  /// Throws [ThemePathException] when [path] has no dark counterpart (e.g.
  /// `page.*`, `fonts.*`) and [variant] is dark.
  static String qualify(String path, ThemeVariant? variant) {
    if (variant != ThemeVariant.dark || path.startsWith('dark.')) return path;
    final head = path.split('.').first;
    if (head == 'palette' || head == 'elements' || head == 'syntax') {
      return 'dark.$path';
    }
    throw ThemePathException(path, 'Has no dark-variant override.');
  }

  /// Validates [path] against the catalog. Throws [ThemePathException].
  static void check(String path) {
    final p = path.split('.');
    if (p.any((s) => s.isEmpty)) {
      throw ThemePathException(path, 'Empty segment.');
    }
    var i = 0;
    if (p[0] == 'dark') {
      if (p.length == 2 && p[1] == 'mode') return;
      if (p.length < 2 ||
          !const {'palette', 'elements', 'syntax'}.contains(p[1])) {
        throw ThemePathException(path, 'Unknown dark section.');
      }
      i = 1;
    }
    final section = p[i];
    final rest = p.sublist(i + 1);
    switch (section) {
      case 'name' || 'description' || 'basedOn' when i == 0 && rest.isEmpty:
        return;
      case 'fonts' when i == 0:
        if (rest.length == 1 &&
            const {'body', 'heading', 'mono'}.contains(rest[0])) {
          return;
        }
      case 'palette':
        if (rest.length == 1 && PaletteKey.fromJsonName(rest[0]) != null) {
          return;
        }
      case 'syntax':
        if (rest.isEmpty) {
          if (i == 1) return;
          break;
        }
        if (SyntaxToken.fromJsonName(rest[0]) != null &&
            _checkFields(ThemeCatalog.syntaxToken, rest.sublist(1))) {
          return;
        }
      case 'elements':
        if (rest.isEmpty) break;
        final e = ThemeElement.fromJsonName(rest[0]);
        if (e != null &&
            _checkFields(ThemeCatalog.elements[e]!, rest.sublist(1))) {
          return;
        }
      case 'page' when i == 0:
        if (_checkFields(ThemeCatalog.page, rest)) return;
      case 'overlays' when i == 0:
        if (_checkFields(ThemeCatalog.overlays, rest)) return;
    }
    throw ThemePathException(path, 'Not a theme property.');
  }

  static bool _checkFields(ObjectProp obj, List<String> rest) {
    if (rest.isEmpty) return true;
    final t = obj.fields[rest.first];
    if (t == null) return false;
    if (rest.length == 1) return true;
    return switch (t) {
      ObjectProp() => _checkFields(t, rest.sublist(1)),
      BorderProp() =>
        rest.length == 2 && const {'width', 'style', 'color'}.contains(rest[1]),
      EdgesProp() =>
        rest.length == 2 &&
            const {'top', 'right', 'bottom', 'left'}.contains(rest[1]),
      _ => false,
    };
  }

  /// The raw JSON value at [path] (qualified for [variant]), or `null`.
  static Object? get(JsonMap json, String path, {ThemeVariant? variant}) {
    final q = qualify(path, variant);
    check(q);
    Object? node = json;
    for (final seg in q.split('.')) {
      if (node is! Map) return null;
      node = node[seg];
    }
    return node;
  }

  /// Returns a copy of [json] with [path] (qualified for [variant]) set to
  /// [value]. `null` resets the property to *inherit*: the key is removed
  /// and emptied parent objects are pruned; for a required light palette
  /// entry the *Wonky Default* value is restored instead (a light palette
  /// cannot inherit).
  static JsonMap set(
    JsonMap json,
    String path,
    Object? value, {
    ThemeVariant? variant,
  }) {
    final q = qualify(path, variant);
    check(q);
    final out = deepCopyJson(json) as JsonMap;
    final segs = q.split('.');
    if (value == null && segs.length == 2 && segs[0] == 'palette') {
      final key = PaletteKey.fromJsonName(segs[1])!;
      if (!key.isCustom) {
        value = BaseTheme.instance.paletteValue(key)?.toJson();
      } else {
        final palette = out['palette'];
        if (palette is Map) palette[segs[1]] = null;
        return out;
      }
    }
    if (value == null) {
      _remove(out, segs);
      return out;
    }
    Map<String, Object?> node = out;
    for (var i = 0; i < segs.length - 1; i++) {
      final child = node[segs[i]];
      if (child is Map<String, Object?>) {
        node = child;
      } else {
        final created = <String, Object?>{};
        // An Edges/Border shorthand value is expanded so one side can be
        // set: "12pt" → {"top": "12pt", …}.
        if (child != null && child is! Map) {
          for (final s in const ['top', 'right', 'bottom', 'left']) {
            created[s] = child;
          }
        }
        node[segs[i]] = created;
        node = created;
      }
    }
    node[segs.last] = deepCopyJson(value);
    return out;
  }

  static void _remove(JsonMap root, List<String> segs) {
    final chain = <Map<String, Object?>>[root];
    Map<String, Object?> node = root;
    for (var i = 0; i < segs.length - 1; i++) {
      final child = node[segs[i]];
      if (child is! Map<String, Object?>) return;
      node = child;
      chain.add(node);
    }
    node.remove(segs.last);
    // Prune emptied containers below the section level.
    for (var i = chain.length - 1; i >= 2; i--) {
      if (chain[i].isEmpty) chain[i - 1].remove(segs[i - 1]);
    }
  }
}

/// RFC 7396 JSON merge patch.
abstract final class ThemeJsonPatch {
  /// Applies [patch] to [target] (RFC 7396): objects merge recursively,
  /// `null` removes a key, any other value replaces. Returns a new value;
  /// inputs are not modified.
  static Object? merge(Object? target, Object? patch) {
    if (patch is! Map) return deepCopyJson(patch);
    final out = target is Map
        ? deepCopyJson(target) as JsonMap
        : <String, Object?>{};
    for (final e in patch.entries) {
      final key = '${e.key}';
      if (e.value == null) {
        out.remove(key);
      } else {
        out[key] = merge(out[key], e.value);
      }
    }
    return out;
  }

  /// Computes a merge patch that turns [from] into [to] (inverse of
  /// [merge] for JSON objects without `null` values; used for MCP
  /// `changes.revert`).
  static Object? diff(Object? from, Object? to) {
    if (from is! Map || to is! Map) return deepCopyJson(to);
    final out = <String, Object?>{};
    for (final k in from.keys) {
      if (!to.containsKey(k)) out['$k'] = null;
    }
    for (final e in to.entries) {
      final before = from[e.key];
      if (!_deepEquals(before, e.value)) {
        out['${e.key}'] = diff(before, e.value);
      }
    }
    return out;
  }

  static bool _deepEquals(Object? a, Object? b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k) || !_deepEquals(a[k], b[k])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
