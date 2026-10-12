import 'dart:math' as math;

import '../../eval/eval_context.dart';
import '../../parser/formula_locale.dart';
import '../../values/dates.dart';
import '../../values/fvalue.dart';
import '../../values/numeric.dart';

/// Built-in implementation of the number-format language subset used by TEXT(), TO_TEXT,
/// DOLLAR and FIXED (06 §5 token semantics). The 06 `NumberFormatter` can replace it through
/// [FormulaEngine.textFormatter].
final class BuiltinNumberTextFormatter implements NumberTextFormatter {
  const BuiltinNumberTextFormatter();

  @override
  String? format(FValue value, String pattern, FormulaLocale locale) {
    if (value is FRich) value = value.scalar;
    final sections = _splitSections(pattern);
    switch (value) {
      case FText(:final v):
        if (sections.length >= 4) return _renderText(sections[3], v);
        for (final s in sections) {
          if (_hasTextPlaceholder(s)) return _renderText(s, v);
        }
        return v;
      case FBool(:final v):
        return v ? 'TRUE' : 'FALSE';
      case FEmpty():
        return _formatNumber(0, sections, locale);
      case FNumber(:final v):
        return _formatNumber(v, sections, locale);
      default:
        return null;
    }
  }

  static List<String> _splitSections(String p) {
    final out = <String>[];
    final b = StringBuffer();
    var q = false;
    for (var i = 0; i < p.length; i++) {
      final c = p[i];
      if (c == '"') q = !q;
      if (!q && c == '\\' && i + 1 < p.length) {
        b
          ..write(c)
          ..write(p[i + 1]);
        i++;
        continue;
      }
      if (!q && c == ';') {
        out.add(b.toString());
        b.clear();
        continue;
      }
      b.write(c);
    }
    out.add(b.toString());
    return out;
  }

  static bool _hasTextPlaceholder(String s) {
    var q = false;
    for (var i = 0; i < s.length; i++) {
      if (s[i] == '"') q = !q;
      if (!q && s[i] == '@') return true;
    }
    return false;
  }

  static String _renderText(String section, String text) {
    final b = StringBuffer();
    _walkLiterals(section, (lit) => b.write(lit), (c) {
      if (c == '@') b.write(text);
    });
    return b.toString();
  }

