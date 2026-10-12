import 'package:petitparser/petitparser.dart';

import 'query_ast.dart';
import 'query_error.dart';

/// Words that cannot be used as bare column identifiers (backquote them instead: `` `BY` ``).
const Set<String> queryReservedWords = {
  'and', 'asc', 'by', 'contains', 'date', 'datetime', 'desc', 'ends', 'false', 'format', //
  'group', 'is', 'label', 'like', 'limit', 'matches', 'no_format', 'no_values', 'not', //
  'null', 'offset', 'options', 'or', 'order', 'pivot', 'select', 'starts', 'timeofday', //
  'timestamp', 'true', 'where', 'with',
};

/// Grammar of the QUERY language (05 §16.1). Keywords are case-insensitive; the clause order
/// is fixed. Once a clause keyword (or a comparison operator) has been read, the rest of the
/// clause is mandatory, so errors are reported where the clause breaks rather than at the
/// clause keyword.
class QueryGrammarDefinition extends GrammarDefinition<Query> {
  @override
  Parser<Query> start() => ref0(query).end();

  // ------------------------------------------------------------------ lexical

  /// One whitespace character (trimming repeats it).
  Parser<void> space() => whitespace();

  /// Trims [parser] with [space].
  Parser<T> tok<T>(Parser<T> parser) => parser.trim(ref0(space));

  /// A case-insensitive keyword not followed by an identifier character.
  Parser<String> keyword(String name) => tok(
    seq2(
      string(name, ignoreCase: true),
      pattern('A-Za-z0-9_').not(),
    ).flatten(message: '"$name" expected'),
  );

  /// A punctuation symbol.
  Parser<String> symbol(String s) => tok(string(s));

  /// `head` followed by a mandatory `body`: absent head → null without consuming; present
  /// head with a failing body → the body's failure.
  Parser<R?> committed<R>(Parser<void> head, Parser<R> body) => [
    seq2(head, body).map2((_, b) => b),
    head.not().map<R?>((_) => null),
  ].toChoiceParser(failureJoiner: selectFirst);

  /// Bare (`A`, `Col3`, `Revenue_2`) or backquoted (`` `my col` ``) column identifier.
  Parser<String> identifier() => tok(
    [
      seq2(
        pattern('A-Za-z_'),
        pattern('A-Za-z0-9_').starString(),
      ).flatten(message: 'identifier expected').where(
        (s) => !queryReservedWords.contains(s.toLowerCase()),
        message: 'identifier expected',
      ),
      pattern('^`').starString().skip(before: char('`'), after: char('`')),
    ].toChoiceParser(),
  );

  /// `'…'` or `"…"` (no escapes, as in GViz).
  Parser<String> stringLiteral() => tok(
    [
      pattern("^'").starString().skip(before: char("'"), after: char("'")),
      pattern('^"').starString().skip(before: char('"'), after: char('"')),
    ].toChoiceParser(),
  );

  /// Decimal number: `12`, `1.5`, `.5`, `2e3`.
  Parser<double> numberLiteral() => tok(
    seq3(
      [
        seq2(digit().plusString(), seq2(char('.'), digit().starString()).optional()),
        seq2(char('.'), digit().plusString()),
      ].toChoiceParser(),
      seq3(anyOf('eE'), anyOf('+-').optional(), digit().plusString()).optional(),
      pattern('A-Za-z_').not(),
    ).flatten(message: 'number expected').map(double.parse),
  );

  /// Non-negative integer (`limit`, `offset`).
  Parser<int> integer() => tok(
    seq2(
      digit().plusString(),
      pattern('A-Za-z_.').not(),
    ).flatten(message: 'integer expected').map(int.parse),
  );

  // ------------------------------------------------------------------ clauses

