/// AST of the number-format language (06 §5.2–5.7), produced by
/// `NumberFormatParser`. Tokens carry their source span so tools (decimals
/// adjuster, custom-format dialog) can edit patterns in place.
library;

/// A parsed number format: 1–4 sections.
final class NumberFormatAst {
  /// Creates an AST.
  const NumberFormatAst(this.source, this.sections);

  /// The pattern text.
  final String source;

  /// Sections in pattern order.
  final List<NfSection> sections;

  /// Whether any of the first two sections carries a condition (`[>1000]`).
  bool get hasConditions => sections.take(2).any((s) => s.condition != null);

  /// The section applied to text values: the 4th section, or a trailing
  /// section that only contains `@`/literals. Null when text shows as is.
  NfSection? get textSection {
    if (sections.length >= 4) return sections[3];
    final last = sections.last;
    if (last.kind == NfSectionKind.text) return last;
    return null;
  }

  /// Sections that apply to numbers (the text section excluded).
  List<NfSection> get numberSections {
    if (sections.length >= 4) return sections.sublist(0, 3);
    if (sections.last.kind == NfSectionKind.text) {
      return sections.sublist(0, sections.length - 1);
    }
    return sections;
  }

  @override
  String toString() => 'NumberFormatAst($source)';
}

/// Kind of a section, derived from its tokens.
enum NfSectionKind {
  /// No tokens: hides values of that kind.
  empty,

  /// Contains the `General` keyword: Automatic display.
  general,

  /// Digit placeholders without exponent or fraction.
  number,

  /// Scientific (`0.00E+00`).
  scientific,

  /// Fraction (`# ?/?`).
  fraction,

  /// Date/time/duration tokens.
  dateTime,

  /// `@` (text placeholder) and literals only.
  text,

  /// Literals only (`"-"`): shows the literal for numbers and hides text.
  literal,
}

/// Comparison operator of a section condition.
enum NfConditionOp {
  /// `<`
  lt('<'),

  /// `<=`
  le('<='),

  /// `>`
  gt('>'),

  /// `>=`
  ge('>='),

  /// `=`
  eq('='),

  /// `<>`
  ne('<>');

  const NfConditionOp(this.symbol);

  /// The operator as written.
  final String symbol;
}

/// A section condition (`[>1000]`).
final class NfCondition {
  /// Creates a condition.
  const NfCondition(this.op, this.value);

  /// Operator.
  final NfConditionOp op;

  /// Right-hand value.
  final double value;

  /// Whether [x] satisfies the condition.
  bool matches(double x) => switch (op) {
    NfConditionOp.lt => x < value,
    NfConditionOp.le => x <= value,
    NfConditionOp.gt => x > value,
    NfConditionOp.ge => x >= value,
    NfConditionOp.eq => x == value,
    NfConditionOp.ne => x != value,
  };

  @override
  String toString() => '[${op.symbol}$value]';
}

/// One section of a format.
final class NfSection {
  /// Creates a section.
  const NfSection({
    required this.tokens,
    required this.kind,
    required this.start,
    required this.end,
    this.condition,
    this.colorArgb,
    this.lcid,
    this.layout,
  });

  /// Resolved tokens in order (conditions and colors removed).
  final List<NfToken> tokens;

  /// Section kind.
  final NfSectionKind kind;

  /// Source span of the section (without the `;`).
  final int start;

  /// End offset (exclusive) of the section.
  final int end;

  /// Optional condition.
  final NfCondition? condition;

  /// Color (`[Red]`, `[Color10]`) as opaque ARGB.
  final int? colorArgb;

  /// LCID from a `[$sym-LCID]` tag: selects month/day names and AM/PM.
  final int? lcid;

  /// Precomputed numeric layout (number, scientific, fraction sections).
  final NfNumberLayout? layout;

  /// Whether the section contains an `AM/PM` or `A/P` token.
  bool get hasAmPm => tokens.any((t) => t is NfAmPm);

  @override
  String toString() => 'NfSection($kind, $tokens)';
}

