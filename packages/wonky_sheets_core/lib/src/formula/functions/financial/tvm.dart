import 'dart:math' as math;

import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../../values/numeric.dart';
import '../registry.dart';
import 'common.dart';

/// Time value of money: payment, value, period, rate and interest-split functions.

/// Payment per period (PMT).
double pmtOf(double rate, double n, double pv, double fv, int type) {
  if (n == 0) {
    fail(ErrorKind.num, 'The number of periods must not be 0.');
  }
  if (rate == 0) return -(pv + fv) / n;
  final q = math.pow(1 + rate, n).toDouble();
  return -(rate * (fv + pv * q)) / ((1 + rate * type) * (q - 1));
}

/// Future value (FV).
double fvOf(double rate, double n, double pmt, double pv, int type) {
  if (rate == 0) return -(pv + pmt * n);
  final q = math.pow(1 + rate, n).toDouble();
  return -(pv * q + pmt * (1 + rate * type) * (q - 1) / rate);
}

/// Present value (PV).
double pvOf(double rate, double n, double pmt, double fv, int type) {
  if (rate == 0) return -(fv + pmt * n);
  final q = math.pow(1 + rate, n).toDouble();
  return -(fv + pmt * (1 + rate * type) * (q - 1) / rate) / q;
}

/// Interest part of payment [per] (IPMT).
double ipmtOf(
  double rate,
  double per,
  double n,
  double pv,
  double fv,
  int type,
) {
  final pmt = pmtOf(rate, n, pv, fv, type);
  if (per == 1) return type == 1 ? 0 : -pv * rate;
  if (type == 1) return (fvOf(rate, per - 2, pmt, pv, 1) - pmt) * rate;
  return fvOf(rate, per - 1, pmt, pv, 0) * rate;
}

void _checkPeriod(String fn, double per, double n) {
  if (per < 1 || per > n) {
    fail(
      ErrorKind.num,
      'Function $fn parameter 2 value is ${Numeric.toText(per)}. It should be between 1 and the number of periods.',
    );
  }
}

