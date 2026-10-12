import '../../addressing/a1.dart';
import '../codec/ref_token.dart';
import '../values/errors.dart';

/// Source span (UTF-16 offsets) of an AST node.
final class SourceSpan {
  final int start;
  final int end;
  const SourceSpan(this.start, this.end);
  static const SourceSpan none = SourceSpan(0, 0);
  int get length => end - start;
  @override
  String toString() => '[$start,$end)';
}

/// Formula AST (05 §4.2). Equality ignores spans.
sealed class Expr {
  final SourceSpan span;
  const Expr(this.span);

  /// Child expressions in source order.
  Iterable<Expr> get children;

  /// Nesting depth of the tree.
  int get depth {
    var d = 0;
    for (final c in children) {
      final cd = c.depth;
      if (cd > d) d = cd;
    }
    return d + 1;
  }
}

final class NumberLit extends Expr {
  final double value;

  /// Source spelling (kept for printing fidelity).
  final String? text;
  const NumberLit(this.value, {this.text, SourceSpan span = SourceSpan.none}) : super(span);
  @override
  Iterable<Expr> get children => const [];
  @override
  bool operator ==(Object other) => other is NumberLit && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'Num($value)';
}

final class StringLit extends Expr {
  final String value;
  const StringLit(this.value, {SourceSpan span = SourceSpan.none}) : super(span);
  @override
  Iterable<Expr> get children => const [];
  @override
  bool operator ==(Object other) => other is StringLit && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'Str("$value")';
}

final class BoolLit extends Expr {
  final bool value;
  const BoolLit(this.value, {SourceSpan span = SourceSpan.none}) : super(span);
  @override
  Iterable<Expr> get children => const [];
  @override
  bool operator ==(Object other) => other is BoolLit && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'Bool($value)';
}

final class ErrorLit extends Expr {
  final ErrorKind kind;
  const ErrorLit(this.kind, {SourceSpan span = SourceSpan.none}) : super(span);
  @override
  Iterable<Expr> get children => const [];
  @override
  bool operator ==(Object other) => other is ErrorLit && other.kind == kind;
  @override
  int get hashCode => kind.hashCode;
  @override
  String toString() => 'Err(${kind.literal})';
}

final class ArrayLit extends Expr {
  final List<List<Expr>> rows;
  const ArrayLit(this.rows, {SourceSpan span = SourceSpan.none}) : super(span);
  @override
  Iterable<Expr> get children => [for (final r in rows) ...r];
  @override
  bool operator ==(Object other) {
    if (other is! ArrayLit || other.rows.length != rows.length) return false;
    for (var i = 0; i < rows.length; i++) {
      if (!_listEq(rows[i], other.rows[i])) return false;
    }
    return true;
  }

  @override
  int get hashCode => rows.length;
  @override
  String toString() => 'Array($rows)';
}

/// A reference: positional A1 (user text, or unconverted) or id-based stored form.
sealed class RefNode {
  const RefNode();
}

final class A1RefNode extends RefNode {
  final A1Area area;
  const A1RefNode(this.area);
  @override
  bool operator ==(Object other) => other is A1RefNode && other.area == area;
  @override
  int get hashCode => area.hashCode;
  @override
  String toString() => area.format();
}

final class StoredRefNode extends RefNode {
  final StoredRef ref;
  const StoredRefNode(this.ref);
  @override
  bool operator ==(Object other) => other is StoredRefNode && other.ref == ref;
  @override
  int get hashCode => ref.hashCode;
  @override
  String toString() => ref.encode();
}

/// Template slot `⟦#n⟧`: the n-th stored reference of the cell (05 §7.2 templates).
final class SlotRefNode extends RefNode {
  final int index;
  const SlotRefNode(this.index);
  @override
  bool operator ==(Object other) => other is SlotRefNode && other.index == index;
  @override
  int get hashCode => index.hashCode;
  @override
  String toString() => '#$index';
}

final class RefExpr extends Expr {
  final RefNode ref;
  const RefExpr(this.ref, {SourceSpan span = SourceSpan.none}) : super(span);
  @override
  Iterable<Expr> get children => const [];
  @override
  bool operator ==(Object other) => other is RefExpr && other.ref == ref;
  @override
  int get hashCode => ref.hashCode;
  @override
  String toString() => 'Ref($ref)';
}

final class NameExpr extends Expr {
  final String name;
  const NameExpr(this.name, {SourceSpan span = SourceSpan.none}) : super(span);
  @override
  Iterable<Expr> get children => const [];
  @override
  bool operator ==(Object other) =>
      other is NameExpr && other.name.toUpperCase() == name.toUpperCase();
  @override
  int get hashCode => name.toUpperCase().hashCode;
  @override
  String toString() => 'Name($name)';
}