/// Numeric layout facts of a number/scientific/fraction section.
final class NfNumberLayout {
  /// Creates a layout.
  const NfNumberLayout({
    required this.integerPlaceholders,
    required this.decimalPlaceholders,
    required this.grouping,
    required this.scaleExponent,
    this.exponentPlaceholders = 0,
    this.numeratorPlaceholders = 0,
    this.denominatorPlaceholders = 0,
    this.fixedDenominator,
    this.fractionHasInteger = false,
  });

  /// Digit placeholders before the decimal point (mantissa for scientific,
  /// the whole-number part for fractions).
  final int integerPlaceholders;

  /// Digit placeholders after the decimal point.
  final int decimalPlaceholders;

  /// Whether thousands grouping is on.
  final bool grouping;

  /// Power of ten applied before display: +2 per `%`, +3 per `‰`, −3 per
  /// scaling comma.
  final int scaleExponent;

  /// Digit placeholders of the exponent.
  final int exponentPlaceholders;

  /// Fraction: numerator placeholders.
  final int numeratorPlaceholders;

  /// Fraction: denominator placeholders (0 with a fixed denominator).
  final int denominatorPlaceholders;

  /// Fraction: fixed denominator (`# ?/16`).
  final int? fixedDenominator;

  /// Fraction: whether a whole-number part precedes the fraction.
  final bool fractionHasInteger;
}

/// A token of a section. [start]/[end] are offsets in the pattern source.
sealed class NfToken {
  const NfToken(this.start, this.end);

  /// Start offset in the source.
  final int start;

  /// End offset (exclusive) in the source.
  final int end;
}

/// Literal text (quoted, escaped, or a plain literal character).
final class NfLiteral extends NfToken {
  /// Creates a literal.
  const NfLiteral(this.text, super.start, super.end);

  /// The text displayed.
  final String text;

  @override
  String toString() => 'lit($text)';
}

/// Kind of digit placeholder.
enum NfDigitKind {
  /// `0`: pads with zeros.
  zero,

  /// `#`: no padding.
  hash,

  /// `?`: pads with a space as wide as a digit.
  question,
}

/// Role of a digit placeholder inside its section.
enum NfDigitRole {
  /// Integer part (or scientific mantissa integer part, or whole-number part
  /// of a fraction).
  integer,

  /// Decimal part.
  decimal,

  /// Exponent digits.
  exponent,

  /// Fraction numerator.
  numerator,

  /// Fraction denominator.
  denominator,
}

/// A digit placeholder `0`, `#` or `?`.
final class NfDigit extends NfToken {
  /// Creates a digit placeholder.
  const NfDigit(this.kind, this.role, super.start, super.end);

  /// Placeholder kind.
  final NfDigitKind kind;

  /// Role in the section.
  final NfDigitRole role;

  @override
  String toString() => 'digit(${kind.name},${role.name})';
}

/// Decimal point (rendered as the locale decimal symbol).
final class NfDecimalPoint extends NfToken {
  /// Creates a decimal point.
  const NfDecimalPoint(super.start, super.end);

  @override
  String toString() => 'point';
}

/// A thousands-grouping comma (turns grouping on; renders nothing itself).
final class NfGroupComma extends NfToken {
  /// Creates a grouping comma.
  const NfGroupComma(super.start, super.end);

  @override
  String toString() => 'group';
}

/// A scaling comma (÷1,000; renders nothing).
final class NfScaleComma extends NfToken {
  /// Creates a scaling comma.
  const NfScaleComma(super.start, super.end);

  @override
  String toString() => 'scale';
}

/// `%` (×100) or `‰` (×1,000).
final class NfPercent extends NfToken {
  /// Creates a percent token.
  const NfPercent(super.start, super.end, {this.permille = false});

  /// Whether this is `‰`.
  final bool permille;

  @override
  String toString() => permille ? 'permille' : 'percent';
}

/// `E+` / `E-` / `e+` / `e-` exponent marker; its digits follow as
/// [NfDigit]s with [NfDigitRole.exponent].
final class NfExponent extends NfToken {
  /// Creates an exponent marker.
  const NfExponent(this.letter, super.start, super.end, {required this.alwaysSign});

  /// `E` or `e` as typed.
  final String letter;

  /// `E+` (always show the sign) vs `E-` (only for negative exponents).
  final bool alwaysSign;

