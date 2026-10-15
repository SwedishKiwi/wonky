import 'syntax_token.dart';

/// A highlighted range of a code string (Slides 07 §2.2).
///
/// [start] and [end] are UTF-16 offsets into the tokenized string; [end] is
/// exclusive and always greater than [start].
final class CodeToken {
  /// Creates a token covering `[start, end)` with [token].
  const CodeToken(this.start, this.end, this.token);

  /// First UTF-16 offset of the range (inclusive).
  final int start;

  /// UTF-16 offset just after the range (exclusive).
  final int end;

  /// The token class the range is colored with.
  final SyntaxToken token;

  /// Number of UTF-16 code units covered.
  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is CodeToken &&
      other.start == start &&
      other.end == end &&
      other.token == token;

  @override
  int get hashCode => Object.hash(start, end, token);

  @override
  String toString() => 'CodeToken($start, $end, ${token.name})';
}

/// Splits code into token ranges (Slides 07 §2.2).
///
/// Implementations: [TextMateTokenizer](textmate/textmate_tokenizer.dart)
/// (the 15 grammars Write ships), [HighlightJsTokenizer](highlight_js/highlight_js_tokenizer.dart)
/// (broad coverage) and the [DefaultCodeTokenizer](default_code_tokenizer.dart)
/// facade that routes between them.
abstract interface class CodeTokenizer {
  /// Whether this tokenizer knows [language] (a normalized id,
  /// `CodeLanguages.normalize`). A known language can still yield no tokens
  /// (highlight.js `plaintext`).
  bool supports(String language);

  /// Tokens of [code] in [language] (normalized id): sorted, disjoint,
  /// non-empty ranges within `code.length`, adjacent ranges of one class
  /// merged. Text not covered is plain (the palette's text color). Empty for
  /// unsupported languages. Never throws.
  List<CodeToken> tokenize(String code, String language);
}
