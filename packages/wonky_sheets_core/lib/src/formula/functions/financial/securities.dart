import 'dart:math' as math;

import '../../eval/eval_context.dart';
import '../../values/dates.dart';
import '../../values/errors.dart';
import '../../values/format_hint.dart';
import '../../values/fvalue.dart';
import '../registry.dart';
import 'common.dart';
import 'day_count.dart';

/// Securities: coupons, bonds, discounted securities and treasury bills (P2).

/// Settlement and maturity arguments [i], [i + 1]; settlement ≥ maturity → `#NUM!`.
(int, int) _settleMat(FunctionArgs a, [int i = 0]) {
  final s = DayCount.dateArg(a, i), m = DayCount.dateArg(a, i + 1);
  if (s >= m) {
    fail(
      ErrorKind.num,
      'Function ${a.fn}: settlement date must be before maturity date.',
    );
  }
  return (s, m);
}

/// Coupon period geometry of a bond: (E, A, DSC, N).
({double e, double a, double dsc, int n}) _coupon(
  int s,
  int m,
  int freq,
  int basis,
) => (
  e: DayCount.couponDays(s, m, freq, basis),
  a: DayCount.couponDaysBefore(s, m, freq, basis),
  dsc: DayCount.couponDaysNext(s, m, freq, basis),
  n: DayCount.couponCount(s, m, freq),
);

/// Bond price per 100 face value (Excel PRICE).
double bondPrice(
  int s,
  int m,
  double rate,
  double yld,
  double red,
  int freq,
  int basis,
) {
  final c = _coupon(s, m, freq, basis);
  final coupon = 100 * rate / freq;
  final accrued = coupon * c.a / c.e;
  if (c.n <= 1) {
    final dsr = c.e - c.a;
    return (red + coupon) / (1 + yld / freq * dsr / c.e) - accrued;
  }
  final q = 1 + yld / freq;
  final x = c.dsc / c.e;
  var p = red / math.pow(q, c.n - 1 + x);
  for (var k = 1; k <= c.n; k++) {
    p += coupon / math.pow(q, k - 1 + x);
  }
  return p - accrued;
}

/// Macaulay duration in years (Excel DURATION).
double bondDuration(
  int s,
  int m,
  double rate,
  double yld,
  int freq,
  int basis,
) {
  final c = _coupon(s, m, freq, basis);
  final x = (c.e - c.a) / c.e;
  final cf = rate * 100 / freq;
  final q = 1 + yld / freq;
  var num = 0.0, den = 0.0;
  for (var k = 1; k <= c.n; k++) {
    final t = k - 1 + x;
    final flow = k == c.n ? cf + 100 : cf;
    final pv = flow / math.pow(q, t);
    num += t * pv;
    den += pv;
  }
  return num / den / freq;
}