  @override
  String toString() => 'exp(${alwaysSign ? '+' : '-'})';
}

/// The fraction slash.
final class NfFractionSlash extends NfToken {
  /// Creates a fraction slash.
  const NfFractionSlash(super.start, super.end);

  @override
  String toString() => 'slash';
}

/// A fixed fraction denominator (`16` in `# ?/16`).
final class NfFixedDenominator extends NfToken {
  /// Creates a fixed denominator.
  const NfFixedDenominator(this.value, super.start, super.end);

  /// Denominator value.
  final int value;

  @override
  String toString() => 'den($value)';
}

/// `@`: the text value.
final class NfTextPlaceholder extends NfToken {
  /// Creates a text placeholder.
  const NfTextPlaceholder(super.start, super.end);

  @override
  String toString() => '@';
}

/// The `General` keyword.
final class NfGeneral extends NfToken {
  /// Creates a General token.
  const NfGeneral(super.start, super.end);

  @override
  String toString() => 'General';
}

/// Date/time units of [NfDatePart].
enum NfDateUnit {
  /// `d`, `dd` (day of month); `ddd`, `dddd` are [weekday].
  day,

  /// `ddd`, `dddd`.
  weekday,

  /// `m`…`mmmmm` (month).
  month,

  /// `yy`, `yyyy`.
  year,

  /// `h`, `hh`.
  hour,

  /// `m`, `mm` resolved as minutes.
  minute,

  /// `s`, `ss`.
  second,
}

/// A date or time token. [length] is the normalized repeat count
/// (day 1–4, month 1–5, year 2/4, hour/minute/second 1–2).
final class NfDatePart extends NfToken {
  /// Creates a date part.
  const NfDatePart(this.unit, this.length, super.start, super.end);

  /// Unit.
  final NfDateUnit unit;

  /// Normalized length.
  final int length;

  @override
  String toString() => '${unit.name}$length';
}

/// Fractional seconds (`.0`, `.00`, `.000` after seconds).
final class NfFractionalSeconds extends NfToken {
  /// Creates fractional seconds.
  const NfFractionalSeconds(this.digits, super.start, super.end);

  /// Number of digits (1–3; more are accepted and zero padded).
  final int digits;

  @override
  String toString() => 'frac$digits';
}

/// Units of elapsed-time tokens.
enum NfElapsedUnit {
  /// `[h]`
  hours,

  /// `[m]`
  minutes,

  /// `[s]`
  seconds,
}

/// Elapsed time `[h]`, `[mm]`, `[ss]` (no wrap-around).
final class NfElapsed extends NfToken {
  /// Creates an elapsed token.
  const NfElapsed(this.unit, this.length, super.start, super.end);

  /// Unit.
  final NfElapsedUnit unit;

  /// Minimum digits (zero padded).
  final int length;

  @override
  String toString() => '[${unit.name}$length]';
}

/// `AM/PM`, `am/pm`, `A/P`, `a/p`.
final class NfAmPm extends NfToken {
  /// Creates an AM/PM token.
  const NfAmPm(this.text, super.start, super.end);

  /// The token as typed.
  final String text;

  /// Whether this is the single-letter `A/P` form.
  bool get isShort => text.length == 3;

  @override
  String toString() => 'ampm($text)';
}

/// `*c`: repeat to fill the cell width.
final class NfRepeat extends NfToken {
  /// Creates a repeat token.
  const NfRepeat(this.char, super.start, super.end);

  /// Repeated character.
  final String char;

  @override
  String toString() => 'repeat($char)';
}

/// `_c`: blank as wide as the character.
final class NfSpacer extends NfToken {
  /// Creates a spacer.
  const NfSpacer(this.char, super.start, super.end);

  /// Reference character.
  final String char;

  @override
  String toString() => 'spacer($char)';
}

/// `[$sym-LCID]`: currency symbol (may be empty) and optional LCID.
final class NfLocaleTag extends NfToken {
  /// Creates a locale tag.
  const NfLocaleTag(this.symbol, this.lcid, super.start, super.end);

  /// Currency symbol displayed (may be empty).
  final String symbol;

  /// Windows LCID, if given.
  final int? lcid;

  @override
  String toString() => 'locale($symbol,$lcid)';
}
