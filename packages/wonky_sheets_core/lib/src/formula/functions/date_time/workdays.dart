import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../registry.dart';
import 'date_common.dart';

/// Working-day arithmetic: NETWORKDAYS, NETWORKDAYS.INTL, WORKDAY, WORKDAY.INTL.
void registerWorkdays(FunctionRegistryBuilder b) {
  const holidaysDesc = 'A range or array of dates to consider holidays.';
  const weekendDesc =
      'A number (1–7: two-day weekends starting Saturday+Sunday, 11–17: single days starting '
      'Sunday) or a 7-character string of 0s and 1s starting Monday (1 = weekend day), e.g. "0000011".';

  FValue networkDays(Args a, WeekendMask weekend, int holidaysIndex) {
    final s = dateArg(a, 0), e = dateArg(a, 1);
    final holidays = holidaysArg(a, holidaysIndex, weekend);
    return FNumber(networkDaysBetween(s, e, weekend, holidays).toDouble());
  }

  FValue workday(Args a, WeekendMask weekend, int holidaysIndex) {
    final s = dateArg(a, 0);
    final n = a.number(1);
    if (n.abs() > 4000000) {
      fail(ErrorKind.num, '${a.fn} evaluates to an out of range value.');
    }
    final holidays = holidaysArg(a, holidaysIndex, weekend);
    return dateResult(a.fn, addWorkdays(s, n.truncate(), weekend, holidays));
  }

  b.fn(
    'NETWORKDAYS',
    'Returns the number of net working days between two provided days.',
    [
      P.num(
        'start_date',
        'The start date of the period from which to calculate the number of net working days.',
      ),
      P.num(
        'end_date',
        'The end date of the period from which to calculate the number of net working days.',
      ),
      P.range('holidays', holidaysDesc, true),
    ],
    (a) => networkDays(a, weekendOfCode(1)!, 2),
    liftable: true,
    priority: Priority.p0,
    examples: [
      'NETWORKDAYS(DATE(1969, 7, 16), DATE(1969, 7, 24))',
      'NETWORKDAYS(A1, B1, C1:C10)',
    ],
    seeAlso: ['NETWORKDAYS.INTL', 'WORKDAY'],
  );

  b.fn(
    'NETWORKDAYS.INTL',
    'Returns the number of net working days between two provided days excluding specified weekend days and holidays.',
    [
      P.num(
        'start_date',
        'The start date of the period from which to calculate the number of net working days.',
      ),
      P.num(
        'end_date',
        'The end date of the period from which to calculate the number of net working days.',
      ),
      P.scalar('weekend', weekendDesc, true, 1),
      P.range('holidays', holidaysDesc, true),
    ],
    (a) => networkDays(a, weekendArg(a, 2), 3),
    liftable: true,
    examples: [
      'NETWORKDAYS.INTL(DATE(1969, 7, 16), DATE(1969, 7, 24), 7)',
      'NETWORKDAYS.INTL(A1, B1, "0000011", C1:C10)',
    ],
    seeAlso: ['NETWORKDAYS', 'WORKDAY.INTL'],
  );

  b.fn(
    'WORKDAY',
    'Calculates the end date after a specified number of working days.',
    [
      P.num('start_date', 'The date from which to begin counting.'),
      P.num(
        'num_days',
        'The number of working days to advance from start_date. Negative values count backwards.',
      ),
      P.range('holidays', holidaysDesc, true),
    ],
    (a) => workday(a, weekendOfCode(1)!, 2),
    liftable: true,
    priority: Priority.p0,
    examples: ['WORKDAY(DATE(1969, 7, 16), 7)', 'WORKDAY(A1, 30, C1:C10)'],
    seeAlso: ['WORKDAY.INTL', 'NETWORKDAYS'],
  );

  b.fn(
    'WORKDAY.INTL',
    'Calculates the date after a specified number of workdays excluding specified weekend days and holidays.',
    [
      P.num('start_date', 'The date from which to begin counting.'),
      P.num(
        'num_days',
        'The number of working days to advance from start_date. Negative values count backwards.',
      ),
      P.scalar('weekend', weekendDesc, true, 1),
      P.range('holidays', holidaysDesc, true),
    ],
    (a) => workday(a, weekendArg(a, 2), 3),
    liftable: true,
    examples: [
      'WORKDAY.INTL(DATE(1969, 7, 16), 7, 7)',
      'WORKDAY.INTL(A1, 30, "0000011", C1:C10)',
    ],
    seeAlso: ['WORKDAY', 'NETWORKDAYS.INTL'],
  );
}

/// Working days in the inclusive span [lo, hi] (no holidays).
int _workdaysIn(int lo, int hi, WeekendMask weekend) {
  if (hi < lo) return 0;
  final n = hi - lo + 1;
  final perWeek = weekend.where((w) => !w).length;
  var count = (n ~/ 7) * perWeek;
  final restStart = lo + (n ~/ 7) * 7;
  for (var d = restStart; d <= hi; d++) {
    if (!weekend[mondayIndex(d)]) count++;
  }
  return count;
}

/// NETWORKDAYS: working days from [s] to [e] inclusive, negative when [s] > [e].
/// [holidays] are sorted working-day serials.
int networkDaysBetween(int s, int e, WeekendMask weekend, List<int> holidays) {
  final lo = s <= e ? s : e, hi = s <= e ? e : s;
  final count =
      _workdaysIn(lo, hi, weekend) -
      (countAtMost(holidays, hi) - countAtMost(holidays, lo - 1));
  return s <= e ? count : -count;
}

/// WORKDAY: the date [days] working days after (or before, when negative) [start].
/// [holidays] are sorted working-day serials.
int addWorkdays(int start, int days, WeekendMask weekend, List<int> holidays) {
  if (days == 0) return start;
  final dir = days > 0 ? 1 : -1;
  final perWeek = weekend.where((w) => !w).length;
  var d = start;
  var rem = days.abs();
  while (rem > 0) {
    if (rem > perWeek) {
      // Jump whole weeks: each covers exactly perWeek working days; holidays in the span are
      // added back.
      final weeks = (rem - 1) ~/ perWeek;
      final nd = d + dir * 7 * weeks;
      final skipped = dir > 0
          ? countAtMost(holidays, nd) - countAtMost(holidays, d)
          : countAtMost(holidays, d - 1) - countAtMost(holidays, nd - 1);
      rem = rem - weeks * perWeek + skipped;
      d = nd;
      if (!isValidDateSerial(d)) return d;
    } else {
      d += dir;
      if (!isValidDateSerial(d)) return d;
      if (!weekend[mondayIndex(d)] && !containsSorted(holidays, d)) rem--;
    }
  }
  return d;
}
