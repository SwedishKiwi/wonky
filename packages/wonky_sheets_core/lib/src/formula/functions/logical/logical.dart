import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../eval/range_access.dart';
import '../../values/coercion.dart';
import '../../values/compare.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../registry.dart';

/// Logical functions (05 §15.4). LET and LAMBDA are compiler special forms; they are
/// registered here for help, autocomplete and arity.
void registerLogical(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.logical;

  b.fn(
    'IF',
    'Returns one value if a logical expression is TRUE and another if it is FALSE.',
    [
      P.any('logical_expression', 'An expression or reference to a cell containing an expression that represents a logical value, i.e. TRUE or FALSE.'),
      P.lazy('value_if_true', 'The value the function returns if logical_expression is TRUE.'),
      P.lazy('value_if_false', 'The value the function returns if logical_expression is FALSE.', true),
    ],
    _if,
    priority: Priority.p0,
    liftable: false,
    handlesErrors: true,
    examples: ['IF(A2 > 100, "High", "Low")', 'IF(B2, "Yes", "No")'],
    seeAlso: ['IFS', 'SWITCH', 'IFERROR'],
  );

  b.fn(
    'IFS',
    'Evaluates multiple conditions and returns a value that corresponds to the first true condition.',
    [
      P.lazy('condition1', 'The first condition to be evaluated.'),
      P.lazy('value1', 'The returned value if condition1 is TRUE.'),
      P.rep('condition2', ArgKind.lazy, 'Additional conditions to be evaluated if the previous ones are FALSE.'),
      P.rep('value2', ArgKind.lazy, 'Additional values to be returned if their corresponding conditions are TRUE.'),
    ],
    _ifs,
    priority: Priority.p0,
    handlesErrors: true,
    examples: ['IFS(A1 > 90, "A", A1 > 80, "B", TRUE, "C")'],
    seeAlso: ['IF', 'SWITCH'],
  );

  b.fn(
    'IFERROR',
    'Returns the first argument if it is not an error value, otherwise returns the second argument if present, or a blank if absent.',
    [
      P.lazy('value', 'The value to return if value itself is not an error.'),
      P.lazy('value_if_error', 'The value the function returns if value is an error.', true),
    ],
    (a) => _catch(a, (e) => true),
    priority: Priority.p0,
    handlesErrors: true,
    examples: ['IFERROR(A1/B1, 0)', 'IFERROR(VLOOKUP(E2, A:B, 2, FALSE), "Not found")'],
    seeAlso: ['IFNA', 'ISERROR'],
  );

  b.fn(
    'IFNA',
    'Evaluates a value. If the value is an #N/A error, returns the specified value.',
    [
      P.lazy('value', 'The value to return if value itself is not an #N/A error.'),
      P.lazy('value_if_na', 'The value the function returns if value is an #N/A error.'),
    ],
    (a) => _catch(a, (e) => e.kind == ErrorKind.na),
    priority: Priority.p0,
    handlesErrors: true,
    examples: ['IFNA(VLOOKUP(E2, A:B, 2, FALSE), "Missing")'],
    seeAlso: ['IFERROR', 'ISNA'],
  );

  b.fn(
    'AND',
    'Returns TRUE if all of the provided arguments are logically true, and FALSE if any of the provided arguments are logically false.',
    [
      P.range('logical_expression1', 'An expression or reference to a cell containing an expression that represents some logical value.'),
      P.rep('logical_expression2', ArgKind.range, 'More expressions that represent logical values.'),
    ],
    (a) => _andOr(a, and: true),
    priority: Priority.p0,
    examples: ['AND(A1 > 0, A1 < 10)', 'AND(TRUE, FALSE)'],
    seeAlso: ['OR', 'NOT', 'XOR'],
  );

  b.fn(
    'OR',
    'Returns TRUE if any of the provided arguments are logically true, and FALSE if all of the provided arguments are logically false.',
    [
      P.range('logical_expression1', 'An expression or reference to a cell containing an expression that represents some logical value.'),
      P.rep('logical_expression2', ArgKind.range, 'More expressions that represent logical values.'),
    ],
    (a) => _andOr(a, and: false),
    priority: Priority.p0,
    examples: ['OR(A1 = "x", B1 = "y")'],
    seeAlso: ['AND', 'NOT', 'XOR'],
  );

  b.fn(
    'XOR',
    'Returns TRUE if an odd number of the provided arguments are logically true.',
    [
      P.range('logical_expression1', 'An expression or reference to a cell containing a logical value.'),
      P.rep('logical_expression2', ArgKind.range, 'More expressions.'),
    ],
    _xor,
    examples: ['XOR(TRUE, FALSE, TRUE)'],
    seeAlso: ['AND', 'OR'],
  );

  b.fn(
    'NOT',
    'Returns the opposite of a logical value.',
    [P.bool_('logical_expression', 'An expression or reference holding an expression that represents some logical value.')],
    (a) => FBool(!a.boolean(0)),
    priority: Priority.p0,
    examples: ['NOT(TRUE)', 'NOT(A1 > 5)'],
    seeAlso: ['AND', 'OR'],
  );

  b.fn('TRUE', 'Returns the logical value TRUE.', const [], (_) => FBool.t, priority: Priority.p0, examples: ['TRUE()']);
  b.fn('FALSE', 'Returns the logical value FALSE.', const [], (_) => FBool.f, priority: Priority.p0, examples: ['FALSE()']);

  b.fn(
    'SWITCH',
    'Tests an expression against a list of cases and returns the corresponding value of the first matching case, with an optional default value if nothing else is met.',
    [
      P.scalar('expression', 'Any valid value.'),
      P.lazy('case1', 'The first case to be checked against expression.'),
      P.lazy('value1', 'The corresponding value to be returned if case1 matches expression.'),
      P.rep('case2', ArgKind.lazy, 'Additional cases to try if the previous ones don\'t match expression.'),
      P.rep('value2', ArgKind.lazy, 'Additional values to be returned if their corresponding cases match expression.'),
    ],
    _switch,
    priority: Priority.p0,
    handlesErrors: true,
    liftable: false,
    examples: ['SWITCH(A1, 1, "One", 2, "Two", "Other")'],
    seeAlso: ['IFS', 'CHOOSE'],
  );

  b.fn(
    'LET',
    'Assigns names to calculation results and returns the result of the formula expression.',
    [
      P.any('name1', 'The name to assign. Must start with a letter and cannot be a cell reference.'),
      P.lazy('value_expression1', 'The formula whose result name1 refers to.'),
      P.rep('name2', ArgKind.any, 'More names.'),
      P.rep('value_expression2', ArgKind.lazy, 'More value expressions; the last argument is the formula expression.'),
    ],
    (_) => FError.value,
    minArgs: 3,
    examples: ['LET(x, 2, y, x * 3, x + y)'],
    seeAlso: ['LAMBDA'],
  );

  b.fn(
    'LAMBDA',
    'Creates and returns a custom function with a set of names and a formula_expression that uses them.',
    [
      P.rep('name', ArgKind.any, 'A name to be used in formula_expression.'),
      P.lazy('formula_expression', 'The formula to calculate.'),
    ],
    (_) => FError.value,
    minArgs: 1,
    examples: ['LAMBDA(x, x * 2)(5)', 'MAP(A1:A3, LAMBDA(v, v + 1))'],
    seeAlso: ['LET', 'MAP', 'REDUCE'],
  );

  b.fn(
    'ISOMITTED',
    'Checks whether the value in a LAMBDA parameter is missing.',
    [P.any('argument', 'The LAMBDA parameter to check.')],
    (a) => FBool(a[0] is FOmitted),
    priority: Priority.p2,
    handlesErrors: true,
    examples: ['LAMBDA(x, y, IF(ISOMITTED(y), x, x + y))(1)'],
  );
}