  Parser<Query> query() => seq2(
    ref0(space).star(),
    seq2(
      seq5(
        ref0(selectClause),
        ref0(whereClause),
        ref0(groupByClause),
        ref0(pivotClause),
        ref0(orderByClause),
      ),
      seq5(
        ref0(limitClause),
        ref0(offsetClause),
        ref0(labelClause),
        ref0(formatClause),
        ref0(optionsClause),
      ),
    ),
  ).map2((_, clauses) {
    final ((sel, wh, gb, pv, ob), (lim, off, lab, fmt, opts)) = clauses;
    return Query(
      select: sel?.items,
      where: wh,
      groupBy: gb ?? const [],
      pivot: pv ?? const [],
      orderBy: ob ?? const [],
      limit: lim,
      offset: off,
      labels: lab ?? const [],
      formats: fmt ?? const [],
      options: opts ?? const {},
    );
  });

  /// `select *` or `select e1, e2, …`.
  Parser<SelectList?> selectClause() => committed(
    ref1(keyword, 'select'),
    [
      ref1(symbol, '*').map((_) => const SelectList(null)),
      ref0(exprList).map(SelectList.new),
    ].toChoiceParser(failureJoiner: selectFarthest),
  );

  Parser<QCond?> whereClause() => committed(ref1(keyword, 'where'), ref0(orCondition));

  Parser<List<QExpr>?> groupByClause() =>
      committed(seq2(ref1(keyword, 'group'), ref1(keyword, 'by')), ref0(exprList));

  Parser<List<QExpr>?> pivotClause() => committed(ref1(keyword, 'pivot'), ref0(exprList));

  Parser<List<QOrderItem>?> orderByClause() => committed(
    seq2(ref1(keyword, 'order'), ref1(keyword, 'by')),
    ref0(orderItem).plusSeparated(ref1(symbol, ',')).map((s) => s.elements),
  );

  Parser<QOrderItem> orderItem() => seq2(
    ref0(expression),
    [
      ref1(keyword, 'asc').map((_) => false),
      ref1(keyword, 'desc').map((_) => true),
    ].toChoiceParser().optional(),
  ).map2((e, desc) => QOrderItem(e, descending: desc ?? false));

  Parser<int?> limitClause() => committed(ref1(keyword, 'limit'), ref0(integer));

  Parser<int?> offsetClause() => committed(ref1(keyword, 'offset'), ref0(integer));

  Parser<List<(QExpr, String)>?> labelClause() =>
      committed(ref1(keyword, 'label'), ref0(exprStringList));

  Parser<List<(QExpr, String)>?> formatClause() =>
      committed(ref1(keyword, 'format'), ref0(exprStringList));

  Parser<Set<QOption>?> optionsClause() => committed(
    ref1(keyword, 'options'),
    ref0(option).plusSeparated(ref1(symbol, ',')).map((s) => s.elements.toSet()),
  );

  Parser<QOption> option() => [
    ref1(keyword, 'no_format').map((_) => QOption.noFormat),
    ref1(keyword, 'no_values').map((_) => QOption.noValues),
  ].toChoiceParser();

  Parser<List<QExpr>> exprList() =>
      ref0(expression).plusSeparated(ref1(symbol, ',')).map((s) => s.elements);

  Parser<List<(QExpr, String)>> exprStringList() => seq2(ref0(expression), ref0(stringLiteral))
      .map2((e, s) => (e, s))
      .plusSeparated(ref1(symbol, ','))
      .map((s) => s.elements);

  // ------------------------------------------------------------------ conditions

  Parser<QCond> orCondition() => ref0(andCondition)
      .plusSeparated(ref1(keyword, 'or'))
      .map((s) => s.elements.length == 1 ? s.elements.first : QOr(s.elements));

  Parser<QCond> andCondition() => ref0(notCondition)
      .plusSeparated(ref1(keyword, 'and'))
      .map((s) => s.elements.length == 1 ? s.elements.first : QAnd(s.elements));

  Parser<QCond> notCondition() => [
    seq2(ref1(keyword, 'not'), ref0(notCondition)).map2((_, c) => QNot(c)),
    ref0(predicate),
  ].toChoiceParser(failureJoiner: selectFarthest);

