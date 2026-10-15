import 'code_tokenizer.dart';
import 'highlight_js/highlight_js_tokenizer.dart';
import 'textmate/textmate_tokenizer.dart';

/// The tokenizer facade every surface uses (Slides 07 §2.2): **TextMate
/// first** (the 15 patched grammars of `CodeLanguages.grammars`, best
/// quality), **highlight.js second** for every other known language.
/// Unknown languages render plain.
///
/// Write's editor uses [TextMateTokenizer] directly and Write's exports
/// [HighlightJsTokenizer] until both switch to this facade in M10 (Write 04
/// §15.5, v2 review Q17/Q25).
final class DefaultCodeTokenizer implements CodeTokenizer {
  const DefaultCodeTokenizer._();

  /// The shared tokenizer.
  static const DefaultCodeTokenizer instance = DefaultCodeTokenizer._();

  @override
  bool supports(String language) =>
      TextMateTokenizer.instance.supports(language) ||
      HighlightJsTokenizer.instance.supports(language);

  @override
  List<CodeToken> tokenize(String code, String language) {
    if (TextMateTokenizer.instance.supports(language)) {
      return TextMateTokenizer.instance.tokenize(code, language);
    }
    if (language.isEmpty) return const [];
    return HighlightJsTokenizer.instance.tokenize(code, language);
  }
}
