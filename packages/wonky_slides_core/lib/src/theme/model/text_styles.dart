/// `DeckTheme.textStylesJson` (Slides 05 §2.5): the 10 theme text styles,
/// list markers, links and inline code chrome.
library;

import '../color/color_ref.dart';
import '../json/json_util.dart';
import 'common.dart';

/// The theme text style keys (paragraph `style` values, 02 §4.1), in
/// display order.
const List<String> themeTextStyleKeys = [
  'title',
  'subtitle',
  'heading',
  'body',
  'body2',
  'caption',
  'quote',
  'attribution',
  'bigNumber',
  'label',
];

/// Bullet glyph keys (02 §4.1 `listStyle`), besides `emoji:<char>`.
const Set<String> bulletGlyphKeys = {
  'disc',
  'circle',
  'square',
  'dash',
  'arrow',
  'check',
  'star',
  'none',
};

/// Numbering keys (02 §4.1 `listStyle`).
const Set<String> numberingKeys = {
  'decimal',
  'lowerAlpha',
  'upperAlpha',
  'lowerRoman',
  'upperRoman',
};

/// Caps transforms.
const Set<String> capsValues = {'all', 'small', 'title'};

/// Paragraph alignments.
const Set<String> alignValues = {'left', 'center', 'right', 'justify'};

/// Font size bounds in su (02 §13).
const double minFontSize = 6;

/// Font size bounds in su (02 §13).
const double maxFontSize = 800;

/// One theme text style. Null properties fall back (05 §4.2 cascade) to
/// the theme's `body` style, then built-in defaults.
final class ThemeTextStyle {
  /// Creates a style.
  const ThemeTextStyle({
    this.font,
    this.size,
    this.weight,
    this.italic,
    this.lineHeight,
    this.letterSpacing,
    this.color,
    this.caps,
    this.align,
    this.spaceBefore,
    this.spaceAfter,
  });

  /// `@heading`, `@body`, `@mono` or a family.
  final FontRef? font;

  /// Size in su (6–800).
  final double? size;

  /// Weight 100–900 (snapped to the family's shipped weights).
  final int? weight;

  /// Italic.
  final bool? italic;

  /// Line height multiplier (0.7–3).
  final double? lineHeight;

  /// Letter spacing in em (−0.2…1).
  final double? letterSpacing;

  /// Text color.
  final ColorRef? color;

  /// `all`, `small` or `title`.
  final String? caps;

  /// `left`, `center`, `right`, `justify`.
  final String? align;

  /// Space before paragraphs (su, 0–400).
  final double? spaceBefore;

  /// Space after paragraphs (su, 0–400).
  final double? spaceAfter;

  /// A copy with sizes and spacing multiplied by [s] (page setup scaling,
  /// 05 §7). Font sizes stay within 6–800 su.
  ThemeTextStyle scaled(double s) => ThemeTextStyle(
    font: font,
    size: size == null ? null : (size! * s).clamp(minFontSize, maxFontSize),
    weight: weight,
    italic: italic,
    lineHeight: lineHeight,
    letterSpacing: letterSpacing,
    color: color,
    caps: caps,
    align: align,
    spaceBefore: spaceBefore == null ? null : spaceBefore! * s,
    spaceAfter: spaceAfter == null ? null : spaceAfter! * s,
  );

  /// A copy with the given properties replaced.
  ThemeTextStyle copyWith({
    FontRef? font,
    double? size,
    int? weight,
    bool? italic,
    double? lineHeight,
    double? letterSpacing,
    ColorRef? color,
    String? caps,
    String? align,
    double? spaceBefore,
    double? spaceAfter,
  }) => ThemeTextStyle(
    font: font ?? this.font,
    size: size ?? this.size,
    weight: weight ?? this.weight,
    italic: italic ?? this.italic,
    lineHeight: lineHeight ?? this.lineHeight,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    color: color ?? this.color,
    caps: caps ?? this.caps,
    align: align ?? this.align,
    spaceBefore: spaceBefore ?? this.spaceBefore,
    spaceAfter: spaceAfter ?? this.spaceAfter,
  );