  /// `expr <tail>` or `( condition )`. The expression form is tried first so that
  /// `(A + 1) > 2` parses as a comparison.
  Parser<QCond> predicate() => [
    seq2(ref0(expression), ref0(predicateTail)).map2((e, tail) => tail == null ? QBoolValue(e) : tail(e)),
    ref0(orCondition).skip(before: ref1(symbol, '('), after: ref1(symbol, ')')),
  ].toChoiceParser(failureJoiner: selectFarthest);

  /// What follows the left operand of a predicate (null: bare boolean expression). An
  /// operator without a valid right operand fails at the right operand.
  Parser<QCond Function(QExpr)?> predicateTail() => [
    seq3(ref1(keyword, 'is'), ref1(keyword, 'not').optional(), ref1(keyword, 'null'))
        .map3<QCond Function(QExpr)?>(
          (_, not, _) => (QExpr e) => QIsNull(e, negated: not != null),
        ),
    seq2(ref0(compareOp), ref0(expression)).map2<QCond Function(QExpr)?>(
      (op, r) => (QExpr l) => QCompare(op, l, r),
    ),
    seq2(ref0(stringOp), ref0(expression)).map2<QCond Function(QExpr)?>(
      (op, r) => (QExpr l) => QStringMatch(op, l, r),
    ),
    [
      ref0(compareOp),
      ref0(stringOp),
      ref1(keyword, 'is'),
    ].toChoiceParser().not().map<QCond Function(QExpr)?>((_) => null),
  ].toChoiceParser(failureJoiner: selectFarthest);

  Parser<QCompareOp> compareOp() => [
    ref1(symbol, '!=').map((_) => QCompareOp.ne),
    ref1(symbol, '<>').map((_) => QCompareOp.ne),
    ref1(symbol, '<=').map((_) => QCompareOp.le),
    ref1(symbol, '>=').map((_) => QCompareOp.ge),
    ref1(symbol, '<').map((_) => QCompareOp.lt),
    ref1(symbol, '>').map((_) => QCompareOp.gt),
    ref1(symbol, '=').map((_) => QCompareOp.eq),
  ].toChoiceParser();

  Parser<QStringOp> stringOp() => [
    ref1(keyword, 'contains').map((_) => QStringOp.contains),
    seq2(ref1(keyword, 'starts'), ref1(keyword, 'with')).map((_) => QStringOp.startsWith),
    seq2(ref1(keyword, 'ends'), ref1(keyword, 'with')).map((_) => QStringOp.endsWith),
    ref1(keyword, 'matches').map((_) => QStringOp.matches),
    ref1(keyword, 'like').map((_) => QStringOp.like),
  ].toChoiceParser();

  // ------------------------------------------------------------------ expressions

  Parser<QExpr> expression() {
    final builder = ExpressionBuilder<QExpr>();
    builder.primitive(ref0(atom));
    builder.group()
      ..wrapper(ref1(symbol, '('), ref1(symbol, ')'), (_, e, _) => e)
      ..prefix(ref1(symbol, '-'), (_, e) => QNegate(e));
    builder.group()
      ..left(ref1(symbol, '*'), (l, _, r) => QArith(QArithOp.mul, l, r))
      ..left(ref1(symbol, '/'), (l, _, r) => QArith(QArithOp.div, l, r))
      ..left(ref1(symbol, '%'), (l, _, r) => QArith(QArithOp.mod, l, r));
    builder.group()
      ..left(ref1(symbol, '+'), (l, _, r) => QArith(QArithOp.add, l, r))
      ..left(ref1(symbol, '-'), (l, _, r) => QArith(QArithOp.sub, l, r));
    return builder.build();
  }

  Parser<QExpr> atom() => [
    ref0(literal),
    ref0(aggregate),
    ref0(scalarCall),
    ref0(identifier).map(QColumn.new),
  ].toChoiceParser(failureJoiner: selectFarthest);

