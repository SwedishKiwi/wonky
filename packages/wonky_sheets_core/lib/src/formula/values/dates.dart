import 'package:wonky_numfmt/wonky_numfmt.dart' show DateSerial;

import '../parser/formula_locale.dart';

export 'package:wonky_numfmt/wonky_numfmt.dart' show DateSerial, Ymd;

/// Result of parsing date/time text.
final class ParsedDateTime {
  final double serial;
  final bool hasDate;
  final bool hasTime;
  const ParsedDateTime(
    this.serial, {
    required this.hasDate,
    required this.hasTime,
  });
}

/// Parses date/time text the way `DATEVALUE`/`TIMEVALUE`/coercion do (05 §6.3, §15.6).
abstract final class DateTimeParser {
  static final RegExp _token = RegExp(
    r"(\d+)|([^\W\d_]+\.?)|(\S)",
    unicode: true,
  );

  /// Parses [text] in [locale]. [currentYear] is used when the year is omitted.
  static ParsedDateTime? parse(
    String text,
    FormulaLocale locale, {
    int currentYear = 2000,
  }) {
    final t = text.trim();
    if (t.isEmpty || t.length > 64) return null;
    final iso = _parseIso(t);
    if (iso != null) return iso;
    // Split off the time part: look for h:mm or h AM/PM.
    final tokens = _token.allMatches(t).map((m) => m.group(0)!).toList();
    if (tokens.isEmpty) return null;
    // Find time segment start: number followed by ':' or number followed by am/pm word.
    var timeStart = -1;
    for (var i = 0; i < tokens.length; i++) {
      if (_isNum(tokens[i]) &&
          i + 1 < tokens.length &&
          (tokens[i + 1] == ':' || _amPm(tokens[i + 1], locale) != null)) {
        // Only if the number is not part of a date like 12.10.2026 (handled by ':' check).
        timeStart = i;
        break;
      }
    }
    double? timeValue;
    List<String> dateTokens = tokens;
    if (timeStart >= 0) {
      final tv = _parseTime(tokens.sublist(timeStart), locale);
      if (tv == null) return null;
      timeValue = tv;
      dateTokens = tokens.sublist(0, timeStart);
    }
    int? dateSerial;
    if (dateTokens.isNotEmpty) {
      dateSerial = _parseDate(dateTokens, locale, currentYear);
      if (dateSerial == null) return null;
    }
    if (dateSerial == null && timeValue == null) return null;
    return ParsedDateTime(
      (dateSerial ?? 0) + (timeValue ?? 0),
      hasDate: dateSerial != null,
      hasTime: timeValue != null,
    );
  }

  static final RegExp _isoRe = RegExp(
    r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:[T ](\d{1,2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?\s*(Z|[+-]\d{2}:?\d{2})?)?$',
  );

  static ParsedDateTime? _parseIso(String t) {
    final m = _isoRe.firstMatch(t);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > DateSerial.daysInMonth(y, mo)) {
      return null;
    }
    final serial = DateSerial.fromYmd(y, mo, d).toDouble();
    if (m.group(4) == null) {
      return ParsedDateTime(serial, hasDate: true, hasTime: false);
    }
    final h = int.parse(m.group(4)!);
    final mi = int.parse(m.group(5)!);
    final s = m.group(6) == null ? 0 : int.parse(m.group(6)!);
    final frac = m.group(7) == null ? 0.0 : double.parse('0.${m.group(7)}');
    if (h > 23 || mi > 59 || s > 59) return null;
    return ParsedDateTime(
      serial + DateSerial.timeFraction(h, mi, s + frac),
      hasDate: true,
      hasTime: true,
    );
  }

  static bool _isNum(String s) =>
      s.isNotEmpty && s.codeUnitAt(0) >= 0x30 && s.codeUnitAt(0) <= 0x39;

  static int? _amPm(String word, FormulaLocale locale) {
    final w = word.toLowerCase().replaceAll('.', '');
    if (w == 'am' || w == 'a') return 0;
    if (w == 'pm' || w == 'p') return 1;
    for (var i = 0; i < locale.amPm.length && i < 2; i++) {
      if (locale.amPm[i].toLowerCase().replaceAll('.', '') == w) return i;
    }
    return null;
  }

