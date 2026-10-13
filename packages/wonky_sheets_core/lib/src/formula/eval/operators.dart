import 'dart:math' as math;

import '../ast/ast.dart';
import '../parser/formula_locale.dart';
import '../values/coercion.dart';
import '../values/compare.dart';
import '../values/errors.dart';
import '../values/format_hint.dart';
import '../values/fvalue.dart';
import '../values/numeric.dart';

/// Scalar operator semantics (05 §3.5) shared by the compiler and the operator functions
/// (ADD, MINUS, …, 05 §15.16), plus element-wise broadcasting.
abstract final class Operators {
  static const int maxText = 50000;

  static FValue _num(
    FValue v,
    FormulaLocale loc,
    String fn,
    int param,
    int year,
    void Function(double) ok,
  ) {
    final r = Coerce.toNumber(v, loc, fn: fn, param: param, currentYear: year);
    if (r is FError) return r;
    ok(r as double);
    return FEmpty.instance;
  }

  /// Applies [op] to two scalars.
  static FValue binary(
    BinaryOp op,
    FValue a,
    FValue b,
    FormulaLocale loc, {
    int year = 2000,
  }) {
    if (a is FRich) a = a.scalar;
    if (b is FRich) b = b.scalar;
    if (op.isComparison) {
      if (a is FError) return a;
      if (b is FError) return b;
      final c = Compare.compare(a, b);
      final r = switch (op) {
        BinaryOp.eq => c == 0,
        BinaryOp.ne => c != 0,
        BinaryOp.lt => c < 0,
        BinaryOp.gt => c > 0,
        BinaryOp.le => c <= 0,
        BinaryOp.ge => c >= 0,
        _ => false,
      };
      return FBool(r);
    }
    if (op == BinaryOp.concat) {
      final x = Coerce.toText(a, loc);
      if (x is FError) return x;
      final y = Coerce.toText(b, loc);
      if (y is FError) return y;
      final s = '$x$y';
      if (s.length > maxText) {
        return FError(ErrorKind.value, ErrorMessages.textTooLong('CONCAT'));
      }
      return FText(s);
    }
    final fn = op.functionName;
    double x = 0, y = 0;
    final ea = _num(a, loc, fn, 1, year, (v) => x = v);
    if (ea is FError) return ea;
    final eb = _num(b, loc, fn, 2, year, (v) => y = v);
    if (eb is FError) return eb;
    final ha = a is FNumber ? a.hint : FormatHint.none;
    final hb = b is FNumber ? b.hint : FormatHint.none;
    switch (op) {
      case BinaryOp.add:
        return _finite(Numeric.add(x, y), _addHint(ha, hb));
      case BinaryOp.sub:
        return _finite(Numeric.sub(x, y), _subHint(ha, hb));
      case BinaryOp.mul:
        return _finite(x * y, _mulHint(ha, hb));
      case BinaryOp.div:
        if (y == 0) {
          return FError(ErrorKind.div0, ErrorMessages.divByZero('DIVIDE', 2));
        }
        return _finite(x / y, _mulHint(ha, FormatHint.none));
      case BinaryOp.pow:
        return power(x, y);
      default:
        return FError.value;
    }
  }

  /// `x ^ y` (Sheets: 0^0 = 1; negative base with fractional exponent → #NUM!).
  static FValue power(double x, double y) {
    if (x == 0 && y == 0) return FNumber.one;
    if (x == 0 && y < 0) {
      return FError(ErrorKind.div0, ErrorMessages.divByZero('POW', 1));
    }
    if (x < 0 && y != y.truncateToDouble()) return FError.num;
    final r = math.pow(x, y).toDouble();
    if (!r.isFinite) return FError.num;
    return FNumber(y == y.truncateToDouble() ? r : Numeric.stabilize(r));
  }

  static FValue _finite(double v, FormatHint h) =>
      v.isFinite ? FNumber(v, h) : FError.num;

  static bool _isTime(FormatHint h) => h.kind == FormatHintKind.time;
  static bool _dateish(FormatHint h) =>
      h.isDateLike || _isTime(h) || h.kind == FormatHintKind.duration;

  static FormatHint _addHint(FormatHint a, FormatHint b) {
    if (a.isDateLike && !b.isDateLike) {
      return _isTime(b) ? FormatHint.dateTime : a;
    }
    if (b.isDateLike && !a.isDateLike) {
      return _isTime(a) ? FormatHint.dateTime : b;
    }
    if (_isTime(a) && _isTime(b)) return FormatHint.time;
    if (a.isNone) return _dateish(b) ? b : _currencyOrPercent(b);
    if (b.isNone) return _dateish(a) ? a : _currencyOrPercent(a);
    if (a == b) return a;
    return FormatHint.none;
  }

