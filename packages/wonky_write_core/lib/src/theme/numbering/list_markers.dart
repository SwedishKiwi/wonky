/// Shared marker text generation for lists and heading numbers (06 §2.4).
library;

import '../model/style_enums.dart';

/// Ordinal text for list numbers and roman/alpha heading labels.
abstract final class ListMarkers {
  /// Default bullet glyphs per indent level (06 §2.4).
  static const defaultBullets = ['•', '◦', '▪', '•', '◦', '▪', '•', '◦', '▪'];

  /// Default numbering cycle per indent level (06 §2.4).
  static const defaultNumbering = [
    ListNumberStyle.decimal,
    ListNumberStyle.lowerAlpha,
    ListNumberStyle.lowerRoman,
    ListNumberStyle.decimal,
    ListNumberStyle.lowerAlpha,
    ListNumberStyle.lowerRoman,
    ListNumberStyle.decimal,
    ListNumberStyle.lowerAlpha,
    ListNumberStyle.lowerRoman,
  ];

  /// The text of ordinal [n] in [style], without suffix: `4` → `"4"`,
  /// `"d"`, `"D"`, `"iv"`, `"IV"`.
  ///
  /// Alpha styles are bijective base 26 (`z` = 26, `aa` = 27). Roman styles
  /// cover 1–3999 and fall back to decimal outside that range; alpha styles
  /// and roman styles fall back to decimal for `n < 1`.
  static String ordinal(int n, ListNumberStyle style) => switch (style) {
    ListNumberStyle.decimal => '$n',
    ListNumberStyle.lowerAlpha => alpha(n),
    ListNumberStyle.upperAlpha => alpha(n).toUpperCase(),
    ListNumberStyle.lowerRoman => roman(n),
    ListNumberStyle.upperRoman => roman(n).toUpperCase(),
  };

  /// Lower-case bijective base-26 letters: 1 → `a`, 26 → `z`, 27 → `aa`,
  /// 702 → `zz`, 703 → `aaa`. Returns decimal text for `n < 1`.
  static String alpha(int n) {
    if (n < 1) return '$n';
    final codes = <int>[];
    var v = n;
    while (v > 0) {
      v--;
      codes.add(0x61 + v % 26);
      v ~/= 26;
    }
    return String.fromCharCodes(codes.reversed);
  }

  static const _romanValues = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
  static const _romanSymbols = [
    'm',
    'cm',
    'd',
    'cd',
    'c',
    'xc',
    'l',
    'xl',
    'x',
    'ix',
    'v',
    'iv',
    'i',
  ];

  /// Lower-case roman numerals for 1–3999 (`i`, `iv`, `mmm`); decimal text
  /// outside that range.
  static String roman(int n) {
    if (n < 1 || n > 3999) return '$n';
    final b = StringBuffer();
    var v = n;
    for (var i = 0; i < _romanValues.length; i++) {
      while (v >= _romanValues[i]) {
        b.write(_romanSymbols[i]);
        v -= _romanValues[i];
      }
    }
    return b.toString();
  }

  /// Full marker text: [ordinal] + [suffix] (`"."` or `")"`).
  static String marker(int n, ListNumberStyle style, {String suffix = '.'}) =>
      ordinal(n, style) + suffix;
}