FValue _scalarOf(Args a, FValue v) {
  if (v is FRef) {
    return a.ctx.arrayMode && !v.area.isSingleCell
        ? RangeAccess.materialize(a.ctx, v)
        : RangeAccess.intersect(a.ctx, v);
  }
  if (v is FRich) return v.scalar;
  return v;
}

Object _truth(FValue v, String fn) {
  if (v is FText) {
    final u = v.v.toUpperCase();
    if (u == 'TRUE') return true;
    if (u == 'FALSE') return false;
    return FError(ErrorKind.value, "Function $fn parameter 1 expects boolean values. But '${v.v}' is a text and cannot be coerced to a boolean.");
  }
  return Coerce.toBool(v, fn: fn);
}

FValue _if(Args a) {
  final cond = _scalarOf(a, a[0]);
  if (cond is FArray) {
    // array condition (array mode or array-valued expression): element-wise
    FValue? t, f;
    FValue tv() => t ??= _branchValue(a, 1, true);
    FValue fv() => f ??= _branchValue(a, 2, true);
    return FArray.generate(cond.rows, cond.cols, (r, c) {
      final x = cond.at(r, c);
      if (x is FError) return x;
      final b = _truth(x, 'IF');
      if (b is FError) return b;
      final src = (b as bool) ? tv() : fv();
      return _elem(src, r, c);
    });
  }
  if (cond is FError) return cond;
  final b = _truth(cond, 'IF');
  if (b is FError) return b;
  if (b as bool) return a.hasLazy(1) ? _passValue(a.lazy(1)) : FBool.f;
  if (!a.hasLazy(2)) return a.length > 2 ? FEmpty.instance : FBool.f;
  return _passValue(a.lazy(2));
}