  static FormatHint _currencyOrPercent(FormatHint h) =>
      h.kind == FormatHintKind.currency || h.kind == FormatHintKind.fromCell
      ? h
      : FormatHint.none;

  static FormatHint _subHint(FormatHint a, FormatHint b) {
    if (a.isDateLike && b.isDateLike) return FormatHint.none;
    if (a.isDateLike && !b.isDateLike) return a;
    if (_isTime(a) && _isTime(b)) return FormatHint.time;
    if (a.kind == FormatHintKind.currency && (b.isNone || b == a)) return a;
    if (a.isNone && b.kind == FormatHintKind.currency) return b;
    return FormatHint.none;
  }

  static FormatHint _mulHint(FormatHint a, FormatHint b) {
    if (a.kind == FormatHintKind.currency && b.isNone) return a;
    if (b.kind == FormatHintKind.currency && a.isNone) return b;
    return FormatHint.none;
  }

  /// Unary minus/plus.
  static FValue unary(
    UnaryOp op,
    FValue v,
    FormulaLocale loc, {
    int year = 2000,
  }) {
    if (v is FRich) v = v.scalar;
    if (op == UnaryOp.plus) {
      // UPLUS returns its argument unchanged (no coercion), like Sheets.
      return v is FOmitted ? FEmpty.instance : v;
    }
    final r = Coerce.toNumber(
      v,
      loc,
      fn: 'UMINUS',
      param: 1,
      currentYear: year,
    );
    if (r is FError) return r;
    final d = r as double;
    return FNumber(d == 0 ? 0.0 : -d, v is FNumber ? v.hint : FormatHint.none);
  }

  /// Postfix percent.
  static FValue percent(FValue v, FormulaLocale loc, {int year = 2000}) {
    if (v is FRich) v = v.scalar;
    final r = Coerce.toNumber(
      v,
      loc,
      fn: 'UNARY_PERCENT',
      param: 1,
      currentYear: year,
    );
    if (r is FError) return r;
    return FNumber((r as double) / 100, FormatHint.percent);
  }

  /// Broadcast shape of two operands; null when incompatible.
  static (int, int)? broadcastShape(int r1, int c1, int r2, int c2) {
    final r = r1 == r2 ? r1 : (r1 == 1 ? r2 : (r2 == 1 ? r1 : -1));
    final c = c1 == c2 ? c1 : (c1 == 1 ? c2 : (c2 == 1 ? c1 : -1));
    if (r < 0 || c < 0) return null;
    return (r, c);
  }

  /// Element of a broadcast operand.
  static FValue elem(FValue v, int r, int c) {
    if (v is FArray) {
      final rr = v.rows == 1 ? 0 : r;
      final cc = v.cols == 1 ? 0 : c;
      if (rr >= v.rows || cc >= v.cols) return FError.na;
      return v.at(rr, cc);
    }
    return v;
  }

  /// Element-wise application over arrays (scalars broadcast).
  static FValue lift2(
    FValue a,
    FValue b,
    String fn,
    FValue Function(FValue x, FValue y) f,
  ) {
    if (a is! FArray && b is! FArray) return f(a, b);
    final (r1, c1) = a is FArray ? (a.rows, a.cols) : (1, 1);
    final (r2, c2) = b is FArray ? (b.rows, b.cols) : (1, 1);
    final shape = broadcastShape(r1, c1, r2, c2);
    if (shape == null) {
      // Sheets pads mismatched arrays with #N/A.
      final rows = math.max(r1, r2), cols = math.max(c1, c2);
      return FArray.generate(rows, cols, (r, c) {
        final x = _padElem(a, r, c);
        final y = _padElem(b, r, c);
        if (x == null || y == null) return FError.na;
        return f(x, y);
      });
    }
    final (rows, cols) = shape;
    return FArray.generate(
      rows,
      cols,
      (r, c) => f(elem(a, r, c), elem(b, r, c)),
    );
  }

  static FValue? _padElem(FValue v, int r, int c) {
    if (v is! FArray) return v;
    final rr = v.rows == 1 ? 0 : r;
    final cc = v.cols == 1 ? 0 : c;
    if (rr >= v.rows || cc >= v.cols) return null;
    return v.at(rr, cc);
  }

  /// Element-wise unary application.
  static FValue lift1(FValue a, FValue Function(FValue x) f) {
    if (a is! FArray) return f(a);
    return FArray.generate(a.rows, a.cols, (r, c) => f(a.at(r, c)));
  }
}
