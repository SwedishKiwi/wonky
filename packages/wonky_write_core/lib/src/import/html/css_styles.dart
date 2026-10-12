/// Minimal CSS handling for the HTML importer: inline `style` declarations
/// and single-class rules from `<style>` elements (Google Docs exports put
/// all formatting into `.cN` classes).
library;

/// Parsed CSS declarations (property names lower-cased, values trimmed,
/// `!important` removed). Later declarations win.
final class CssDeclarations {
  /// Creates declarations from a map.
  const CssDeclarations(this.values);

  /// Empty declarations.
  static const empty = CssDeclarations({});

  /// Property → value.
  final Map<String, String> values;

  /// Parses a declaration block (`a: b; c: d`).
  static CssDeclarations parse(String? style) {
    if (style == null || style.trim().isEmpty) return empty;
    final out = <String, String>{};
    for (final part in _splitDeclarations(style)) {
      final colon = part.indexOf(':');
      if (colon <= 0) continue;
      final key = part.substring(0, colon).trim().toLowerCase();
      var value = part.substring(colon + 1).trim();
      value = value.replaceFirst(RegExp(r'\s*!important\s*$'), '');
      if (key.isEmpty) continue;
      out[key] = value;
    }
    return out.isEmpty ? empty : CssDeclarations(out);
  }

  // Splits on `;` outside quotes and parentheses.
  static List<String> _splitDeclarations(String s) {
    final parts = <String>[];
    var depth = 0;
    String? quote;
    var start = 0;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (quote != null) {
        if (c == quote) quote = null;
      } else if (c == '"' || c == "'") {
        quote = c;
      } else if (c == '(') {
        depth++;
      } else if (c == ')') {
        if (depth > 0) depth--;
      } else if (c == ';' && depth == 0) {
        parts.add(s.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(s.substring(start));
    return parts;
  }

  /// The value of [property] (lower-case name), or `null`.
  String? operator [](String property) => values[property];

  /// Whether there are no declarations.
  bool get isEmpty => values.isEmpty;

  /// These declarations overridden by [other].
  CssDeclarations merge(CssDeclarations other) {
    if (other.isEmpty) return this;
    if (isEmpty) return other;
    return CssDeclarations({...values, ...other.values});
  }
}

/// Class-based rules collected from `<style>` elements. Only simple
/// selectors `.class` and `tag.class` are supported (no combinators).
final class CssClassRules {
  /// Creates rules.
  CssClassRules(this._byClass);

  /// No rules.
  static final empty = CssClassRules(const {});

  final Map<String, CssDeclarations> _byClass;

  /// Parses style sheet texts.
  static CssClassRules parse(Iterable<String> sheets) {
    final byClass = <String, CssDeclarations>{};
    final rule = RegExp(r'([^{}]+)\{([^{}]*)\}');
    final simple = RegExp(r'^[A-Za-z0-9]*\.([A-Za-z0-9_-]+)$');
    for (final sheet in sheets) {
      final css = sheet.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
      for (final m in rule.allMatches(css)) {
        final decls = CssDeclarations.parse(m.group(2));
        if (decls.isEmpty) continue;
        for (final sel in m.group(1)!.split(',')) {
          final s = simple.firstMatch(sel.trim());
          if (s == null) continue;
          final cls = s.group(1)!;
          byClass[cls] = (byClass[cls] ?? CssDeclarations.empty).merge(decls);
        }
      }
    }
    return byClass.isEmpty ? empty : CssClassRules(byClass);
  }

  /// Declarations of [classes] (in order).
  CssDeclarations forClasses(Iterable<String> classes) {
    if (_byClass.isEmpty) return CssDeclarations.empty;
    var out = CssDeclarations.empty;
    for (final c in classes) {
      final d = _byClass[c];
      if (d != null) out = out.merge(d);
    }
    return out;
  }
}

/// Interpretation of common CSS values.
abstract final class CssValues {
  /// `true` = bold, `false` = explicitly not bold, `null` = unknown.
  static bool? fontWeightBold(String? v) {
    if (v == null) return null;
    final s = v.trim().toLowerCase();
    if (s == 'bold' || s == 'bolder') return true;
    if (s == 'normal' || s == 'lighter') return false;
    final n = int.tryParse(s);
    if (n != null) return n >= 600;
    return null;
  }

  /// `true` = italic, `false` = explicitly normal, `null` = unknown.
  static bool? fontStyleItalic(String? v) {
    if (v == null) return null;
    final s = v.trim().toLowerCase();
    if (s.startsWith('italic') || s.startsWith('oblique')) return true;
    if (s == 'normal') return false;
    return null;
  }

  static const _defaultColors = {
    'black',
    '#000',
    '#000000',
    'rgb(0,0,0)',
    'rgba(0,0,0,1)',
    'inherit',
    'initial',
    'unset',
    'currentcolor',
    'windowtext',
    'auto',
    'transparent',
    'text',
  };

  static const _defaultBackgrounds = {
    'transparent',
    'none',
    'white',
    '#fff',
    '#ffffff',
    'rgb(255,255,255)',
    'rgba(255,255,255,1)',
    'rgba(0,0,0,0)',
    'inherit',
    'initial',
    'unset',
    'window',
    'auto',
  };

  /// Whether a `color` value is a non-default text color.
  static bool isCustomColor(String? v) =>
      v != null &&
      v.trim().isNotEmpty &&
      !_defaultColors.contains(v.toLowerCase().replaceAll(' ', ''));

  /// Whether a `background(-color)` value is a highlight.
  static bool isHighlight(String? v) {
    if (v == null) return false;
    final s = v.toLowerCase().replaceAll(' ', '');
    if (s.isEmpty) return false;
    return !_defaultBackgrounds.contains(s) &&
        !s.startsWith('transparent') &&
        !s.startsWith('none');
  }
}