  /// JSON form (null properties omitted).
  JsonMap toJson() {
    final out = <String, Object?>{};
    putIfNotNull(out, 'font', font?.value);
    putIfNotNull(out, 'size', size);
    putIfNotNull(out, 'weight', weight);
    putIfNotNull(out, 'italic', italic);
    putIfNotNull(out, 'lineHeight', lineHeight);
    putIfNotNull(out, 'letterSpacing', letterSpacing);
    putIfNotNull(out, 'color', color?.json);
    putIfNotNull(out, 'caps', caps);
    putIfNotNull(out, 'align', align);
    putIfNotNull(out, 'spaceBefore', spaceBefore);
    putIfNotNull(out, 'spaceAfter', spaceAfter);
    return out;
  }

  /// Parses one style object.
  static ThemeTextStyle? fromJson(Object? json, String path, IssueSink sink) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {
        'font',
        'size',
        'weight',
        'italic',
        'lineHeight',
        'letterSpacing',
        'color',
        'caps',
        'align',
        'spaceBefore',
        'spaceAfter',
      },
    );
    if (r == null) return null;
    return ThemeTextStyle(
      font: readFontRef(r, 'font'),
      size: r.number('size', min: minFontSize, max: maxFontSize),
      weight: r.integer('weight', min: 100, max: 900),
      italic: r.boolean('italic'),
      lineHeight: r.number('lineHeight', min: 0.7, max: 3),
      letterSpacing: r.number('letterSpacing', min: -0.2, max: 1),
      color: readColor(r, 'color'),
      caps: r.string('caps', allowed: capsValues),
      align: r.string('align', allowed: alignValues),
      spaceBefore: r.number('spaceBefore', min: 0, max: 400),
      spaceAfter: r.number('spaceAfter', min: 0, max: 400),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeTextStyle && jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => canonicalJson(toJson()).hashCode;
}

/// List markers per indent level (05 §2.5 `lists`).
final class ThemeListStyles {
  /// Creates list styles.
  const ThemeListStyles({
    required this.bullets,
    required this.numbering,
    required this.bulletColor,
    required this.indentPerLevel,
    required this.markerGap,
    required this.levelSizeScale,
  });

  /// Defaults of 05 §2.5.
  static const ThemeListStyles defaults = ThemeListStyles(
    bullets: [
      'disc',
      'dash',
      'circle',
      'dash',
      'circle',
      'dash',
      'circle',
      'dash',
      'circle',
    ],
    numbering: [
      'decimal',
      'lowerAlpha',
      'lowerRoman',
      'decimal',
      'lowerAlpha',
      'lowerRoman',
      'decimal',
      'lowerAlpha',
      'lowerRoman',
    ],
    bulletColor: ThemeColor('accent1'),
    indentPerLevel: 56,
    markerGap: 20,
    levelSizeScale: 0.9,
  );

  /// Bullet glyph per level 0–8.
  final List<String> bullets;

  /// Numbering per level 0–8.
  final List<String> numbering;

  /// Marker color.
  final ColorRef bulletColor;

  /// Indent per level (su).
  final double indentPerLevel;

  /// Gap between marker and text (su).
  final double markerGap;

  /// Each level's size relative to the previous one (0.5–1).
  final double levelSizeScale;

  /// A copy with lengths multiplied by [s].
  ThemeListStyles scaled(double s) => ThemeListStyles(
    bullets: bullets,
    numbering: numbering,
    bulletColor: bulletColor,
    indentPerLevel: indentPerLevel * s,
    markerGap: markerGap * s,
    levelSizeScale: levelSizeScale,
  );

  /// JSON form.
  JsonMap toJson() => {
    'bullets': bullets,
    'numbering': numbering,
    'bulletColor': bulletColor.json,
    'indentPerLevel': normalizeJsonNumber(indentPerLevel),
    'markerGap': normalizeJsonNumber(markerGap),
    'levelSizeScale': normalizeJsonNumber(levelSizeScale),
  };