/// Function call; `null` arguments are omitted (`f(1,,3)`).
final class CallExpr extends Expr {
  final String name;
  final List<Expr?> args;

  /// Span of the function name.
  final SourceSpan nameSpan;
  const CallExpr(
    this.name,
    this.args, {
    SourceSpan span = SourceSpan.none,
    this.nameSpan = SourceSpan.none,
  }) : super(span);
  @override
  Iterable<Expr> get children => [for (final a in args) ?a];
  @override
  bool operator ==(Object other) =>
      other is CallExpr &&
      other.name.toUpperCase() == name.toUpperCase() &&
      _listEq(other.args, args);
  @override
  int get hashCode => name.toUpperCase().hashCode;
  @override
  String toString() => 'Call($name, $args)';
}

/// Invocation of a function value: `LAMBDA(x, x+1)(5)`.
final class InvokeExpr extends Expr {
  final Expr callee;
  final List<Expr?> args;
  const InvokeExpr(this.callee, this.args, {SourceSpan span = SourceSpan.none}) : super(span);
  @override
  Iterable<Expr> get children => [callee, for (final a in args) ?a];
  @override
  bool operator ==(Object other) =>
      other is InvokeExpr && other.callee == callee && _listEq(other.args, args);
  @override
  int get hashCode => callee.hashCode;
  @override
  String toString() => 'Invoke($callee, $args)';
}

enum UnaryOp {
  plus('+', 'UPLUS'),
  minus('-', 'UMINUS');

  const UnaryOp(this.symbol, this.functionName);
  final String symbol;
  final String functionName;
}

final class UnaryExpr extends Expr {
  final UnaryOp op;
  final Expr operand;
  const UnaryExpr(this.op, this.operand, {SourceSpan span = SourceSpan.none}) : super(span);
  @override
  Iterable<Expr> get children => [operand];
  @override
  bool operator ==(Object other) =>
      other is UnaryExpr && other.op == op && other.operand == operand;
  @override
  int get hashCode => Object.hash(op, operand);
  @override
  String toString() => 'Unary(${op.symbol}, $operand)';
}

final class PercentExpr extends Expr {
  final Expr operand;
  const PercentExpr(this.operand, {SourceSpan span = SourceSpan.none}) : super(span);
  @override
  Iterable<Expr> get children => [operand];
  @override
  bool operator ==(Object other) => other is PercentExpr && other.operand == operand;
  @override
  int get hashCode => operand.hashCode;
  @override
  String toString() => 'Percent($operand)';
}

enum BinaryOp {
  add('+', 'ADD'),
  sub('-', 'MINUS'),
  mul('*', 'MULTIPLY'),
  div('/', 'DIVIDE'),
  pow('^', 'POW'),
  concat('&', 'CONCAT'),
  eq('=', 'EQ'),
  ne('<>', 'NE'),
  lt('<', 'LT'),
  gt('>', 'GT'),
  le('<=', 'LTE'),
  ge('>=', 'GTE');

  const BinaryOp(this.symbol, this.functionName);
  final String symbol;

  /// Operator function name used in error messages (Sheets parity).
  final String functionName;

  bool get isComparison => index >= BinaryOp.eq.index;
}

final class BinaryExpr extends Expr {
  final BinaryOp op;
  final Expr left;
  final Expr right;
  const BinaryExpr(this.op, this.left, this.right, {SourceSpan span = SourceSpan.none})
    : super(span);
  @override
  Iterable<Expr> get children => [left, right];
  @override
  bool operator ==(Object other) =>
      other is BinaryExpr && other.op == op && other.left == left && other.right == right;
  @override
  int get hashCode => Object.hash(op, left, right);
  @override
  String toString() => 'Binary(${op.symbol}, $left, $right)';
}

/// Range operator between reference-valued expressions: `A1:INDEX(B:B, 5)`.
final class RangeOpExpr extends Expr {
  final Expr left;
  final Expr right;
  const RangeOpExpr(this.left, this.right, {SourceSpan span = SourceSpan.none}) : super(span);
  @override
  Iterable<Expr> get children => [left, right];
  @override
  bool operator ==(Object other) =>
      other is RangeOpExpr && other.left == left && other.right == right;
  @override
  int get hashCode => Object.hash(left, right);
  @override
  String toString() => 'RangeOp($left, $right)';
}

/// Parenthesized expression, kept for printing fidelity.
final class ParenExpr extends Expr {
  final Expr inner;
  const ParenExpr(this.inner, {SourceSpan span = SourceSpan.none}) : super(span);
  @override
  Iterable<Expr> get children => [inner];
  @override
  int get depth => inner.depth;
  @override
  bool operator ==(Object other) => other is ParenExpr && other.inner == inner;
  @override
  int get hashCode => inner.hashCode;
  @override
  String toString() => 'Paren($inner)';
}

bool _listEq(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
