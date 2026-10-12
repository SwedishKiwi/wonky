import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../values/dates.dart';
import '../../values/errors.dart';
import '../../values/format_hint.dart';
import '../../values/fvalue.dart';

/// Shared helpers of the date & time functions (05 §6.5, §15.6).

/// Smallest valid date serial (0001-01-01).
final int minDateSerial = DateSerial.fromYmd(1, 1, 1);

/// Largest valid date serial (9999-12-31).
final int maxDateSerial = DateSerial.fromYmd(9999, 12, 31);

/// Whether the integer date [serial] lies in the supported calendar range.
bool isValidDateSerial(int serial) =>
    serial >= minDateSerial && serial <= maxDateSerial;

/// Throws `#NUM!` unless [serial] is a supported date; returns it.
int checkDate(String fn, int serial) {
  if (!isValidDateSerial(serial)) {
    fail(ErrorKind.num, '$fn evaluates to an out of range value $serial.');
  }
  return serial;
}

/// Serial (with time fraction) of argument [i]: text is parsed with DATEVALUE rules by
/// [Args.number]; out-of-range dates are `#NUM!`.
double dateTimeArg(Args a, int i) {
  final x = a.number(i);
  if (!x.isFinite || x < minDateSerial || x >= maxDateSerial + 1) {
    fail(
      ErrorKind.num,
      'Function ${a.fn} parameter ${i + 1} value $x is out of range.',
    );
  }
  return x;
}

/// Integer date serial of argument [i] (time of day dropped).
int dateArg(Args a, int i) => dateTimeArg(a, i).floor();

/// Date result with the `date` format hint, range checked.
FValue dateResult(String fn, int serial) =>
    FNumber(checkDate(fn, serial).toDouble(), FormatHint.date);

/// Time of day of [serial] rounded to the nearest second (Sheets behavior for HOUR/MINUTE/SECOND).
({int hour, int minute, int second}) timeOfDay(double serial) {
  final frac = serial - serial.floor();
  var total = (frac * 86400).round();
  if (total >= 86400) total = 0;
  return (
    hour: total ~/ 3600,
    minute: (total % 3600) ~/ 60,
    second: total % 60,
  );
}

/// Day of week of [serial], 0 = Monday … 6 = Sunday.
int mondayIndex(int serial) => (DateSerial.weekday(serial.toDouble()) + 6) % 7;

/// Weekend days, indexed Monday (0) … Sunday (6).
typedef WeekendMask = List<bool>;

/// Parses a WORKDAY.INTL / NETWORKDAYS.INTL weekend argument at [i] (omitted/blank → Sat+Sun):
/// codes 1–7 (two days), 11–17 (one day), or a 7-character `"0000011"` mask starting Monday.
WeekendMask weekendArg(Args a, int i) {
  if (!a.has(i)) return weekendOfCode(1)!;
  final v = a.scalar(i);
  if (v is FOmitted || v is FEmpty) return weekendOfCode(1)!;
  if (v is FText) {
    final s = v.v;
    if (s.length == 7 && RegExp(r'^[01]{7}$').hasMatch(s)) {
      final mask = [for (var k = 0; k < 7; k++) s[k] == '1'];
      if (mask.every((w) => w)) {
        fail(
          ErrorKind.value,
          'Function ${a.fn} parameter ${i + 1} has no working days.',
        );
      }
      return mask;
    }
    // A number written as text is a weekend code (but a 0/1 mask of the wrong length is not);
    // anything else is invalid.
    final n = RegExp(r'^[01]+$').hasMatch(s) ? null : num.tryParse(s.trim());
    if (n == null) {
      fail(
        ErrorKind.value,
        "Function ${a.fn} parameter ${i + 1} value '$s' is not a valid weekend.",
      );
    }
    return _codeOrFail(a, i, n.toDouble());
  }
  return _codeOrFail(a, i, a.number(i));
}

WeekendMask _codeOrFail(Args a, int i, double x) {
  final mask = x == x.truncateToDouble() ? weekendOfCode(x.toInt()) : null;
  if (mask == null) {
    fail(
      ErrorKind.num,
      'Function ${a.fn} parameter ${i + 1} value is not a valid weekend code.',
    );
  }
  return mask;
}

/// Weekend mask of a numeric weekend code, or null when invalid.
WeekendMask? weekendOfCode(int code) {
  final mask = List<bool>.filled(7, false);
  if (code >= 1 && code <= 7) {
    // 1 = Sat+Sun, 2 = Sun+Mon, … 7 = Fri+Sat.
    mask[(code + 4) % 7] = true;
    mask[(code + 5) % 7] = true;
    return mask;
  }
  if (code >= 11 && code <= 17) {
    // 11 = Sunday only, 12 = Monday only, … 17 = Saturday only.
    mask[(code - 11 + 6) % 7] = true;
    return mask;
  }
  return null;
}

/// Sorted, de-duplicated holiday serials of argument [i] that fall on working days. Numbers
/// are dates, text is parsed with DATEVALUE rules, blanks are skipped, errors propagate.
List<int> holidaysArg(Args a, int i, WeekendMask weekend) {
  if (!a.has(i)) return const [];
  final days = <int>{};
  a.forEach(i, (v) {
    if (v is FRich) v = v.scalar;
    switch (v) {
      case FEmpty() || FOmitted():
        return;
      case FError():
        throw FormulaError(v);
      case FNumber(:final v):
        days.add(_holiday(a, i, v));
      case FText(:final v) when v.trim().isEmpty:
        return;
      case FText(:final v):
        final p = DateTimeParser.parse(
          v,
          a.locale,
          currentYear: a.ctx.currentYear,
        );
        if (p == null) {
          fail(ErrorKind.value, ErrorMessages.expectsNumber(a.fn, i + 1, v));
        }
        days.add(_holiday(a, i, p.serial));
      default:
        fail(
          ErrorKind.value,
          ErrorMessages.expectsNumber(a.fn, i + 1, v.debugText),
        );
    }
  });
  return days.where((d) => !weekend[mondayIndex(d)]).toList()..sort();
}

int _holiday(Args a, int i, double x) {
  if (!x.isFinite || x < minDateSerial || x >= maxDateSerial + 1) {
    fail(
      ErrorKind.num,
      'Function ${a.fn} parameter ${i + 1} contains an out of range date.',
    );
  }
  return x.floor();
}

/// Number of entries of the sorted list [xs] that are ≤ [x].
int countAtMost(List<int> xs, int x) {
  var lo = 0, hi = xs.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (xs[mid] <= x) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// Whether the sorted list [xs] contains [x].
bool containsSorted(List<int> xs, int x) {
  final k = countAtMost(xs, x);
  return k > 0 && xs[k - 1] == x;
}
