import 'dart:convert';

import '../code_languages.dart';
import '../code_tokenizer.dart';
import '../grammars/grammars.dart';
import 'scope_classifier.dart';
import 'span_parser.dart';

/// Tokenizes code with the embedded TextMate grammars (Slides 07 §2.2; the
/// engine copied from `syntax_highlight`, see `THIRD_PARTY.md`) and maps
/// their scopes to token classes with [ScopeClassifier].
///
/// Supports the languages of [CodeLanguages.grammars]. Grammars are embedded
/// Dart strings, parsed lazily on first use, so [tokenize] is synchronous
/// and works without Flutter (server, isolates).
final class TextMateTokenizer implements CodeTokenizer {
  const TextMateTokenizer._();

  /// The shared tokenizer.
  static const TextMateTokenizer instance = TextMateTokenizer._();

  static final Map<String, Grammar?> _grammars = {};

  /// The parsed grammar [id] (a key of [embeddedGrammars]), or `null` when
  /// there is none or it fails to parse.
  static Grammar? _grammar(String id) => _grammars.putIfAbsent(id, () {
    final json = embeddedGrammars[id];
    if (json == null) return null;
    try {
      return Grammar.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  });

  @override
  bool supports(String language) => CodeLanguages.grammarFor(language) != null;

  @override
  List<CodeToken> tokenize(String code, String language) {
    final id = CodeLanguages.grammarFor(language);
    if (id == null || code.isEmpty) return const [];
    final grammar = _grammar(id);
    if (grammar == null) return const [];
    try {
      final tokens = <CodeToken>[];
      for (final span in SpanParser.parse(grammar, code)) {
        final token = ScopeClassifier.tokenFor(span.scopes);
        if (token == null) continue;
        var start = span.start.clamp(0, code.length);
        final end = span.end.clamp(0, code.length);
        // The contract (sorted, disjoint) holds even if a capture is still
        // misplaced (SH-7 locates captures by search): exporters write each
        // token's text, so an overlap would duplicate code.
        if (tokens.isNotEmpty && start < tokens.last.end) {
          start = tokens.last.end;
        }
        if (end <= start) continue;
        if (tokens.isNotEmpty) {
          final last = tokens.last;
          if (last.end == start && last.token == token) {
            tokens.last = CodeToken(last.start, end, token);
            continue;
          }
        }
        tokens.add(CodeToken(start, end, token));
      }
      return tokens;
    } catch (_) {
      return const [];
    }
  }
}
