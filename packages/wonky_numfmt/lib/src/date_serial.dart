/// A civil date.
typedef Ymd = ({int year, int month, int day});

/// Serial dates: days since 1899-12-30 (02 §2), fractional part = time of day.
abstract final class DateSerial {
  /// Serial of 1970-01-01 (Unix epoch).
  static const int unixEpoch = 25569;

  static int _floorDiv(int a, int b) => (a / b).floor();

  /// Days since 1970-01-01 for a proleptic Gregorian date (Hinnant's algorithm).
  static int _daysFromCivil(int y, int m, int d) {
    y -= m <= 2 ? 1 : 0;
    final era = _floorDiv(y, 400);
    final yoe = y - era * 400;
    final mp = (m + 9) % 12;
    final doy = (153 * mp + 2) ~/ 5 + d - 1;
    final doe = yoe * 365 + yoe ~/ 4 - yoe ~/ 100 + doy;
    return era * 146097 + doe - 719468;
  }

  static Ymd _civilFromDays(int z) {
    z += 719468;
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

  /// Serial of a date; month and day overflow roll over (`DATE(2024, 13, 1)` = 2025-01-01).
  static int fromYmd(int year, int month, int day) {
    final m0 = month - 1;
    final y = year + _floorDiv(m0, 12);
    final m = m0 - _floorDiv(m0, 12) * 12 + 1;
    return _daysFromCivil(y, m, 1) + (day - 1) + unixEpoch;
  }

  /// Civil date of the integer part of [serial].
  static Ymd toYmd(double serial) => _civilFromDays(serial.floor() - unixEpoch);

  /// Civil date of an integer serial.
  static Ymd toYmdInt(int serial) => _civilFromDays(serial - unixEpoch);

  static bool isLeapYear(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  static int daysInMonth(int y, int m) {
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (m == 2 && isLeapYear(y)) return 29;
    return days[m - 1];
  }

  /// Day of week, 0 = Sunday … 6 = Saturday.
  static int weekday(double serial) {
    final d = serial.floor();
    // Serial 1 (1899-12-31) was a Sunday.
    return ((d - 1) % 7 + 7) % 7;
  }

  /// Time of day of [serial] split into (hour, minute, second, millisecond), rounded to the
  /// nearest millisecond.
  static ({int hour, int minute, int second, int ms}) timeOf(double serial) {
    final frac = serial - serial.floor();
    var totalMs = (frac * 86400000).round();
    if (totalMs >= 86400000) totalMs = 0;
    final h = totalMs ~/ 3600000;
    final m = (totalMs % 3600000) ~/ 60000;
    final s = (totalMs % 60000) ~/ 1000;
    final ms = totalMs % 1000;
    return (hour: h, minute: m, second: s, ms: ms);
  }

  /// Seconds-resolution time fraction.
  static double timeFraction(int h, int m, num s) =>
      (h * 3600 + m * 60 + s) / 86400.0;

  /// Serial (with fraction) of a UTC instant expressed as milliseconds since the Unix epoch.
  static double fromUnixMillis(int ms) => unixEpoch + ms / 86400000.0;

  /// Unix milliseconds of a serial interpreted as UTC.
  static int toUnixMillis(double serial) =>
      ((serial - unixEpoch) * 86400000).round();
}