void registerSecurities(FunctionRegistryBuilder b) {
  final settlement = P.num(
    'settlement',
    'The settlement date of the security, the date after issuance when the security is delivered to the buyer.',
  );
  final maturity = P.num(
    'maturity',
    'The maturity or end date of the security, when it can be redeemed at face, or par value.',
  );
  final frequency = P.num(
    'frequency',
    'The number of interest or coupon payments per year (1, 2, or 4).',
  );
  final basis = P.num(
    'day_count_convention',
    'An indicator of what day count method to use.',
    true,
    0,
  );
  final rate = P.num('rate', 'The annualized rate of interest.');
  final redemption = P.num(
    'redemption',
    'The redemption amount per 100 face value, or par.',
  );

  // ---------------------------------------------------------------- accrued interest

  b.fn(
    'ACCRINT',
    'Calculates the accrued interest of a security that has periodic payments.',
    [
      P.num('issue', 'The date the security was initially issued.'),
      P.num('first_payment', 'The first date interest will be paid.'),
      settlement,
      rate,
      P.num('redemption', 'The redemption amount per 100 face value, or par.'),
      frequency,
      basis,
    ],
    (a) {
      final issue = DayCount.dateArg(a, 0), first = DayCount.dateArg(a, 1);
      final settle = DayCount.dateArg(a, 2);
      final r = positive(a, 3), par = positive(a, 4);
      final freq = DayCount.frequencyArg(a, 5);
      final bs = DayCount.basisArg(a, 6);
      if (issue >= settle) fail(ErrorKind.num);
      final step = 12 ~/ freq;
      // Quasi-coupon periods anchored on the first payment date, from the one containing issue.
      var k = 0;
      while (DayCount.shiftCoupon(first, k * step) > issue) {
        k--;
      }
      while (DayCount.shiftCoupon(first, (k + 1) * step) <= issue) {
        k++;
      }
      var sum = 0.0;
      for (var guard = 0; guard < 100000; guard++, k++) {
        final ps = DayCount.shiftCoupon(first, k * step);
        if (ps >= settle) break;
        final pe = DayCount.shiftCoupon(first, (k + 1) * step);
        final from = math.max(ps, issue), to = math.min(pe, settle);
        final nl = switch (bs) {
          DayCount.actualActual => (pe - ps).toDouble(),
          DayCount.actual365 => 365 / freq,
          _ => 360 / freq,
        };
        sum += DayCount.days(from, to, bs) / nl;
      }
      return finResult(par * r / freq * sum);
    },
    priority: Priority.p2,
    examples: [
      'ACCRINT(DATE(2008,3,1), DATE(2008,8,31), DATE(2008,5,1), 0.1, 1000, 2, 0)',
    ],
    seeAlso: ['ACCRINTM'],
  );
  b.fn(
    'ACCRINTM',
    'Calculates the accrued interest of a security that pays interest at maturity.',
    [
      P.num('issue', 'The date the security was initially issued.'),
      P.num('maturity', 'The maturity date of the security.'),
      rate,
      P.num(
        'redemption',
        'The redemption amount per 100 face value, or par.',
        true,
        1000,
      ),
      basis,
    ],
    (a) {
      final issue = DayCount.dateArg(a, 0), mat = DayCount.dateArg(a, 1);
      final r = positive(a, 2);
      final par = a.has(3) ? positive(a, 3) : 1000.0;
      final bs = DayCount.basisArg(a, 4);
      if (issue >= mat) fail(ErrorKind.num);
      return finResult(par * r * DayCount.yearFrac(issue, mat, bs));
    },
    priority: Priority.p2,
    examples: ['ACCRINTM(DATE(2008,4,1), DATE(2008,6,15), 0.1, 1000, 3)'],
    seeAlso: ['ACCRINT'],
  );

  // ---------------------------------------------------------------- coupons

  void coupon(
    String name,
    String summary,
    FValue Function(int s, int m, int f, int basis) f,
    String example,
  ) {
    b.fn(
      name,
      summary,
      [settlement, maturity, frequency, basis],
      (a) {
        final (s, m) = _settleMat(a);
        final freq = DayCount.frequencyArg(a, 2);
        final bs = DayCount.basisArg(a, 3);
        return f(s, m, freq, bs);
      },
      priority: Priority.p2,
      examples: [example],
      seeAlso: [
        'COUPDAYBS',
        'COUPDAYS',
        'COUPDAYSNC',
        'COUPNCD',
        'COUPNUM',
        'COUPPCD',
      ].where((n) => n != name).toList(),
    );
  }

  coupon(
    'COUPDAYBS',
    'Calculates the number of days from the first coupon, or interest payment, until settlement.',
    (s, m, f, bs) => finResult(DayCount.couponDaysBefore(s, m, f, bs)),
    'COUPDAYBS(DATE(2007,1,25), DATE(2008,11,15), 2, 1)',
  );
  coupon(
    'COUPDAYS',
    'Calculates the number of days in the coupon, or interest payment, period that contains the specified settlement date.',
    (s, m, f, bs) => finResult(DayCount.couponDays(s, m, f, bs)),
    'COUPDAYS(DATE(2007,1,25), DATE(2008,11,15), 2, 1)',
  );
  coupon(
    'COUPDAYSNC',
    'Calculates the number of days from the settlement date until the next coupon, or interest payment.',
    (s, m, f, bs) => finResult(DayCount.couponDaysNext(s, m, f, bs)),
    'COUPDAYSNC(DATE(2007,1,25), DATE(2008,11,15), 2, 1)',
  );
  coupon(
    'COUPNCD',
    'Calculates next coupon, or interest payment, date after the settlement date.',
    (s, m, f, _) =>
        FNumber(DayCount.nextCoupon(s, m, f).toDouble(), FormatHint.date),
    'COUPNCD(DATE(2007,1,25), DATE(2008,11,15), 2, 1)',
  );
  coupon(
    'COUPNUM',
    'Calculates the number of coupons, or interest payments, between the settlement date and the maturity date of the investment.',
    (s, m, f, _) => FNumber(DayCount.couponCount(s, m, f).toDouble()),
    'COUPNUM(DATE(2007,1,25), DATE(2008,11,15), 2, 1)',
  );
  coupon(
    'COUPPCD',
    'Calculates last coupon, or interest payment, date before the settlement date.',
    (s, m, f, _) =>
        FNumber(DayCount.previousCoupon(s, m, f).toDouble(), FormatHint.date),
    'COUPPCD(DATE(2007,1,25), DATE(2008,11,15), 2, 1)',
  );

  // ---------------------------------------------------------------- bonds

  final yieldP = P.num('yield', 'The expected annual yield of the security.');
  b.fn(
    'PRICE',
    'Calculates the price of a security paying periodic interest, such as a US Treasury Bond, based on expected yield.',
    [settlement, maturity, rate, yieldP, redemption, frequency, basis],
    (a) {
      final (s, m) = _settleMat(a);
      final r = nonNegative(a, 2), y = nonNegative(a, 3), red = positive(a, 4);
      final freq = DayCount.frequencyArg(a, 5);
      final bs = DayCount.basisArg(a, 6);
      return finResult(bondPrice(s, m, r, y, red, freq, bs));
    },
    priority: Priority.p2,
    examples: [
      'PRICE(DATE(2008,2,15), DATE(2017,11,15), 0.0575, 0.065, 100, 2, 0)',
    ],
    seeAlso: ['YIELD', 'DURATION'],
  );
  b.fn(
    'YIELD',
    'Calculates the annual yield of a security paying periodic interest, such as a US Treasury Bond, based on price.',
    [
      settlement,
      maturity,
      rate,
      P.num(
        'price',
        'The price at which the security is bought per 100 face value.',
      ),
      redemption,
      frequency,
      basis,
    ],
    (a) {
      final (s, m) = _settleMat(a);
      final r = nonNegative(a, 2), pr = positive(a, 3), red = positive(a, 4);
      final freq = DayCount.frequencyArg(a, 5);
      final bs = DayCount.basisArg(a, 6);
      final c = _coupon(s, m, freq, bs);
      if (c.n <= 1) {
        final dsr = c.e - c.a;
        final base = pr / 100 + c.a / c.e * r / freq;
        return finResult(
          ((red / 100 + r / freq) - base) / base * freq * c.e / dsr,
        );
      }
      double f(double y) => bondPrice(s, m, r, y, red, freq, bs) - pr;
      double df(double y) {
        const h = 1e-7;
        return (f(y + h) - f(y - h)) / (2 * h);
      }

      final guess = r > 0 ? r : 0.05;
      final y =
          newton(f, df, guess, lower: -freq.toDouble()) ??
          bracketAndBisect(f, guess, lower: -freq.toDouble());
      if (y == null) fail(ErrorKind.num, 'YIELD could not find a result.');
      return finResult(y);
    },
    priority: Priority.p2,
    examples: [
      'YIELD(DATE(2008,2,15), DATE(2016,11,15), 0.0575, 95.04287, 100, 2, 0)',
    ],
    seeAlso: ['PRICE', 'YIELDDISC', 'YIELDMAT'],
  );

  FValue duration(FunctionArgs a, bool modified) {
    final (s, m) = _settleMat(a);
    final r = nonNegative(a, 2), y = nonNegative(a, 3);
    final freq = DayCount.frequencyArg(a, 4);
    final bs = DayCount.basisArg(a, 5);
    final d = bondDuration(s, m, r, y, freq, bs);
    return finResult(modified ? d / (1 + y / freq) : d);
  }

  final durParams = [settlement, maturity, rate, yieldP, frequency, basis];
  b.fn(
    'DURATION',
    'Calculates the Macaulay duration of a security paying periodic interest, such as a US Treasury Bond, based on expected yield.',
    durParams,
    (a) => duration(a, false),
    priority: Priority.p2,
    examples: ['DURATION(DATE(2008,1,1), DATE(2016,1,1), 0.08, 0.09, 2, 1)'],
    seeAlso: ['MDURATION', 'PRICE'],
  );
  b.fn(
    'MDURATION',
    'Calculates the modified Macaulay duration of a security paying periodic interest, such as a US Treasury Bond, based on expected yield.',
    durParams,
    (a) => duration(a, true),
    priority: Priority.p2,
    examples: ['MDURATION(DATE(2008,1,1), DATE(2016,1,1), 0.08, 0.09, 2, 1)'],
    seeAlso: ['DURATION'],
  );

  // ---------------------------------------------------------------- discounted securities

  b.fn(
    'DISC',
    'Calculates the discount rate of a security based on price.',
    [
      settlement,
      maturity,
      P.num(
        'price',
        'The price at which the security is bought per 100 face value.',
      ),
      redemption,
      basis,
    ],
    (a) {
      final (s, m) = _settleMat(a);
      final pr = positive(a, 2), red = positive(a, 3);
      final bs = DayCount.basisArg(a, 4);
      return finResult((1 - pr / red) / DayCount.yearFrac(s, m, bs));
    },
    priority: Priority.p2,
    examples: ['DISC(DATE(2007,1,25), DATE(2007,6,15), 97.975, 100, 1)'],
    seeAlso: ['PRICEDISC', 'YIELDDISC'],
  );
  b.fn(
    'PRICEDISC',
    'Calculates the price of a discount (non-interest-bearing) security, based on expected yield.',
    [
      settlement,
      maturity,
      P.num(
        'discount',
        'The discount rate of the security at time of purchase.',
      ),
      redemption,
      basis,
    ],
    (a) {
      final (s, m) = _settleMat(a);
      final d = positive(a, 2), red = positive(a, 3);
      final bs = DayCount.basisArg(a, 4);
      return finResult(red * (1 - d * DayCount.yearFrac(s, m, bs)));
    },
    priority: Priority.p2,
    examples: ['PRICEDISC(DATE(2008,2,16), DATE(2008,3,1), 0.0525, 100, 2)'],
    seeAlso: ['DISC', 'YIELDDISC'],
  );
  b.fn(
    'PRICEMAT',
    'Calculates the price of a security paying interest at maturity, based on expected yield.',
    [
      settlement,
      maturity,
      P.num('issue', 'The date the security was initially issued.'),
      rate,
      yieldP,
      basis,
    ],
    (a) {
      final (s, m) = _settleMat(a);
      final issue = DayCount.dateArg(a, 2);
      final r = nonNegative(a, 3), y = nonNegative(a, 4);
      final bs = DayCount.basisArg(a, 5);
      final im = DayCount.yearFrac(issue, m, bs);
      final isf = DayCount.yearFrac(issue, s, bs);
      final sm = DayCount.yearFrac(s, m, bs);
      return finResult(100 * ((1 + im * r) / (1 + sm * y) - isf * r));
    },
    priority: Priority.p2,
    examples: [
      'PRICEMAT(DATE(2008,2,15), DATE(2008,4,13), DATE(2007,11,11), 0.061, 0.061, 0)',
    ],
    seeAlso: ['YIELDMAT'],
  );
  b.fn(
    'RECEIVED',
    'Calculates the amount received at maturity for an investment in fixed-income securities purchased on a given date.',
    [
      settlement,
      maturity,
      P.num(
        'investment',
        'The amount invested (irrespective of face value of each security).',
      ),
      P.num('discount', 'The discount rate of the security invested in.'),
      basis,
    ],
    (a) {
      final (s, m) = _settleMat(a);
      final inv = positive(a, 2), d = positive(a, 3);
      final bs = DayCount.basisArg(a, 4);
      final den = 1 - d * DayCount.yearFrac(s, m, bs);
      if (den <= 0) fail(ErrorKind.num);
      return finResult(inv / den);
    },
    priority: Priority.p2,
    examples: [
      'RECEIVED(DATE(2008,2,15), DATE(2008,5,15), 1000000, 0.0575, 2)',
    ],
    seeAlso: ['INTRATE'],
  );
  b.fn(
    'INTRATE',
    'Calculates the effective interest rate generated when an investment is purchased at one price and sold at another with no interest or dividends generated by the investment itself.',
    [
      P.num('buy_date', 'The date of purchase of the investment.'),
      P.num('sell_date', 'The date of sale of the investment.'),
      P.num('buy_price', 'The price at which the investment was purchased.'),
      P.num('sell_price', 'The price at which the investment was sold.'),
      basis,
    ],
    (a) {
      final (s, m) = _settleMat(a);
      final inv = positive(a, 2), red = positive(a, 3);
      final bs = DayCount.basisArg(a, 4);
      return finResult((red - inv) / inv / DayCount.yearFrac(s, m, bs));
    },
    priority: Priority.p2,
    examples: [
      'INTRATE(DATE(2008,2,15), DATE(2008,5,15), 1000000, 1014420, 2)',
    ],
    seeAlso: ['RECEIVED'],
  );
  b.fn(
    'YIELDDISC',
    'Calculates the annual yield of a discount (non-interest-bearing) security, based on price.',
    [
      settlement,
      maturity,
      P.num(
        'price',
        'The price at which the security is bought per 100 face value.',
      ),
      redemption,
      basis,
    ],
    (a) {
      final (s, m) = _settleMat(a);
      final pr = positive(a, 2), red = positive(a, 3);
      final bs = DayCount.basisArg(a, 4);
      return finResult((red / pr - 1) / DayCount.yearFrac(s, m, bs));
    },
    priority: Priority.p2,
    examples: ['YIELDDISC(DATE(2008,2,16), DATE(2008,3,1), 99.795, 100, 2)'],
    seeAlso: ['DISC', 'PRICEDISC'],
  );
  b.fn(
    'YIELDMAT',
    'Calculates the annual yield of a security paying interest at maturity, based on price.',
    [
      settlement,
      maturity,
      P.num('issue', 'The date the security was initially issued.'),
      rate,
      P.num(
        'price',
        'The price at which the security is bought per 100 face value.',
      ),
      basis,
    ],
    (a) {
      final (s, m) = _settleMat(a);
      final issue = DayCount.dateArg(a, 2);
      final r = nonNegative(a, 3), pr = positive(a, 4);
      final bs = DayCount.basisArg(a, 5);
      final im = DayCount.yearFrac(issue, m, bs);
      final isf = DayCount.yearFrac(issue, s, bs);
      final sm = DayCount.yearFrac(s, m, bs);
      return finResult(((1 + im * r) / (pr / 100 + isf * r) - 1) / sm);
    },
    priority: Priority.p2,
    examples: [
      'YIELDMAT(DATE(2008,3,15), DATE(2008,11,3), DATE(2007,11,8), 0.0625, 100.0123, 0)',
    ],
    seeAlso: ['PRICEMAT'],
  );

  // ---------------------------------------------------------------- treasury bills

  /// Settlement/maturity of a T-bill: maturity at most one year after settlement.
  (int, int) tbill(FunctionArgs a) {
    final (s, m) = _settleMat(a);
    final sy = DateSerial.toYmdInt(s);
    if (m > DateSerial.fromYmd(sy.year + 1, sy.month, sy.day)) {
      fail(
        ErrorKind.num,
        'Function ${a.fn}: maturity must be within one year of settlement.',
      );
    }
    return (s, m);
  }

  final discount = P.num(
    'discount',
    'The discount rate of the bill at time of purchase.',
  );
  b.fn(
    'TBILLEQ',
    'Calculates the equivalent annualized rate of return of a US Treasury Bill based on discount rate.',
    [settlement, maturity, discount],
    (a) {
      final (s, m) = tbill(a);
      final d = positive(a, 2);
      final dsm = (m - s).toDouble();
      if (dsm <= 182) return finResult(365 * d / (360 - d * dsm));
      final price = 1 - d * dsm / 360;
      if (price <= 0) fail(ErrorKind.num);
      final t = dsm / (dsm == 366 ? 366 : 365);
      final disc = t * t - (2 * t - 1) * (1 - 1 / price);
      if (disc < 0) fail(ErrorKind.num);
      return finResult((-2 * t + 2 * math.sqrt(disc)) / (2 * t - 1));
    },
    priority: Priority.p2,
    examples: ['TBILLEQ(DATE(2008,3,31), DATE(2008,6,1), 0.0914)'],
    seeAlso: ['TBILLPRICE', 'TBILLYIELD'],
  );
  b.fn(
    'TBILLPRICE',
    'Calculates the price of a US Treasury Bill based on discount rate.',
    [settlement, maturity, discount],
    (a) {
      final (s, m) = tbill(a);
      final d = positive(a, 2);
      final p = 100 * (1 - d * (m - s) / 360);
      if (p <= 0) fail(ErrorKind.num);
      return finResult(p);
    },
    priority: Priority.p2,
    examples: ['TBILLPRICE(DATE(2008,3,31), DATE(2008,6,1), 0.09)'],
    seeAlso: ['TBILLEQ', 'TBILLYIELD'],
  );
  b.fn(
    'TBILLYIELD',
    'Calculates the yield of a US Treasury Bill based on price.',
    [
      settlement,
      maturity,
      P.num(
        'price',
        'The price at which the Treasury Bill is purchased per 100 face value.',
      ),
    ],
    (a) {
      final (s, m) = tbill(a);
      final pr = positive(a, 2);
      return finResult((100 - pr) / pr * 360 / (m - s));
    },
    priority: Priority.p2,
    examples: ['TBILLYIELD(DATE(2008,3,31), DATE(2008,6,1), 98.45)'],
    seeAlso: ['TBILLEQ', 'TBILLPRICE'],
  );
}
