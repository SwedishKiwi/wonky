/// Enumerations of resolved element styles (06 §2.4).
library;

import 'json_util.dart';

/// Heading numbering style (06 §2.4 `headings.numbering.style`).
enum HeadingNumberingStyle implements JsonEnum {
  /// `1.` — only the heading's own counter.
  decimal('decimal'),

  /// `1.1.1` — the full counter path, no trailing dot.
  outline('outline'),

  /// `1.1.1.` — the full counter path with a trailing dot.
  legal('legal'),

  /// `I.` / `A.` / `1.` per depth.
  upperRomanUpperAlphaDecimal('upperRoman-upperAlpha-decimal');

  const HeadingNumberingStyle(this.json);

  @override
  final String json;
}

/// Ordered list number style per indent level.
enum ListNumberStyle implements JsonEnum {
  /// 1, 2, 3.
  decimal,

  /// a, b, …, z, aa, ab.
  lowerAlpha,

  /// A, B, …, Z, AA, AB.
  upperAlpha,

  /// i, ii, iii.
  lowerRoman,

  /// I, II, III.
  upperRoman;

  @override
  String get json => name;
}

/// Link underline mode.
enum LinkUnderline implements JsonEnum {
  /// Always underlined.
  always,

  /// Underlined while hovered (static exports: not underlined).
  hover,

  /// Never underlined.
  none;

  @override
  String get json => name;
}

/// Horizontal rule style.
enum RuleStyle implements JsonEnum {
  /// Solid line.
  solid('solid'),

  /// Dashed line.
  dashed('dashed'),

  /// Dotted line.
  dotted('dotted'),

  /// Double line.
  doubleLine('double'),

  /// Centered ornament glyph(s) instead of a line.
  ornament('ornament');

  const RuleStyle(this.json);

  @override
  final String json;
}

/// Task checkbox shape.
enum CheckboxShape implements JsonEnum {
  /// Square corners.
  square,

  /// Rounded corners.
  rounded,

  /// Circle.
  circle;

  @override
  String get json => name;
}

/// Shadow strength (page shadow in the editor, image shadow).
enum ShadowLevel implements JsonEnum {
  /// No shadow.
  none,

  /// Soft shadow.
  soft,

  /// Strong shadow.
  strong;

  @override
  String get json => name;
}

/// Image alignment.
enum ImageAlign implements JsonEnum {
  /// Centered.
  center,

  /// Start-aligned.
  left;

  @override
  String get json => name;
}

/// Table width mode.
enum TableWidth implements JsonEnum {
  /// Width from content.
  auto,

  /// Full content width.
  full;

  @override
  String get json => name;
}

/// Which table borders are drawn.
enum TableBorders implements JsonEnum {
  /// All cell borders.
  all,

  /// Horizontal lines between rows (plus top and bottom).
  horizontal,

  /// Only the outer frame.
  outer,

  /// Only the line below the header row.
  headerOnly,

  /// No borders.
  none;

  @override
  String get json => name;
}
