import 'dart:math' as math;

import '../../eval/args.dart';
import '../../values/dates.dart';
import 'common.dart';

/// Excel-compatible day count conventions (`day_count_convention` / `basis`):
///
/// | Basis | Convention |
/// |-------|------------|
/// | 0 | US (NASD) 30/360 |
/// | 1 | Actual/actual |
/// | 2 | Actual/360 |
/// | 3 | Actual/365 |
/// | 4 | European 30/360 |
abstract final class DayCount {
  static const int us30360 = 0;
  static const int actualActual = 1;
  static const int actual360 = 2;
  static const int actual365 = 3;
  static const int eu30360 = 4;

  /// Day count convention argument [i] (default 0); outside 0–4 → `#NUM!`.
  static int basisArg(Args a, int i) {
    final b = a.numberOr(i, 0, blankIsDefault: true).truncate();
    if (b < 0 || b > 4) {
      numError(
        a.fn,
        i + 1,
        'value is $b. Valid values are between 0 and 4 inclusive.',
      );
    }
    return b;
  }

  /// Coupon frequency argument [i]: 1, 2 or 4, else `#NUM!`.
  static int frequencyArg(Args a, int i) {
    final f = a.number(i).truncate();
    if (f != 1 && f != 2 && f != 4) {
      numError(a.fn, i + 1, 'value is $f. Valid values are 1, 2 and 4.');
    }
    return f;
  }

  /// Date argument [i] as an integer serial (time of day truncated); negative → `#NUM!`.
  static int dateArg(Args a, int i) {
    final d = a.number(i);
    if (d < 0) numError(a.fn, i + 1, 'should be a valid date.');
    return d.floor();
  }

  static bool _lastOfFeb(Ymd d) =>
      d.month == 2 && d.day == DateSerial.daysInMonth(d.year, 2);

  /// Day count between two serials under [basis] (30/360 for 0 and 4, actual otherwise).
  static int days(int start, int end, int basis) {
    switch (basis) {
      case us30360:
        return days360Us(start, end);
      case eu30360:
        final s = DateSerial.toYmdInt(start), e = DateSerial.toYmdInt(end);
        return _diff360(
          s.year,
          s.month,
          math.min(s.day, 30),
          e.year,
          e.month,
          math.min(e.day, 30),
        );
      default:
        return end - start;
    }
  }

  /// US (NASD) 30/360 with the end-of-February rules used by Excel's YEARFRAC.
  static int days360Us(int start, int end) {
    final s = DateSerial.toYmdInt(start), e = DateSerial.toYmdInt(end);
    var sd = s.day, ed = e.day;
    if (_lastOfFeb(s)) {
      if (_lastOfFeb(e)) ed = 30;
      sd = 30;
    }
    if (sd == 31) sd = 30;
    if (ed == 31 && sd >= 30) ed = 30;
    return _diff360(s.year, s.month, sd, e.year, e.month, ed);
  }

  static int _diff360(int y1, int m1, int d1, int y2, int m2, int d2) =>
      (y2 - y1) * 360 + (m2 - m1) * 30 + (d2 - d1);

  /// Fraction of a year between two serials (YEARFRAC semantics, order-insensitive).
  static double yearFrac(int start, int end, int basis) {
    if (start > end) {
      final t = start;
      start = end;
      end = t;
    }
    switch (basis) {
      case us30360:
      case eu30360:
        return days(start, end, basis) / 360;
      case actual360:
        return (end - start) / 360;
      case actual365:
        return (end - start) / 365;
      default:
        return _actualActual(start, end);
    }
  }

  static double _actualActual(int start, int end) {
    if (start == end) return 0;
    final s = DateSerial.toYmdInt(start), e = DateSerial.toYmdInt(end);
    final withinYear =
        s.year == e.year ||
        (e.year == s.year + 1 &&
            (s.month > e.month || (s.month == e.month && s.day >= e.day)));
    if (withinYear) {
      double length;
      if (s.year == e.year) {
        length = DateSerial.isLeapYear(s.year) ? 366 : 365;
      } else {
        final leapInRange =
            (DateSerial.isLeapYear(s.year) &&
                start <= DateSerial.fromYmd(s.year, 2, 29)) ||
            (DateSerial.isLeapYear(e.year) &&
                end >= DateSerial.fromYmd(e.year, 2, 29));
        length = leapInRange ? 366 : 365;
      }
      return (end - start) / length;
    }
    final years = e.year - s.year + 1;
    final total =
        DateSerial.fromYmd(e.year + 1, 1, 1) - DateSerial.fromYmd(s.year, 1, 1);
    return (end - start) / (total / years);
  }