  static ThemeListStyles? _fromJson(Object? json, String path, IssueSink sink) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {
        'bullets',
        'numbering',
        'bulletColor',
        'indentPerLevel',
        'markerGap',
        'levelSizeScale',
      },
    );
    if (r == null) return null;
    List<String> levels(
      String key,
      bool Function(String) valid,
      List<String> fallback,
    ) {
      final list = r.list(key);
      if (list == null) return fallback;
      if (list.length != 9) {
        sink.error(r.at(key), 'wrong_length', 'Expected 9 levels (0–8).');
        return fallback;
      }
      final out = <String>[];
      for (var i = 0; i < 9; i++) {
        final v = list[i];
        if (v is! String || !valid(v)) {
          sink.error(
            '${r.at(key)}[$i]',
            'out_of_range',
            'Unknown marker "$v".',
          );
          return fallback;
        }
        out.add(v);
      }
      return List.unmodifiable(out);
    }

    final d = defaults;
    return ThemeListStyles(
      bullets: levels(
        'bullets',
        (v) =>
            bulletGlyphKeys.contains(v) ||
            (v.startsWith('emoji:') && v.length > 6),
        d.bullets,
      ),
      numbering: levels('numbering', numberingKeys.contains, d.numbering),
      bulletColor: readColor(r, 'bulletColor') ?? d.bulletColor,
      indentPerLevel:
          r.number('indentPerLevel', min: 0, max: 400) ?? d.indentPerLevel,
      markerGap: r.number('markerGap', min: 0, max: 200) ?? d.markerGap,
      levelSizeScale:
          r.number('levelSizeScale', min: 0.5, max: 1) ?? d.levelSizeScale,
    );
  }
}

/// Link styling (05 §2.5 `links`).
final class ThemeLinkStyle {
  /// Creates link styling.
  const ThemeLinkStyle({required this.color, required this.underline});

  /// Defaults.
  static const ThemeLinkStyle defaults = ThemeLinkStyle(
    color: ThemeColor('link'),
    underline: true,
  );

  /// Link color.
  final ColorRef color;

  /// Whether links are underlined.
  final bool underline;

  /// JSON form.
  JsonMap toJson() => {'color': color.json, 'underline': underline};
}

/// Inline code chrome (05 §2.5 `inlineCode`).
final class ThemeInlineCodeStyle {
  /// Creates inline code chrome.
  const ThemeInlineCodeStyle({
    required this.background,
    required this.radius,
    required this.paddingX,
  });

  /// Defaults.
  static const ThemeInlineCodeStyle defaults = ThemeInlineCodeStyle(
    background: ThemeColor('bg2'),
    radius: 6,
    paddingX: 8,
  );

  /// Background color.
  final ColorRef background;

  /// Corner radius (su).
  final double radius;

  /// Horizontal padding (su).
  final double paddingX;

  /// JSON form.
  JsonMap toJson() => {
    'background': background.json,
    'radius': normalizeJsonNumber(radius),
    'paddingX': normalizeJsonNumber(paddingX),
  };
}

/// The `textStylesJson` column.
final class ThemeTextStyles {
  /// Creates text styles; [styles] should hold every key of
  /// [themeTextStyleKeys].
  ThemeTextStyles({
    required Map<String, ThemeTextStyle> styles,
    this.lists = ThemeListStyles.defaults,
    this.links = ThemeLinkStyle.defaults,
    this.inlineCode = ThemeInlineCodeStyle.defaults,
  }) : styles = Map.unmodifiable(styles);

  /// Styles by key.
  final Map<String, ThemeTextStyle> styles;

  /// List markers.
  final ThemeListStyles lists;

  /// Links.
  final ThemeLinkStyle links;

  /// Inline code.
  final ThemeInlineCodeStyle inlineCode;

  /// The style [key] (falls back to `body`).
  ThemeTextStyle operator [](String key) =>
      styles[key] ?? styles['body'] ?? const ThemeTextStyle();

  /// A copy with sizes and lengths multiplied by [s] (05 §7).
  ThemeTextStyles scaled(double s) => ThemeTextStyles(
    styles: {for (final e in styles.entries) e.key: e.value.scaled(s)},
    lists: lists.scaled(s),
    links: links,
    inlineCode: ThemeInlineCodeStyle(
      background: inlineCode.background,
      radius: inlineCode.radius * s,
      paddingX: inlineCode.paddingX * s,
    ),
  );

  /// A copy with [key] replaced.
  ThemeTextStyles withStyle(String key, ThemeTextStyle style) =>
      ThemeTextStyles(
        styles: {...styles, key: style},
        lists: lists,
        links: links,
        inlineCode: inlineCode,
      );

  /// The JSON column value.
  JsonMap toJson() => {
    'v': 1,
    'styles': {
      for (final k in themeTextStyleKeys)
        if (styles[k] != null) k: styles[k]!.toJson(),
    },
    'lists': lists.toJson(),
    'links': links.toJson(),
    'inlineCode': inlineCode.toJson(),
  };