FValue _passValue(FValue v) => v is FOmitted ? FEmpty.instance : v;

FValue _branchValue(Args a, int i, bool arrayMode) {
  if (!a.hasLazy(i)) return i == 2 && a.length > 2 ? FEmpty.instance : FBool.f;
  var v = a.lazy(i);
  if (v is FRef) v = RangeAccess.deref(a.ctx, v);
  return v;
}

FValue _elem(FValue src, int r, int c) {
  if (src is FArray) {
    final rr = src.rows == 1 ? 0 : r;
    final cc = src.cols == 1 ? 0 : c;
    if (rr >= src.rows || cc >= src.cols) return FError.na;
    return src.at(rr, cc);
  }
  return src;
}

FValue _ifs(Args a) {
  final n = a.length;
  if (n.isOdd) {
    return FError(ErrorKind.na, ErrorMessages.wrongArgCount('IFS', 2, 255, n));
  }
  for (var i = 0; i < n; i += 2) {
    final c = _scalarOf(a, a.lazy(i));
    if (c is FArray) {
      // element-wise in array mode
      return _ifsArray(a, i);
    }
    if (c is FError) return c;
    final t = _truth(c, 'IFS');
    if (t is FError) return t;
    if (t as bool) return _passValue(a.lazy(i + 1));
  }
  return const FError(ErrorKind.na, 'No match.');
}

FValue _ifsArray(Args a, int start) {
  final conds = <FValue>[];
  final vals = <FValue>[];
  for (var i = start; i < a.length; i += 2) {
    conds.add(_scalarOf(a, a.lazy(i)));
    var v = a.lazy(i + 1);
    if (v is FRef) v = RangeAccess.deref(a.ctx, v);
    vals.add(v);
  }
  var rows = 1, cols = 1;
  for (final c in conds) {
    if (c is FArray) {
      if (c.rows > rows) rows = c.rows;
      if (c.cols > cols) cols = c.cols;
    }
  }
  return FArray.generate(rows, cols, (r, c) {
    for (var k = 0; k < conds.length; k++) {
      final x = _elem(conds[k], r, c);
      if (x is FError) return x;
      final t = _truth(x, 'IFS');
      if (t is FError) return t;
      if (t as bool) return _elem(vals[k], r, c);
    }
    return const FError(ErrorKind.na, 'No match.');
  });
}

