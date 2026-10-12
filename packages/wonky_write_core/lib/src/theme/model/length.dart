/// The theme `Length` value type (06 §2.1).
library;

import 'json_util.dart';

/// Unit of a [Length].
enum LengthUnit implements JsonEnum {
  /// Typographic point (1/72 in).
  pt('pt'),

  /// CSS pixel (`1pt = 4/3 px`).
  px('px'),

  /// Relative to a font size (06 §2.1).
  em('em'),

  /// Millimetre.
  mm('mm'),

  /// Inch.
  inch('in'),

  /// Percentage of a reference width (widths only).
  percent('%');

  const LengthUnit(this.json);

  @override
  final String json;

  /// Whether lengths in this unit need a reference value to become absolute.
  bool get isRelative => this == em || this == percent;
}

/// Points per CSS pixel (`1px = 0.75pt`).
const double ptPerPx = 0.75;

/// Points per inch.
const double ptPerInch = 72;

/// Points per millimetre.
const double ptPerMm = 72 / 25.4;

/// A theme length such as `"11pt"`, `"1.5em"` or `"60%"` (06 §2.1).
///
/// Immutable; equal when value and unit are equal (`"12pt"` and `"16px"`
/// are different lengths even though they resolve to the same size).
final class Length {
  /// Creates a length of [value] in [unit].
  const Length(this.value, this.unit);

  /// A length in points.
  const Length.pt(this.value) : unit = LengthUnit.pt;

  /// A length in CSS pixels.
  const Length.px(this.value) : unit = LengthUnit.px;

  /// A length in em.
  const Length.em(this.value) : unit = LengthUnit.em;

  /// A length in inches.
  const Length.inch(this.value) : unit = LengthUnit.inch;

  /// A length in millimetres.
  const Length.mm(this.value) : unit = LengthUnit.mm;

  /// A percentage.
  const Length.percent(this.value) : unit = LengthUnit.percent;

  /// Zero points.
  static const zero = Length.pt(0);

  /// The numeric value.
  final double value;

  /// The unit of [value].
  final LengthUnit unit;

  static final _pattern = RegExp(
    r'^\s*(-?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)\s*(pt|px|em|mm|in|%)\s*$',
  );

  /// Parses `"<number><unit>"`, e.g. `"11pt"`, `"-0.01em"`, `"60%"`.
  ///
  /// Throws a [FormatException] for anything else.
  static Length parse(String text) {
    final l = tryParse(text);
    if (l == null) throw FormatException('Invalid length', text);
    return l;
  }

  /// Like [parse] but returns `null` for invalid input.
  static Length? tryParse(String text) {
    final m = _pattern.firstMatch(text);
    if (m == null) return null;
    final v = double.tryParse(m.group(1)!);
    if (v == null || !v.isFinite) return null;
    final unit = enumFromJson(LengthUnit.values, m.group(2));
    if (unit == null) return null;
    return Length(v, unit);
  }

  /// Whether the length needs a reference value ([LengthUnit.isRelative]).
  bool get isRelative => unit.isRelative;

  /// This length in points.
  ///
  /// [relativeTo] (in pt) is the reference for `em` (a font size) and `%`
  /// (a width); it is ignored for absolute units.
  double toPt([double relativeTo = 0]) => switch (unit) {
    LengthUnit.pt => value,
    LengthUnit.px => value * ptPerPx,
    LengthUnit.em => value * relativeTo,
    LengthUnit.mm => value * ptPerMm,
    LengthUnit.inch => value * ptPerInch,
    LengthUnit.percent => value / 100 * relativeTo,
  };

  /// The JSON form, e.g. `"11pt"` (integral values without fraction).
  String toJson() => '${formatThemeNumber(value)}${unit.json}';

  @override
  bool operator ==(Object other) =>
      other is Length && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);

  @override
  String toString() => toJson();
}
