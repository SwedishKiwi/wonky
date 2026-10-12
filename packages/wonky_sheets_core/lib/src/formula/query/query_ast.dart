/// Typed AST of the Google Visualization API query language subset used by QUERY
/// (05 §16.1).
///
/// Nodes compare structurally through [QExpr.key] (column ids case-insensitively, function
/// names in lower case), which is how `group by`, `label` and `format` match select items.
library;

/// Arithmetic operators of the query language.
enum QArithOp {
  add('+', 'sum'),
  sub('-', 'difference'),
  mul('*', 'product'),
  div('/', 'quotient'),
  mod('%', 'modulo');

  const QArithOp(this.symbol, this.functionName);

  /// Operator symbol in query text.
  final String symbol;

  /// GViz function name (used in generated column labels).
  final String functionName;
}

/// Aggregation functions.
enum QAggFn { avg, count, max, min, sum }

/// Scalar functions (05 §16.1 `fn_name`).
enum QScalarFn {
  year(1),
  month(1),
  day(1),
  hour(1),
  minute(1),
  second(1),
  millisecond(1),
  quarter(1),
  dayofweek(1),
  now(0),
  datediff(2),
  todate(1),
  upper(1),
  lower(1);

  const QScalarFn(this.arity);

  /// Number of arguments the function takes.
  final int arity;

  /// Looks up a function by its case-insensitive name.
  static QScalarFn? byName(String name) {
    final l = name.toLowerCase();
    for (final f in values) {
      if (f.name == l) return f;
    }
    return null;
  }
}

/// Kinds of typed date/time literals.
enum QDateKind { date, datetime, timeofday }

/// A value expression.
sealed class QExpr {
  const QExpr();

  /// Canonical structural key; equal keys denote equal expressions.
  String get key;

  /// Direct sub-expressions.
  List<QExpr> get children => const [];

  /// Whether this expression contains an aggregation.
  bool get hasAggregate => children.any((c) => c is QAggregate || c.hasAggregate);

  @override
  bool operator ==(Object other) => other is QExpr && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => key;
}

/// A column identifier (`A`, `Col2`, `` `B` ``).
final class QColumn extends QExpr {
  /// Identifier as written (without backquotes).
  final String id;

  const QColumn(this.id);

  @override
  String get key => 'col:${id.toUpperCase()}';
}

/// A number literal.
final class QNumber extends QExpr {
  final double value;

  const QNumber(this.value);

  @override
  String get key => 'num:$value';
}

/// A string literal.
final class QString extends QExpr {
  final String value;

  const QString(this.value);

  @override
  String get key => 'str:$value';
}

/// `true` / `false`.
final class QBool extends QExpr {
  final bool value;

  const QBool(this.value);

  @override
  String get key => 'bool:$value';
}

/// `date '…'`, `datetime '…'` (alias `timestamp`), `timeofday '…'`.
final class QDateLiteral extends QExpr {
  final QDateKind kind;
  final String text;

  const QDateLiteral(this.kind, this.text);

  @override
  String get key => '${kind.name}:$text';
}

/// Unary minus.
final class QNegate extends QExpr {
  final QExpr operand;

  const QNegate(this.operand);

  @override
  List<QExpr> get children => [operand];

  @override
  String get key => 'neg(${operand.key})';
}

/// Binary arithmetic.
final class QArith extends QExpr {
  final QArithOp op;
  final QExpr left;
  final QExpr right;

  const QArith(this.op, this.left, this.right);

  @override
  List<QExpr> get children => [left, right];

  @override
  String get key => '${op.name}(${left.key},${right.key})';
}

/// `avg(x)`, `count(x)`, `max(x)`, `min(x)`, `sum(x)`.
final class QAggregate extends QExpr {
  final QAggFn fn;
  final QExpr argument;

  const QAggregate(this.fn, this.argument);

  @override
  List<QExpr> get children => [argument];

  @override
  String get key => 'agg:${fn.name}(${argument.key})';
}

/// A scalar function call.
final class QCall extends QExpr {
  final QScalarFn fn;
  final List<QExpr> args;

  const QCall(this.fn, this.args);

  @override
  List<QExpr> get children => args;

  @override
  String get key => 'fn:${fn.name}(${args.map((a) => a.key).join(',')})';
}

/// Comparison operators.
enum QCompareOp { eq, ne, lt, gt, le, ge }

/// String operators.
enum QStringOp { contains, startsWith, endsWith, matches, like }

/// A boolean condition (`where` clause).
sealed class QCond {
  const QCond();
}

/// `a or b or …`.
final class QOr extends QCond {
  final List<QCond> operands;
  const QOr(this.operands);
}

/// `a and b and …`.
final class QAnd extends QCond {
  final List<QCond> operands;
  const QAnd(this.operands);
}

/// `not a`.
final class QNot extends QCond {
  final QCond operand;
  const QNot(this.operand);
}

/// `x <op> y`.
final class QCompare extends QCond {
  final QCompareOp op;
  final QExpr left;
  final QExpr right;
  const QCompare(this.op, this.left, this.right);
}

/// `x contains y`, `x starts with y`, … .
final class QStringMatch extends QCond {
  final QStringOp op;
  final QExpr left;
  final QExpr right;
  const QStringMatch(this.op, this.left, this.right);
}

/// `x is null` / `x is not null`.
final class QIsNull extends QCond {
  final QExpr operand;
  final bool negated;
  const QIsNull(this.operand, {this.negated = false});
}

/// A bare boolean-valued expression used as a condition (`where C` for a boolean column).
final class QBoolValue extends QCond {
  final QExpr operand;
  const QBoolValue(this.operand);
}

/// One `order by` item.
final class QOrderItem {
  final QExpr expr;
  final bool descending;
  const QOrderItem(this.expr, {this.descending = false});
}

/// Query options.
enum QOption { noFormat, noValues }

/// A parsed query. Clause lists are empty when the clause is absent.
final class Query {
  /// Select items; null for `select *` or no select clause.
  final List<QExpr>? select;
  final QCond? where;
  final List<QExpr> groupBy;
  final List<QExpr> pivot;
  final List<QOrderItem> orderBy;
  final int? limit;
  final int? offset;
  final List<(QExpr, String)> labels;
  final List<(QExpr, String)> formats;
  final Set<QOption> options;

  const Query({
    this.select,
    this.where,
    this.groupBy = const [],
    this.pivot = const [],
    this.orderBy = const [],
    this.limit,
    this.offset,
    this.labels = const [],
    this.formats = const [],
    this.options = const {},
  });
}
