import 'package:clock/clock.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../formula/values/dates.dart';
import 'condition.dart';

/// An inclusive range of date serials (whole days).
typedef DayRange = ({int lo, int hi});

/// "Today" and relative dates in the spreadsheet time zone (06 §15.2, 07 §3.3).
///
/// Time comes from an injected [Clock] (tests use `Clock.fixed`); the zone is
/// an IANA name (`Europe/Berlin`), `UTC`, or a fixed offset (`UTC+05:30`,
/// `GMT-8`, `+02:00`). Unknown zones fall back to UTC.
final class SpreadsheetDates {
  /// Creates the resolver.
  SpreadsheetDates({this.timeZone = 'UTC', Clock? clock}) : _clock = clock;

  /// The spreadsheet time zone.
  final String timeZone;
  final Clock? _clock;

  Clock get _now => _clock ?? clock;

  static bool _tzInitialized = false;

  static final RegExp _offsetRe = RegExp(r'^(?:UTC|GMT)?\s*([+-])(\d{1,2})(?::?(\d{2}))?$');

  /// The UTC offset of [timeZone] at the instant [utc].
  Duration offsetAt(DateTime utc) {
    final z = timeZone.trim();
    if (z.isEmpty || z == 'UTC' || z == 'GMT' || z == 'Etc/UTC' || z == 'Z') return Duration.zero;
    final m = _offsetRe.firstMatch(z);
    if (m != null) {
      final sign = m.group(1) == '-' ? -1 : 1;
      final h = int.parse(m.group(2)!);
      final min = int.tryParse(m.group(3) ?? '') ?? 0;
      return Duration(minutes: sign * (h * 60 + min));
    }
    try {
      if (!_tzInitialized) {
        if (!tz.timeZoneDatabase.isInitialized) tzdata.initializeTimeZones();
        _tzInitialized = true;
      }
      final loc = tz.getLocation(z);
      return Duration(milliseconds: loc.timeZone(utc.millisecondsSinceEpoch).offset);
    } on Object {
      return Duration.zero;
    }
  }

  /// The current local wall-clock time as a date serial (fractional days).
  double nowSerial() {
    final utc = _now.now().toUtc();
    final local = utc.add(offsetAt(utc));
    return DateSerial.fromUnixMillis(local.millisecondsSinceEpoch);
  }

  /// Today's date serial in the spreadsheet time zone.
  int todaySerial() => nowSerial().floor();

  /// The UTC instant of the next local midnight (when relative-date rules must
  /// be re-evaluated).
  DateTime nextMidnightUtc() {
    final utc = _now.now().toUtc();
    final offset = offsetAt(utc);
    final local = utc.add(offset);
    final nextLocal = DateTime.utc(local.year, local.month, local.day + 1);
    return nextLocal.subtract(offset);
  }

  /// The days covered by [rel] given [today]: single days for today /
  /// tomorrow / yesterday; `[start, today]` for the past week / month / year.
  static DayRange range(RelativeDate rel, int today) => switch (rel) {
    RelativeDate.today => (lo: today, hi: today),
    RelativeDate.tomorrow => (lo: today + 1, hi: today + 1),
    RelativeDate.yesterday => (lo: today - 1, hi: today - 1),
    RelativeDate.pastWeek => (lo: today - 7, hi: today),
    RelativeDate.pastMonth => (lo: addMonths(today, -1), hi: today),
    RelativeDate.pastYear => (lo: addMonths(today, -12), hi: today),
  };

  /// `EDATE`: [serial] shifted by [months], clamped to the month's last day.
  static int addMonths(int serial, int months) {
    final d = DateSerial.toYmdInt(serial);
    final total = d.year * 12 + (d.month - 1) + months;
    final y = total ~/ 12 - (total < 0 && total % 12 != 0 ? 1 : 0);
    final m = total - y * 12 + 1;
    final day = d.day.clamp(1, DateSerial.daysInMonth(y, m));
    return DateSerial.fromYmd(y, m, day);
  }
}
