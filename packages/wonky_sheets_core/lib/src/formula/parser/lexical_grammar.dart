import 'package:petitparser/petitparser.dart';

import '../ast/ast.dart';
import '../values/errors.dart';
import 'formula_locale.dart';
import 'lexer.dart';

/// A parser backed by a hand-written scanner `(buffer, position) → (value, end)?`.
final class ScanParser<T> extends Parser<T> {
  final (T, int)? Function(String buffer, int position) scanner;
  final String message;
  ScanParser(this.scanner, this.message);

  @override
  Result<T> parseOn(Context context) {
    final r = scanner(context.buffer, context.position);
    if (r == null) return context.failure(message);
    return context.success(r.$1, r.$2);
  }

  @override
  int fastParseOn(String buffer, int position) {
    final r = scanner(buffer, position);
    return r == null ? -1 : r.$2;
  }

  @override
  ScanParser<T> copy() => ScanParser<T>(scanner, message);

  @override
  bool hasEqualProperties(ScanParser<T> other) =>
      super.hasEqualProperties(other) && identical(scanner, other.scanner);
}

/// Numbers, strings, booleans, errors, identifiers and whitespace (05 §3.3).
mixin LexicalGrammar on GrammarDefinition<Expr> {
  FormulaLocale get locale;

  /// Whitespace allowed between tokens.
  Parser<void> ws() => pattern(' \t\r\n').star();

  /// Trims [ws] around [p].
  Parser<T> tok<T>(Parser<T> p) => p.trim(pattern(' \t\r\n'));

  Parser<Expr> numberLiteral() =>
      ScanParser<Expr>(_scanNumber, 'number expected');

  (Expr, int)? _scanNumber(String s, int i) {
    final n = s.length;
    final dec = locale.decimal.codeUnitAt(0);
    var j = i;
    bool digit(int k) =>
        k < n && s.codeUnitAt(k) >= 0x30 && s.codeUnitAt(k) <= 0x39;
    while (digit(j)) {
      j++;
    }
    final intDigits = j - i;
    var fracDigits = 0;
    if (j < n && s.codeUnitAt(j) == dec) {
      if (digit(j + 1) || (dec == 0x2e && intDigits > 0)) {
        j++;
        final f = j;
        while (digit(j)) {
          j++;
        }
        fracDigits = j - f;
      }
    }
    if (intDigits == 0 && fracDigits == 0) return null;
    if (j < n && (s.codeUnitAt(j) == 0x65 || s.codeUnitAt(j) == 0x45)) {
      var k = j + 1;
      if (k < n && (s.codeUnitAt(k) == 0x2b || s.codeUnitAt(k) == 0x2d)) k++;
      final ds = k;
      while (digit(k)) {
        k++;
      }
      if (k > ds) j = k;
    }
    // A number directly followed by an identifier character is not a number (e.g. "1A").
    if (j < n && FormulaLexer.isIdentStart(s.codeUnitAt(j))) return null;
    final text = s.substring(i, j);
    final norm = dec == 0x2e ? text : text.replaceAll(locale.decimal, '.');
    final v = double.tryParse(norm.startsWith('.') ? '0$norm' : norm);
    if (v == null) return null;
    return (NumberLit(v, text: text, span: SourceSpan(i, j)), j);
  }

  Parser<Expr> stringLiteral() =>
      ScanParser<Expr>(_scanString, 'string expected');

  (Expr, int)? _scanString(String s, int i) {
    if (i >= s.length || s.codeUnitAt(i) != 0x22) return null;
    final b = StringBuffer();
    var j = i + 1;
    while (j < s.length) {
      final c = s.codeUnitAt(j);
      if (c == 0x22) {
        if (j + 1 < s.length && s.codeUnitAt(j + 1) == 0x22) {
          b.write('"');
          j += 2;
          continue;
        }
        return (StringLit(b.toString(), span: SourceSpan(i, j + 1)), j + 1);
      }
      b.writeCharCode(c);
      j++;
    }
    return null;
  }

  Parser<Expr> booleanLiteral() =>
      ScanParser<Expr>(_scanBool, 'boolean expected');

  (Expr, int)? _scanBool(String s, int i) {
    for (final (word, value) in const [('TRUE', true), ('FALSE', false)]) {
      final e = i + word.length;
      if (e <= s.length && s.substring(i, e).toUpperCase() == word) {
        if (e < s.length) {
          final c = s.codeUnitAt(e);
          if (c == 0x28 || FormulaLexer.isIdentPart(c)) return null;
        }
        return (BoolLit(value, span: SourceSpan(i, e)), e);
      }
    }
    return null;
  }

  Parser<Expr> errorLiteral() =>
      ScanParser<Expr>(_scanError, 'error literal expected');

  (Expr, int)? _scanError(String s, int i) {
    if (i >= s.length || s.codeUnitAt(i) != 0x23) return null;
    for (final lit in ErrorKind.literalsLongestFirst) {
      final e = i + lit.length;
      if (e <= s.length && s.substring(i, e).toUpperCase() == lit) {
        return (
          ErrorLit(ErrorKind.fromLiteral(lit)!, span: SourceSpan(i, e)),
          e,
        );
      }
    }
    return null;
  }

  Parser<(String, SourceSpan)> identifier() =>
      ScanParser<(String, SourceSpan)>(_scanIdentifier, 'identifier expected');

  ((String, SourceSpan), int)? _scanIdentifier(String s, int i) {
    if (i >= s.length || !FormulaLexer.isIdentStart(s.codeUnitAt(i))) {
      return null;
    }
    var j = i + 1;
    while (j < s.length && FormulaLexer.isIdentPart(s.codeUnitAt(j))) {
      j++;
    }
    return ((s.substring(i, j), SourceSpan(i, j)), j);
  }

  /// Argument separator: locale separator, plus `,` when unambiguous (05 §3.2).
  Parser<String> argSeparator() => locale.argSeparator == ','
      ? char(',')
      : [char(locale.argSeparator), char(',')].toChoiceParser();

  Parser<String> arrayColSeparator() => locale.arrayColSeparator == ','
      ? char(',')
      : [char(locale.arrayColSeparator), char(',')].toChoiceParser();

  Parser<String> arrayRowSeparator() => char(locale.arrayRowSeparator);
}
