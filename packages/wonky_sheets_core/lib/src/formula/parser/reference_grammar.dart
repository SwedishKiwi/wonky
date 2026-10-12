import 'package:petitparser/petitparser.dart';

import '../../addressing/a1.dart';
import '../ast/ast.dart';
import '../codec/ref_token.dart';
import 'lexical_grammar.dart';

/// A1 references (with sheet prefixes) and stored `⟦…⟧` tokens (05 §3.4).
mixin ReferenceGrammar on GrammarDefinition<Expr>, LexicalGrammar {
  /// Whether stored tokens are accepted.
  bool get storedForm;

  Parser<Expr> a1Reference() => ScanParser<Expr>(_scanA1, 'reference expected');

  (Expr, int)? _scanA1(String s, int i) {
    final m = A1Scanner.scan(s, i);
    if (m == null) return null;
    return (RefExpr(A1RefNode(m.area), span: SourceSpan(i, m.end)), m.end);
  }

  Parser<Expr> storedReference() => ScanParser<Expr>(_scanStored, 'stored reference expected');

  (Expr, int)? _scanStored(String s, int i) {
    if (!storedForm || i >= s.length || s.codeUnitAt(i) != RefToken.openCode) return null;
    final close = s.indexOf(RefToken.close, i);
    if (close < 0) return null;
    if (i + 1 < s.length && s.codeUnitAt(i + 1) == 0x23) {
      final n = int.tryParse(s.substring(i + 2, close));
      if (n == null) return null;
      return (RefExpr(SlotRefNode(n), span: SourceSpan(i, close + 1)), close + 1);
    }
    final a = RefToken.decode(s.substring(i, close + 1));
    if (a == null) return null;
    var end = close + 1;
    RefToken? b;
    if (end + 1 < s.length && s.codeUnitAt(end) == 0x3a && s.codeUnitAt(end + 1) == RefToken.openCode) {
      final close2 = s.indexOf(RefToken.close, end + 1);
      if (close2 > 0) {
        b = RefToken.decode(s.substring(end + 1, close2 + 1));
        if (b != null) end = close2 + 1;
      }
    }
    return (RefExpr(StoredRefNode(StoredRef(a, b)), span: SourceSpan(i, end)), end);
  }
}
