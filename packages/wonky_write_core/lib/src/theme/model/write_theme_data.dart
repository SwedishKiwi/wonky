/// The persisted theme model `WriteThemeData` (06 §2.2, §3).
library;

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';

import '../../delta/hash.dart' show canonicalJsonEncode;
import 'package:wonky_fonts/wonky_fonts.dart';
import 'color_ref.dart';
import 'json_util.dart';
import 'properties.dart';
import 'syntax_token.dart';
import 'theme_parser.dart';
import 'values.dart';

/// Style properties of one element (sparse; absent keys inherit).
typedef ElementStyleSpec = PropertyBag;

/// The `page` section (sparse).
typedef PageStyleSpec = PropertyBag;

/// The `overlays` section (sparse; absent = app token).
typedef OverlaySpec = PropertyBag;

/// Current theme schema version.
const int currentThemeSchemaVersion = 1;

/// Schema URL of exported theme JSON (06 §10.5) and MCP resource name.
const String themeSchemaUrl = 'https://wonky.work/schemas/write-theme-v1.json';

/// MCP resource URI of the JSON schema (06 §12).
const String themeSchemaResourceUri = 'wonky://schemas/write-theme-v1.json';

/// The `fonts` section: concrete families of the three roles.
final class ThemeFonts {
  /// Creates the fonts section.
  const ThemeFonts({
    this.body = FontRegistry.defaultBody,
    this.heading = FontRegistry.defaultHeading,
    this.mono = FontRegistry.defaultMono,
  });

  /// Body family.
  final String body;

  /// Heading family.
  final String heading;

  /// Monospace family.
  final String mono;

  /// The family of [role].
  String of(FontRole role) => switch (role) {
    FontRole.body => body,
    FontRole.heading => heading,
    FontRole.mono => mono,
  };

  /// The families as a role map.
  Map<FontRole, String> get asMap => {
    FontRole.body: body,
    FontRole.heading: heading,
    FontRole.mono: mono,
  };

  /// JSON form.
  JsonMap toJson() => {'body': body, 'heading': heading, 'mono': mono};

  @override
  bool operator ==(Object other) =>
      other is ThemeFonts &&
      other.body == body &&
      other.heading == heading &&
      other.mono == mono;

  @override
  int get hashCode => Object.hash(body, heading, mono);

  @override
  String toString() => 'ThemeFonts(${toJson()})';
}

/// A palette: [PaletteKey] → [ColorRef]. The light palette is complete (all
/// non-custom keys set); dark palettes may be partial (derived mode).
final class ThemePalette {
  /// Creates a palette from [entries] (copied).
  ThemePalette(Map<PaletteKey, ColorRef> entries)
    : _entries = Map.unmodifiable(entries);

  const ThemePalette._empty() : _entries = const {};

  /// The empty palette.
  static const empty = ThemePalette._empty();

  final Map<PaletteKey, ColorRef> _entries;

  /// The set entries.
  Map<PaletteKey, ColorRef> get entries => _entries;

  /// The entry of [key], or `null` when unset.
  ColorRef? operator [](PaletteKey key) => _entries[key];

  /// Whether no entry is set.
  bool get isEmpty => _entries.isEmpty;

  /// The required (non-custom) keys that are not set.
  List<PaletteKey> get missingKeys => [
    for (final k in PaletteKey.values)
      if (!k.isCustom && !_entries.containsKey(k)) k,
  ];

  /// Whether all required keys are set.
  bool get isComplete => missingKeys.isEmpty;

  /// A copy with [key] set to [value] (removed when `null`).
  ThemePalette withEntry(PaletteKey key, ColorRef? value) {
    final m = Map<PaletteKey, ColorRef>.of(_entries);
    if (value == null) {
      m.remove(key);
    } else {
      m[key] = value;
    }
    return ThemePalette(m);
  }

  /// This palette with the entries of [over] applied.
  ThemePalette merge(ThemePalette over) =>
      over.isEmpty ? this : ThemePalette({..._entries, ...over._entries});

