/// Serial date system of the spreadsheet (06 §5.6): value = days since
/// 1899-12-30 00:00, fraction = time of day. Negative serials are dates before
/// 1899-12-30 (down to 0001-01-01); the maximum is 9999-12-31.
abstract final class SerialCalendar {
  /// Days from 1970-01-01 to 1899-12-30.
  static const int _epochOffset = 25569;

  /// Serial of 0001-01-01.
  static const int minSerial = -693593;

  /// Serial of 9999-12-31.
  static const int maxSerial = 2958465;

  /// Whether [serial] lies in the supported date range (fraction included).
  static bool inRange(double serial) =>
      serial.isFinite && serial >= minSerial && serial < maxSerial + 1;

  static int _floorDiv(int a, int b) {
    final q = a ~/ b;
    return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q;
  }

  /// Serial (whole days) of the proleptic Gregorian date [year]-[month]-[day].
  /// Month and day overflow are normalized (month 13 → January next year,
  /// day 0 → last day of the previous month).
  static int serialOf(int year, int month, int day) {
    final m0 = month - 1;
    year += _floorDiv(m0, 12);
    month = m0 % 12 + 1;
    final y = month <= 2 ? year - 1 : year;
    final era = _floorDiv(y, 400);
    final yoe = y - era * 400;
    final mp = (month + 9) % 12;
    final doy = (153 * mp + 2) ~/ 5;
    final doe = yoe * 365 + yoe ~/ 4 - yoe ~/ 100 + doy;
    final days1970 = era * 146097 + doe - 719468;
    return days1970 + _epochOffset + day - 1;
  }

  /// Year, month (1–12) and day (1–31) of the whole-day serial [serial].
  static ({int year, int month, int day}) dateOf(int serial) {
    final z = serial - _epochOffset + 719468;
    final era = _floorDiv(z, 146097);
    final doe = z - era * 146097;
    final yoe = (doe - doe ~/ 1460 + doe ~/ 36524 - doe ~/ 146096) ~/ 365;
    final y = yoe + era * 400;
    final doy = doe - (365 * yoe + yoe ~/ 4 - yoe ~/ 100);
    final mp = (5 * doy + 2) ~/ 153;
    final d = doy - (153 * mp + 2) ~/ 5 + 1;
    final m = mp < 10 ? mp + 3 : mp - 9;
    return (year: m <= 2 ? y + 1 : y, month: m, day: d);
  }

  /// Day of week of the whole-day serial: 0 = Sunday … 6 = Saturday.
  static int weekdayOf(int serial) => (serial + 6) % 7;

  /// Whether [year] is a leap year.
  static bool isLeapYear(int year) => (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  /// Number of days in [month] of [year].
  static int daysInMonth(int year, int month) => switch (month) {
    2 => isLeapYear(year) ? 29 : 28,
    4 || 6 || 9 || 11 => 30,
    _ => 31,
  };

  /// Serial of a date-time (wall clock, no time zone).
  static double serialOfDateTime(
    int year,
    int month,
    int day, [
    int hour = 0,
    int minute = 0,
    num second = 0,
  ]) => serialOf(year, month, day) + (hour * 3600 + minute * 60 + second) / 86400.0;

  /// Serial of the date part of [dateTime] (its fields, ignoring time zone).
  static int serialOfDate(DateTime dateTime) =>
      serialOf(dateTime.year, dateTime.month, dateTime.day);

  /// Adds [months] to the date [serial] (whole days), clamping the day to the
  /// end of the target month (Jan 31 + 1 month → Feb 28/29).
  static int addMonths(int serial, int months, {int? preferredDay}) {
    final d = dateOf(serial);
    final total = d.year * 12 + (d.month - 1) + months;
    final year = _floorDiv(total, 12);
    final month = total - year * 12 + 1;
    final day = preferredDay ?? d.day;
    final dim = daysInMonth(year, month);
    return serialOf(year, month, day > dim ? dim : day);
  }
}
