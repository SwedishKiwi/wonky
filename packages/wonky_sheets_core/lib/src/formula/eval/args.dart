import '../functions/function_spec.dart';
import '../model/workbook_view.dart';
import '../parser/formula_locale.dart';
import '../values/coercion.dart';
import '../values/errors.dart';
import '../values/format_hint.dart';
import '../values/fvalue.dart';
import 'eval_context.dart';
import 'lambda.dart';
import 'range_access.dart';

/// How aggregates treat values inside ranges/arrays (05 §6.3).
enum AggMode {
  /// Numbers only; text, booleans and blanks ignored (SUM, AVERAGE, …).
  numbers,

  /// Text counts as 0 and booleans as 0/1 (AVERAGEA, MAXA, …).
  a,
}

/// Evaluated arguments of one call, with coercion helpers for implementations.
///
/// Helpers throw [FormulaError] for errors; the dispatcher turns them into values.
final class Args {
  final EvalContext ctx;
  final FunctionSpec spec;
  final List<FValue> _values;
  final List<CompiledExpr?> _thunks;

  Args(this.ctx, this.spec, this._values, this._thunks);

  int get length => _values.length;
  String get fn => spec.name;
  FormulaLocale get locale => ctx.locale;

  FValue operator [](int i) =>
      i < _values.length ? _values[i] : FOmitted.instance;

  /// Whether argument [i] was given (not omitted).
  bool has(int i) =>
      i < _values.length &&
      (_values[i] is! FOmitted || _thunks.length > i && _thunks[i] != null);

  /// Raw list of values.
  List<FValue> get values => _values;

  // ---------------------------------------------------------------- scalars

  FValue _scalar(int i) {
    var v = this[i];
    if (v is FRich) v = v.scalar;
    if (v is FRef) v = RangeAccess.intersect(ctx, v);
    if (v is FArray) v = v.topLeft;
    if (v is FRich) v = v.scalar;
    return v;
  }

  /// Scalar value; errors throw.
  FValue scalar(int i) {
    final v = _scalar(i);
    if (v is FError) throw FormulaError(v);
    return v;
  }

  /// Scalar value; errors are returned as values.
  FValue scalarOrError(int i) => _scalar(i);

  double _toNumber(FValue v, int i) {
    final r = Coerce.toNumber(
      v,
      locale,
      fn: fn,
      param: i + 1,
      currentYear: ctx.currentYear,
    );
    if (r is FError) throw FormulaError(r);
    final d = r as double;
    return d;
  }

  /// Number coercion of argument [i] (omitted → 0).
  double number(int i) => _toNumber(_scalar(i), i);

  /// Number or [d] when omitted (or blank when [blankIsDefault]).
  double numberOr(int i, double d, {bool blankIsDefault = false}) {
    if (!has(i)) return d;
    final v = _scalar(i);
    if (v is FOmitted || (blankIsDefault && v is FEmpty)) return d;
    return _toNumber(v, i);
  }

  /// Integer (truncated toward zero).
  int integer(int i) => _trunc(number(i));

  int intOr(int i, int d) => has(i) ? _trunc(numberOr(i, d.toDouble())) : d;

  static int _trunc(double x) {
    if (!x.isFinite) fail(ErrorKind.num);
    if (x.abs() > 9.0e15) return x < 0 ? -9000000000000000 : 9000000000000000;
    return x.truncate();
  }

  /// Text coercion.
  String text(int i) {
    final r = Coerce.toText(_scalar(i), locale);
    if (r is FError) throw FormulaError(r);
    return r as String;
  }

  String textOr(int i, String d) {
    if (!has(i)) return d;
    final v = _scalar(i);
    if (v is FOmitted) return d;
    final r = Coerce.toText(v, locale);
    if (r is FError) throw FormulaError(r);
    return r as String;
  }

  /// Boolean coercion.
  bool boolean(int i) {
    final r = Coerce.toBool(_scalar(i), fn: fn, param: i + 1);
    if (r is FError) throw FormulaError(r);
    return r as bool;
  }

  bool boolOr(int i, bool d) {
    if (!has(i)) return d;
    final v = _scalar(i);
    if (v is FOmitted) return d;
    final r = Coerce.toBool(v, fn: fn, param: i + 1);
    if (r is FError) throw FormulaError(r);
    return r as bool;
  }

  // ---------------------------------------------------------------- ranges

  /// Argument as dense array (references materialized and clamped).
  FArray array(int i) => RangeAccess.toArray(ctx, this[i]);

  /// Argument as reference, else `#VALUE!` (or [message]).
  FRef ref(int i, [String? message]) {
    final v = this[i];
    if (v is FRef) return v;
    if (v is FError) throw FormulaError(v);
    fail(
      ErrorKind.value,
      message ?? 'Function $fn parameter ${i + 1} expects a range.',
    );
  }

  /// Whether argument [i] is a reference.
  bool isRef(int i) => this[i] is FRef;

