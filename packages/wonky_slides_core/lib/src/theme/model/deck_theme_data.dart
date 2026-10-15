/// The content of one `DeckTheme` row (Slides 02 §3.2, 05 §2) as typed
/// values, with the column codec.
library;

import 'dart:convert';

import '../json/json_util.dart';
import 'background.dart';
import 'object_styles.dart';
import 'text_styles.dart';
import 'theme_colors.dart';
import 'theme_fonts.dart';

/// The JSON columns of `DeckTheme` (names as in 02 §3.2).
enum DeckThemeColumn {
  /// 05 §2.2.
  colorsJson(required: true),

  /// 05 §2.3.
  fontsJson(required: true),

  /// 05 §2.5.
  textStylesJson(required: true),

  /// 05 §2.6.
  backgroundJson(required: true),

  /// 05 §2.7.
  shapeStyleJson(required: false),

  /// 05 §2.8.
  tableStyleJson(required: false),

  /// 05 §2.9.
  codeStyleJson(required: false),

  /// 05 §2.10.
  chartStyleJson(required: false);

  const DeckThemeColumn({required this.required});

  /// Whether the column is non-nullable.
  final bool required;

  /// The column for [name], or `null`.
  static DeckThemeColumn? fromName(String name) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return null;
  }
}

/// A theme's content: what a `DeckTheme` row stores besides `id`, `deck`
/// and `sortKey`.
final class DeckThemeData {
  /// Creates theme data.
  const DeckThemeData({
    required this.name,
    this.sourceKey,
    required this.colors,
    required this.fonts,
    required this.textStyles,
    this.background = SlideBackground.themeDefault,
    this.shapeStyles,
    this.tableStyle,
    this.codeStyle,
    this.chartStyle,
  });

  /// Display name.
  final String name;

  /// Provenance: `builtin:<key>@<v>`, `deck:<itemUuid>:<themeId>` or `null`.
  final String? sourceKey;

  /// `colorsJson`.
  final ThemeColors colors;

  /// `fontsJson`.
  final ThemeFonts fonts;

  /// `textStylesJson`.
  final ThemeTextStyles textStyles;

  /// `backgroundJson`.
  final SlideBackground background;

  /// `shapeStyleJson` (null → built-in defaults).
  final ThemeShapeStyles? shapeStyles;

  /// `tableStyleJson` (null → built-in defaults).
  final ThemeTableStyle? tableStyle;

  /// `codeStyleJson` (null → the Wonky palette pair).
  final ThemeCodeStyle? codeStyle;

  /// `chartStyleJson` (null → accent palette).
  final ThemeChartStyle? chartStyle;

  /// The decoded JSON value of [column] (`null` for an absent optional
  /// column).
  JsonMap? columnJson(DeckThemeColumn column) => switch (column) {
    DeckThemeColumn.colorsJson => colors.toJson(),
    DeckThemeColumn.fontsJson => fonts.toJson(),
    DeckThemeColumn.textStylesJson => textStyles.toJson(),
    DeckThemeColumn.backgroundJson => background.toJson(),
    DeckThemeColumn.shapeStyleJson => shapeStyles?.toJson(),
    DeckThemeColumn.tableStyleJson => tableStyle?.toJson(),
    DeckThemeColumn.codeStyleJson => codeStyle?.toJson(),
    DeckThemeColumn.chartStyleJson => chartStyle?.toJson(),
  };

  /// The row's column values: `name`, `sourceKey` and every JSON column as
  /// a JSON string (`null` for absent optional columns).
  Map<String, String?> toColumns() => {
    'name': name,
    'sourceKey': sourceKey,
    for (final c in DeckThemeColumn.values)
      c.name: switch (columnJson(c)) {
        final JsonMap json => jsonEncode(json),
        null => null,
      },
  };

  /// All columns as one JSON object (`{name, sourceKey, colorsJson: {…}, …}`):
  /// the theme part of a theme package (05 §6) and MCP payloads.
  JsonMap toJson() => {
    'name': name,
    if (sourceKey != null) 'sourceKey': sourceKey,
    for (final c in DeckThemeColumn.values)
      if (columnJson(c) != null) c.name: columnJson(c),
  };

  /// A stable hash of the visual content (all JSON columns, not the name):
  /// the cache key of resolved themes and theme previews (05 §1 P3).
  String get contentHash => stableHash(
    canonicalJson({
      for (final c in DeckThemeColumn.values) c.name: columnJson(c),
    }),
  );

  /// A copy with the given parts replaced.
  DeckThemeData copyWith({
    String? name,
    String? sourceKey,
    ThemeColors? colors,
    ThemeFonts? fonts,
    ThemeTextStyles? textStyles,
    SlideBackground? background,
    ThemeShapeStyles? shapeStyles,
    ThemeTableStyle? tableStyle,
    ThemeCodeStyle? codeStyle,
    ThemeChartStyle? chartStyle,
  }) => DeckThemeData(
    name: name ?? this.name,
    sourceKey: sourceKey ?? this.sourceKey,
    colors: colors ?? this.colors,
    fonts: fonts ?? this.fonts,
    textStyles: textStyles ?? this.textStyles,
    background: background ?? this.background,
    shapeStyles: shapeStyles ?? this.shapeStyles,
    tableStyle: tableStyle ?? this.tableStyle,
    codeStyle: codeStyle ?? this.codeStyle,
    chartStyle: chartStyle ?? this.chartStyle,
  );

  @override
  bool operator ==(Object other) =>
      other is DeckThemeData && jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => canonicalJson(toJson()).hashCode;
}
