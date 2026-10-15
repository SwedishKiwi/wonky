/// Small value types shared by the theme model: appearance, font refs,
/// rectangles in slide units and JSON readers for them (Slides 02 §2.2).
library;

import '../color/color_ref.dart';
import '../json/json_util.dart';

/// Which color scheme of the deck's themes is used (`Deck.appearance`,
/// 05 §2.4). Values match the synced `DeckAppearance` enum by name.
enum SlideAppearance {
  /// The `light` scheme.
  light,

  /// The `dark` scheme.
  dark;

  /// Parses a name; `null` when unknown.
  static SlideAppearance? fromName(Object? name) {
    for (final a in values) {
      if (a.name == name) return a;
    }
    return null;
  }
}

/// A theme font role (`@heading`, `@body`, `@mono`).
enum ThemeFontRole {
  /// Titles and headings.
  heading,

  /// Body text.
  body,

  /// Code.
  mono;

  /// The reference spelling (`@heading`).
  String get ref => '@$name';
}

/// A font reference: a theme role (`@heading`/`@body`/`@mono`) or a family
/// name from the bundled registry (02 §2.2).
final class FontRef {
  /// Creates a reference from its JSON spelling.
  const FontRef(this.value);

  /// A reference to [role].
  FontRef.role(ThemeFontRole role) : value = role.ref;

  /// `@heading`, `@body`, `@mono` or a family name.
  final String value;

  /// The role when this is a role reference, else `null`.
  ThemeFontRole? get role => switch (value) {
    '@heading' => ThemeFontRole.heading,
    '@body' => ThemeFontRole.body,
    '@mono' => ThemeFontRole.mono,
    _ => null,
  };

  /// The family name when this is not a role reference.
  String? get family => role == null ? value : null;

  @override
  bool operator ==(Object other) => other is FontRef && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// An axis-aligned rectangle in slide units (su).
final class SuRect {
  /// Creates a rectangle.
  const SuRect(this.x, this.y, this.width, this.height);

  /// Left.
  final double x;

  /// Top.
  final double y;

  /// Width (> 0).
  final double width;

  /// Height (> 0).
  final double height;

  /// Right edge.
  double get right => x + width;

  /// Bottom edge.
  double get bottom => y + height;

  /// A rectangle moved by ([dx], [dy]).
  SuRect translate(double dx, double dy) =>
      SuRect(x + dx, y + dy, width, height);

  /// A rectangle inset by [d] on every side.
  SuRect deflate(double d) =>
      SuRect(x + d, y + d, width - 2 * d, height - 2 * d);

  /// Whether [other] lies inside this rectangle (within [tolerance]).
  bool containsRect(SuRect other, {double tolerance = 1e-6}) =>
      other.x >= x - tolerance &&
      other.y >= y - tolerance &&
      other.right <= right + tolerance &&
      other.bottom <= bottom + tolerance;

  /// `[x, y, width, height]` (numbers normalized).
  List<num> toList() => [
    normalizeJsonNumber(x),
    normalizeJsonNumber(y),
    normalizeJsonNumber(width),
    normalizeJsonNumber(height),
  ];

  @override
  bool operator ==(Object other) =>
      other is SuRect &&
      (other.x - x).abs() < 1e-9 &&
      (other.y - y).abs() < 1e-9 &&
      (other.width - width).abs() < 1e-9 &&
      (other.height - height).abs() < 1e-9;

  @override
  int get hashCode => Object.hash(
    (x * 1000).round(),
    (y * 1000).round(),
    (width * 1000).round(),
    (height * 1000).round(),
  );

  @override
  String toString() => 'SuRect($x, $y, $width × $height)';
}

/// Reads a [ColorRef] field. Reports `wrong_type` / `invalid_color` errors.
ColorRef? readColor(
  JsonReader r,
  String key, {
  bool required = false,
  bool allowThemeRefs = true,
}) {
  final raw = r.map[key];
  if (raw == null) {
    if (required) r.sink.error(r.at(key), 'missing', 'A color is required.');
    return null;
  }
  return parseColorValue(
    raw,
    r.at(key),
    r.sink,
    allowThemeRefs: allowThemeRefs,
  );
}

/// Parses one color value found at [path].
ColorRef? parseColorValue(
  Object? raw,
  String path,
  IssueSink sink, {
  bool allowThemeRefs = true,
}) {
  if (raw is! String) {
    sink.error(path, 'wrong_type', 'Expected a color string.');
    return null;
  }
  final c = ColorRef.tryParse(raw);
  if (c == null) {
    sink.error(path, 'invalid_color', '"$raw" is not a valid color.');
    return null;
  }
  if (!allowThemeRefs && c is! HexColor) {
    sink.error(path, 'invalid_color', 'Expected a hex color (#RRGGBB[AA]).');
    return null;
  }
  return c;
}

/// Reads a [FontRef] field (a role reference or a non-empty family name).
FontRef? readFontRef(JsonReader r, String key, {bool required = false}) {
  final s = r.string(key, required: required);
  if (s == null) return null;
  final t = s.trim();
  if (t.isEmpty ||
      t.length > 100 ||
      (t.startsWith('@') && FontRef(t).role == null)) {
    r.sink.error(r.at(key), 'invalid_font', '"$s" is not a font reference.');
    return null;
  }
  return FontRef(t);
}