  /// Parses the column. Missing styles are filled from [fallbackStyles]
  /// (warning `missing`); errors → `null`.
  static ThemeTextStyles? fromJson(
    Object? json,
    IssueSink sink, {
    String path = 'textStylesJson',
    Map<String, ThemeTextStyle> fallbackStyles = const {},
  }) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {'v', 'styles', 'lists', 'links', 'inlineCode'},
    );
    if (r == null) return null;
    r.version(required: true);
    final before = sink.errors.length;
    final s = r.child(
      'styles',
      known: themeTextStyleKeys.toSet(),
      required: true,
    );
    final styles = <String, ThemeTextStyle>{};
    if (s != null) {
      for (final k in themeTextStyleKeys) {
        if (!s.has(k)) {
          final fb = fallbackStyles[k];
          sink.warn(
            s.at(k),
            'missing',
            fb == null
                ? 'Style "$k" is missing; the body style is used.'
                : 'Style "$k" is missing; the default was added.',
          );
          if (fb != null) styles[k] = fb;
          continue;
        }
        final style = ThemeTextStyle.fromJson(s.map[k], s.at(k), sink);
        if (style != null) styles[k] = style;
      }
    }
    final lists = r.has('lists')
        ? ThemeListStyles._fromJson(r.map['lists'], r.at('lists'), sink)
        : null;
    final l = r.child('links', known: {'color', 'underline'});
    final links = l == null
        ? ThemeLinkStyle.defaults
        : ThemeLinkStyle(
            color: readColor(l, 'color') ?? ThemeLinkStyle.defaults.color,
            underline: l.boolean('underline') ?? true,
          );
    final c = r.child(
      'inlineCode',
      known: {'background', 'radius', 'paddingX'},
    );
    final inline = c == null
        ? ThemeInlineCodeStyle.defaults
        : ThemeInlineCodeStyle(
            background:
                readColor(c, 'background') ??
                ThemeInlineCodeStyle.defaults.background,
            radius: c.number('radius', min: 0, max: 200) ?? 6,
            paddingX: c.number('paddingX', min: 0, max: 200) ?? 8,
          );
    if (sink.errors.length > before) return null;
    return ThemeTextStyles(
      styles: styles,
      lists: lists ?? ThemeListStyles.defaults,
      links: links,
      inlineCode: inline,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeTextStyles && jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => canonicalJson(toJson()).hashCode;
}

/// The default text styles of 05 §2.5 (used to fill missing styles and by
/// the built-in themes as their base).
final Map<String, ThemeTextStyle> defaultThemeTextStyles = Map.unmodifiable({
  'title': const ThemeTextStyle(
    font: FontRef('@heading'),
    size: 96,
    weight: 700,
    lineHeight: 1.05,
    letterSpacing: -0.02,
    color: ThemeColor('text1'),
  ),
  'subtitle': const ThemeTextStyle(
    font: FontRef('@body'),
    size: 44,
    weight: 400,
    lineHeight: 1.25,
    color: ThemeColor('text2'),
  ),
  'heading': const ThemeTextStyle(
    font: FontRef('@heading'),
    size: 64,
    weight: 700,
    lineHeight: 1.1,
    color: ThemeColor('text1'),
  ),
  'body': const ThemeTextStyle(
    font: FontRef('@body'),
    size: 40,
    weight: 400,
    lineHeight: 1.35,
    color: ThemeColor('text1'),
    spaceAfter: 16,
  ),
  'body2': const ThemeTextStyle(
    font: FontRef('@body'),
    size: 32,
    weight: 400,
    lineHeight: 1.4,
    color: ThemeColor('text2'),
  ),
  'caption': const ThemeTextStyle(
    font: FontRef('@body'),
    size: 24,
    weight: 400,
    lineHeight: 1.3,
    color: ThemeColor('text2'),
  ),
  'quote': const ThemeTextStyle(
    font: FontRef('@heading'),
    size: 72,
    weight: 500,
    lineHeight: 1.15,
    italic: false,
    color: ThemeColor('text1'),
  ),
  'attribution': const ThemeTextStyle(
    font: FontRef('@body'),
    size: 28,
    weight: 600,
    caps: 'all',
    letterSpacing: 0.08,
    color: ThemeColor('text2'),
  ),
  'bigNumber': const ThemeTextStyle(
    font: FontRef('@heading'),
    size: 280,
    weight: 800,
    lineHeight: 1.0,
    color: ThemeColor('accent1'),
  ),
  'label': const ThemeTextStyle(
    font: FontRef('@body'),
    size: 20,
    weight: 600,
    caps: 'all',
    letterSpacing: 0.1,
    color: ThemeColor('text2'),
  ),
});
