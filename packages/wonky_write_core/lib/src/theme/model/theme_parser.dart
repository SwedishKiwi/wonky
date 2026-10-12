/// Parsing and semantic validation of theme JSON (06 §2.7).
library;

import '../../fonts/font_registry.dart';
import 'catalog.dart';
import 'color_ref.dart';
import 'json_util.dart';
import 'properties.dart';
import 'syntax_token.dart';
import 'values.dart';
import 'write_theme_data.dart';

/// Result of [parseThemeJson].
final class ThemeParseResult {
  /// Creates a result.
  const ThemeParseResult(this.theme, this.errors, this.warnings);

  /// The cleaned theme, or `null` when [errors] is not empty.
  final WriteThemeData? theme;

  /// Blocking issues.
  final List<ThemeIssue> errors;

  /// Non-blocking issues (values dropped, replaced or snapped).
  final List<ThemeIssue> warnings;
}

/// Top-level keys of an exported theme envelope that are ignored silently.
const _envelopeKeys = {r'$schema', 'exportedAt'};

const _topLevelKeys = {
  'schemaVersion',
  'name',
  'description',
  'basedOn',
  'fonts',
  'palette',
  'dark',
  'page',
  'elements',
  'syntax',
  'overlays',
};

/// Parses already-migrated theme [json] (schema v1), collecting errors and
/// warnings. Does not run migrations (see `ThemeMigrations`).
ThemeParseResult parseThemeJson(Object? json) {
  final sink = ThemeIssueSink();
  if (json is! Map) {
    sink.error('', 'wrong_type', 'A theme must be a JSON object.');
    return ThemeParseResult(null, sink.errors, sink.warnings);
  }
  for (final k in json.keys) {
    if (!_topLevelKeys.contains(k) && !_envelopeKeys.contains(k)) {
      sink.warning('$k', 'unknown_property', 'Unknown property "$k" dropped.');
    }
  }

  final version = json['schemaVersion'];
  if (version != currentThemeSchemaVersion) {
    sink.error(
      'schemaVersion',
      'unsupported_version',
      'Expected schemaVersion $currentThemeSchemaVersion, got $version.',
    );
  }

  final name = _string(json['name'], 'name', sink, required: true, max: 80);
  final description = _string(
    json['description'],
    'description',
    sink,
    max: 500,
  );
  final basedOn = _string(json['basedOn'], 'basedOn', sink, max: 200);

  final fonts = _parseFonts(json['fonts'], sink);
  final roleFamilies = fonts.asMap;
  PropParseContext ctx(FontRole role) => PropParseContext(
    issues: sink,
    roleFamilies: roleFamilies,
    defaultRole: role,
  );

  final palette = _parsePalette(json['palette'], 'palette', sink);
  if (palette != null) {
    for (final k in palette.missingKeys) {
      sink.error(
        'palette.${k.name}',
        'incomplete_palette',
        'The light palette must define "${k.name}".',
      );
    }
    _checkPaletteRefs(palette, 'palette', sink, base: null);
  } else if (json['palette'] == null) {
    sink.error('palette', 'incomplete_palette', 'The light palette is missing.');
  }

  final elements = _parseElements(json['elements'], 'elements', sink, ctx);
  final dark = _parseDark(json['dark'], sink, ctx, palette);
  final page =
      ThemeCatalog.page.parse(json['page'], 'page', ctx(FontRole.body)) ??
      PropertyBag.empty;
  final syntax = _parseSyntax(json['syntax'], 'syntax', sink, ctx) ??
      SyntaxPalette.empty;
  final overlays =
      ThemeCatalog.overlays.parse(
        json['overlays'],
        'overlays',
        ctx(FontRole.body),
      ) ??
      PropertyBag.empty;

  _checkNumbering(elements, 'elements', sink);
  _checkNumbering(dark.elements, 'dark.elements', sink, base: elements);

  if (sink.errors.isNotEmpty || name == null || palette == null) {
    return ThemeParseResult(null, sink.errors, sink.warnings);
  }
  final theme = WriteThemeData(
    name: name,
    description: description,
    basedOn: basedOn,
    fonts: fonts,
    palette: palette,
    dark: dark,
    page: page,
    elements: elements,
    syntax: syntax,
    overlays: overlays,
  );
  return ThemeParseResult(theme, sink.errors, sink.warnings);
}