  /// Shape (rows, cols) of argument [i].
  (int, int) shape(int i) => RangeAccess.shape(this[i]);

  /// Visits values of argument [i] (references skip blanks).
  void forEach(int i, void Function(FValue v) visit) =>
      RangeAccess.forEach(ctx, this[i], visit);

  /// Flattened values (row-major for arrays; references materialized).
  List<FValue> flat(int i) {
    final v = this[i];
    if (v is FRef || v is FArray) return array(i).elements.toList();
    if (v is FRich) return [v.scalar];
    return [v];
  }

  // ---------------------------------------------------------------- lazy & lambdas

  /// Evaluates lazy argument [i] in the current mode (omitted → [FOmitted]).
  FValue lazy(int i) {
    if (i >= _thunks.length) return FOmitted.instance;
    final t = _thunks[i];
    if (t == null) return FOmitted.instance;
    return t(ctx);
  }

  /// Evaluates lazy argument [i] and dereferences it to a scalar value (errors returned).
  FValue lazyScalar(int i) {
    var v = lazy(i);
    if (v is FRef) {
      v = ctx.arrayMode
          ? RangeAccess.materialize(ctx, v)
          : RangeAccess.intersect(ctx, v);
    }
    if (v is FRich) v = v.scalar;
    return v;
  }

  /// Whether lazy argument [i] was given.
  bool hasLazy(int i) => i < _thunks.length && _thunks[i] != null;

  /// Lambda argument.
  FCallable lambda(int i) {
    final v = this[i];
    if (v is FLambda) return v.closure;
    if (v is FError) throw FormulaError(v);
    fail(ErrorKind.value, 'Argument ${i + 1} of $fn must be a LAMBDA.');
  }

  /// Calls a function value.
  FValue call(FCallable f, List<FValue> args) => invokeCallable(ctx, f, args);

  // ---------------------------------------------------------------- aggregates

  /// Numbers of arguments [from]..[to] per aggregate rules. Errors throw.
  List<double> numbers({
    int from = 0,
    int? to,
    AggMode mode = AggMode.numbers,
  }) {
    final out = <double>[];
    collectNumbers(out, from: from, to: to, mode: mode);
    return out;
  }

  /// Collects numbers into [out]; returns the hint of the first numeric value found in a
  /// formatted range (SUM/AVERAGE/MIN/MAX hint rule, 05 §6.2).
  FormatHint collectNumbers(
    List<double> out, {
    int from = 0,
    int? to,
    AggMode mode = AggMode.numbers,
  }) {
    var hint = FormatHint.none;
    var hintChecked = false;
    final end = to ?? length;
    for (var i = from; i < end; i++) {
      final v = this[i];
      if (v is FRef) {
        final s = RangeAccess.sheetOf(ctx, v.area);
        if (s == null) fail(ErrorKind.ref, ErrorMessages.referenceDoesNotExist);
        if (v.dynamic) ctx.deps.areas.add(v.area);
        ctx.host.forEachValue(s, v.area.rect, (r, c, x) {
          if (x is FRich) x = x.scalar;
          switch (x) {
            case FNumber(:final v):
              if (!hintChecked) {
                hintChecked = true;
                hint = x.hint.isNone ? ctx.host.cellHint(s, r, c) : x.hint;
              }
              out.add(v);
            case FError():
              throw FormulaError(x);
            case FBool(:final v):
              if (mode == AggMode.a) out.add(v ? 1 : 0);
            case FText():
              if (mode == AggMode.a) out.add(0);
            default:
              break;
          }
        });
      } else if (v is FArray) {
        for (var r = 0; r < v.rows; r++) {
          for (var c = 0; c < v.cols; c++) {
            var x = v.at(r, c);
            if (x is FRich) x = x.scalar;
            switch (x) {
              case FNumber(:final v):
                if (!hintChecked) {
                  hintChecked = true;
                  hint = x.hint;
                }
                out.add(v);
              case FError():
                throw FormulaError(x);
              case FBool(:final v):
                if (mode == AggMode.a) out.add(v ? 1 : 0);
              case FText():
                if (mode == AggMode.a) out.add(0);
              default:
                break;
            }
          }
        }
      } else if (v is FOmitted) {
        continue;
      } else {
        // direct scalar argument: coerced
        var x = v;
        if (x is FRich) x = x.scalar;
        if (x is FError) throw FormulaError(x);
        if (x is FEmpty) {
          if (mode == AggMode.a) out.add(0);
          continue;
        }
        if (x is FNumber && !hintChecked) {
          hintChecked = true;
          hint = x.hint;
        }
        out.add(_toNumber(x, i));
      }
    }
    return hint;
  }

  /// Sheet of a reference argument.
  SheetView sheetOfRef(FRef r) {
    final s = RangeAccess.sheetOf(ctx, r.area);
    if (s == null) fail(ErrorKind.ref, ErrorMessages.referenceDoesNotExist);
    return s;
  }
}
