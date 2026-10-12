import '../../eval/eval_context.dart';
import '../../values/dates.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../registry.dart';
import 'date_common.dart';

/// Days of the week and week numbers: WEEKDAY, WEEKNUM, ISOWEEKNUM.
void registerWeeks(FunctionRegistryBuilder b) {
  b.fn(
    'WEEKDAY',
    'Returns a number representing the day of the week of the date provided.',
    [
      P.num('date', 'The date for which to determine the day of the week.'),
      P.num(
        'type',
        'The numbering system: 1 = Sunday is 1 (default), 2 = Monday is 1, 3 = Monday is 0, '
            '11–17 = week starts Monday … Sunday with 1.',
        true,
        1,
      ),
    ],
    (a) {
      final d = dateArg(a, 0);
      final type = a.has(1) ? a.number(1).truncate() : 1;
      final r = weekdayOf(d, type);
      if (r == null) {
        fail(
          ErrorKind.num,
          'Function WEEKDAY parameter 2 value $type is out of range.',
        );
      }
      return FNumber(r.toDouble());
    },
    priority: Priority.p0,
    examples: ['WEEKDAY(DATE(1969, 7, 20))', 'WEEKDAY("2008-02-14", 2)'],
    seeAlso: ['WEEKNUM', 'ISOWEEKNUM', 'DAY'],
  );

  b.fn(
    'WEEKNUM',
    'Returns a number representing the week of the year where the provided date falls.',
    [
      P.num('date', 'The date for which to determine the week number.'),
      P.num(
        'type',
        'The day the week starts on: 1 = Sunday (default), 2 = Monday, 11–17 = Monday … Sunday, '
            '21 = ISO 8601 weeks.',
        true,
        1,
      ),
    ],
    (a) {
      final d = dateArg(a, 0);
      final type = a.has(1) ? a.number(1).truncate() : 1;
      final r = weekNum(d, type);
      if (r == null) {
        fail(
          ErrorKind.num,
          'Function WEEKNUM parameter 2 value $type is out of range.',
        );
      }
      return FNumber(r.toDouble());
    },
    priority: Priority.p0,
    examples: ['WEEKNUM(DATE(1969, 7, 20))', 'WEEKNUM("2012-03-09", 2)'],
    seeAlso: ['ISOWEEKNUM', 'WEEKDAY'],
  );

  b.fn(
    'ISOWEEKNUM',
    'Returns the number of the ISO week of the year where the provided date falls.',
    [P.num('date', 'The date for which to determine the ISO week number.')],
    (a) => FNumber(isoWeekNum(dateArg(a, 0)).toDouble()),
    examples: ['ISOWEEKNUM(DATE(1969, 7, 20))', 'ISOWEEKNUM("2012-03-09")'],
    seeAlso: ['WEEKNUM', 'WEEKDAY'],
  );
}

/// WEEKDAY of serial [d] for return [type], or null when the type is invalid.
int? weekdayOf(int d, int type) {
  final sun0 = DateSerial.weekday(d.toDouble()); // 0 = Sunday
  final mon0 = (sun0 + 6) % 7; // 0 = Monday
  return switch (type) {
    1 => sun0 + 1,
    2 => mon0 + 1,
    3 => mon0,
    // 11 = week starts Monday … 16 = Saturday, 17 = Sunday.
    >= 11 && <= 17 => (mon0 - (type - 11)) % 7 + 1,
    _ => null,
  };
}

/// WEEKNUM of serial [d]; null for an invalid [type].
int? weekNum(int d, int type) {
  if (type == 21) return isoWeekNum(d);
  final int start; // first day of the week, 0 = Monday
  if (type == 1) {
    start = 6;
  } else if (type == 2) {
    start = 0;
  } else if (type >= 11 && type <= 17) {
    start = type - 11;
  } else {
    return null;
  }
  final y = DateSerial.toYmdInt(d).year;
  final jan1 = DateSerial.fromYmd(y, 1, 1);
  final offset = (mondayIndex(jan1) - start) % 7;
  return (d - jan1 + offset) ~/ 7 + 1;
}

/// ISO 8601 week number of serial [d].
int isoWeekNum(int d) {
  final thursday = d - mondayIndex(d) + 3;
  final y = DateSerial.toYmdInt(thursday).year;
  return (thursday - DateSerial.fromYmd(y, 1, 1)) ~/ 7 + 1;
}
