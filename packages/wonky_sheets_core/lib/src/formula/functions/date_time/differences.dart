import '../../eval/eval_context.dart';
import '../../values/dates.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../registry.dart';
import 'date_common.dart';

/// Differences between dates: DATEDIF, DAYS, DAYS360, YEARFRAC.
void registerDifferences(FunctionRegistryBuilder b) {
  b.fn(
    'DATEDIF',
    'Calculates the number of days, months, or years between two dates.',
    [
      P.num('start_date', 'The start date to consider in the calculation.'),
      P.num('end_date', 'The end date to consider in the calculation.'),
      P.text(
        'unit',
        'A text abbreviation for unit of time: "Y" (whole years), "M" (whole months), "D" (days), '
            '"MD" (days ignoring months and years), "YM" (months ignoring years), '
            '"YD" (days ignoring years).',
      ),
    ],
    (a) {
      final s = dateArg(a, 0), e = dateArg(a, 1);
      final unit = a.text(2).trim().toUpperCase();
      if (s > e) {
        fail(
          ErrorKind.num,
          'Function DATEDIF parameter 1 (start date) should be on or before parameter 2 (end date).',
        );
      }
      final r = dateDif(s, e, unit);
      if (r == null) {
        fail(
          ErrorKind.num,
          "Function DATEDIF parameter 3 value is '$unit'. It should be one of Y, M, D, MD, YM, YD.",
        );
      }
      return FNumber(r.toDouble());
    },
    priority: Priority.p0,
    examples: [
      'DATEDIF(DATE(1969, 7, 16), DATE(1969, 7, 24), "D")',
      'DATEDIF(A1, TODAY(), "Y")',
    ],
    seeAlso: ['DAYS', 'YEARFRAC', 'NETWORKDAYS'],
  );

  b.fn(
    'DAYS',
    'Returns the number of days between two dates.',
    [
      P.num('end_date', 'The end of the date range.'),
      P.num('start_date', 'The start of the date range.'),
    ],
    (a) {
      final e = dateArg(a, 0), s = dateArg(a, 1);
      return FNumber((e - s).toDouble());
    },
    examples: [
      'DAYS(DATE(1969, 7, 24), DATE(1969, 7, 16))',
      'DAYS("2021-03-15", "2021-02-01")',
    ],
    seeAlso: ['DATEDIF', 'DAYS360', 'NETWORKDAYS'],
  );

  b.fn(
    'DAYS360',
    'Returns the difference between two days based on the 360-day year used in some financial interest calculations.',
    [
      P.num('start_date', 'The start date to consider in the calculation.'),
      P.num('end_date', 'The end date to consider in the calculation.'),
      P.bool_(
        'method',
        'FALSE (or omitted) uses the US (NASD) method; TRUE uses the European method.',
        true,
        false,
      ),
    ],
    (a) {
      final s = DateSerial.toYmdInt(dateArg(a, 0)),
          e = DateSerial.toYmdInt(dateArg(a, 1));
      final european = a.boolOr(2, false);
      return FNumber(days360(s, e, european: european).toDouble());
    },
    examples: [
      'DAYS360(DATE(1969, 7, 16), DATE(1970, 7, 24))',
      'DAYS360("2011-01-30", "2011-12-31", TRUE)',
    ],
    seeAlso: ['DAYS', 'YEARFRAC'],
  );

  b.fn(
    'YEARFRAC',
    'Returns the number of years, including fractional years, between two dates using a specified day count convention.',
    [
      P.num('start_date', 'The start date to consider in the calculation.'),
      P.num('end_date', 'The end date to consider in the calculation.'),
      P.num(
        'day_count_convention',
        'The day count method: 0 = US (NASD) 30/360, 1 = actual/actual, 2 = actual/360, '
            '3 = actual/365, 4 = European 30/360.',
        true,
        0,
      ),
    ],
    (a) {
      final s = dateArg(a, 0), e = dateArg(a, 1);
      final basis = a.has(2) ? a.number(2).truncate() : 0;
      if (basis < 0 || basis > 4) {
        fail(
          ErrorKind.num,
          'Function YEARFRAC parameter 3 value is $basis. Valid values are between 0 and 4 inclusive.',
        );
      }
      return FNumber(yearFrac(s, e, basis));
    },
    examples: [
      'YEARFRAC(DATE(1969, 7, 16), DATE(1969, 7, 24), 1)',
      'YEARFRAC("2012-01-01", "2012-07-30")',
    ],
    seeAlso: ['DATEDIF', 'DAYS360'],
  );
}

