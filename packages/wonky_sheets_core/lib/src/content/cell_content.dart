import 'dart:convert';

import 'rich_text.dart';

/// Error literals of the spreadsheet (05 §6.6), in `ERROR.TYPE` order where defined.
enum CellErrorKind {
  nullRef('#NULL!', 1),
  div0('#DIV/0!', 2),
  value('#VALUE!', 3),
  ref('#REF!', 4),
  name('#NAME?', 5),
  num('#NUM!', 6),
  na('#N/A', 7),
  parse('#ERROR!', 8),
  spill('#SPILL!', 9),
  calc('#CALC!', 14),
  loading('#LOADING', 15),
  blocked('#BLOCKED!', 16);

  const CellErrorKind(this.literal, this.code);

  /// Literal as typed and displayed (`#N/A`).
  final String literal;

  /// `ERROR.TYPE` code (used for ordering errors in sorts).
  final int code;

  static final Map<String, CellErrorKind> _byLiteral = {
    for (final k in CellErrorKind.values) k.literal.toUpperCase(): k,
  };

  /// Parses an error literal (case-insensitive), or null.
  static CellErrorKind? tryParse(String text) => _byLiteral[text.trim().toUpperCase()];
}

/// A scalar cell value: what a literal cell holds, or a computed formula result
/// as seen by charts, conditional formats, filters, sort and exporters.
///
/// Dates and times are numbers (serial days since 1899-12-30).
sealed class CellValue {
  const CellValue();

  /// Empty value (blank cell, or formula returning nothing).
  static const CellValue empty = EmptyValue();

  /// Wraps a Dart value: `num` → [NumberValue], `String` → [TextValue],
  /// `bool` → [BoolValue], `null` → [EmptyValue], [CellErrorKind] → [ErrorValue].
  factory CellValue.from(Object? v) => switch (v) {
    null => const EmptyValue(),
    final CellValue c => c,
    final num n => NumberValue(n.toDouble()),
    final String s => TextValue(s),
    final bool b => BoolValue(b),
    final CellErrorKind e => ErrorValue(e),
    _ => TextValue(v.toString()),
  };

  /// Whether the value is blank (empty, or the empty string when [emptyStringIsBlank]).
  bool isBlank({bool emptyStringIsBlank = true}) => switch (this) {
    EmptyValue() => true,
    TextValue(:final text) => emptyStringIsBlank && text.isEmpty,
    _ => false,
  };

  /// The number if this is a [NumberValue], else null.
  double? get asNumber => switch (this) {
    NumberValue(:final number) => number,
    _ => null,
  };

  /// The Dart representation (`double`, `String`, `bool`, `CellErrorKind` or null).
  Object? get dartValue => switch (this) {
    EmptyValue() => null,
    NumberValue(:final number) => number,
    TextValue(:final text) => text,
    BoolValue(:final value) => value,
    ErrorValue(:final kind) => kind,
  };
}

/// Blank.
final class EmptyValue extends CellValue {
  /// Creates the empty value.
  const EmptyValue();

  @override
  bool operator ==(Object other) => other is EmptyValue;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'EmptyValue';
}

/// A number (dates/times included).
final class NumberValue extends CellValue {
  /// Creates a number value.
  const NumberValue(this.number);

  /// The value.
  final double number;

  @override
  bool operator ==(Object other) => other is NumberValue && other.number == number;

  @override
  int get hashCode => number.hashCode;

  @override
  String toString() => 'NumberValue($number)';
}

/// Text.
final class TextValue extends CellValue {
  /// Creates a text value.
  const TextValue(this.text);

  /// The text.
  final String text;

  @override
  bool operator ==(Object other) => other is TextValue && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'TextValue($text)';
}

/// A boolean.
final class BoolValue extends CellValue {
  /// Creates a boolean value.
  const BoolValue(this.value);

  /// The value.
  final bool value;

  @override
  bool operator ==(Object other) => other is BoolValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BoolValue($value)';
}

/// An error.
final class ErrorValue extends CellValue {
  /// Creates an error value.
  const ErrorValue(this.kind, [this.message]);

  /// The error kind.
  final CellErrorKind kind;

  /// Optional human-readable message (tooltips).
  final String? message;

  @override
  bool operator ==(Object other) => other is ErrorValue && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;

  @override
  String toString() => 'ErrorValue(${kind.literal})';
}

/// Decoded `Cell.content` (02 §2). Use [CellContent.decode] / [encode].
///
/// | Prefix | Class |
/// |--------|-------|
/// | `=` | [FormulaContent] (stored-reference form, text includes the `=`) |
/// | `n:` | [NumberContent] |
/// | `s:` | [TextContent] |
/// | `b:` | [BoolContent] |
/// | `e:` | [ErrorContent] |
/// | `r:` | [RichTextContent] |
sealed class CellContent {
  const CellContent();