FValue _catch(Args a, bool Function(FError e) catches) {
  var v = a.lazy(0);
  if (v is FOmitted) v = FEmpty.instance;
  if (v is FRef) {
    if (v.area.isSingleCell) {
      final x = RangeAccess.cell(a.ctx, v);
      if (x is FError && !x.pending && catches(x)) return _fallback(a);
      return v;
    }
    if (a.ctx.arrayMode) v = RangeAccess.materialize(a.ctx, v);
  }
  if (v is FArray) {
    FValue? fb;
    return FArray.generate(v.rows, v.cols, (r, c) {
      final x = v is FArray ? v.at(r, c) : v;
      if (x is FError && !x.pending && catches(x)) {
        fb ??= _fallback(a);
        return _elem(fb!, r, c);
      }
      return x;
    });
  }
  if (v is FError && !v.pending && catches(v)) return _fallback(a);
  return v;
}

FValue _fallback(Args a) {
  if (!a.hasLazy(1)) return FEmpty.instance;
  var v = a.lazy(1);
  if (v is FOmitted) return FEmpty.instance;
  if (v is FRef) v = RangeAccess.deref(a.ctx, v);
  return v;
}

FValue _andOr(Args a, {required bool and}) {
  var any = false;
  var result = and;
  for (var i = 0; i < a.length; i++) {
    final v = a[i];
    if (v is FOmitted) continue;
    if (v is FRef || v is FArray) {
      FError? err;
      RangeAccess.forEach(a.ctx, v, (x) {
        if (err != null) return;
        if (x is FRich) x = x.scalar;
        switch (x) {
          case FError():
            err = x;
          case FBool(:final v):
            any = true;
            result = and ? (result && v) : (result || v);
          case FNumber(:final v):
            any = true;
            result = and ? (result && v != 0) : (result || v != 0);
          default:
            break; // text and blanks ignored
        }
      });
      if (err != null) return err!;
      continue;
    }
    var x = v;
    if (x is FRich) x = x.scalar;
    if (x is FError) return x;
    if (x is FEmpty) continue;
    final t = _truth(x, and ? 'AND' : 'OR');
    if (t is FError) return t;
    any = true;
    result = and ? (result && (t as bool)) : (result || (t as bool));
  }
  if (!any) {
    return FError(ErrorKind.value, 'Function ${and ? 'AND' : 'OR'} parameter 1 expects boolean values.');
  }
  return FBool(result);
}

FValue _xor(Args a) {
  var count = 0;
  var any = false;
  for (var i = 0; i < a.length; i++) {
    final v = a[i];
    if (v is FRef || v is FArray) {
      FError? err;
      RangeAccess.forEach(a.ctx, v, (x) {
        if (err != null) return;
        if (x is FRich) x = x.scalar;
        if (x is FError) err = x;
        if (x is FBool) {
          any = true;
          if (x.v) count++;
        }
        if (x is FNumber) {
          any = true;
          if (x.v != 0) count++;
        }
      });
      if (err != null) return err!;
      continue;
    }
    if (v is FOmitted || v is FEmpty) continue;
    if (v is FError) return v;
    final t = _truth(v is FRich ? v.scalar : v, 'XOR');
    if (t is FError) return t;
    any = true;
    if (t as bool) count++;
  }
  if (!any) return FError(ErrorKind.value, 'Function XOR parameter 1 expects boolean values.');
  return FBool(count.isOdd);
}

FValue _switch(Args a) {
  final e = a.scalarOrError(0);
  if (e is FError) return e;
  final n = a.length;
  final pairs = (n - 1) ~/ 2;
  for (var k = 0; k < pairs; k++) {
    var c = a.lazy(1 + 2 * k);
    c = _scalarOf(a, c);
    if (c is FError) return c;
    if (Compare.compare(e, c) == 0 && _sameKind(e, c)) return _passValue(a.lazy(2 + 2 * k));
  }
  if ((n - 1).isOdd) return _passValue(a.lazy(n - 1));
  return const FError(ErrorKind.na, 'No match.');
}

bool _sameKind(FValue a, FValue b) {
  if (a is FEmpty || b is FEmpty) return true;
  return a.runtimeType == b.runtimeType;
}

/// Helper for other categories: evaluates a lazy arg as scalar.
FValue lazyScalar(EvalContext ctx, FValue v) {
  if (v is FRef) return RangeAccess.intersect(ctx, v);
  return v;
}