  static double? _parseTime(List<String> toks, FormulaLocale locale) {
    // h[:mm[:ss[.fff]]] [am/pm]
    final nums = <String>[];
    var i = 0;
    String? fraction;
    while (i < toks.length) {
      final tk = toks[i];
      if (_isNum(tk)) {
        nums.add(tk);
        i++;
        if (i < toks.length && toks[i] == ':') {
          i++;
          continue;
        }
        if (i + 1 < toks.length &&
            (toks[i] == '.' || toks[i] == locale.decimal) &&
            _isNum(toks[i + 1]) &&
            nums.length == 3) {
          fraction = toks[i + 1];
          i += 2;
        }
        break;
      }
      return null;
    }
    if (nums.isEmpty || nums.length > 3) return null;
    int? ampm;
    if (i < toks.length) {
      ampm = _amPm(toks[i], locale);
      if (ampm == null) return null;
      i++;
    }
    if (i != toks.length) return null;
    var h = int.parse(nums[0]);
    final m = nums.length > 1 ? int.parse(nums[1]) : 0;
    final s = nums.length > 2 ? int.parse(nums[2]) : 0;
    if (nums.length == 1 && ampm == null) return null;
    if (m > 59 || s > 59) return null;
    if (ampm != null) {
      if (h < 1 || h > 12) return null;
      if (h == 12) h = 0;
      if (ampm == 1) h += 12;
    } else if (h > 9999) {
      return null;
    }
    final fs = fraction == null ? 0.0 : double.parse('0.$fraction');
    return (h * 3600 + m * 60 + s + fs) / 86400.0;
  }

  static int? _monthFromWord(String word, FormulaLocale locale) {
    final w = word.toLowerCase().replaceAll('.', '');
    if (w.length < 3) return null;
    for (final names in [
      locale.months,
      locale.shortMonths,
      FormulaLocale.englishMonths,
      FormulaLocale.englishShortMonths,
    ]) {
      for (var i = 0; i < names.length && i < 12; i++) {
        final n = names[i].toLowerCase().replaceAll('.', '');
        if (n == w ||
            (w.length >= 3 && n.startsWith(w) && n.length >= w.length)) {
          return i + 1;
        }
      }
    }
    if (w == 'sept') return 9;
    return null;
  }

  static bool _isWeekday(String word, FormulaLocale locale) {
    final w = word.toLowerCase().replaceAll('.', '');
    for (final names in [
      locale.weekdays,
      locale.shortWeekdays,
      FormulaLocale.englishWeekdays,
      FormulaLocale.englishShortWeekdays,
    ]) {
      for (final n in names) {
        if (n.toLowerCase().replaceAll('.', '') == w) return true;
      }
    }
    return false;
  }

  static int _year(String s) {
    final y = int.parse(s);
    if (s.length <= 2) return y < 30 ? 2000 + y : 1900 + y;
    return y;
  }

  static int? _parseDate(
    List<String> toks,
    FormulaLocale locale,
    int currentYear,
  ) {
    final nums = <String>[];
    int? monthWord;
    final seps = <String>{};
    var hasComma = false;
    for (final tk in toks) {
      if (_isNum(tk)) {
        nums.add(tk);
      } else if (tk.length == 1 && !RegExp(r'\w', unicode: true).hasMatch(tk)) {
        if (tk == ',') {
          hasComma = true;
        } else {
          seps.add(tk);
        }
      } else {
        final m = _monthFromWord(tk, locale);
        if (m != null && monthWord == null) {
          monthWord = m;
        } else if (_isWeekday(tk, locale)) {
          continue;
        } else {
          return null;
        }
      }
    }
    if (hasComma && monthWord == null) return null;
    if (seps.length > 1 &&
        !(seps.length == 2 && seps.contains('.') && seps.contains(' '))) {
      // allow "12. Okt. 2026"; otherwise mixed separators are invalid
      if (!seps.every((s) => s == '.' || s == '-' || s == ' ' || s == '/')) {
        return null;
      }
    }
    int y, m, d;
    if (monthWord != null) {
      m = monthWord;
      if (nums.isEmpty || nums.length > 2) return null;
      if (nums.length == 1) {
        final n = nums[0];
        if (n.length >= 3) {
          y = int.parse(n);
          d = 1;
        } else {
          d = int.parse(n);
          y = currentYear;
        }
      } else {
        // day year or year day (year has 4 digits)
        if (nums[0].length >= 3) {
          y = int.parse(nums[0]);
          d = int.parse(nums[1]);
        } else {
          d = int.parse(nums[0]);
          y = _year(nums[1]);
        }
      }
    } else {
      if (nums.length < 2 || nums.length > 3) return null;
      if (nums[0].length >= 3) {
        if (nums.length != 3) return null;
        y = int.parse(nums[0]);
        m = int.parse(nums[1]);
        d = int.parse(nums[2]);
      } else if (nums.length == 2) {
        y = currentYear;
        if (locale.dateOrder == DateOrder.dmy) {
          d = int.parse(nums[0]);
          m = int.parse(nums[1]);
        } else {
          m = int.parse(nums[0]);
          d = int.parse(nums[1]);
        }
      } else {
        y = _year(nums[2]);
        switch (locale.dateOrder) {
          case DateOrder.dmy:
            d = int.parse(nums[0]);
            m = int.parse(nums[1]);
          case DateOrder.mdy:
          case DateOrder.ymd:
            m = int.parse(nums[0]);
            d = int.parse(nums[1]);
        }
      }
    }
    if (m < 1 || m > 12 || d < 1 || y < 0 || y > 9999) return null;
    if (d > DateSerial.daysInMonth(y, m)) return null;
    return DateSerial.fromYmd(y, m, d);
  }
}