  Parser<QExpr> literal() => [
    ref0(numberLiteral).map(QNumber.new),
    ref0(stringLiteral).map(QString.new),
    ref1(keyword, 'true').map((_) => const QBool(true)),
    ref1(keyword, 'false').map((_) => const QBool(false)),
    seq2(ref1(keyword, 'datetime'), ref0(stringLiteral)).map2((_, s) => QDateLiteral(QDateKind.datetime, s)),
    seq2(ref1(keyword, 'timestamp'), ref0(stringLiteral)).map2((_, s) => QDateLiteral(QDateKind.datetime, s)),
    seq2(ref1(keyword, 'timeofday'), ref0(stringLiteral)).map2((_, s) => QDateLiteral(QDateKind.timeofday, s)),
    seq2(ref1(keyword, 'date'), ref0(stringLiteral)).map2((_, s) => QDateLiteral(QDateKind.date, s)),
  ].toChoiceParser(failureJoiner: selectFarthest);

  /// `avg(x)`, `count(x)`, `max(x)`, `min(x)`, `sum(x)`.
  Parser<QExpr> aggregate() => seq3(
    [
      for (final f in QAggFn.values) ref1(keyword, f.name).map((_) => f),
    ].toChoiceParser(),
    ref1(symbol, '('),
    seq2(ref0(expression), ref1(symbol, ')')),
  ).map3((f, _, a) => QAggregate(f, a.$1));

  /// `year(x)`, `now()`, `dateDiff(a, b)`, … (names case-insensitive).
  Parser<QExpr> scalarCall() => seq3(
    [
      for (final f in QScalarFn.values) ref1(keyword, f.name).map((_) => f),
    ].toChoiceParser(),
    ref1(symbol, '('),
    seq2(
      ref0(expression).starSeparated(ref1(symbol, ',')),
      ref1(symbol, ')'),
    ),
  ).map3((f, _, a) => QCall(f, a.$1.elements));
}

/// Result of the select clause (`items == null` for `select *`).
final class SelectList {
  final List<QExpr>? items;
  const SelectList(this.items);
}

/// Parses query strings (05 §16).
abstract final class QueryParser {
  static final Parser<Query> _parser = QueryGrammarDefinition().build();

  /// Parses [text]; throws [QueryException] (`PARSE_ERROR: Encountered "x" at line l, column c.`).
  static Query parse(String text) {
    final r = _parser.parse(text);
    if (r case Success(:final value)) return value;
    throw errorAt(text, r.position);
  }

  /// The PARSE_ERROR for a failure at [offset] in [text].
  static QueryException errorAt(String text, int offset) {
    var p = offset.clamp(0, text.length);
    while (p < text.length && _isSpace(text.codeUnitAt(p))) {
      p++;
    }
    var line = 1, col = 1;
    for (var i = 0; i < p; i++) {
      if (text.codeUnitAt(i) == 0x0a) {
        line++;
        col = 1;
      } else {
        col++;
      }
    }
    return QueryException.parse(_tokenAt(text, p), line, col);
  }

  static bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d;

  static bool _isWord(int c) =>
      (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a) || c == 0x5f;

  static String _tokenAt(String text, int p) {
    if (p >= text.length) return '<EOF>';
    final c = text.codeUnitAt(p);
    if (_isWord(c)) {
      var e = p;
      while (e < text.length && (_isWord(text.codeUnitAt(e)) || text.codeUnitAt(e) == 0x2e)) {
        e++;
      }
      return text.substring(p, e);
    }
    if (c == 0x27 || c == 0x22 || c == 0x60) {
      final end = text.indexOf(String.fromCharCode(c), p + 1);
      return end < 0 ? text.substring(p) : text.substring(p, end + 1);
    }
    return String.fromCharCode(text.runes.elementAt(_runeIndex(text, p)));
  }

  static int _runeIndex(String text, int p) {
    var i = 0, n = 0;
    while (i < p) {
      final c = text.codeUnitAt(i);
      i += (c >= 0xd800 && c <= 0xdbff) ? 2 : 1;
      n++;
    }
    return n;
  }
}