String? _string(
  Object? v,
  String path,
  ThemeIssueSink sink, {
  bool required = false,
  required int max,
}) {
  if (v == null) {
    if (required) sink.error(path, 'required', '"$path" is required.');
    return null;
  }
  if (v is! String) {
    sink.error(path, 'wrong_type', 'Expected a string.');
    return null;
  }
  final t = v.trim();
  if (required && t.isEmpty) {
    sink.error(path, 'required', '"$path" must not be empty.');
    return null;
  }
  if (t.length > max) {
    sink.error(path, 'too_long', 'At most $max characters.');
    return null;
  }
  return t;
}

ThemeFonts _parseFonts(Object? json, ThemeIssueSink sink) {
  if (json == null) return const ThemeFonts();
  if (json is! Map) {
    sink.error('fonts', 'wrong_type', 'Expected an object.');
    return const ThemeFonts();
  }
  for (final k in json.keys) {
    if (k != 'body' && k != 'heading' && k != 'mono') {
      sink.warning(
        'fonts.$k',
        'unknown_property',
        'Unknown property "$k" dropped.',
      );
    }
  }
  String family(String role) {
    final v = json[role];
    final fallback = FontRegistry.defaultFor(role);
    if (v == null) return fallback;
    if (v is! String) {
      sink.error('fonts.$role', 'wrong_type', 'Expected a family name.');
      return fallback;
    }
    final canonical = FontRegistry.canonicalName(v);
    if (canonical == null) {
      sink.warning(
        'fonts.$role',
        'unknown_font',
        'Unknown font family "$v"; using "$fallback".',
      );
      return fallback;
    }
    return canonical;
  }

  return ThemeFonts(
    body: family('body'),
    heading: family('heading'),
    mono: family('mono'),
  );
}

ThemePalette? _parsePalette(Object? json, String path, ThemeIssueSink sink) {
  if (json == null) return null;
  if (json is! Map) {
    sink.error(path, 'wrong_type', 'Expected an object.');
    return null;
  }
  final out = <PaletteKey, ColorRef>{};
  for (final e in json.entries) {
    final key = PaletteKey.fromJsonName('${e.key}');
    if (key == null) {
      sink.warning(
        '$path.${e.key}',
        'unknown_property',
        'Unknown palette key "${e.key}" dropped.',
      );
      continue;
    }
    final v = e.value;
    if (v == null) continue;
    if (v is! String) {
      sink.error('$path.${key.name}', 'wrong_type', 'Expected a color.');
      continue;
    }
    final c = ColorRef.tryParse(v.trim());
    if (c == null) {
      sink.error('$path.${key.name}', 'invalid_color', 'Invalid color "$v".');
      continue;
    }
    out[key] = c;
  }
  return ThemePalette(out);
}

/// Checks palette references for cycles and references to unset keys.
/// [base] is the palette that unset keys fall back to (dark derived mode).
void _checkPaletteRefs(
  ThemePalette palette,
  String path,
  ThemeIssueSink sink, {
  required ThemePalette? base,
}) {
  for (final start in palette.entries.keys) {
    final seen = <PaletteKey>{start};
    var current = palette[start];
    while (current != null && current.kind == ColorRefKind.palette) {
      final next = current.paletteKey!;
      if (!seen.add(next)) {
        sink.error(
          '$path.${start.name}',
          'palette_cycle',
          'Palette reference cycle through "@${next.name}".',
        );
        break;
      }
      final target = palette[next] ?? base?[next];
      if (target == null) {
        sink.error(
          '$path.${start.name}',
          'palette_ref_unset',
          'References "@${next.name}", which is not set.',
        );
        break;
      }
      current = target;
    }
  }
}

