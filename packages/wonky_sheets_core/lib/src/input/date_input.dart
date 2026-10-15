import 'package:wonky_numfmt/wonky_numfmt.dart';

import '../format/number_format/inference.dart';

/// Kinds of recognized date/time input.
enum DateInputKind {
  /// Date only.
  date,

  /// Time of day.
  time,

  /// Date and time.
  dateTime,

  /// Elapsed duration (`36:15:00`).
  duration,
}

/// A date/time recognized in typed input.
final class DateInputMatch {
  /// Creates a match.
  const DateInputMatch(this.serial, this.kind, this.format);

  /// Serial value (days since 1899-12-30, fraction = time).
  final double serial;

  /// What was recognized.
  final DateInputKind kind;

  /// Auto-detected format (preset id or pattern).
  final String format;
}

/// Locale-aware recognizer for typed dates, times, date-times and durations
/// (03 §8.6): numeric dates in locale order, month names (short/long, with
/// dots), ISO dates, 2-digit years, partial dates, 12/24-hour times with
/// seconds and fractions.
final class DateInputRecognizer {
  DateInputRecognizer._(
    this.locale,
    this._months,
    this._weekdays,
    this._am,
    this._pm,
  );

  /// Locale data.
  final LocaleFormatData locale;

  /// Lower-cased month names (dots stripped) → month (1–12).
  final Map<String, int> _months;

  /// Lower-cased weekday names (skipped before dates).
  final Set<String> _weekdays;
  final Set<String> _am;
  final Set<String> _pm;

  static final Map<String, DateInputRecognizer> _cache = {};

  static const List<String> _enMonths = [
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september', //
    'october', 'november', 'december',
  ];
  static const List<String> _enWeekdays = [
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday', //
  ];

  /// Recognizer for [locale].
  static DateInputRecognizer forLocale(LocaleFormatData locale) =>
      _cache[locale.id] ??= _build(locale);

  static String _norm(String s) {
    var t = s.toLowerCase().trim();
    while (t.endsWith('.')) {
      t = t.substring(0, t.length - 1);
    }
    return t;
  }

  static DateInputRecognizer _build(LocaleFormatData l) {
    final months = <String, int>{};
    void addMonths(List<String> names) {
      for (var i = 0; i < names.length && i < 12; i++) {
        final n = _norm(names[i]);
        if (n.isNotEmpty) months.putIfAbsent(n, () => i + 1);
      }
    }

    addMonths(l.months);
    addMonths(l.standaloneMonths);
    addMonths(l.shortMonths);
    addMonths(l.standaloneShortMonths);
    addMonths(_enMonths);
    addMonths([for (final m in _enMonths) m.substring(0, 3)]);
    months.putIfAbsent('sept', () => 9);
    // Unique prefixes (≥ 3 letters) of long names.
    final prefixes = <String, Set<int>>{};
    for (final names in [l.months, l.standaloneMonths, _enMonths]) {
      for (var i = 0; i < 12; i++) {
        final n = _norm(names[i]);
        for (var k = 3; k < n.length; k++) {
          (prefixes[n.substring(0, k)] ??= {}).add(i + 1);
        }
      }
    }
    for (final e in prefixes.entries) {
      if (e.value.length == 1) months.putIfAbsent(e.key, () => e.value.first);
    }
    final weekdays = <String>{
      for (final w in [...l.weekdays, ...l.shortWeekdays, ..._enWeekdays])
        _norm(w),
      for (final w in _enWeekdays) w.substring(0, 3),
    };
    final am = {'am', 'a', 'a.m', _norm(l.am)};
    final pm = {'pm', 'p', 'p.m', _norm(l.pm)};
    return DateInputRecognizer._(l, months, weekdays, am, pm);
  }

  static final RegExp _timeRe = RegExp(
    r'(?:^|[\sT])(\d+):(\d{1,2})(?::(\d{1,2})(?:[.,](\d+))?)?(?:\s*([^\d\s:][^\s]*))?$',
    unicode: true,
  );
  static final RegExp _hourAmPmRe = RegExp(
    r'(?:^|\s)(\d{1,2})\s*([^\d\s:][^\s]*)$',
    unicode: true,
  );
  static final RegExp _isoRe = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');
  static final RegExp _tokenRe = RegExp(
    r'\d+|[\p{L}\p{M}]+\.?|\S',
    unicode: true,
  );