  /// Days in a year under [basis] for the year containing [serial] (360, 365 or actual).
  static int yearDays(int serial, int basis) => switch (basis) {
    actualActual =>
      DateSerial.isLeapYear(DateSerial.toYmdInt(serial).year) ? 366 : 365,
    actual365 => 365,
    _ => 360,
  };

  // ------------------------------------------------------------------ coupons

  /// The coupon date [months] months from [anchor] (negative = earlier). An anchor on the last
  /// day of its month yields month ends; other days are clamped to the month length.
  static int shiftCoupon(int anchor, int months) {
    final a = DateSerial.toYmdInt(anchor);
    final total = a.year * 12 + (a.month - 1) + months;
    final y = (total / 12).floor();
    final m = total - y * 12 + 1;
    final dim = DateSerial.daysInMonth(y, m);
    final eom = a.day == DateSerial.daysInMonth(a.year, a.month);
    return DateSerial.fromYmd(y, m, eom ? dim : math.min(a.day, dim));
  }

  /// Number of coupon periods `k` from maturity back to the previous coupon date (the latest
  /// coupon date on or before settlement); equals COUPNUM.
  static int _periodsBack(int settlement, int maturity, int frequency) {
    final step = 12 ~/ frequency;
    final s = DateSerial.toYmdInt(settlement),
        m = DateSerial.toYmdInt(maturity);
    final months = (m.year - s.year) * 12 + m.month - s.month;
    var k = math.max(0, months ~/ step - 1);
    while (shiftCoupon(maturity, -k * step) > settlement) {
      k++;
    }
    while (k > 0 && shiftCoupon(maturity, -(k - 1) * step) <= settlement) {
      k--;
    }
    return k;
  }

  /// Coupon date on or before settlement (COUPPCD).
  static int previousCoupon(int settlement, int maturity, int frequency) =>
      shiftCoupon(
        maturity,
        -_periodsBack(settlement, maturity, frequency) * (12 ~/ frequency),
      );

  /// First coupon date after settlement (COUPNCD).
  static int nextCoupon(int settlement, int maturity, int frequency) =>
      shiftCoupon(
        maturity,
        -(_periodsBack(settlement, maturity, frequency) - 1) *
            (12 ~/ frequency),
      );

  /// Number of coupons payable between settlement and maturity (COUPNUM).
  static int couponCount(int settlement, int maturity, int frequency) =>
      _periodsBack(settlement, maturity, frequency);

  /// Days in the coupon period containing settlement (COUPDAYS).
  static double couponDays(
    int settlement,
    int maturity,
    int frequency,
    int basis,
  ) {
    if (basis == actualActual) {
      return (nextCoupon(settlement, maturity, frequency) -
              previousCoupon(settlement, maturity, frequency))
          .toDouble();
    }
    return (basis == actual365 ? 365 : 360) / frequency;
  }

  /// Days from the start of the coupon period to settlement (COUPDAYBS).
  static double couponDaysBefore(
    int settlement,
    int maturity,
    int frequency,
    int basis,
  ) => days(
    previousCoupon(settlement, maturity, frequency),
    settlement,
    basis,
  ).toDouble();

  /// Days from settlement to the next coupon date (COUPDAYSNC).
  static double couponDaysNext(
    int settlement,
    int maturity,
    int frequency,
    int basis,
  ) {
    if (basis == us30360 || basis == eu30360) {
      return couponDays(settlement, maturity, frequency, basis) -
          couponDaysBefore(settlement, maturity, frequency, basis);
    }
    return (nextCoupon(settlement, maturity, frequency) - settlement)
        .toDouble();
  }
}
