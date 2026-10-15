import '../code_tokenizer.dart';
import '../syntax_token.dart';

/// A lexeme: the unit that type-in snapping and morph animate (Slides 07
/// §5.2 step 4, §5.6 step 1).
final class CodeLexeme {
  /// Creates a lexeme covering `code[start, end)`.
  const CodeLexeme(this.start, this.end, this.text, this.token);

  /// UTF-16 offsets into the code.
  final int start;
  final int end;

  /// The lexeme's text.
  final String text;

  /// Token class (null = plain text).
  final SyntaxToken? token;

  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is CodeLexeme &&
      other.start == start &&
      other.end == end &&
      other.token == token;

  @override
  int get hashCode => Object.hash(start, end, token);

  @override
  String toString() => 'CodeLexeme($start, $end, "$text", ${token?.name})';
}

/// Splits code into lexemes: token spans split at whitespace (whitespace is
/// never a lexeme); words (letters, digits, `_`, `$`) and single
/// punctuation characters are separate lexemes, except inside strings and
/// comments, which only split at whitespace.
abstract final class CodeLexer {
  /// Lexemes of [code] with its tokenizer [tokens] (sorted, disjoint), in
  /// document order.
  static List<CodeLexeme> lex(String code, List<CodeToken> tokens) {
    final out = <CodeLexeme>[];
    var pos = 0;
    for (final t in tokens) {
      if (t.start > pos) _split(code, pos, t.start, null, out);
      final start = t.start < pos ? pos : t.start;
      if (t.end > start) _split(code, start, t.end, t.token, out);
      if (t.end > pos) pos = t.end;
    }
    if (pos < code.length) _split(code, pos, code.length, null, out);
    return out;
  }

  static void _split(
    String code,
    int start,
    int end,
    SyntaxToken? token,
    List<CodeLexeme> out,
  ) {
    final wordsOnly =
        token == SyntaxToken.string || token == SyntaxToken.comment;
    var i = start;
    while (i < end) {
      final c = code.codeUnitAt(i);
      if (_isSpace(c)) {
        i++;
        continue;
      }
      var j = i + 1;
      if (wordsOnly) {
        while (j < end && !_isSpace(code.codeUnitAt(j))) {
          j++;
        }
      } else if (_isWord(c)) {
        while (j < end && _isWord(code.codeUnitAt(j))) {
          j++;
        }
      } else if (c >= 0xD800 && c <= 0xDBFF && j < end) {
        j++; // keep a surrogate pair together
      }
      out.add(CodeLexeme(i, j, code.substring(i, j), token));
      i = j;
    }
  }

  static bool _isSpace(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0x0C;

  static bool _isWord(int c) =>
      (c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A) ||
      c == 0x5F ||
      c == 0x24 ||
      (c >= 0x80 && !(c >= 0x2000 && c <= 0x206F) && c != 0x3000);
}