  /// JSON form. With [full], every key is listed (unset keys as `null`, as
  /// in the light palette); otherwise only set keys.
  JsonMap toJson({bool full = false}) => {
    for (final k in PaletteKey.values)
      if (full || _entries.containsKey(k)) k.name: _entries[k]?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is ThemePalette &&
      const MapEquality<PaletteKey, ColorRef>().equals(
        other._entries,
        _entries,
      );

  @override
  int get hashCode => const MapEquality<PaletteKey, ColorRef>().hash(_entries);

  @override
  String toString() => 'ThemePalette(${toJson()})';
}

/// The `syntax` section: [SyntaxToken] → `{color, fontStyle, fontWeight}`.
final class SyntaxPalette {
  /// Creates a syntax palette from [tokens] (copied).
  SyntaxPalette(Map<SyntaxToken, PropertyBag> tokens)
    : _tokens = Map.unmodifiable(tokens);

  const SyntaxPalette._empty() : _tokens = const {};

  /// The empty syntax palette (all tokens use the base / `codeText`).
  static const empty = SyntaxPalette._empty();

  final Map<SyntaxToken, PropertyBag> _tokens;

  /// The set token styles.
  Map<SyntaxToken, PropertyBag> get tokens => _tokens;

  /// The style of [token], or `null`.
  PropertyBag? operator [](SyntaxToken token) => _tokens[token];

  /// Whether no token is set.
  bool get isEmpty => _tokens.isEmpty;

  /// JSON form (set tokens only).
  JsonMap toJson() => {
    for (final t in SyntaxToken.values)
      if (_tokens.containsKey(t)) t.name: _tokens[t]!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is SyntaxPalette &&
      const MapEquality<SyntaxToken, PropertyBag>().equals(
        other._tokens,
        _tokens,
      );

  @override
  int get hashCode =>
      const MapEquality<SyntaxToken, PropertyBag>().hash(_tokens);
}

/// `dark.mode` (06 §4).
enum DarkMode implements JsonEnum {
  /// Dark palette derived from the light palette, then overrides.
  derived,

  /// Dark palette given completely.
  explicit;

  @override
  String get json => name;
}

/// The `dark` section (06 §2.2, §4).
final class DarkVariantSpec {
  /// Creates the dark section.
  DarkVariantSpec({
    this.mode = DarkMode.derived,
    this.palette = ThemePalette.empty,
    Map<ThemeElement, ElementStyleSpec> elements = const {},
    this.syntax,
  }) : elements = Map.unmodifiable(elements);

  /// Derivation mode.
  final DarkMode mode;

  /// Derived mode: overrides on top of the derived palette. Explicit mode:
  /// the complete dark palette.
  final ThemePalette palette;

  /// Element overrides for the dark variant (sparse).
  final Map<ThemeElement, ElementStyleSpec> elements;

  /// Dark syntax palette; `null` = derive from the light syntax palette.
  final SyntaxPalette? syntax;

  /// JSON form.
  JsonMap toJson() => {
    'mode': mode.json,
    'palette': palette.toJson(),
    'elements': elementsToJson(elements),
    'syntax': syntax?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is DarkVariantSpec &&
      other.mode == mode &&
      other.palette == palette &&
      const MapEquality<ThemeElement, PropertyBag>().equals(
        other.elements,
        elements,
      ) &&
      other.syntax == syntax;

  @override
  int get hashCode => Object.hash(
    mode,
    palette,
    const MapEquality<ThemeElement, PropertyBag>().hash(elements),
    syntax,
  );
}

/// Encodes a sparse element map (empty specs omitted).
JsonMap elementsToJson(Map<ThemeElement, ElementStyleSpec> elements) => {
  for (final e in ThemeElement.values)
    if (elements[e]?.isNotEmpty ?? false) e.name: elements[e]!.toJson(),
};

/// A complete theme (06 §2.2): immutable, `==` by value, JSON round trip.
///
/// Parse untrusted JSON with `WriteThemeValidator` (collects errors and
/// warnings); [WriteThemeData.fromJson] throws a [ThemeFormatException] on
/// errors and silently applies the cleaning of the validator (unknown
/// properties dropped, unknown fonts replaced, weights snapped).
final class WriteThemeData {
  /// Creates a theme.
  WriteThemeData({
    this.schemaVersion = currentThemeSchemaVersion,
    required this.name,
    this.description,
    this.basedOn,
    this.fonts = const ThemeFonts(),
    required this.palette,
    DarkVariantSpec? dark,
    this.page = PropertyBag.empty,
    Map<ThemeElement, ElementStyleSpec> elements = const {},
    this.syntax = SyntaxPalette.empty,
    this.overlays = PropertyBag.empty,
  }) : dark = dark ?? DarkVariantSpec(),
       elements = Map.unmodifiable({
         for (final e in elements.entries)
           if (e.value.isNotEmpty) e.key: e.value,
       });