Map<ThemeElement, ElementStyleSpec> _parseElements(
  Object? json,
  String path,
  ThemeIssueSink sink,
  PropParseContext Function(FontRole role) ctx,
) {
  if (json == null) return const {};
  if (json is! Map) {
    sink.error(path, 'wrong_type', 'Expected an object.');
    return const {};
  }
  final out = <ThemeElement, ElementStyleSpec>{};
  for (final e in json.entries) {
    final element = ThemeElement.fromJsonName('${e.key}');
    if (element == null) {
      sink.warning(
        '$path.${e.key}',
        'unknown_property',
        'Unknown element "${e.key}" dropped.',
      );
      continue;
    }
    final bag = ThemeCatalog.elements[element]!.parse(
      e.value,
      '$path.${element.name}',
      ctx(ThemeCatalog.roleOf(element)),
    );
    if (bag != null && bag.isNotEmpty) out[element] = bag;
  }
  return out;
}

SyntaxPalette? _parseSyntax(
  Object? json,
  String path,
  ThemeIssueSink sink,
  PropParseContext Function(FontRole role) ctx,
) {
  if (json == null) return null;
  if (json is! Map) {
    sink.error(path, 'wrong_type', 'Expected an object.');
    return null;
  }
  final out = <SyntaxToken, PropertyBag>{};
  for (final e in json.entries) {
    final token = SyntaxToken.fromJsonName('${e.key}');
    if (token == null) {
      sink.warning(
        '$path.${e.key}',
        'unknown_property',
        'Unknown syntax token "${e.key}" dropped.',
      );
      continue;
    }
    final bag = ThemeCatalog.syntaxToken.parse(
      e.value,
      '$path.${token.name}',
      ctx(FontRole.mono),
    );
    if (bag != null && bag.isNotEmpty) out[token] = bag;
  }
  return SyntaxPalette(out);
}

DarkVariantSpec _parseDark(
  Object? json,
  ThemeIssueSink sink,
  PropParseContext Function(FontRole role) ctx,
  ThemePalette? light,
) {
  if (json == null) return DarkVariantSpec();
  if (json is! Map) {
    sink.error('dark', 'wrong_type', 'Expected an object.');
    return DarkVariantSpec();
  }
  for (final k in json.keys) {
    if (!const {'mode', 'palette', 'elements', 'syntax'}.contains(k)) {
      sink.warning(
        'dark.$k',
        'unknown_property',
        'Unknown property "$k" dropped.',
      );
    }
  }
  var mode = DarkMode.derived;
  final modeJson = json['mode'];
  if (modeJson != null) {
    final m = enumFromJson(DarkMode.values, modeJson);
    if (m == null) {
      sink.error(
        'dark.mode',
        'invalid_value',
        'Expected "derived" or "explicit".',
      );
    } else {
      mode = m;
    }
  }
  final palette =
      _parsePalette(json['palette'], 'dark.palette', sink) ??
      ThemePalette.empty;
  if (mode == DarkMode.explicit) {
    for (final k in palette.missingKeys) {
      sink.error(
        'dark.palette.${k.name}',
        'incomplete_palette',
        'An explicit dark palette must define "${k.name}".',
      );
    }
    _checkPaletteRefs(palette, 'dark.palette', sink, base: null);
  } else {
    _checkPaletteRefs(palette, 'dark.palette', sink, base: light);
  }
  return DarkVariantSpec(
    mode: mode,
    palette: palette,
    elements: _parseElements(json['elements'], 'dark.elements', sink, ctx),
    syntax: _parseSyntax(json['syntax'], 'dark.syntax', sink, ctx),
  );
}

void _checkNumbering(
  Map<ThemeElement, ElementStyleSpec> elements,
  String path,
  ThemeIssueSink sink, {
  Map<ThemeElement, ElementStyleSpec>? base,
}) {
  final n = elements[ThemeElement.headings]?.bag('numbering');
  if (n == null) return;
  final b = base?[ThemeElement.headings]?.bag('numbering');
  final from = n.integer('fromLevel') ?? b?.integer('fromLevel') ?? 1;
  final to = n.integer('toLevel') ?? b?.integer('toLevel') ?? 6;
  if (from > to) {
    sink.error(
      '$path.headings.numbering',
      'numbering_range',
      'fromLevel ($from) must not be greater than toLevel ($to).',
    );
  }
}