  /// Iterates a section, calling [lit] for literal text and [tok] for format characters.
  static void _walkLiterals(String s, void Function(String) lit, void Function(String) tok) {
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '"') {
        final end = s.indexOf('"', i + 1);
        final e = end < 0 ? s.length : end;
        lit(s.substring(i + 1, e));
        i = e;
        continue;
      }
      if (c == '\\' && i + 1 < s.length) {
        lit(s[i + 1]);
        i++;
        continue;
      }
      if (c == '_' && i + 1 < s.length) {
        lit(' ');
        i++;
        continue;
      }
      if (c == '*' && i + 1 < s.length) {
        i++;
        continue;
      }
      if (c == '[') {
        final end = s.indexOf(']', i);
        if (end > 0) {
          final inner = s.substring(i + 1, end);
          if (inner.startsWith(r'$')) {
            final dash = inner.indexOf('-');
            lit(dash < 0 ? inner.substring(1) : inner.substring(1, dash));
          } else {
            tok('[$inner]');
          }
          i = end;
          continue;
        }
      }
      tok(c);
    }
  }

  static final RegExp _cond = RegExp(r'^\[(<=|>=|<>|<|>|=)(-?[\d.]+)\]');

  static (String, String?) _stripCondition(String s) {
    final m = _cond.firstMatch(s);
    if (m == null) return (s, null);
    return (s.substring(m.end), '${m.group(1)}${m.group(2)}');
  }

  static bool _test(String cond, double x) {
    final m = RegExp(r'^(<=|>=|<>|<|>|=)(-?[\d.]+)$').firstMatch(cond)!;
    final v = double.parse(m.group(2)!);
    return switch (m.group(1)) {
      '<' => x < v,
      '>' => x > v,
      '<=' => x <= v,
      '>=' => x >= v,
      '<>' => x != v,
      _ => x == v,
    };
  }

  String _formatNumber(double x, List<String> sections, FormulaLocale locale) {
    var section = sections[0];
    var useAbs = false;
    final conds = [for (final s in sections) _stripCondition(_stripColors(s))];
    if (conds.any((c) => c.$2 != null)) {
      var chosen = -1;
      for (var i = 0; i < conds.length && i < 3; i++) {
        if (conds[i].$2 != null && _test(conds[i].$2!, x)) {
          chosen = i;
          break;
        }
      }
      if (chosen < 0) {
        chosen = conds.indexWhere((c) => c.$2 == null);
        if (chosen < 0) chosen = 0;
      }
      section = conds[chosen].$1;
      useAbs = chosen > 0 && x < 0;
    } else {
      final n = sections.length;
      if (x < 0 && n >= 2) {
        section = conds[1].$1;
        useAbs = true;
      } else if (x == 0 && n >= 3) {
        section = conds[2].$1;
      } else {
        section = conds[0].$1;
      }
    }
    final v = useAbs ? x.abs() : x;
    if (_isDateSection(section)) return _formatDate(v, section, locale);
    return _formatPlain(v, section, locale);
  }

  static String _stripColors(String s) => s.replaceAll(
    RegExp(r'\[(Black|Blue|Cyan|Green|Magenta|Red|White|Yellow|Color\d+)\]', caseSensitive: false),
    '',
  );

  static bool _isDateSection(String s) {
    var found = false;
    _walkLiterals(s, (_) {}, (c) {
      final l = c.toLowerCase();
      if (l == 'y' || l == 'd' || l == 'h' || l == 's' || l == 'm') found = true;
      if (c.startsWith('[') && RegExp(r'^\[(h+|m+|s+)\]$', caseSensitive: false).hasMatch(c)) {
        found = true;
      }
    });
    if (!found) return false;
    // "m" alone (without y/d/h/s) in a numeric format like "0.0m" is rare; treat as date.
    return true;
  }

  // ------------------------------------------------------------------ dates

  String _formatDate(double serial, String section, FormulaLocale locale) {
    final toks = <String>[];
    final lits = <bool>[];
    _walkLiterals(section, (l) {
      toks.add(l);
      lits.add(true);
    }, (c) {
      toks.add(c);
      lits.add(false);
    });
    // group repeated letters
    final groups = <(String, bool)>[];
    for (var i = 0; i < toks.length; i++) {
      final t = toks[i];
      if (lits[i]) {
        groups.add((t, true));
        continue;
      }
      if (t.length == 1 && RegExp('[ydhmsYDHMS]').hasMatch(t)) {
        var j = i;
        while (j + 1 < toks.length && !lits[j + 1] && toks[j + 1].toLowerCase() == t.toLowerCase()) {
          j++;
        }
        groups.add((t.toLowerCase() * (j - i + 1), false));
        i = j;
        continue;
      }
      if ((t == 'A' || t == 'a') && i + 4 < toks.length) {
        final five = toks.sublist(i, i + 5).join();
        if (five.toUpperCase() == 'AM/PM') {
          groups.add(('AM/PM', false));
          i += 4;
          continue;
        }
      }
      if ((t == 'A' || t == 'a') && i + 2 < toks.length && toks.sublist(i, i + 3).join().toUpperCase() == 'A/P') {
        groups.add(('A/P${t == 'a' ? 'l' : ''}', false));
        i += 2;
        continue;
      }
      if (t == '.' && i + 1 < toks.length && toks[i + 1] == '0') {
        var j = i + 1;
        while (j + 1 < toks.length && toks[j + 1] == '0') {
          j++;
        }
        groups.add(('.${'0' * (j - i)}', false));
        i = j;
        continue;
      }
      groups.add((t, true));
    }
    final hasAmPm = groups.any((g) => !g.$2 && g.$1.startsWith('A'));
    // decide m = minute when preceded by h or followed by s
    final kinds = <String>[];
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      if (g.$2 || !g.$1.startsWith('m')) {
        kinds.add(g.$1);
        continue;
      }
      var minute = false;
      for (var j = i - 1; j >= 0; j--) {
        if (groups[j].$2) continue;
        final k = groups[j].$1;
        if (k.startsWith('h') || k.startsWith('[h')) minute = true;
        break;
      }
      for (var j = i + 1; j < groups.length && !minute; j++) {
        if (groups[j].$2) continue;
        final k = groups[j].$1;
        if (k.startsWith('s') || k.startsWith('[s')) minute = true;
        break;
      }
      kinds.add(minute ? 'M${g.$1}' : g.$1);
    }
    // fractional seconds precision
    var fracDigits = 0;
    for (var i = 0; i < groups.length; i++) {
      if (!groups[i].$2 && groups[i].$1.startsWith('.')) {
        fracDigits = math.max(fracDigits, groups[i].$1.length - 1);
      }
    }
    final scale = math.pow(10, fracDigits).toInt();
    final totalUnits = (serial * 86400 * scale).round();
    final dayPart = (totalUnits / (86400 * scale)).floor();
    final secUnits = totalUnits - dayPart * 86400 * scale;
    final secs = secUnits ~/ scale;
    final frac = secUnits % scale;
    final ymd = DateSerial.toYmdInt(dayPart);
    final h = secs ~/ 3600, mi = (secs % 3600) ~/ 60, se = secs % 60;
    final wd = ((dayPart - 1) % 7 + 7) % 7;
    final b = StringBuffer();
    String two(int n) => n.toString().padLeft(2, '0');
    for (var i = 0; i < groups.length; i++) {
      final (text, isLit) = groups[i];
      if (isLit) {
        b.write(text);
        continue;
      }
      final k = kinds[i];
      switch (k) {
        case 'y' || 'yy':
          b.write(two(ymd.year % 100));
        case 'yyy' || 'yyyy':
          b.write(ymd.year.toString().padLeft(4, '0'));
        case 'd':
          b.write(ymd.day);
        case 'dd':
          b.write(two(ymd.day));
        case 'ddd':
          b.write(locale.shortWeekdays[wd]);
        case 'dddd':
          b.write(locale.weekdays[wd]);
        case 'm':
          b.write(ymd.month);
        case 'mm':
          b.write(two(ymd.month));
        case 'mmm':
          b.write(locale.shortMonths[ymd.month - 1]);
        case 'mmmm':
          b.write(locale.months[ymd.month - 1]);
        case 'mmmmm':
          b.write(locale.months[ymd.month - 1].substring(0, 1));
        case 'Mm':
          b.write(mi);
        case 'Mmm':
          b.write(two(mi));
        case 'h':
          b.write(hasAmPm ? ((h + 11) % 12 + 1) : h);
        case 'hh':
          b.write(two(hasAmPm ? ((h + 11) % 12 + 1) : h));
        case 's':
          b.write(se);
        case 'ss':
          b.write(two(se));
        case 'AM/PM':
          b.write(h < 12 ? locale.amPm[0] : locale.amPm[1]);
        case 'A/P':
          b.write(h < 12 ? 'A' : 'P');
        case 'A/Pl':
          b.write(h < 12 ? 'a' : 'p');
        default:
          if (k.startsWith('.')) {
            b
              ..write(locale.decimal)
              ..write(frac.toString().padLeft(fracDigits, '0').substring(0, k.length - 1));
          } else if (k.startsWith('[')) {
            final inner = k.substring(1, k.length - 1).toLowerCase();
            final totalSec = (serial * 86400).round();
            final n = switch (inner[0]) {
              'h' => totalSec ~/ 3600,
              'm' => totalSec ~/ 60,
              _ => totalSec,
            };
            b.write(n.toString().padLeft(inner.length, '0'));
          } else {
            b.write(k);
          }
      }
    }
    return b.toString();
  }

  // ------------------------------------------------------------------ numbers

  String _formatPlain(double x, String section, FormulaLocale locale) {
    // Collect tokens with literal markers.
    final parts = <(String, bool)>[];
    _walkLiterals(section, (l) => parts.add((l, true)), (c) => parts.add((c, false)));
    final fmt = parts.where((p) => !p.$2).map((p) => p.$1).join();
    if (!RegExp(r'[0#?]').hasMatch(fmt)) {
      final b = StringBuffer();
      for (final p in parts) {
        b.write(p.$1);
      }
      final text = b.toString();
      final g = RegExp('general', caseSensitive: false);
      if (g.hasMatch(text)) {
        return text.replaceFirst(g, Numeric.toText(x, decimal: locale.decimal));
      }
      if (parts.isEmpty) return Numeric.toText(x, decimal: locale.decimal);
      return text;
    }
    final percentCount = '%'.allMatches(fmt).length;
    var v = x * math.pow(100, percentCount);
    // exponent
    final expMatch = RegExp(r'[Ee]([+-])').firstMatch(fmt);
    final hasExp = expMatch != null;
    // split into integer/decimal sections on the first '.' among placeholders
    var intPh = 0, decPh = 0, decZeros = 0, intZeros = 0;
    var seenDot = false;
    var grouping = false;
    var trailingCommas = 0;
    var inExp = false;
    var expDigits = 0;
    var fraction = false;
    for (var i = 0; i < fmt.length; i++) {
      final c = fmt[i];
      if (inExp) {
        if (c == '0' || c == '#') expDigits++;
        continue;
      }
      switch (c) {
        case '0' || '#' || '?':
          if (seenDot) {
            decPh++;
            if (c == '0') decZeros = decPh;
          } else {
            intPh++;
            if (c == '0') intZeros++;
            trailingCommas = 0;
          }
        case '.':
          seenDot = true;
        case ',':
          if (!seenDot) {
            final nextIsPh = i + 1 < fmt.length && '0#?'.contains(fmt[i + 1]);
            if (nextIsPh && intPh > 0) {
              grouping = true;
            } else if (intPh > 0) {
              trailingCommas++;
            }
          }
        case 'E' || 'e':
          if (i + 1 < fmt.length && (fmt[i + 1] == '+' || fmt[i + 1] == '-')) {
            inExp = true;
            i++;
          }
        case '/':
          fraction = true;
      }
    }
    if (fraction) return _formatFraction(x, fmt, parts, locale);
    v /= math.pow(1000, trailingCommas);
    final negative = v < 0;
    v = v.abs();
    String digits;
    String? expStr;
    if (hasExp) {
      var e = v == 0 ? 0 : (math.log(v) / math.ln10).floor();
      final step = intPh > 1 && intZeros == 0 ? intPh : 1;
      if (step > 1) e = (e / step).floor() * step;
      var mant = v / math.pow(10, e);
      final rounded = Numeric.roundHalfAway(mant, decPh);
      if (rounded >= math.pow(10, step)) {
        e += step;
        mant = v / math.pow(10, e);
      }
      digits = _fixed(mant, decPh, decZeros, intZeros, grouping: false, locale: locale);
      final sign = e < 0 ? '-' : (expMatch.group(1) == '+' ? '+' : '');
      expStr = '${fmt.contains('e') ? 'e' : 'E'}$sign${e.abs().toString().padLeft(math.max(expDigits, 1), '0')}';
    } else {
      digits = _fixed(v, decPh, decZeros, intZeros, grouping: grouping, locale: locale);
    }
    // assemble: literals before the first placeholder, digits, literals after
    final b = StringBuffer();
    if (negative && digits.replaceAll(RegExp(r'[0.,\s]'), '').isNotEmpty) b.write('-');
    var wroteNumber = false;
    for (final p in parts) {
      if (p.$2) {
        b.write(p.$1);
        continue;
      }
      final c = p.$1;
      if ('0#?.,'.contains(c) || ((c == 'E' || c == 'e' || c == '+' || c == '-') && hasExp)) {
        if (!wroteNumber) {
          b.write(digits);
          if (expStr != null) b.write(expStr);
          wroteNumber = true;
        }
        continue;
      }
      if (c == '%') {
        b.write('%');
        continue;
      }
      if (c.startsWith('[')) continue;
      b.write(c);
    }
    return b.toString();
  }

  static String _fixed(
    double v,
    int decPh,
    int decZeros,
    int intZeros, {
    required bool grouping,
    required FormulaLocale locale,
  }) {
    final r = Numeric.roundHalfAway(v, decPh);
    final s = r.toStringAsFixed(decPh);
    var intPart = s;
    var decPart = '';
    final dot = s.indexOf('.');
    if (dot >= 0) {
      intPart = s.substring(0, dot);
      decPart = s.substring(dot + 1);
    }
    while (decPart.length > decZeros && decPart.endsWith('0')) {
      decPart = decPart.substring(0, decPart.length - 1);
    }
    if (intPart == '0' && intZeros == 0) intPart = '';
    if (intPart.length < intZeros) intPart = intPart.padLeft(intZeros, '0');
    if (grouping && intPart.length > 3) {
      final b = StringBuffer();
      final lead = intPart.length % 3;
      if (lead > 0) b.write(intPart.substring(0, lead));
      for (var i = lead; i < intPart.length; i += 3) {
        if (b.isNotEmpty) b.write(locale.group);
        b.write(intPart.substring(i, i + 3));
      }
      intPart = b.toString();
    }
    if (decPh == 0) return intPart;
    return '$intPart${locale.decimal}$decPart';
  }

  String _formatFraction(double x, String fmt, List<(String, bool)> parts, FormulaLocale locale) {
    final m = RegExp(r'([#0?]*)\s*([#0?]+)/([#0?]+|\d+)').firstMatch(fmt);
    if (m == null) return Numeric.toText(x, decimal: locale.decimal);
    final neg = x < 0;
    final a = x.abs();
    final hasInt = m.group(1)!.isNotEmpty;
    final whole = hasInt ? a.floor() : 0;
    final f = a - whole;
    final denSpec = m.group(3)!;
    int num, den;
    if (RegExp(r'^\d+$').hasMatch(denSpec)) {
      den = int.parse(denSpec);
      num = (f * den).round();
    } else {
      final maxDen = math.pow(10, denSpec.length).toInt() - 1;
      (num, den) = _bestFraction(f, maxDen);
    }
    var w = whole;
    if (num == den && hasInt) {
      w += 1;
      num = 0;
    }
    final b = StringBuffer();
    if (neg) b.write('-');
    if (hasInt) {
      if (w != 0 || num == 0) b.write(w);
      if (num != 0) {
        if (w != 0) b.write(' ');
        b.write('$num/$den');
      }
    } else {
      b.write('${num + whole * den}/$den');
    }
    return b.toString();
  }

  static (int, int) _bestFraction(double f, int maxDen) {
    var bestN = 0, bestD = 1;
    var bestErr = f;
    for (var d = 1; d <= maxDen; d++) {
      final n = (f * d).round();
      final err = (f - n / d).abs();
      if (err < bestErr - 1e-12) {
        bestErr = err;
        bestN = n;
        bestD = d;
        if (err == 0) break;
      }
    }
    return (bestN, bestD);
  }
}
