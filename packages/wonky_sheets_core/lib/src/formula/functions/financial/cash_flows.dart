import 'dart:math' as math;

import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../registry.dart';
import 'common.dart';

/// Discounted cash flow functions: NPV, IRR, XNPV, XIRR, MIRR.

const String _irrFailed = 'IRR could not find a result.';

double _npv0(double r, List<double> v) {
  var s = 0.0;
  for (var i = 0; i < v.length; i++) {
    s += v[i] / math.pow(1 + r, i);
  }
  return s;
}

double _dnpv0(double r, List<double> v) {
  var s = 0.0;
  for (var i = 1; i < v.length; i++) {
    s -= i * v[i] / math.pow(1 + r, i + 1);
  }
  return s;
}

double _xnpv(double r, List<double> v, List<double> d) {
  var s = 0.0;
  for (var i = 0; i < v.length; i++) {
    s += v[i] / math.pow(1 + r, (d[i] - d[0]) / 365);
  }
  return s;
}

double _dxnpv(double r, List<double> v, List<double> d) {
  var s = 0.0;
  for (var i = 1; i < v.length; i++) {
    final t = (d[i] - d[0]) / 365;
    s -= t * v[i] / math.pow(1 + r, t + 1);
  }
  return s;
}

/// Newton from [guess], falling back to bracketing + bisection on (-1, ∞).
double _solveRate(
  double Function(double) f,
  double Function(double) df,
  double guess,
) {
  final r =
      newton(f, df, guess, lower: -1) ?? bracketAndBisect(f, guess, lower: -1);
  if (r == null || !r.isFinite) fail(ErrorKind.num, _irrFailed);
  return r;
}

(List<double>, List<double>) _datedFlows(FunctionArgs a, int iv, int id) {
  final (v, d) = pairedFlows(a, iv, id);
  if (v.isEmpty) fail(ErrorKind.num);
  for (final x in d) {
    if (x < 0 || x < d[0]) {
      fail(
        ErrorKind.num,
        'Function ${a.fn}: all dates must be on or after the first date.',
      );
    }
  }
  return (v, d);
}

void registerCashFlows(FunctionRegistryBuilder b) {
  b.fn(
    'NPV',
    'Calculates the net present value of an investment based on a series of periodic cash flows and a discount rate.',
    [
      P.num('discount', 'The discount rate of the investment over one period.'),
      P.range('cashflow1', 'The first future cash flow.'),
      P.rep('cashflow2', ArgKind.range, 'Additional future cash flows.'),
    ],
    (a) {
      final r = a.number(0);
      if (r == -1) fail(ErrorKind.div0, ErrorMessages.divZeroEval(a.fn));
      final flows = <double>[];
      for (var i = 1; i < a.length; i++) {
        collectCashFlows(a, i, flows);
      }
      var s = 0.0;
      for (var i = 0; i < flows.length; i++) {
        s += flows[i] / math.pow(1 + r, i + 1);
      }
      return currencyResult(s);
    },
    priority: Priority.p0,
    examples: ['NPV(0.1, -10000, 3000, 4200, 6800)', 'NPV(0.08, B2:B6)'],
    seeAlso: ['XNPV', 'IRR', 'PV'],
  );
  b.fn(
    'IRR',
    'Calculates the internal rate of return on an investment based on a series of periodic cash flows.',
    [
      P.array(
        'cashflow_amounts',
        'An array or range containing the income or payments associated with the investment.',
      ),
      P.num(
        'rate_guess',
        'An estimate for what the internal rate of return will be.',
        true,
        0.1,
      ),
    ],
    (a) {
      final v = cashFlows(a, 0);
      final guess = a.numberOr(1, 0.1, blankIsDefault: true);
      if (!hasSignChange(v)) fail(ErrorKind.num, _irrFailed);
      return finResult(
        _solveRate((r) => _npv0(r, v), (r) => _dnpv0(r, v), guess),
      );
    },
    priority: Priority.p0,
    examples: [
      'IRR({-70000, 12000, 15000, 18000, 21000, 26000})',
      'IRR(A2:A6, 0.1)',
    ],
    seeAlso: ['XIRR', 'MIRR', 'NPV'],
  );
  b.fn(
    'XNPV',
    'Calculates the net present value of an investment based on a specified series of potentially irregularly spaced cash flows and a discount rate.',
    [
      P.num('discount', 'The discount rate of the investment over one period.'),
      P.array(
        'cashflow_amounts',
        'A range of cells containing the income or payments associated with the investment.',
      ),
      P.array(
        'cashflow_dates',
        'A range of cells with dates corresponding to the cash flows.',
      ),
    ],
    (a) {
      final r = a.number(0);
      if (r <= -1) fail(ErrorKind.num);
      final (v, d) = _datedFlows(a, 1, 2);
      return finResult(_xnpv(r, v, d));
    },
    examples: ['XNPV(0.09, B2:B6, C2:C6)'],
    seeAlso: ['NPV', 'XIRR'],
  );
  b.fn(
    'XIRR',
    'Calculates the internal rate of return of an investment based on a specified series of potentially irregularly spaced cash flows.',
    [
      P.array(
        'cashflow_amounts',
        'An array or range containing the income or payments associated with the investment.',
      ),
      P.array(
        'cashflow_dates',
        'An array or range with dates corresponding to the cash flows.',
      ),
      P.num(
        'rate_guess',
        'An estimate for what the internal rate of return will be.',
        true,
        0.1,
      ),
    ],
    (a) {
      final (v, d) = _datedFlows(a, 0, 1);
      final guess = a.numberOr(2, 0.1, blankIsDefault: true);
      if (!hasSignChange(v)) fail(ErrorKind.num, _irrFailed);
      return finResult(
        _solveRate((r) => _xnpv(r, v, d), (r) => _dxnpv(r, v, d), guess),
      );
    },
    examples: ['XIRR(B2:B6, C2:C6)'],
    seeAlso: ['IRR', 'XNPV'],
  );
  b.fn(
    'MIRR',
    'Calculates the modified internal rate of return on an investment based on a series of periodic cash flows and the difference between the interest rate paid on financing versus the return received on reinvested income.',
    [
      P.array(
        'cashflow_amounts',
        'An array or range containing the income or payments associated with the investment.',
      ),
      P.num('financing_rate', 'The interest rate paid on funds invested.'),
      P.num(
        'reinvestment_return_rate',
        'The return (as a percentage) earned on reinvestment of income received from the investment.',
      ),
    ],
    (a) {
      final v = cashFlows(a, 0);
      final fr = a.number(1), rr = a.number(2);
      if (fr == -1 || rr == -1) {
        fail(ErrorKind.div0, ErrorMessages.divZeroEval(a.fn));
      }
      final n = v.length;
      var pos = 0.0, neg = 0.0;
      for (var i = 0; i < n; i++) {
        if (v[i] > 0) pos += v[i] / math.pow(1 + rr, i);
        if (v[i] < 0) neg += v[i] / math.pow(1 + fr, i);
      }
      if (pos == 0 || neg == 0 || n < 2) {
        fail(ErrorKind.div0, ErrorMessages.divZeroEval(a.fn));
      }
      final terminal = pos * math.pow(1 + rr, n - 1);
      return finResult(math.pow(-terminal / neg, 1 / (n - 1)) - 1);
    },
    examples: ['MIRR({-120000, 39000, 30000, 21000, 37000, 46000}, 0.1, 0.12)'],
    seeAlso: ['IRR', 'XIRR'],
  );
}
