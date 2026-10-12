import 'dart:math' as math;

import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../registry.dart';
import 'common.dart';
import 'day_count.dart';

/// Depreciation: SLN, SYD, DB, DDB, VDB, AMORLINC.

/// Double-declining depreciation of one period (LibreOffice `ScGetDDB`).
double _ddb(
  double cost,
  double salvage,
  double life,
  double period,
  double factor,
) {
  var rate = factor / life;
  double oldValue;
  if (rate >= 1) {
    rate = 1;
    oldValue = period == 1 ? cost : 0;
  } else {
    oldValue = cost * math.pow(1 - rate, period - 1);
  }
  final newValue = cost * math.pow(1 - rate, period);
  final d = newValue < salvage ? oldValue - salvage : oldValue - newValue;
  return d < 0 ? 0 : d;
}

/// Declining balance over [period] whole/partial periods with switch to straight line
/// (LibreOffice `ScInterVDB`).
double _interVdb(
  double cost,
  double salvage,
  double life,
  double life1,
  double period,
  double factor,
) {
  var vdb = 0.0;
  final intEnd = period.ceil();
  var remaining = cost - salvage;
  var nowSln = false;
  var sln = 0.0;
  for (var i = 1; i <= intEnd; i++) {
    double term;
    if (!nowSln) {
      final ddb = _ddb(cost, salvage, life, i.toDouble(), factor);
      sln = remaining / (life1 - (i - 1));
      if (sln > ddb) {
        term = sln;
        nowSln = true;
      } else {
        term = ddb;
        remaining -= ddb;
      }
    } else {
      term = sln;
    }
    if (i == intEnd) term *= period + 1 - intEnd;
    vdb += term;
  }
  return vdb;
}

double _vdb(
  double cost,
  double salvage,
  double life,
  double start,
  double end,
  double factor,
  bool noSwitch,
) {
  final intStart = start.floorToDouble();
  final intEnd = end.ceilToDouble();
  if (noSwitch) {
    var vdb = 0.0;
    for (var i = intStart.toInt() + 1; i <= intEnd.toInt(); i++) {
      var term = _ddb(cost, salvage, life, i.toDouble(), factor);
      if (i == intStart + 1) {
        term *= math.min(end, intStart + 1) - start;
      } else if (i == intEnd) {
        term *= end + 1 - intEnd;
      }
      vdb += term;
    }
    return vdb;
  }
  var part = 0.0;
  if (start != intStart) {
    final value = cost - _interVdb(cost, salvage, life, life, intStart, factor);
    part +=
        (start - intStart) *
        _interVdb(value, salvage, life, life - intStart, 1, factor);
  }
  if (end != intEnd) {
    final tempStart = intEnd - 1;
    final value =
        cost - _interVdb(cost, salvage, life, life, tempStart, factor);
    part +=
        (intEnd - end) *
        _interVdb(value, salvage, life, life - tempStart, 1, factor);
  }
  final base = cost - _interVdb(cost, salvage, life, life, intStart, factor);
  return _interVdb(
        base,
        salvage,
        life,
        life - intStart,
        intEnd - intStart,
        factor,
      ) -
      part;
}

