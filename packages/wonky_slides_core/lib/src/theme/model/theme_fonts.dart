/// `DeckTheme.fontsJson` (Slides 05 §2.3): heading, body and mono families.
library;

import '../fonts/slides_fonts.dart';
import '../json/json_util.dart';
import 'common.dart';

/// One theme font role: a bundled family and its default weight.
final class ThemeFont {
  /// Creates a theme font.
  const ThemeFont(this.family, this.weight);

  /// Family name (bundled registry, 05 §3).
  final String family;

  /// Default weight 100–900 for runs using the role.
  final int weight;

  /// JSON form.
  JsonMap toJson() => {'family': family, 'weight': weight};

  static ThemeFont? _fromJson(
    Object? json,
    String path,
    IssueSink sink,
    ThemeFontRole role,
  ) {
    final r = JsonReader.object(json, path, sink, known: {'family', 'weight'});
    if (r == null) return null;
    final family = r.string('family', required: true)?.trim();
    final weight = r.integer('weight', min: 100, max: 900) ?? 400;
    if (family == null || family.isEmpty) {
      if (family != null) {
        sink.error(r.at('family'), 'missing', 'Empty family.');
      }
      return null;
    }
    final canonical = SlidesFonts.canonicalName(family);
    if (canonical == null) {
      final category =
          SlidesFonts.categoryOf(family) ?? SlidesFonts.categoryOfRole(role);
      sink.warn(
        r.at('family'),
        'unknown_font',
        '"$family" is not a bundled font; '
            '${SlidesFonts.fallbackFamilies[category]} is used instead.',
      );
    }
    return ThemeFont(canonical ?? family, weight);
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeFont && other.family == family && other.weight == weight;

  @override
  int get hashCode => Object.hash(family, weight);

  @override
  String toString() => '$family $weight';
}

/// The `fontsJson` column.
final class ThemeFonts {
  /// Creates the fonts.
  const ThemeFonts({
    required this.heading,
    required this.body,
    required this.mono,
  });

  /// `@heading`.
  final ThemeFont heading;

  /// `@body`.
  final ThemeFont body;

  /// `@mono`.
  final ThemeFont mono;

  /// The font of [role].
  ThemeFont of(ThemeFontRole role) => switch (role) {
    ThemeFontRole.heading => heading,
    ThemeFontRole.body => body,
    ThemeFontRole.mono => mono,
  };

  /// A copy with [role] replaced.
  ThemeFonts withRole(ThemeFontRole role, ThemeFont font) => ThemeFonts(
    heading: role == ThemeFontRole.heading ? font : heading,
    body: role == ThemeFontRole.body ? font : body,
    mono: role == ThemeFontRole.mono ? font : mono,
  );

  /// The JSON column value.
  JsonMap toJson() => {
    'v': 1,
    'heading': heading.toJson(),
    'body': body.toJson(),
    'mono': mono.toJson(),
  };

  /// Parses the column (errors → `null`).
  static ThemeFonts? fromJson(
    Object? json,
    IssueSink sink, {
    String path = 'fontsJson',
  }) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {'v', 'heading', 'body', 'mono'},
    );
    if (r == null) return null;
    r.version(required: true);
    final h = ThemeFont._fromJson(
      r.map['heading'],
      r.at('heading'),
      sink,
      ThemeFontRole.heading,
    );
    final b = ThemeFont._fromJson(
      r.map['body'],
      r.at('body'),
      sink,
      ThemeFontRole.body,
    );
    final m = ThemeFont._fromJson(
      r.map['mono'],
      r.at('mono'),
      sink,
      ThemeFontRole.mono,
    );
    if (h == null || b == null || m == null) return null;
    return ThemeFonts(heading: h, body: b, mono: m);
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeFonts &&
      other.heading == heading &&
      other.body == body &&
      other.mono == mono;

  @override
  int get hashCode => Object.hash(heading, body, mono);
}
