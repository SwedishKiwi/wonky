import '../../eval/eval_context.dart';
import '../../values/dates.dart';
import '../../values/errors.dart';
import '../../values/format_hint.dart';
import '../../values/fvalue.dart';
import '../registry.dart';
import 'date_common.dart';

/// Constructing, parsing and splitting dates and times; NOW and TODAY.
void registerCalendar(FunctionRegistryBuilder b) {
  b.fn(
    'DATE',
    'Converts a year, month, and day into a date.',
    [
      P.num(
        'year',
        'The year component of the date. Years 0–1899 are added to 1900.',
      ),
      P.num(
        'month',
        'The month component of the date; values outside 1–12 roll over into other years.',
      ),
      P.num(
        'day',
        'The day component of the date; values outside the month roll over into other months.',
      ),
    ],
    (a) {
      var y = a.integer(0);
      final m = a.integer(1), d = a.integer(2);
      if (y < 0 || y >= 10000) {
        fail(
          ErrorKind.num,
          'Function DATE parameter 1 value is $y. It should be between 0 and 9999.',
        );
      }
      if (y < 1900) y += 1900;
      if (m.abs() > 120000 || d.abs() > 4000000) {
        fail(ErrorKind.num, 'DATE evaluates to an out of range value.');
      }
      return dateResult('DATE', DateSerial.fromYmd(y, m, d));
    },
    priority: Priority.p0,
    examples: ['DATE(1969, 7, 20)', 'DATE(2024, 13, 1)'],
    seeAlso: ['TIME', 'DATEVALUE', 'YEAR', 'MONTH', 'DAY'],
  );

  b.fn(
    'DATEVALUE',
    'Converts a provided date string in a known format to a date value.',
    [
      P.text(
        'date_string',
        'The string representing the date, e.g. "2024-03-01" or "1 March 2024".',
      ),
    ],
    (a) {
      final v = a.scalar(0);
      if (v is FNumber) {
        return dateResult('DATEVALUE', checkDate('DATEVALUE', v.v.floor()));
      }
      final s = a.text(0);
      final p = DateTimeParser.parse(
        s,
        a.locale,
        currentYear: a.ctx.currentYear,
      );
      if (p == null || !p.hasDate) {
        fail(
          ErrorKind.value,
          "DATEVALUE parameter '$s' cannot be parsed to date/time.",
        );
      }
      return dateResult('DATEVALUE', p.serial.floor());
    },
    priority: Priority.p0,
    examples: ['DATEVALUE("1969-07-20")', 'DATEVALUE("7/20/1969")'],
    seeAlso: ['TIMEVALUE', 'DATE', 'TO_DATE'],
  );

  b.fn(
    'TIMEVALUE',
    'Returns the fraction of a 24-hour day the time represents.',
    [
      P.text(
        'time_string',
        'The string that holds the time representation, e.g. "2:15 PM".',
      ),
    ],
    (a) {
      final v = a.scalar(0);
      if (v is FNumber) {
        return FNumber(v.v - v.v.floorToDouble(), FormatHint.time);
      }
      final s = a.text(0);
      final p = DateTimeParser.parse(
        s,
        a.locale,
        currentYear: a.ctx.currentYear,
      );
      if (p == null) {
        fail(
          ErrorKind.value,
          "TIMEVALUE parameter '$s' cannot be parsed to date/time.",
        );
      }
      return FNumber(p.serial - p.serial.floorToDouble(), FormatHint.time);
    },
    priority: Priority.p0,
    examples: ['TIMEVALUE("2:15 PM")', 'TIMEVALUE("14:15:30")'],
    seeAlso: ['DATEVALUE', 'TIME'],
  );

  b.fn(
    'TIME',
    'Converts an hour, minute, and second into a time.',
    [
      P.num('hour', 'The hour component of the time.'),
      P.num('minute', 'The minute component of the time.'),
      P.num('second', 'The second component of the time.'),
    ],
    (a) {
      final h = a.number(0).truncateToDouble();
      final m = a.number(1).truncateToDouble();
      final s = a.number(2).truncateToDouble();
      final total = h * 3600 + m * 60 + s;
      if (total < 0) {
        fail(ErrorKind.num, 'TIME evaluates to an out of range value.');
      }
      if (total > 9.0e15) {
        fail(ErrorKind.num, 'TIME evaluates to an out of range value.');
      }
      return FNumber((total % 86400) / 86400, FormatHint.time);
    },
    priority: Priority.p0,
    examples: ['TIME(11, 40, 59)', 'TIME(25, 0, 0)'],
    seeAlso: ['DATE', 'TIMEVALUE', 'HOUR', 'MINUTE', 'SECOND'],
  );

  // ---- date parts
  void datePart(
    String name,
    String summary,
    int Function(Ymd ymd) part,
    List<String> examples,
  ) {
    b.fn(
      name,
      summary,
      [
        P.num(
          'date',
          'The date from which to extract the component. Text is parsed as a date.',
        ),
      ],
      (a) => FNumber(part(DateSerial.toYmdInt(dateArg(a, 0))).toDouble()),
      priority: Priority.p0,
      examples: examples,
      seeAlso: const ['DATE', 'YEAR', 'MONTH', 'DAY'],
    );
  }

  datePart(
    'YEAR',
    'Returns the year specified by a given date.',
    (d) => d.year,
    ['YEAR(DATE(1969, 7, 20))', 'YEAR("2024-03-01")'],
  );
  datePart(
    'MONTH',
    'Returns the month of the year a specific date falls in, in numeric format.',
    (d) => d.month,
    ['MONTH(DATE(1969, 7, 20))'],
  );
  datePart(
    'DAY',
    'Returns the day of the month that a specific date falls on, in numeric format.',
    (d) => d.day,
    ['DAY(DATE(1969, 7, 20))'],
  );

  // ---- time parts (rounded to the nearest second, like Sheets)
  void timePart(
    String name,
    String summary,
    int Function(({int hour, int minute, int second}) t) part,
    List<String> examples,
  ) {
    b.fn(
      name,
      summary,
      [
        P.num(
          'time',
          'The time from which to extract the component. Text is parsed as a time.',
        ),
      ],
      (a) => FNumber(part(timeOfDay(dateTimeArg(a, 0))).toDouble()),
      priority: Priority.p0,
      examples: examples,
      seeAlso: const ['TIME', 'HOUR', 'MINUTE', 'SECOND'],
    );
  }

  timePart(
    'HOUR',
    'Returns the hour component of a specific time, in numeric format.',
    (t) => t.hour,
    ['HOUR("2:15 PM")', 'HOUR(NOW())'],
  );
  timePart(
    'MINUTE',
    'Returns the minute component of a specific time, in numeric format.',
    (t) => t.minute,
    ['MINUTE("2:15 PM")'],
  );
  timePart(
    'SECOND',
    'Returns the second component of a specific time, in numeric format.',
    (t) => t.second,
    ['SECOND("14:15:30")'],
  );

  // ---- month arithmetic
  b.fn(
    'EDATE',
    'Returns a date a specified number of months before or after another date.',
    [
      P.num('start_date', 'The date from which to calculate the result.'),
      P.num(
        'months',
        'The number of months before (negative) or after (positive) start_date.',
      ),
    ],
    (a) {
      final d = DateSerial.toYmdInt(dateArg(a, 0));
      final months = a.integer(1);
      if (months.abs() > 120000) {
        fail(ErrorKind.num, 'EDATE evaluates to an out of range value.');
      }
      final first = DateSerial.fromYmd(d.year, d.month + months, 1);
      final t = DateSerial.toYmdInt(first);
      final day = d.day.clamp(1, DateSerial.daysInMonth(t.year, t.month));
      return dateResult('EDATE', first + day - 1);
    },
    priority: Priority.p0,
    examples: ['EDATE(DATE(1969, 7, 20), 1)', 'EDATE("2024-01-31", 1)'],
    seeAlso: ['EOMONTH', 'DATE'],
  );

  b.fn(
    'EOMONTH',
    'Returns a date representing the last day of a month which falls a specified number of months before or after another date.',
    [
      P.num('start_date', 'The date from which to calculate the result.'),
      P.num(
        'months',
        'The number of months before (negative) or after (positive) start_date to consider.',
      ),
    ],
    (a) {
      final d = DateSerial.toYmdInt(dateArg(a, 0));
      final months = a.integer(1);
      if (months.abs() > 120000) {
        fail(ErrorKind.num, 'EOMONTH evaluates to an out of range value.');
      }
      return dateResult(
        'EOMONTH',
        DateSerial.fromYmd(d.year, d.month + months + 1, 1) - 1,
      );
    },
    priority: Priority.p0,
    examples: ['EOMONTH(DATE(1969, 7, 20), 1)', 'EOMONTH("2024-02-10", 0)'],
    seeAlso: ['EDATE', 'DATE'],
  );

  b.fn(
    'EPOCHTODATE',
    'Converts a Unix epoch timestamp in seconds, milliseconds, or microseconds to a datetime in Universal Time Coordinated (UTC).',
    [
      P.num(
        'timestamp',
        'A Unix epoch timestamp, in seconds, milliseconds, or microseconds.',
      ),
      P.num(
        'unit',
        'The unit of time of the timestamp: 1 = seconds, 2 = milliseconds, 3 = microseconds.',
        true,
        1,
      ),
    ],
    (a) {
      final ts = a.number(0);
      final unit = a.has(1) ? a.number(1) : 1.0;
      final ms = switch (unit) {
        1 => ts * 1000,
        2 => ts,
        3 => ts / 1000,
        _ => fail(
          ErrorKind.num,
          'Function EPOCHTODATE parameter 2 value should be 1, 2 or 3.',
        ),
      };
      if (ts < 0) {
        fail(
          ErrorKind.num,
          'Function EPOCHTODATE parameter 1 value is $ts. It should be greater than or equal to 0.',
        );
      }
      if (DateSerial.unixEpoch + ms / 86400000 >= maxDateSerial + 1) {
        fail(ErrorKind.num, 'EPOCHTODATE evaluates to an out of range value.');
      }
      return FNumber(
        DateSerial.fromUnixMillis(ms.truncate()),
        FormatHint.dateTime,
      );
    },
    examples: ['EPOCHTODATE(1655906710)', 'EPOCHTODATE(1655906568893, 2)'],
    seeAlso: ['DATE', 'NOW'],
  );

  // ---- current date and time (volatile, 05 §9.3, §12)
  b.fn(
    'NOW',
    'Returns the current date and time as a date value, in the spreadsheet time zone.',
    const [],
    (a) => FNumber(localNowSerial(a.ctx), FormatHint.dateTime),
    volatile: true,
    priority: Priority.p0,
    examples: ['NOW()'],
    seeAlso: ['TODAY'],
  );
  b.fn(
    'TODAY',
    'Returns the current date as a date value, in the spreadsheet time zone.',
    const [],
    (a) => FNumber(localNowSerial(a.ctx).floorToDouble(), FormatHint.date),
    volatile: true,
    priority: Priority.p0,
    examples: ['TODAY()'],
    seeAlso: ['NOW'],
  );
}

/// Serial of the current instant (EngineClock) as local date-time in the spreadsheet time zone.
double localNowSerial(EvalContext ctx) {
  ctx.deps.volatile = true;
  final utc = ctx.host.clock.nowUtc();
  final offset = ctx.host.timeZones.offsetAt(ctx.host.settings.timeZone, utc);
  return DateSerial.fromUnixMillis(
    utc.millisecondsSinceEpoch + offset.inMilliseconds,
  );
}
