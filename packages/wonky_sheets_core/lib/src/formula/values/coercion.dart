import '../parser/formula_locale.dart';
import 'dates.dart';
import 'errors.dart';
import 'format_hint.dart';
import 'fvalue.dart';
import 'numeric.dart';

/// Parses numeric text the way formula coercion does (05 §6.3): plain numbers, exponents,
/// locale grouping and currency, percent, parenthesized negatives, dates and times.
abstract final class TextNumberParser {
  static const Set<String> _currencySymbols = {
    r'$',
    '€',
    '£',
    '¥',
    '₹',
    '₩',
    '₽',
    '₺',
    '₪',
    '฿',
    '₫',
    '₴',
    'zł',
    'kr',
    'Kč',
    'Ft',
    r'R$', //
  };

  /// Returns the number and its implied format, or null when [text] is not numeric.
  static (double, FormatHint)? parse(
    String text,
    FormulaLocale locale, {
    int currentYear = 2000,
    bool allowDates = true,
  }) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final n = parsePlain(t, locale);
    if (n != null) return n;
    if (!allowDates) return null;
    final dt = DateTimeParser.parse(t, locale, currentYear: currentYear);
    if (dt == null) return null;
    final hint = dt.hasDate
        ? (dt.hasTime ? FormatHint.dateTime : FormatHint.date)
        : (dt.serial >= 1 ? FormatHint.duration : FormatHint.time);
    return (dt.serial, hint);
  }

  /// Numbers only (no dates).
  static (double, FormatHint)? parsePlain(String t, FormulaLocale locale) {
    var s = t;
    var negative = false;
    var hint = FormatHint.none;
    if (s.startsWith('(') && s.endsWith(')') && s.length > 2) {
      negative = true;
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.startsWith('-')) {
      negative = !negative;
      s = s.substring(1).trimLeft();
    } else if (s.startsWith('+')) {
      s = s.substring(1).trimLeft();
    }
    // currency prefix / suffix
    String? currency;
    for (final sym in [locale.currencySymbol, ..._currencySymbols]) {
      if (sym.isEmpty) continue;
      if (s.startsWith(sym)) {
        currency = sym;
        s = s.substring(sym.length).trimLeft();
        break;
      }
      if (s.endsWith(sym)) {
        currency = sym;
        s = s.substring(0, s.length - sym.length).trimRight();
        break;
      }
    }
    if (currency != null && s.startsWith('-') && !negative) {
      negative = true;
      s = s.substring(1);
    }
    var percent = false;
    if (s.endsWith('%')) {
      percent = true;
      s = s.substring(0, s.length - 1).trimRight();
    }
    if (s.isEmpty) return null;
    final v = _parseDigits(s, locale);
    if (v == null) return null;
    var value = v;
    if (percent) {
      value /= 100;
      hint = FormatHint.percent;
    } else if (currency != null) {
      hint = FormatHint.currency(_codeFor(currency, locale));
    }
    if (negative) value = -value;
    if (!value.isFinite) return null;
    return (value, hint);
  }

  static String? _codeFor(String symbol, FormulaLocale locale) {
    if (symbol == locale.currencySymbol) return null;
    return switch (symbol) {
      r'$' => 'USD',
      '€' => 'EUR',
      '£' => 'GBP',
      '¥' => 'JPY',
      '₹' => 'INR',
      _ => null,
    };
  }

  static double? _parseDigits(String s, FormulaLocale locale) {
    final dec = locale.decimal;
    final group = locale.group;
    final groupAlt = group == ' ' || group == ' ' ? ' ' : group;
    final intPart = StringBuffer();
    final fracPart = StringBuffer();
    var seenDecimal = false;
    var seenDigit = false;
    final groupPositions = <int>[];
    var i = 0;
    var digitsSinceGroup = 0;
    var intDigits = 0;
    for (; i < s.length; i++) {
      final c = s[i];
      final code = c.codeUnitAt(0);
      if (code >= 0x30 && code <= 0x39) {
        seenDigit = true;
        if (seenDecimal) {
          fracPart.write(c);
        } else {
          intPart.write(c);
          intDigits++;
          digitsSinceGroup++;
        }
        continue;
      }
      if (c == dec && !seenDecimal) {
        seenDecimal = true;
        continue;
      }
      if (!seenDecimal && (c == group || c == groupAlt) && seenDigit) {
        groupPositions.add(intDigits);
        digitsSinceGroup = 0;
        continue;
      }
      if ((c == 'e' || c == 'E') && seenDigit) break;
      return null;
    }
    if (!seenDigit) return null;
    if (groupPositions.isNotEmpty) {
      // groups must be exactly 3 digits apart and the first group 1-3 digits
      if (groupPositions.first < 1 || groupPositions.first > 3) return null;
      for (var g = 1; g < groupPositions.length; g++) {
        if (groupPositions[g] - groupPositions[g - 1] != 3) return null;
      }
      if (digitsSinceGroup != 3) return null;
    }
    var exp = 0;
    if (i < s.length) {
      final rest = s.substring(i + 1);
      final m = RegExp(r'^[+-]?\d{1,4}$').firstMatch(rest);
      if (m == null) return null;
      exp = int.parse(rest.startsWith('+') ? rest.substring(1) : rest);
    }
    final str =
        '${intPart.isEmpty ? '0' : intPart}.${fracPart.isEmpty ? '0' : fracPart}e$exp';
    return double.tryParse(str);
  }
}

