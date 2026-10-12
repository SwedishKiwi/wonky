import 'package:petitparser/petitparser.dart';

import '../ast/ast.dart';
import 'expression_grammar.dart';
import 'formula_locale.dart';
import 'lexical_grammar.dart';
import 'lexer.dart';
import 'parse_error.dart';
import 'reference_grammar.dart';

/// The formula grammar (05 §3.3) as a strongly typed [GrammarDefinition].
///
/// The leading `=` is optional. [storedForm] additionally accepts `⟦…⟧` tokens.
class FormulaGrammar extends GrammarDefinition<Expr>
    with LexicalGrammar, ReferenceGrammar, ExpressionGrammar {
  @override
  final FormulaLocale locale;
  @override
  final bool storedForm;

  FormulaGrammar(this.locale, {this.storedForm = true});

  @override
  Parser<Expr> start() =>
      seq3(tok(char('=')).optional(), tok(ref0(expression)), endOfInput()).map3((_, e, _) => e);
}

/// Cached parsers per `(locale, storedForm)` and the public parse entry point.
abstract final class FormulaParser {
  static final Map<String, Parser<Expr>> _cache = {};

  /// Maximum nesting depth (05 §3.8).
  static const int maxDepth = 256;

  /// Maximum A1 formula length.
  static const int maxLength = 32768;

  static Parser<Expr> _parser(FormulaLocale locale, bool storedForm) =>
      _cache.putIfAbsent('${locale.id}|$storedForm', () {
        return FormulaGrammar(locale, storedForm: storedForm).build();
      });

  /// Parses [text] (with or without leading `=`). Throws [FormulaParseError].
  static Expr parse(
    String text, {
    FormulaLocale locale = FormulaLocale.enUS,
    bool storedForm = true,
  }) {
    final r = tryParse(text, locale: locale, storedForm: storedForm);
    if (r.$1 != null) return r.$1!;
    throw r.$2!;
  }

  /// Parses [text], returning either the AST or the error.
  static (Expr?, FormulaParseError?) tryParse(
    String text, {
    FormulaLocale locale = FormulaLocale.enUS,
    bool storedForm = true,
  }) {
    if (text.length > maxLength) {
      return (null, FormulaParseError.of(ParseErrorKey.tooLong, 0, text.length));
    }
    final tokens = FormulaLexer(locale: locale, storedForm: storedForm).tokenize(text);
    var maxD = 0;
    for (final t in tokens) {
      if (t.depth > maxD) maxD = t.depth;
    }
    if (maxD > maxDepth) {
      return (null, FormulaParseError.of(ParseErrorKey.tooDeep, 0, text.length));
    }
    final result = _parser(locale, storedForm).parse(text);
    switch (result) {
      case Success(:final value):
        if (value.depth > maxDepth) {
          return (null, FormulaParseError.of(ParseErrorKey.tooDeep, 0, text.length));
        }
        return (value, null);
      case Failure(:final position):
        return (null, _diagnose(text, tokens, position));
    }
  }

  static FormulaParseError _diagnose(String text, List<FormulaToken> tokens, int position) {
    for (final t in tokens) {
      if (t.kind == TokenKind.unterminatedString) {
        return FormulaParseError.of(ParseErrorKey.unterminatedString, t.start, t.end - t.start);
      }
    }
    var depth = 0;
    for (final t in tokens) {
      if (t.kind == TokenKind.openParen) depth++;
      if (t.kind == TokenKind.closeParen) depth--;
    }
    if (depth > 0) {
      return FormulaParseError.of(ParseErrorKey.missingCloseParen, text.length, 0);
    }
    // Empty array element: "{1,,2}"
    final sig = FormulaLexer.significant(tokens);
    for (var i = 0; i + 1 < sig.length; i++) {
      final a = sig[i].kind;
      final b = sig[i + 1].kind;
      final sepA = a == TokenKind.arrayColSep || a == TokenKind.arrayRowSep || a == TokenKind.openBrace;
      final sepB = b == TokenKind.arrayColSep || b == TokenKind.arrayRowSep || b == TokenKind.closeBrace;
      if (sepA && sepB && !(a == TokenKind.openBrace && b == TokenKind.closeBrace)) {
        return FormulaParseError.of(ParseErrorKey.emptyArrayElement, sig[i + 1].start);
      }
    }
    // Find the token at/after the failure position.
    for (final t in sig) {
      if (t.end > position) {
        if (t.kind == TokenKind.unknown || t.kind == TokenKind.sheetPrefix) {
          return FormulaParseError.of(ParseErrorKey.invalidReference, t.start, t.end - t.start);
        }
        return FormulaParseError.of(ParseErrorKey.unexpectedToken, t.start, t.end - t.start);
      }
    }
    return FormulaParseError.of(ParseErrorKey.unexpectedToken, position.clamp(0, text.length));
  }
}