  /// Parses [json]; throws [ThemeFormatException] when it has errors.
  factory WriteThemeData.fromJson(Object? json) {
    final result = parseThemeJson(json);
    if (result.theme == null) {
      throw ThemeFormatException(result.errors);
    }
    return result.theme!;
  }

  /// Parses canonical/compact JSON text (see [fromJson]).
  factory WriteThemeData.fromJsonString(String source) =>
      WriteThemeData.fromJson(jsonDecode(source));

  /// Schema version (always [currentThemeSchemaVersion] after migration).
  final int schemaVersion;

  /// Display name (1–80 characters).
  final String name;

  /// Optional description.
  final String? description;

  /// Provenance (informational), e.g. `"builtin:classic-serif"`.
  final String? basedOn;

  /// Font roles.
  final ThemeFonts fonts;

  /// Light palette (complete).
  final ThemePalette palette;

  /// Dark variant spec.
  final DarkVariantSpec dark;

  /// Page section.
  final PageStyleSpec page;

  /// Element styles (sparse; empty specs are dropped).
  final Map<ThemeElement, ElementStyleSpec> elements;

  /// Light syntax palette.
  final SyntaxPalette syntax;

  /// Overlay overrides of app tokens.
  final OverlaySpec overlays;

  /// The style spec of [element] (empty when unset).
  ElementStyleSpec element(ThemeElement element) =>
      elements[element] ?? PropertyBag.empty;

  /// JSON form (keys in schema order; use [canonicalJson] for storage).
  JsonMap toJson() => {
    'schemaVersion': schemaVersion,
    'name': name,
    if (description != null) 'description': description,
    if (basedOn != null) 'basedOn': basedOn,
    'fonts': fonts.toJson(),
    'palette': palette.toJson(full: true),
    'dark': dark.toJson(),
    'page': page.toJson(),
    'elements': elementsToJson(elements),
    'syntax': syntax.toJson(),
    'overlays': overlays.toJson(),
  };

  /// Canonical JSON: sorted keys, no whitespace (06 §5.1). Identical on VM
  /// and web; parsing it back and re-encoding is byte-identical.
  late final String canonicalJson = canonicalJsonEncode(toJson());

  /// SHA-256 (lower-case hex) of [canonicalJson].
  late final String contentHash = sha256
      .convert(utf8.encode(canonicalJson))
      .toString();

  /// A copy with the given fields replaced.
  WriteThemeData copyWith({
    String? name,
    String? description,
    String? basedOn,
    ThemeFonts? fonts,
    ThemePalette? palette,
    DarkVariantSpec? dark,
    PageStyleSpec? page,
    Map<ThemeElement, ElementStyleSpec>? elements,
    SyntaxPalette? syntax,
    OverlaySpec? overlays,
  }) => WriteThemeData(
    schemaVersion: schemaVersion,
    name: name ?? this.name,
    description: description ?? this.description,
    basedOn: basedOn ?? this.basedOn,
    fonts: fonts ?? this.fonts,
    palette: palette ?? this.palette,
    dark: dark ?? this.dark,
    page: page ?? this.page,
    elements: elements ?? this.elements,
    syntax: syntax ?? this.syntax,
    overlays: overlays ?? this.overlays,
  );

  @override
  bool operator ==(Object other) =>
      other is WriteThemeData && other.canonicalJson == canonicalJson;

  @override
  int get hashCode => canonicalJson.hashCode;

  @override
  String toString() => 'WriteThemeData($name, $contentHash)';
}

/// Thrown by [WriteThemeData.fromJson] for invalid theme JSON.
final class ThemeFormatException implements Exception {
  /// Creates the exception with the blocking [errors].
  const ThemeFormatException(this.errors);

  /// The blocking issues.
  final List<ThemeIssue> errors;

  @override
  String toString() =>
      'ThemeFormatException: ${errors.map((e) => e.toString()).join('; ')}';
}
