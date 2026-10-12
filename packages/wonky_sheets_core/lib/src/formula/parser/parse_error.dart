/// Message keys of formula parse errors (05 §4.2).
enum ParseErrorKey {
  unexpectedToken,
  missingCloseParen,
  unterminatedString,
  emptyArrayElement,
  invalidReference,
  tooDeep,
  trailingInput,
  tooLong,
}

/// A formula parse error with the offending position (UTF-16 offset into the formula text,
/// including a leading `=` when present).
final class FormulaParseError implements Exception {
  final int offset;
  final int length;
  final ParseErrorKey messageKey;
  final String message;

  const FormulaParseError(this.offset, this.length, this.messageKey, this.message);

  factory FormulaParseError.of(ParseErrorKey key, int offset, [int length = 1]) {
    final pos = offset + 1;
    final msg = switch (key) {
      ParseErrorKey.unexpectedToken => 'Formula parse error at position $pos.',
      ParseErrorKey.missingCloseParen => 'Formula parse error: missing closing parenthesis.',
      ParseErrorKey.unterminatedString => 'Formula parse error: unterminated text at position $pos.',
      ParseErrorKey.emptyArrayElement => 'Formula parse error: empty array element at position $pos.',
      ParseErrorKey.invalidReference => 'Formula parse error: invalid reference at position $pos.',
      ParseErrorKey.tooDeep => 'Formula is too deeply nested',
      ParseErrorKey.trailingInput => 'Formula parse error at position $pos.',
      ParseErrorKey.tooLong => 'Formula is too long',
    };
    return FormulaParseError(offset, length, key, msg);
  }

  @override
  String toString() => 'FormulaParseError($messageKey @$offset: $message)';
}