/// Context-free coercions shared by operators and functions. Errors are returned as
/// [FError] values with Sheets messages that name [fn] and the 1-based [param].
abstract final class Coerce {
  /// Number coercion of a scalar (05 §6.3). Returns a double or an [FError].
  static Object toNumber(
    FValue v,
    FormulaLocale locale, {
    String fn = 'ADD',
    int param = 1,
    int currentYear = 2000,
  }) {
    switch (v) {
      case FNumber(:final v):
        return v;
      case FBool(:final v):
        return v ? 1.0 : 0.0;
      case FEmpty() || FOmitted():
        return 0.0;
      case FText(:final v):
        final p = TextNumberParser.parse(v, locale, currentYear: currentYear);
        if (p == null) {
          return FError(
            ErrorKind.value,
            ErrorMessages.expectsNumber(fn, param, v),
          );
        }
        return p.$1;
      case FError():
        return v;
      case FRich(:final scalar):
        return toNumber(
          scalar,
          locale,
          fn: fn,
          param: param,
          currentYear: currentYear,
        );
      case FArray():
        return toNumber(
          v.topLeft,
          locale,
          fn: fn,
          param: param,
          currentYear: currentYear,
        );
      case FRef():
      case FLambda():
        return FError(
          ErrorKind.value,
          ErrorMessages.expectsNumber(fn, param, v.debugText),
        );
    }
  }

  /// Text coercion of a scalar.
  static Object toText(FValue v, FormulaLocale locale) {
    switch (v) {
      case FText(:final v):
        return v;
      case FNumber(:final v):
        return Numeric.toText(v, decimal: locale.decimal);
      case FBool(:final v):
        return v ? 'TRUE' : 'FALSE';
      case FEmpty() || FOmitted():
        return '';
      case FError():
        return v;
      case FRich(:final scalar):
        return toText(scalar, locale);
      case FArray():
        return toText(v.topLeft, locale);
      case FRef() || FLambda():
        return FError(ErrorKind.value);
    }
  }

  /// Boolean coercion of a scalar.
  static Object toBool(FValue v, {String fn = 'IF', int param = 1}) {
    switch (v) {
      case FBool(:final v):
        return v;
      case FNumber(:final v):
        return v != 0;
      case FEmpty() || FOmitted():
        return false;
      case FText(:final v):
        final u = v.trim().toUpperCase();
        if (u == 'TRUE') return true;
        if (u == 'FALSE') return false;
        return FError(
          ErrorKind.value,
          ErrorMessages.expectsBoolean(fn, param, v),
        );
      case FError():
        return v;
      case FRich(:final scalar):
        return toBool(scalar, fn: fn, param: param);
      case FArray():
        return toBool(v.topLeft, fn: fn, param: param);
      case FRef() || FLambda():
        return FError(ErrorKind.value);
    }
  }
}
