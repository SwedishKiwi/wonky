import 'dart:math' as math;

import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../values/coercion.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../helpers.dart';
import '../registry.dart';
import 'common.dart';

final _nested = RegExp(r'\b(SUBTOTAL|AGGREGATE)\s*\(');

/// A collected value; [inRange] values follow range rules (text/booleans ignored).
typedef _Item = (FValue value, bool inRange);

/// Collects the values of arguments [from]..[to] for SUBTOTAL/AGGREGATE.
List<_Item> _collect(
  Args a,
  int from,
  int to, {
  required bool skipHidden,
  required bool includeUserHidden,
  required bool skipNested,
  required bool ignoreErrors,
}) {
  final out = <_Item>[];
  final host = a.ctx.host;
  for (var i = from; i < to; i++) {
    final v = a[i];
    switch (v) {
      case FRef():
        a.ctx.deps.filter = true;
        if (v.dynamic) a.ctx.deps.areas.add(v.area);
        final s = a.sheetOfRef(v);
        final hidden = <int, bool>{};
        host.forEachValue(s, v.area.rect, (r, c, x) {
          if (skipHidden &&
              hidden.putIfAbsent(
                r,
                () => host.isRowHidden(
                  s,
                  r,
                  includeUserHidden: includeUserHidden,
                ),
              )) {
            return;
          }
          if (skipNested) {
            final f = host.formulaAt(s, r, c);
            if (f != null && _nested.hasMatch(f.toUpperCase())) return;
          }
          if (x is FRich) x = x.scalar;
          if (x is FEmpty || (x is FError && ignoreErrors)) return;
          out.add((x, true));
        });
      case FArray():
        for (var x in v.elements) {
          if (x is FRich) x = x.scalar;
          if (x is FEmpty || (x is FError && ignoreErrors)) continue;
          out.add((x, true));
        }
      case FOmitted():
        break;
      default:
        var x = v;
        if (x is FRich) x = x.scalar;
        if (x is FError && ignoreErrors) break;
        out.add((x, false));
    }
  }
  return out;
}

List<double> _numbers(Args a, List<_Item> items) {
  final out = <double>[];
  for (final (v, inRange) in items) {
    switch (v) {
      case FNumber(:final v):
        out.add(v);
      case FError():
        throw FormulaError(v);
      default:
        if (inRange) break;
        final r = Coerce.toNumber(v, a.locale, fn: a.fn, param: 2);
        if (r is FError) throw FormulaError(r);
        out.add(r as double);
    }
  }
  return out;
}

/// Applies aggregate [code] (1–13) to [items].
FValue _apply(Args a, int code, List<_Item> items) {
  switch (code) {
    case 2:
      var n = 0;
      for (final (v, inRange) in items) {
        if (v is FNumber || (!inRange && isCountableScalar(v, a))) n++;
      }
      return FNumber(n.toDouble());
    case 3:
      return FNumber(items.length.toDouble());
  }
  final xs = _numbers(a, items);
  switch (code) {
    case 1:
      if (xs.isEmpty) divZero(a);
      return numResult(meanOf(xs));
    case 4:
      return xs.isEmpty ? FNumber.zero : numResult(xs.reduce(math.max));
    case 5:
      return xs.isEmpty ? FNumber.zero : numResult(xs.reduce(math.min));
    case 6:
      if (xs.isEmpty) return FNumber.zero;
      return numResult(xs.fold(1.0, (p, x) => p * x));
    case 7:
      return numResult(math.sqrt(variance(a, xs, sample: true)));
    case 8:
      return numResult(math.sqrt(variance(a, xs, sample: false)));
    case 9:
      return numResult(sumOf(xs));
    case 10:
      return numResult(variance(a, xs, sample: true));
    case 11:
      return numResult(variance(a, xs, sample: false));
    case 12:
      if (xs.isEmpty) fail(ErrorKind.num);
      xs.sort();
      final n = xs.length;
      return numResult(
        n.isOdd ? xs[n ~/ 2] : (xs[n ~/ 2 - 1] + xs[n ~/ 2]) / 2,
      );
    case 13:
      final m = modes(xs);
      if (m.isEmpty) fail(ErrorKind.na, 'No mode for the data in ${a.fn}.');
      return numResult(m.first);
  }
  fail(ErrorKind.value);
}

/// Applies the array-form aggregate [code] (14–19) with parameter [k].
FValue _applyK(Args a, int code, List<_Item> items, double k) {
  final xs = _numbers(a, items)..sort();
  if (xs.isEmpty) fail(ErrorKind.num);
  switch (code) {
    case 14 || 15:
      final n = k.ceil();
      if (n < 1 || n > xs.length) fail(ErrorKind.num);
      return numResult(code == 14 ? xs[xs.length - n] : xs[n - 1]);
    case 16:
      if (k < 0 || k > 1) fail(ErrorKind.num);
      return numResult(percentileInc(xs, k));
    case 17:
      final q = k.truncate();
      if (q < 0 || q > 4) fail(ErrorKind.num);
      return numResult(percentileInc(xs, q / 4));
    case 18:
      if (k <= 0 || k >= 1) fail(ErrorKind.num);
      final r = percentileExc(xs, k);
      if (r == null) fail(ErrorKind.num);
      return numResult(r);
    default: // 19
      final q = k.truncate();
      if (q < 1 || q > 3) fail(ErrorKind.num);
      final r = percentileExc(xs, q / 4);
      if (r == null) fail(ErrorKind.num);
      return numResult(r);
  }
}