void registerTvm(FunctionRegistryBuilder b) {
  final rate = P.num('rate', 'The interest rate per period.');
  final nper = P.num('number_of_periods', 'The number of payments to be made.');
  final pmt = P.num('payment_amount', 'The amount per period to be paid.');
  final pv = P.num('present_value', 'The current value of the annuity.');
  final type = P.num(
    'end_or_beginning',
    'Whether payments are due at the end (0) or beginning (1) of each period.',
    true,
    0,
  );
  final period = P.num(
    'period',
    'The amortization period, in terms of number of periods.',
  );

  b.fn(
    'PMT',
    'Calculates the periodic payment for an annuity investment based on constant-amount periodic payments and a constant interest rate.',
    [
      rate,
      nper,
      pv,
      P.num(
        'future_value',
        'The future value remaining after the final payment has been made.',
        true,
        0,
      ),
      type,
    ],
    (a) => currencyResult(
      pmtOf(
        a.number(0),
        a.number(1),
        a.number(2),
        a.numberOr(3, 0),
        paymentType(a, 4),
      ),
    ),
    priority: Priority.p0,
    examples: ['PMT(0.08/12, 10, 10000)', 'PMT(0.06/12, 18*12, 0, 50000)'],
    seeAlso: ['IPMT', 'PPMT', 'PV', 'FV'],
  );
  b.fn(
    'FV',
    'Calculates the future value of an annuity investment based on constant-amount periodic payments and a constant interest rate.',
    [
      rate,
      nper,
      pmt,
      P.num('present_value', 'The current value of the annuity.', true, 0),
      type,
    ],
    (a) => currencyResult(
      fvOf(
        a.number(0),
        a.number(1),
        a.number(2),
        a.numberOr(3, 0),
        paymentType(a, 4),
      ),
    ),
    priority: Priority.p0,
    examples: ['FV(0.06/12, 10, -200, -500, 1)'],
    seeAlso: ['PV', 'PMT', 'NPER', 'RATE'],
  );
  b.fn(
    'PV',
    'Calculates the present value of an annuity investment based on constant-amount periodic payments and a constant interest rate.',
    [
      rate,
      nper,
      pmt,
      P.num(
        'future_value',
        'The future value remaining after the final payment has been made.',
        true,
        0,
      ),
      type,
    ],
    (a) => currencyResult(
      pvOf(
        a.number(0),
        a.number(1),
        a.number(2),
        a.numberOr(3, 0),
        paymentType(a, 4),
      ),
    ),
    priority: Priority.p0,
    examples: ['PV(0.08/12, 12*20, 500)'],
    seeAlso: ['FV', 'PMT', 'NPV'],
  );
  b.fn(
    'NPER',
    'Calculates the number of payment periods for an investment based on constant-amount periodic payments and a constant interest rate.',
    [
      rate,
      pmt,
      pv,
      P.num(
        'future_value',
        'The future value remaining after the final payment has been made.',
        true,
        0,
      ),
      type,
    ],
    (a) {
      final r = a.number(0), p = a.number(1), v = a.number(2);
      final f = a.numberOr(3, 0);
      final t = paymentType(a, 4);
      if (r == 0) {
        if (p == 0) fail(ErrorKind.num);
        return finResult(-(v + f) / p);
      }
      final num = p * (1 + r * t) - f * r;
      final den = v * r + p * (1 + r * t);
      if (den == 0 || num / den <= 0) fail(ErrorKind.num);
      return finResult(math.log(num / den) / math.log(1 + r));
    },
    priority: Priority.p0,
    examples: ['NPER(0.12/12, -100, -1000, 10000, 1)'],
    seeAlso: ['RATE', 'PMT', 'PV', 'FV'],
  );
  b.fn(
    'RATE',
    'Calculates the interest rate of an annuity investment based on constant-amount periodic payments and the assumption of a constant interest rate.',
    [
      nper,
      P.num('payment_per_period', 'The amount per period to be paid.'),
      pv,
      P.num(
        'future_value',
        'The future value remaining after the final payment has been made.',
        true,
        0,
      ),
      type,
      P.num(
        'rate_guess',
        'An estimate for what the interest rate will be.',
        true,
        0.1,
      ),
    ],
    (a) {
      final n = a.number(0), p = a.number(1), v = a.number(2);
      final f = a.numberOr(3, 0);
      final t = paymentType(a, 4);
      final guess = a.numberOr(5, 0.1, blankIsDefault: true);
      if (n <= 0) fail(ErrorKind.num);
      double fn(double r) {
        if (r == 0) return v + p * n + f;
        final q = math.pow(1 + r, n).toDouble();
        return v * q + p * (1 + r * t) * (q - 1) / r + f;
      }

      double dfn(double r) {
        if (r == 0) return n * v + p * t * n + p * n * (n - 1) / 2;
        final q = math.pow(1 + r, n).toDouble();
        final q1 = math.pow(1 + r, n - 1).toDouble();
        return n * v * q1 +
            p * t * (q - 1) / r +
            p * (1 + r * t) * (n * q1 * r - (q - 1)) / (r * r);
      }

      final r = newton(fn, dfn, guess, lower: -1);
      if (r == null) fail(ErrorKind.num, 'RATE could not find a result.');
      return finResult(r);
    },
    priority: Priority.p0,
    examples: ['RATE(4*12, -200, 8000)'],
    seeAlso: ['NPER', 'PMT', 'IRR'],
  );
  b.fn(
    'IPMT',
    'Calculates the payment on interest for an investment based on constant-amount periodic payments and a constant interest rate.',
    [
      rate,
      period,
      nper,
      pv,
      P.num(
        'future_value',
        'The future value remaining after the final payment has been made.',
        true,
        0,
      ),
      type,
    ],
    (a) {
      final r = a.number(0),
          per = a.number(1),
          n = a.number(2),
          v = a.number(3);
      _checkPeriod(a.fn, per, n);
      return currencyResult(
        ipmtOf(r, per, n, v, a.numberOr(4, 0), paymentType(a, 5)),
      );
    },
    examples: ['IPMT(0.1/12, 1, 3*12, 8000)'],
    seeAlso: ['PPMT', 'PMT', 'CUMIPMT'],
  );
  b.fn(
    'PPMT',
    'Calculates the payment on the principal of an investment based on constant-amount periodic payments and a constant interest rate.',
    [
      rate,
      period,
      nper,
      pv,
      P.num(
        'future_value',
        'The future value remaining after the final payment has been made.',
        true,
        0,
      ),
      type,
    ],
    (a) {
      final r = a.number(0),
          per = a.number(1),
          n = a.number(2),
          v = a.number(3);
      final f = a.numberOr(4, 0);
      final t = paymentType(a, 5);
      _checkPeriod(a.fn, per, n);
      return currencyResult(pmtOf(r, n, v, f, t) - ipmtOf(r, per, n, v, f, t));
    },
    examples: ['PPMT(0.1/12, 1, 2*12, 2000)'],
    seeAlso: ['IPMT', 'PMT', 'CUMPRINC'],
  );
  b.fn(
    'ISPMT',
    'Calculates the interest paid during a particular period of an investment with even principal payments (straight-line).',
    [rate, period, nper, pv],
    (a) {
      final r = a.number(0),
          per = a.number(1),
          n = a.number(2),
          v = a.number(3);
      if (n == 0) fail(ErrorKind.div0, ErrorMessages.divByZero(a.fn, 3));
      return finResult(v * r * (per / n - 1));
    },
    examples: ['ISPMT(0.1/12, 1, 3*12, 8000000)'],
    seeAlso: ['IPMT', 'CUMIPMT'],
  );

  FValue cumulative(FunctionArgs a, bool interest) {
    final r = a.number(0), n = a.number(1).truncateToDouble(), v = a.number(2);
    final start = a.number(3).truncate(), end = a.number(4).truncate();
    final t = a.number(5);
    if (r <= 0 || n <= 0 || v <= 0) fail(ErrorKind.num);
    if (start < 1 || end < start || end > n) fail(ErrorKind.num);
    if (t != 0 && t != 1) {
      numError(
        a.fn,
        6,
        'value is ${Numeric.toText(t)}. Valid values are 0 and 1.',
      );
    }
    final type = t.toInt();
    final payment = pmtOf(r, n, v, 0, type);
    var sum = 0.0;
    for (var per = start; per <= end; per++) {
      final ip = ipmtOf(r, per.toDouble(), n, v, 0, type);
      sum += interest ? ip : payment - ip;
    }
    return finResult(sum);
  }

  final cumParams = [
    rate,
    nper,
    pv,
    P.num(
      'first_period',
      'The number of the payment period to begin the cumulative calculation.',
    ),
    P.num(
      'last_period',
      'The number of the payment period to end the cumulative calculation.',
    ),
    P.num(
      'end_or_beginning',
      'Whether payments are due at the end (0) or beginning (1) of each period.',
    ),
  ];
  b.fn(
    'CUMIPMT',
    'Calculates the cumulative interest over a range of payment periods for an investment based on constant-amount periodic payments and a constant interest rate.',
    cumParams,
    (a) => cumulative(a, true),
    examples: ['CUMIPMT(0.09/12, 30*12, 125000, 13, 24, 0)'],
    seeAlso: ['CUMPRINC', 'IPMT'],
  );
  b.fn(
    'CUMPRINC',
    'Calculates the cumulative principal paid over a range of payment periods for an investment based on constant-amount periodic payments and a constant interest rate.',
    cumParams,
    (a) => cumulative(a, false),
    examples: ['CUMPRINC(0.09/12, 30*12, 125000, 13, 24, 0)'],
    seeAlso: ['CUMIPMT', 'PPMT'],
  );

  b.fn(
    'EFFECT',
    'Calculates the annual effective interest rate given the nominal rate and number of compounding periods per year.',
    [
      P.num('nominal_rate', 'The nominal interest rate per year.'),
      P.num('periods_per_year', 'The number of compounding periods per year.'),
    ],
    (a) {
      final r = a.number(0), p = a.number(1).truncateToDouble();
      if (r <= 0 || p < 1) fail(ErrorKind.num);
      return finResult(math.pow(1 + r / p, p) - 1);
    },
    examples: ['EFFECT(0.0525, 4)'],
    seeAlso: ['NOMINAL'],
  );
  b.fn(
    'NOMINAL',
    'Calculates the annual nominal interest rate given the effective rate and number of compounding periods per year.',
    [
      P.num('effective_rate', 'The effective interest rate per year.'),
      P.num('periods_per_year', 'The number of compounding periods per year.'),
    ],
    (a) {
      final r = a.number(0), p = a.number(1).truncateToDouble();
      if (r <= 0 || p < 1) fail(ErrorKind.num);
      return finResult(p * (math.pow(1 + r, 1 / p) - 1));
    },
    examples: ['NOMINAL(0.053543, 4)'],
    seeAlso: ['EFFECT'],
  );
  b.fn(
    'PDURATION',
    'Returns the number of periods for an investment to reach a specific value at a given rate.',
    [
      P.num('rate', 'The rate at which the investment grows each period.'),
      P.num('present_value', "The investment's current value."),
      P.num('future_value', "The investment's desired future value."),
    ],
    (a) {
      final r = a.number(0), v = a.number(1), f = a.number(2);
      if (r <= 0 || v <= 0 || f <= 0) fail(ErrorKind.num);
      return finResult((math.log(f) - math.log(v)) / math.log(1 + r));
    },
    examples: ['PDURATION(0.025, 2000, 2200)'],
    seeAlso: ['RRI', 'NPER'],
  );
  b.fn(
    'RRI',
    'Returns the interest rate needed for an investment to reach a specific value within a given number of periods.',
    [
      P.num('number_of_periods', 'The number of periods.'),
      P.num('present_value', 'The present value of the investment.'),
      P.num('future_value', 'The future value of the investment.'),
    ],
    (a) {
      final n = a.number(0), v = a.number(1), f = a.number(2);
      if (n <= 0 || v == 0) fail(ErrorKind.num);
      return finResult(math.pow(f / v, 1 / n) - 1);
    },
    examples: ['RRI(96, 10000, 11000)'],
    seeAlso: ['PDURATION', 'RATE'],
  );
  b.fn(
    'FVSCHEDULE',
    'Calculates the future value of some principal based on a specified series of potentially varying interest rates.',
    [
      P.num(
        'principal',
        'The amount of initial capital or value to compound against.',
      ),
      P.range(
        'rate_schedule',
        'A series of interest rates to compound against the principal.',
      ),
    ],
    (a) {
      var v = a.number(0);
      for (final r in cashFlows(a, 1)) {
        v *= 1 + r;
      }
      return finResult(v);
    },
    examples: ['FVSCHEDULE(1, {0.09, 0.11, 0.1})'],
    seeAlso: ['FV'],
  );

  // Fractional dollar prices.
  int unitArg(FunctionArgs a) {
    final u = a.number(1).truncate();
    if (u < 0) fail(ErrorKind.num);
    if (u == 0) fail(ErrorKind.div0, ErrorMessages.divByZero(a.fn, 2));
    return u;
  }

  double scale(int unit) {
    var p = 1.0;
    while (p < unit) {
      p *= 10;
    }
    return p;
  }

  b.fn(
    'DOLLARDE',
    'Converts a price quotation given as a decimal fraction into a decimal value.',
    [
      P.num(
        'fractional_price',
        'The price quotation given using fractional decimal conventions.',
      ),
      P.num(
        'unit',
        'The units of the fraction, e.g. 8 for 1/8ths or 32 for 1/32nds.',
      ),
    ],
    (a) {
      final x = a.number(0);
      final u = unitArg(a);
      final whole = x.truncateToDouble();
      return finResult(whole + (x - whole) * scale(u) / u);
    },
    examples: ['DOLLARDE(100.10, 32)'],
    seeAlso: ['DOLLARFR'],
  );
  b.fn(
    'DOLLARFR',
    'Converts a price quotation given as a decimal value into a decimal fraction.',
    [
      P.num('decimal_price', 'The price quotation given as a decimal value.'),
      P.num(
        'unit',
        'The units of the desired fraction, e.g. 8 for 1/8ths or 32 for 1/32nds.',
      ),
    ],
    (a) {
      final x = a.number(0);
      final u = unitArg(a);
      final whole = x.truncateToDouble();
      return finResult(whole + (x - whole) * u / scale(u));
    },
    examples: ['DOLLARFR(100.125, 32)'],
    seeAlso: ['DOLLARDE'],
  );
}