/// DATEDIF for integer serials [s] ≤ [e]; null for an unknown [unit].
int? dateDif(int s, int e, String unit) {
  final a = DateSerial.toYmdInt(s), b = DateSerial.toYmdInt(e);
  var months = (b.year - a.year) * 12 + (b.month - a.month);
  if (b.day < a.day) months--;
  switch (unit) {
    case 'D':
      return e - s;
    case 'M':
      return months;
    case 'Y':
      return months ~/ 12;
    case 'YM':
      return months % 12;
    case 'MD':
      // Days after the last whole month (start day clamped to the month length, like EDATE).
      if (b.day >= a.day) return b.day - a.day;
      final first = DateSerial.fromYmd(b.year, b.month - 1, 1);
      final p = DateSerial.toYmdInt(first);
      final anchor =
          first + a.day.clamp(1, DateSerial.daysInMonth(p.year, p.month)) - 1;
      return e - anchor;
    case 'YD':
      // Days from the most recent anniversary of the start date.
      var y = b.year;
      var anchor = _anniversary(a, y);
      if (anchor > e) anchor = _anniversary(a, --y);
      return e - anchor;
  }
  return null;
}

int _anniversary(Ymd start, int year) => DateSerial.fromYmd(
  year,
  start.month,
  start.day.clamp(1, DateSerial.daysInMonth(year, start.month)),
);

bool _lastOfFeb(Ymd d) =>
    d.month == 2 && d.day == DateSerial.daysInMonth(d.year, 2);

/// 30/360 day count used by DAYS360 (US/NASD or European method).
int days360(Ymd s, Ymd e, {required bool european}) {
  var d1 = s.day, d2 = e.day;
  if (european) {
    if (d1 == 31) d1 = 30;
    if (d2 == 31) d2 = 30;
  } else {
    if (d1 == 31 || _lastOfFeb(s)) d1 = 30;
    // An end day of 31 becomes 30 only when the start is the 30th (else it counts as the 1st of
    // the next month).
    if (d2 == 31 && d1 == 30) d2 = 30;
  }
  return (e.year - s.year) * 360 + (e.month - s.month) * 30 + (d2 - d1);
}

/// Excel-compatible YEARFRAC for integer serials (dates are swapped when [s] > [e]).
double yearFrac(int s, int e, int basis) {
  if (s == e) return 0;
  if (s > e) {
    final t = s;
    s = e;
    e = t;
  }
  final a = DateSerial.toYmdInt(s), b = DateSerial.toYmdInt(e);
  switch (basis) {
    case 0:
      var d1 = a.day, d2 = b.day;
      if (d1 == 31 && d2 == 31) {
        d1 = 30;
        d2 = 30;
      } else if (d1 == 31) {
        d1 = 30;
      } else if (d1 == 30 && d2 == 31) {
        d2 = 30;
      } else if (_lastOfFeb(a) && _lastOfFeb(b)) {
        d1 = 30;
        d2 = 30;
      } else if (_lastOfFeb(a)) {
        d1 = 30;
      }
      return ((b.year - a.year) * 360 + (b.month - a.month) * 30 + (d2 - d1)) /
          360;
    case 1:
      final withinYear =
          a.year == b.year ||
          (a.year + 1 == b.year &&
              (a.month > b.month || (a.month == b.month && a.day >= b.day)));
      if (withinYear) {
        final double yearLength;
        if (a.year == b.year && DateSerial.isLeapYear(a.year)) {
          yearLength = 366;
        } else if (_feb29Between(s, e, a, b) || (b.month == 2 && b.day == 29)) {
          yearLength = 366;
        } else {
          yearLength = 365;
        }
        return (e - s) / yearLength;
      }
      final years = b.year - a.year + 1;
      final daysInYears =
          DateSerial.fromYmd(b.year + 1, 1, 1) -
          DateSerial.fromYmd(a.year, 1, 1);
      return (e - s) / (daysInYears / years);
    case 2:
      return (e - s) / 360;
    case 3:
      return (e - s) / 365;
    default:
      final d1 = a.day == 31 ? 30 : a.day, d2 = b.day == 31 ? 30 : b.day;
      return ((b.year - a.year) * 360 + (b.month - a.month) * 30 + (d2 - d1)) /
          360;
  }
}

bool _feb29Between(int s, int e, Ymd a, Ymd b) {
  if (DateSerial.isLeapYear(a.year) && s < DateSerial.fromYmd(a.year, 3, 1)) {
    return true;
  }
  if (DateSerial.isLeapYear(b.year) && e >= DateSerial.fromYmd(b.year, 3, 1)) {
    return true;
  }
  return false;
}