  static final RegExp _letterStart = RegExp(r'^\p{L}', unicode: true);

  static bool _allDigits(String s) {
    if (s.isEmpty) return false;
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c < 0x30 || c > 0x39) return false;
    }
    return true;
  }

  /// Recognizes [text] (trimmed). [today] supplies the year of partial
  /// dates (`1/2` → January 2 of that year).
  DateInputMatch? match(String text, DateTime today) {
    if (text.isEmpty) return null;
    final c0 = text.codeUnitAt(0);
    if (!(c0 >= 0x30 && c0 <= 0x39) && !_letterStart.hasMatch(text)) {
      return null;
    }
    // Time part at the end.
    _Time? time;
    var datePart = text;
    var isoT = false;
    final tm = _timeRe.firstMatch(text);
    if (tm != null) {
      final t = _time(
        tm.group(1)!,
        tm.group(2)!,
        tm.group(3),
        tm.group(4),
        tm.group(5),
      );
      if (t != null) {
        time = t;
        final start = tm.start;
        isoT = start < text.length && text[start] == 'T';
        datePart = text.substring(0, start).trim();
      } else if (tm.group(5) == null) {
        return null;
      }
    }
    if (time == null) {
      final hm = _hourAmPmRe.firstMatch(text);
      if (hm != null) {
        final t = _time(
          hm.group(1)!,
          '0',
          null,
          null,
          hm.group(2),
          hourOnly: true,
        );
        if (t != null) {
          time = t;
          datePart = text.substring(0, hm.start).trim();
        }
      }
    }
    while (datePart.endsWith(',')) {
      datePart = datePart.substring(0, datePart.length - 1).trimRight();
    }
    if (time != null && datePart.isEmpty) {
      if (time.duration) {
        return DateInputMatch(
          time.fraction,
          DateInputKind.duration,
          FormatInference.elapsed(seconds: time.seconds),
        );
      }
      return DateInputMatch(
        time.fraction,
        DateInputKind.time,
        FormatInference.time(
          seconds: time.seconds,
          fraction: time.fractional,
          twelveHour: time.twelveHour,
        ),
      );
    }
    if (time != null && time.duration) return null;
    if (isoT && !_isoRe.hasMatch(datePart)) return null;
    final date = _date(datePart, today);
    if (date == null) return null;
    final serial = SerialCalendar.serialOf(date.y, date.m, date.d);
    if (serial < SerialCalendar.minSerial ||
        serial > SerialCalendar.maxSerial) {
      return null;
    }
    if (time == null) {
      return DateInputMatch(
        serial.toDouble(),
        DateInputKind.date,
        date.iso ? FormatInference.isoDate() : NumberFormatPresets.date,
      );
    }
    return DateInputMatch(
      serial + time.fraction,
      DateInputKind.dateTime,
      date.iso
          ? FormatInference.isoDate(time: true, seconds: time.seconds)
          : NumberFormatPresets.dateTime,
    );
  }

  _Time? _time(
    String h,
    String m,
    String? s,
    String? frac,
    String? marker, {
    bool hourOnly = false,
  }) {
    var hour = int.parse(h);
    final minute = int.parse(m);
    final second = s == null ? 0 : int.parse(s);
    if (minute > 59 || second > 59) return null;
    if (!hourOnly && m.length != 2 && s != null) return null;
    var twelve = false;
    if (marker != null) {
      final mk = _norm(marker);
      final isAm = _am.contains(mk);
      final isPm = _pm.contains(mk);
      if (!isAm && !isPm) return null;
      if (hour < 1 || hour > 12) {
        if (!(hour == 0 && isAm)) return null;
      }
      hour = hour % 12 + (isPm ? 12 : 0);
      twelve = true;
    } else if (hourOnly) {
      return null;
    }
    var fracSeconds = 0.0;
    if (frac != null) fracSeconds = double.parse('0.$frac');
    final total = hour * 3600 + minute * 60 + second + fracSeconds;
    return _Time(
      total / 86400.0,
      seconds: s != null,
      fractional: frac != null,
      twelveHour: twelve,
      duration: !twelve && hour >= 24,
    );
  }

  int _year(String digits) {
    final y = int.parse(digits);
    if (digits.length <= 2) return y < 30 ? 2000 + y : 1900 + y;
    return y;
  }

  ({int y, int m, int d, bool iso})? _valid(
    int y,
    int m,
    int d, {
    bool iso = false,
  }) {
    if (m < 1 || m > 12 || d < 1 || y < 1 || y > 9999) return null;
    if (d > SerialCalendar.daysInMonth(y, m)) return null;
    return (y: y, m: m, d: d, iso: iso);
  }

  ({int y, int m, int d, bool iso})? _date(String s, DateTime today) {
    if (s.isEmpty) return null;
    final iso = _isoRe.firstMatch(s);
    if (iso != null) {
      return _valid(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
        iso: true,
      );
    }
    final numeric = _numericDate(s, today);
    if (numeric != null) return numeric;
    return _namedDate(s, today);
  }

  ({int y, int m, int d, bool iso})? _numericDate(String s, DateTime today) {
    String? sep;
    for (final c in const ['/', '-', '.']) {
      if (s.contains(c)) {
        if (sep != null) return null;
        sep = c;
      }
    }
    if (sep == null) return null;
    var body = s;
    if (sep == '.' && body.endsWith('.')) {
      body = body.substring(0, body.length - 1);
    }
    final parts = body.split(sep).map((p) => p.trim()).toList();
    if (parts.length < 2 || parts.length > 3 || !parts.every(_allDigits)) {
      return null;
    }
    final order = locale.dateOrder;
    if (parts.length == 3) {
      final a = parts[0], b = parts[1], c = parts[2];
      if (a.length == 4 || order == DatePartOrder.ymd) {
        if (a.length > 4 || b.length > 2 || c.length > 2) return null;
        return _valid(_year(a), int.parse(b), int.parse(c));
      }
      if (a.length > 2 || b.length > 2 || c.length > 4 || c.length == 3) {
        return null;
      }
      final y = _year(c);
      return order == DatePartOrder.mdy
          ? _valid(y, int.parse(a), int.parse(b))
          : _valid(y, int.parse(b), int.parse(a));
    }
    final a = parts[0], b = parts[1];
    if (b.length == 4 && a.length <= 2) {
      return _valid(int.parse(b), int.parse(a), 1);
    }
    if (a.length == 4 && b.length <= 2) {
      return _valid(int.parse(a), int.parse(b), 1);
    }
    if (a.length > 2 || b.length > 2) return null;
    final y = today.year;
    return order == DatePartOrder.dmy
        ? _valid(y, int.parse(b), int.parse(a))
        : _valid(y, int.parse(a), int.parse(b));
  }

  static const Set<String> _fillers = {'de', 'del', 'of', 'the'};

  ({int y, int m, int d, bool iso})? _namedDate(String s, DateTime today) {
    final tokens = [
      for (final m in _tokenRe.allMatches(s))
        if (!const {',', '.', '-', '/'}.contains(m.group(0))) m.group(0)!,
    ];
    if (tokens.isEmpty) return null;
    var month = -1;
    var monthPos = -1;
    final numbers = <(int, String)>[];
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (_allDigits(t)) {
        numbers.add((i, t));
        continue;
      }
      final n = _norm(t);
      final mo = _months[n];
      if (mo != null && month < 0) {
        month = mo;
        monthPos = i;
        continue;
      }
      if (i == 0 && _weekdays.contains(n)) continue;
      if (_fillers.contains(n)) continue;
      return null;
    }
    if (month < 0 || numbers.isEmpty || numbers.length > 2) return null;
    if (numbers.length == 1) {
      final (_, t) = numbers.first;
      if (t.length == 4) return _valid(int.parse(t), month, 1);
      if (t.length > 2) return null;
      return _valid(today.year, month, int.parse(t));
    }
    final (p1, t1) = numbers[0];
    final (_, t2) = numbers[1];
    if (t1.length == 4 && p1 < monthPos) {
      // 2026 Oct 12
      if (t2.length > 2) return null;
      return _valid(int.parse(t1), month, int.parse(t2));
    }
    if (t1.length > 2) return null;
    if (t2.length != 4 && t2.length != 2) return null;
    return _valid(_year(t2), month, int.parse(t1));
  }
}

final class _Time {
  const _Time(
    this.fraction, {
    required this.seconds,
    required this.fractional,
    required this.twelveHour,
    required this.duration,
  });

  final double fraction;
  final bool seconds;
  final bool fractional;
  final bool twelveHour;
  final bool duration;
}