void registerDepreciation(FunctionRegistryBuilder b) {
  final cost = P.num('cost', 'The initial cost of the asset.');
  final salvage = P.num(
    'salvage',
    'The value of the asset at the end of depreciation.',
  );
  final life = P.num(
    'life',
    'The number of periods over which the asset is depreciated.',
  );
  final period = P.num(
    'period',
    'The single period within life for which to calculate depreciation.',
  );

  b.fn(
    'SLN',
    'Calculates the depreciation of an asset for one period using the straight-line method.',
    [cost, salvage, life],
    (a) {
      final c = a.number(0), s = a.number(1), l = a.number(2);
      if (l == 0) fail(ErrorKind.div0, ErrorMessages.divByZero(a.fn, 3));
      return finResult((c - s) / l);
    },
    examples: ['SLN(30000, 7500, 10)'],
    seeAlso: ['SYD', 'DB', 'DDB'],
  );
  b.fn(
    'SYD',
    'Calculates the depreciation of an asset for a specified period using the sum of years digits method.',
    [cost, salvage, life, period],
    (a) {
      final c = a.number(0), s = a.number(1), l = a.number(2), p = a.number(3);
      if (l <= 0 || p <= 0 || p > l) fail(ErrorKind.num);
      return finResult((c - s) * (l - p + 1) * 2 / (l * (l + 1)));
    },
    examples: ['SYD(30000, 7500, 10, 1)'],
    seeAlso: ['SLN', 'DDB'],
  );
  b.fn(
    'DB',
    'Calculates the depreciation of an asset for a specified period using the arithmetic declining balance method.',
    [
      cost,
      salvage,
      life,
      period,
      P.num(
        'month',
        'The number of months in the first year of depreciation.',
        true,
        12,
      ),
    ],
    (a) {
      final c = a.number(0), s = a.number(1), l = a.number(2);
      final p = a.number(3).truncateToDouble();
      final m = a.numberOr(4, 12, blankIsDefault: true).truncateToDouble();
      if (m < 1 || m > 12 || c < 0 || s < 0 || l <= 0 || p <= 0 || p > l + 1) {
        fail(ErrorKind.num);
      }
      if (c == 0) return finResult(0);
      final rateRaw = 1 - math.pow(s / c, 1 / l);
      final rate = (rateRaw * 1000).round() / 1000;
      final first = c * rate * m / 12;
      if (p == 1) return finResult(first);
      var total = first;
      var dep = first;
      final full = math.min(p, l).toInt();
      for (var i = 2; i <= full; i++) {
        dep = (c - total) * rate;
        total += dep;
      }
      if (p > l) dep = (c - total) * rate * (12 - m) / 12;
      return finResult(dep);
    },
    examples: ['DB(1000000, 100000, 6, 1, 7)'],
    seeAlso: ['DDB', 'VDB', 'SLN'],
  );
  b.fn(
    'DDB',
    'Calculates the depreciation of an asset for a specified period using the double-declining balance method.',
    [
      cost,
      salvage,
      life,
      period,
      P.num('factor', 'The factor by which depreciation decreases.', true, 2),
    ],
    (a) {
      final c = a.number(0), s = a.number(1), l = a.number(2), p = a.number(3);
      final f = a.numberOr(4, 2, blankIsDefault: true);
      if (c < 0 || s < 0 || l <= 0 || p <= 0 || p > l || f <= 0) {
        fail(ErrorKind.num);
      }
      return finResult(_ddb(c, s, l, p, f));
    },
    examples: ['DDB(2400, 300, 10, 1, 2)'],
    seeAlso: ['DB', 'VDB', 'SYD'],
  );
  b.fn(
    'VDB',
    'Returns the depreciation of an asset for a particular period (or partial period) using the variable declining balance method.',
    [
      cost,
      salvage,
      life,
      P.num('start_period', 'The starting period to calculate depreciation.'),
      P.num('end_period', 'The ending period to calculate depreciation.'),
      P.num('factor', 'The factor by which depreciation decreases.', true, 2),
      P.bool_(
        'no_switch',
        'Whether to keep the declining balance method instead of switching to straight-line depreciation when it is greater.',
        true,
        false,
      ),
    ],
    (a) {
      final c = a.number(0), s = a.number(1), l = a.number(2);
      final st = a.number(3), en = a.number(4);
      final f = a.numberOr(5, 2, blankIsDefault: true);
      final noSwitch = a.boolOr(6, false);
      if (st < 0 ||
          en < st ||
          en > l ||
          c < 0 ||
          s < 0 ||
          s > c ||
          l <= 0 ||
          f <= 0) {
        fail(ErrorKind.num);
      }
      return finResult(_vdb(c, s, l, st, en, f, noSwitch));
    },
    examples: ['VDB(2400, 300, 10*12, 6, 18)'],
    seeAlso: ['DDB', 'DB'],
  );
  b.fn(
    'AMORLINC',
    'Returns the depreciation for an accounting period, or the prorated depreciation if the asset was purchased in the middle of a period (French accounting system).',
    [
      cost,
      P.num('purchase_date', 'The date the asset was purchased.'),
      P.num('first_period_end', 'The date the first period ended.'),
      salvage,
      P.num(
        'period',
        'The single period within life for which to calculate depreciation.',
      ),
      P.num('rate', 'The deprecation rate.'),
      P.num('basis', 'The day count convention to use.', true, 0),
    ],
    (a) {
      final c = a.number(0);
      final purchase = DayCount.dateArg(a, 1),
          firstEnd = DayCount.dateArg(a, 2);
      final s = a.number(3), p = a.number(4), r = a.number(5);
      final basis = DayCount.basisArg(a, 6);
      if (c <= 0 || s < 0 || s > c || p < 0 || r <= 0 || firstEnd < purchase) {
        fail(ErrorKind.num);
      }
      final per = p.truncate();
      final oneRate = c * r;
      final firstRate = DayCount.yearFrac(purchase, firstEnd, basis) * r * c;
      final fullPeriods = ((c - s - firstRate) / oneRate).truncate();
      double result;
      if (per == 0) {
        result = firstRate;
      } else if (per <= fullPeriods) {
        result = oneRate;
      } else if (per == fullPeriods + 1) {
        result = c - s - oneRate * fullPeriods - firstRate;
      } else {
        result = 0;
      }
      return finResult(result > 0 ? result : 0);
    },
    priority: Priority.p2,
    examples: [
      'AMORLINC(2400, DATE(2008,8,19), DATE(2008,12,31), 300, 1, 0.15, 1)',
    ],
    seeAlso: ['SLN', 'DB'],
  );
}
