import 'package:petitparser/petitparser.dart';

import '../ast/ast.dart';
import 'lexical_grammar.dart';
import 'reference_grammar.dart';

/// Operator precedence (05 §3.5), primaries, calls and array literals.
mixin ExpressionGrammar
    on GrammarDefinition<Expr>, LexicalGrammar, ReferenceGrammar {
  Parser<Expr> expression() {
    final builder = ExpressionBuilder<Expr>();
    builder.primitive(ref0(postfixPrimary));
    Parser<Token<String>> op(String s) => tok(string(s).token());
    SourceSpan span(Expr a, Expr b) => SourceSpan(a.span.start, b.span.end);

    // 1. range operator
    builder.group().left(
      op(':'),
      (Expr a, Token<String> _, Expr b) => RangeOpExpr(a, b, span: span(a, b)),
    );
    // 2. unary +/- (binds tighter than ^: -2^2 = 4)
    builder.group()
      ..prefix(
        tok(char('-').token()),
        (Token<String> t, Expr v) =>
            UnaryExpr(UnaryOp.minus, v, span: SourceSpan(t.start, v.span.end)),
      )
      ..prefix(
        tok(char('+').token()),
        (Token<String> t, Expr v) =>
            UnaryExpr(UnaryOp.plus, v, span: SourceSpan(t.start, v.span.end)),
      );
    // 3. percent
    builder.group().postfix(
      tok(char('%').token()),
      (Expr v, Token<String> t) =>
          PercentExpr(v, span: SourceSpan(v.span.start, t.stop)),
    );
    // 4. power (left-assoc: 2^3^2 = 64)
    builder.group().left(
      op('^'),
      (Expr a, Token<String> _, Expr b) =>
          BinaryExpr(BinaryOp.pow, a, b, span: span(a, b)),
    );
    // 5. * /
    builder.group()
      ..left(
        op('*'),
        (Expr a, Token<String> _, Expr b) =>
            BinaryExpr(BinaryOp.mul, a, b, span: span(a, b)),
      )
      ..left(
        op('/'),
        (Expr a, Token<String> _, Expr b) =>
            BinaryExpr(BinaryOp.div, a, b, span: span(a, b)),
      );
    // 6. + -
    builder.group()
      ..left(
        op('+'),
        (Expr a, Token<String> _, Expr b) =>
            BinaryExpr(BinaryOp.add, a, b, span: span(a, b)),
      )
      ..left(
        op('-'),
        (Expr a, Token<String> _, Expr b) =>
            BinaryExpr(BinaryOp.sub, a, b, span: span(a, b)),
      );
    // 7. &
    builder.group().left(
      op('&'),
      (Expr a, Token<String> _, Expr b) =>
          BinaryExpr(BinaryOp.concat, a, b, span: span(a, b)),
    );
    // 8. comparisons
    final cmp = [
      ('<>', BinaryOp.ne),
      ('<=', BinaryOp.le),
      ('>=', BinaryOp.ge),
      ('<', BinaryOp.lt),
      ('>', BinaryOp.gt),
      ('=', BinaryOp.eq),
    ];
    final g = builder.group();
    for (final (sym, bop) in cmp) {
      g.left(
        op(sym),
        (Expr a, Token<String> _, Expr b) =>
            BinaryExpr(bop, a, b, span: span(a, b)),
      );
    }
    return builder.build();
  }

  /// A primary followed by invocations `(…)(…)`.
  Parser<Expr> postfixPrimary() =>
      seq2(
        ref0(primary),
        seq3(char('('), ref0(argList), tok(char(')')).token()).star(),
      ).map2((p, calls) {
        var e = p;
        for (final (_, args, close) in calls) {
          e = InvokeExpr(e, args, span: SourceSpan(p.span.start, close.stop));
        }
        return e;
      });

  Parser<Expr> primary() => [
    ref0(stringLiteral),
    ref0(storedReference),
    ref0(functionCall),
    ref0(a1Reference),
    ref0(numberLiteral),
    ref0(booleanLiteral),
    ref0(errorLiteral),
    ref0(arrayLiteral),
    ref0(nameReference),
    ref0(parenthesized),
  ].toChoiceParser(failureJoiner: selectFarthest);

  Parser<Expr> nameReference() => ref0(
    identifier,
  ).map(((String, SourceSpan) id) => NameExpr(id.$1, span: id.$2));

  Parser<Expr> parenthesized() => seq3(
    char('(').token(),
    tok(ref0(expression)),
    char(')').token(),
  ).map3((o, e, c) => ParenExpr(e, span: SourceSpan(o.start, c.stop)));

  Parser<Expr> functionCall() =>
      seq4(
        ref0(identifier),
        char('('),
        ref0(argList),
        tok(char(')')).token(),
      ).map4(
        (id, _, args, close) => CallExpr(
          id.$1,
          args,
          span: SourceSpan(id.$2.start, close.stop),
          nameSpan: id.$2,
        ),
      );

  /// Arguments: empty list for `()`, otherwise separated optional expressions.
  Parser<List<Expr?>> argList() => [
    ref0(ws).skip(after: char(')').and()).map((_) => <Expr?>[]),
    tok(
      ref0(expression).optional(),
    ).plusSeparated(tok(ref0(argSeparator))).map((sl) => sl.elements),
  ].toChoiceParser();

  Parser<Expr> arrayLiteral() => seq3(
    tok(char('{').token()),
    tok(ref0(expression))
        .plusSeparated(tok(ref0(arrayColSeparator)))
        .map((sl) => sl.elements)
        .plusSeparated(tok(ref0(arrayRowSeparator)))
        .map((sl) => sl.elements),
    char('}').token(),
  ).map3((o, rows, c) => ArrayLit(rows, span: SourceSpan(o.start, c.stop)));
}