  /// Decodes a stored `content` string. `null` → null (no value). Unknown
  /// prefixes decode as text of the whole string (robust against bad data).
  static CellContent? decode(String? content) {
    if (content == null) return null;
    if (content.isEmpty) return const TextContent('');
    if (content.codeUnitAt(0) == 0x3d) return FormulaContent(content);
    if (content.length >= 2 && content.codeUnitAt(1) == 0x3a) {
      final body = content.substring(2);
      switch (content.codeUnitAt(0)) {
        case 0x6e: // n
          final d = double.tryParse(body);
          if (d != null && d.isFinite) return NumberContent(d);
        case 0x73: // s
          return TextContent(body);
        case 0x62: // b
          return BoolContent(body == '1' || body.toLowerCase() == 'true');
        case 0x65: // e
          return ErrorContent(CellErrorKind.tryParse(body) ?? CellErrorKind.value);
        case 0x72: // r
          final rt = RichText.tryParseJson(body);
          if (rt != null) return RichTextContent(rt);
      }
    }
    return TextContent(content);
  }

  /// Content for a literal [CellValue] (`EmptyValue` → null).
  static CellContent? fromValue(CellValue value) => switch (value) {
    EmptyValue() => null,
    NumberValue(:final number) => NumberContent(number),
    TextValue(:final text) => TextContent(text),
    BoolValue(:final value) => BoolContent(value),
    ErrorValue(:final kind) => ErrorContent(kind),
  };

  /// The encoded `content` column value.
  String encode();

  /// The literal value (formulas → [EmptyValue]; their value is computed by the
  /// formula engine).
  CellValue get literalValue;

  /// Whether this is a formula.
  bool get isFormula => this is FormulaContent;

  /// Plain text of text/rich content, else null.
  String? get plainText => switch (this) {
    TextContent(:final text) => text,
    RichTextContent(:final rich) => rich.text,
    _ => null,
  };

  /// Encodes [content] or returns null.
  static String? encodeOrNull(CellContent? content) => content?.encode();

  /// Shortest round-trip representation used after `n:`.
  static String formatNumber(double d) {
    if (d == d.truncateToDouble() && d.abs() < 1e21) {
      // Avoid "-0".
      if (d == 0) return '0';
      return d.toInt().toString();
    }
    return d.toString();
  }
}

/// `=…` formula in stored-reference form.
final class FormulaContent extends CellContent {
  /// Creates formula content; [text] must start with `=`.
  const FormulaContent(this.text);

  /// The stored formula including the leading `=`.
  final String text;

  /// The formula without the leading `=`.
  String get body => text.substring(1);

  @override
  String encode() => text;

  @override
  CellValue get literalValue => const EmptyValue();

  @override
  bool operator ==(Object other) => other is FormulaContent && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'FormulaContent($text)';
}

/// `n:` number.
final class NumberContent extends CellContent {
  /// Creates number content.
  const NumberContent(this.number);

  /// The number.
  final double number;

  @override
  String encode() => 'n:${CellContent.formatNumber(number)}';

  @override
  CellValue get literalValue => NumberValue(number);

  @override
  bool operator ==(Object other) => other is NumberContent && other.number == number;

  @override
  int get hashCode => number.hashCode;

  @override
  String toString() => 'NumberContent($number)';
}

/// `s:` text (also text forced with a leading `'`).
final class TextContent extends CellContent {
  /// Creates text content.
  const TextContent(this.text);

  /// The text.
  final String text;

  @override
  String encode() => 's:$text';

  @override
  CellValue get literalValue => TextValue(text);

  @override
  bool operator ==(Object other) => other is TextContent && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'TextContent($text)';
}

/// `b:` boolean.
final class BoolContent extends CellContent {
  /// Creates boolean content.
  const BoolContent(this.value);

  /// The value.
  final bool value;

  @override
  String encode() => value ? 'b:1' : 'b:0';

  @override
  CellValue get literalValue => BoolValue(value);

  @override
  bool operator ==(Object other) => other is BoolContent && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BoolContent($value)';
}

/// `e:` error literal.
final class ErrorContent extends CellContent {
  /// Creates error content.
  const ErrorContent(this.kind);

  /// The error kind.
  final CellErrorKind kind;

  @override
  String encode() => 'e:${kind.literal}';

  @override
  CellValue get literalValue => ErrorValue(kind);

  @override
  bool operator ==(Object other) => other is ErrorContent && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;

  @override
  String toString() => 'ErrorContent(${kind.literal})';
}

/// `r:` rich text.
final class RichTextContent extends CellContent {
  /// Creates rich text content.
  const RichTextContent(this.rich);

  /// The rich text.
  final RichText rich;

  @override
  String encode() => 'r:${jsonEncode(rich.toJson())}';

  @override
  CellValue get literalValue => TextValue(rich.text);

  @override
  bool operator ==(Object other) => other is RichTextContent && other.rich == rich;

  @override
  int get hashCode => rich.hashCode;

  @override
  String toString() => 'RichTextContent(${rich.text})';
}