/// SUBTOTAL and AGGREGATE (05 §15.1).
void registerSubtotal(FunctionRegistryBuilder b) {
  b.fn(
    'SUBTOTAL',
    'Returns a subtotal for a vertical range of cells using a specified aggregation function.',
    [
      P.num(
        'function_code',
        'The function to use in subtotal aggregation: 1–11 ignore filtered rows; 101–111 also ignore hidden rows.',
      ),
      P.range('range1', 'The first range over which to calculate a subtotal.'),
      P.rep(
        'range2',
        ArgKind.range,
        'Additional ranges over which to calculate subtotals.',
      ),
    ],
    (a) {
      final code = a.integer(0);
      final base = code > 100 ? code - 100 : code;
      if (base < 1 || base > 11 || (code > 11 && code < 101)) {
        fail(
          ErrorKind.value,
          'Function SUBTOTAL parameter 1 value $code is not a valid function code.',
        );
      }
      final items = _collect(
        a,
        1,
        a.length,
        skipHidden: true,
        includeUserHidden: code > 100,
        skipNested: true,
        ignoreErrors: false,
      );
      if (base != 2 && base != 3) {
        for (final (v, _) in items) {
          if (v is FError) throw FormulaError(v);
        }
      }
      return _apply(a, base, items);
    },
    category: FunctionCategory.math,
    usesFilterVisibility: true,
    priority: Priority.p0,
    examples: ['SUBTOTAL(9, A2:A100)', 'SUBTOTAL(109, A2:A100)'],
    seeAlso: ['AGGREGATE', 'SUM'],
    notes:
        'Codes 1–11: AVERAGE, COUNT, COUNTA, MAX, MIN, PRODUCT, STDEV, STDEVP, SUM, VAR, VARP. '
        'Cells containing SUBTOTAL or AGGREGATE formulas are skipped.',
  );
  b.fn(
    'AGGREGATE',
    'Returns an aggregate of a list or database, with options to ignore hidden rows, error values and nested subtotals.',
    [
      P.num('function_num', 'The function to use (1–19).'),
      P.num('options', 'Which values to ignore (0–7).'),
      P.array(
        'ref1',
        'The first range or array; for functions 14–19 the array to evaluate.',
      ),
      P.rep(
        'ref2',
        ArgKind.array,
        'Additional ranges; for functions 14–19 the k argument.',
      ),
    ],
    (a) {
      final fn = a.integer(0), opt = a.integer(1);
      if (fn < 1 || fn > 19 || opt < 0 || opt > 7) fail(ErrorKind.value);
      final skipHidden = opt == 1 || opt == 3 || opt == 5 || opt == 7;
      final ignoreErrors = opt == 2 || opt == 3 || opt == 6 || opt == 7;
      final skipNested = opt <= 3;
      if (fn >= 14) {
        if (a.length < 4) {
          fail(
            ErrorKind.value,
            'AGGREGATE function $fn requires a k argument.',
          );
        }
        final items = _collect(
          a,
          2,
          3,
          skipHidden: skipHidden,
          includeUserHidden: true,
          skipNested: skipNested,
          ignoreErrors: ignoreErrors,
        );
        return _applyK(a, fn, items, a.number(3));
      }
      final items = _collect(
        a,
        2,
        a.length,
        skipHidden: skipHidden,
        includeUserHidden: true,
        skipNested: skipNested,
        ignoreErrors: ignoreErrors,
      );
      if (fn != 2 && fn != 3) {
        for (final (v, _) in items) {
          if (v is FError) throw FormulaError(v);
        }
      }
      return _apply(a, fn, items);
    },
    category: FunctionCategory.math,
    usesFilterVisibility: true,
    examples: ['AGGREGATE(9, 6, A2:A100)', 'AGGREGATE(14, 6, A2:A100, 2)'],
    seeAlso: ['SUBTOTAL'],
    notes:
        'Functions: 1 AVERAGE, 2 COUNT, 3 COUNTA, 4 MAX, 5 MIN, 6 PRODUCT, 7 STDEV.S, 8 STDEV.P, '
        '9 SUM, 10 VAR.S, 11 VAR.P, 12 MEDIAN, 13 MODE.SNGL, 14 LARGE, 15 SMALL, 16 PERCENTILE.INC, '
        '17 QUARTILE.INC, 18 PERCENTILE.EXC, 19 QUARTILE.EXC. Options: 0–3 ignore nested '
        'SUBTOTAL/AGGREGATE, 1/3/5/7 hidden rows, 2/3/6/7 error values.',
  );
}
