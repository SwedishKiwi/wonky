import '../../eval/eval_context.dart';
import '../../parser/formula_locale.dart';
import '../../values/dates.dart';
import '../../values/fvalue.dart';

/// Built-in implementation of the number-format language used by TEXT(), TO_TEXT, DOLLAR and
/// FIXED (06 §5 token semantics: sections, conditions, colors, literals, `0 # ? . ,`, scaling,
/// `%`, `‰`, `E+`/`E-`, fractions, `@`, dates/times incl. elapsed `[h]`, AM/PM, fractional
/// seconds, locale symbols). Output is plain text: colors are dropped, `_c` becomes a space and
/// `*c` is omitted. The 06 `NumberFormatter` can replace it through [FormulaEngine.textFormatter].
final class BuiltinNumberTextFormatter implements NumberTextFormatter {
  const BuiltinNumberTextFormatter();

  static final Map<String, _Format?> _cache = {};

  @override
  String? format(FValue value, String pattern, FormulaLocale locale) {
    if (value is FRich) value = value.scalar;
    final f = _parse(pattern);
    if (f == null) return null;
    switch (value) {
      case FText(:final v):
        return f.formatText(v, locale);
      case FBool(:final v):
        return v ? 'TRUE' : 'FALSE';
      case FEmpty() || FOmitted():
        return f.formatNumber(0, locale);
      case FNumber(:final v):
        if (!v.isFinite) return null;
        return f.formatNumber(v, locale);
      default:
        return null;
    }
  }

  /// Automatic ("General") display of a number (06 §5.9).
  static String automatic(double x, FormulaLocale locale) => _automatic(x, locale);

  static _Format? _parse(String pattern) {
    if (_cache.containsKey(pattern)) return _cache[pattern];
    _Format? f;
    try {
      f = _Format.parse(pattern);
    } on _InvalidPattern {
      f = null;
    }
    if (_cache.length > 2000) _cache.clear();
    _cache[pattern] = f;
    return f;
  }
}

// ======================================================================== tokens

final class _InvalidPattern implements Exception {
  const _InvalidPattern();
}

enum _K { lit, ph, dot, comma, percent, permille, exp, at, slash, digit, date, elapsed, ampm, general, fracSec }

final class _T {
  final _K k;

  /// Literal text, placeholder char (`0#?`), digit, date letter (`y m d h s`, `M` = minute),
  /// AM/PM form (`AM/PM`, `am/pm`, `A/P`, `a/p`).
  final String s;

  /// Repeat count (date tokens, fractional second digits) or exponent flags.
  final int n;

  const _T(this.k, [this.s = '', this.n = 0]);

  @override
  String toString() => '${k.name}($s,$n)';
}

final class _Cond {
  final String op;
  final double value;
  const _Cond(this.op, this.value);

  bool test(double x) => switch (op) {
    '<' => x < value,
    '>' => x > value,
    '<=' => x <= value,
    '>=' => x >= value,
    '<>' => x != value,
    _ => x == value,
  };
}

final class _Section {
  final List<_T> toks;
  final _Cond? cond;
  final String? localeId;
  _Section(this.toks, this.cond, this.localeId);

  bool get isEmpty => toks.isEmpty;
  bool get hasAt => toks.any((t) => t.k == _K.at);
  bool get isDate => toks.any((t) => t.k == _K.date || t.k == _K.elapsed || t.k == _K.ampm);
  bool get hasElapsed => toks.any((t) => t.k == _K.elapsed);
}

final class _Format {
  final List<_Section> sections;
  _Format(this.sections);

  static final RegExp _condRe = RegExp(r'^(<=|>=|<>|<|>|=)\s*([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)$');
  static final RegExp _elapsedRe = RegExp(r'^(h+|m+|s+)$', caseSensitive: false);

  static _Format parse(String p) {
    final raw = _split(p);
    if (raw.length > 4) throw const _InvalidPattern();
    return _Format([for (final s in raw) _tokenize(s)]);
  }

  static List<String> _split(String p) {
    final out = <String>[];
    final b = StringBuffer();
    var q = false;
    for (var i = 0; i < p.length; i++) {
      final c = p[i];
      if (c == '"') q = !q;
      if (!q && c == r'\' && i + 1 < p.length) {
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
    if (q) throw const _InvalidPattern();
    out.add(b.toString());
    return out;
  }

  static _Section _tokenize(String s) {
    final toks = <_T>[];
    _Cond? cond;
    String? localeId;
    void lit(String t) {
      if (t.isEmpty) return;
      if (toks.isNotEmpty && toks.last.k == _K.lit) {
        toks[toks.length - 1] = _T(_K.lit, toks.last.s + t);
      } else {
        toks.add(_T(_K.lit, t));
      }
    }

    var i = 0;
    while (i < s.length) {
      final c = s[i];
      final lower = c.toLowerCase();
      switch (c) {
        case '"':
          final end = s.indexOf('"', i + 1);
          if (end < 0) throw const _InvalidPattern();
          lit(s.substring(i + 1, end));
          i = end + 1;
          continue;
        case r'\':
          lit(i + 1 < s.length ? s[i + 1] : '');
          i += 2;
          continue;
        case '_':
          lit(' ');
          i += 2;
          continue;
        case '*':
          i += 2;
          continue;
        case '[':
          final end = s.indexOf(']', i);
          if (end < 0) throw const _InvalidPattern();
          final inner = s.substring(i + 1, end).trim();
          i = end + 1;
          final cm = _condRe.firstMatch(inner);
          if (cm != null) {
            cond = _Cond(cm.group(1)!, double.parse(cm.group(2)!));
          } else if (_elapsedRe.hasMatch(inner)) {
            toks.add(_T(_K.elapsed, inner[0].toLowerCase(), inner.length));
          } else if (inner.startsWith(r'$')) {
            final dash = inner.indexOf('-');
            lit(dash < 0 ? inner.substring(1) : inner.substring(1, dash));
            if (dash >= 0) localeId = _lcidLocale(inner.substring(dash + 1)) ?? localeId;
          }
          // colors ([Red], [Color10]) and other bracket tokens ([DBNum1], …) do not apply to
          // text output
          continue;
        case '0' || '#' || '?':
          toks.add(_T(_K.ph, c));
        case '.':
          toks.add(const _T(_K.dot));
        case ',':
          toks.add(const _T(_K.comma));
        case '%':
          toks.add(const _T(_K.percent));
        case '‰':
          toks.add(const _T(_K.permille));
        case '@':
          toks.add(const _T(_K.at));
        case '/':
          toks.add(const _T(_K.slash));
        case 'E' || 'e' when i + 1 < s.length && (s[i + 1] == '+' || s[i + 1] == '-'):
          toks.add(_T(_K.exp, c, s[i + 1] == '+' ? 1 : 0));
          i += 2;
          continue;
        default:
          if (c.codeUnitAt(0) >= 0x31 && c.codeUnitAt(0) <= 0x39) {
            toks.add(_T(_K.digit, c));
          } else if (lower == 'g' && s.length - i >= 7 && s.substring(i, i + 7).toLowerCase() == 'general') {
            toks.add(const _T(_K.general));
            i += 7;
            continue;
          } else if (lower == 'a' && s.length - i >= 5 && s.substring(i, i + 5).toLowerCase() == 'am/pm') {
            toks.add(_T(_K.ampm, s.substring(i, i + 5) == 'am/pm' ? 'am/pm' : 'AM/PM'));
            i += 5;
            continue;
          } else if (lower == 'a' && s.length - i >= 3 && s.substring(i, i + 3).toLowerCase() == 'a/p') {
            toks.add(_T(_K.ampm, c == 'a' ? 'a/p' : 'A/P'));
            i += 3;
            continue;
          } else if ('ymdhs'.contains(lower)) {
            var j = i + 1;
            while (j < s.length && s[j].toLowerCase() == lower) {
              j++;
            }
            toks.add(_T(_K.date, lower, j - i));
            i = j;
            continue;
          } else {
            lit(c);
          }
      }
      i++;
    }
    final section = _Section(toks, cond, localeId);
    return section.isDate ? _toDateSection(section) : section;
  }

  /// Reinterprets number tokens of a date section: `.0…` → fractional seconds, everything else
  /// literal; `m`/`mm` → minutes after hours or before seconds.
  static _Section _toDateSection(_Section s) {
    final src = s.toks;
    final out = <_T>[];
    void lit(String t) {
      if (out.isNotEmpty && out.last.k == _K.lit) {
        out[out.length - 1] = _T(_K.lit, out.last.s + t);
      } else {
        out.add(_T(_K.lit, t));
      }
    }

    for (var i = 0; i < src.length; i++) {
      final t = src[i];
      switch (t.k) {
        case _K.dot when i + 1 < src.length && src[i + 1].k == _K.ph && src[i + 1].s == '0':
          var j = i + 1;
          while (j < src.length && src[j].k == _K.ph && src[j].s == '0') {
            j++;
          }
          out.add(_T(_K.fracSec, '', j - i - 1));
          i = j - 1;
        case _K.date || _K.elapsed || _K.ampm:
          out.add(t);
        case _K.lit:
          lit(t.s);
        case _K.ph || _K.digit:
          lit(t.s);
        case _K.dot:
          lit('.');
        case _K.comma:
          lit(',');
        case _K.percent:
          lit('%');
        case _K.permille:
          lit('‰');
        case _K.slash:
          lit('/');
        case _K.exp:
          lit('${t.s}${t.n == 1 ? '+' : '-'}');
        case _K.at || _K.general || _K.fracSec:
          break;
      }
    }
    // minutes vs months
    for (var i = 0; i < out.length; i++) {
      final t = out[i];
      if (t.k != _K.date || t.s != 'm' || t.n > 2) continue;
      var minute = false;
      for (var j = i - 1; j >= 0; j--) {
        final p = out[j];
        if (p.k == _K.lit) continue;
        minute = (p.k == _K.date || p.k == _K.elapsed) && p.s == 'h';
        break;
      }
      if (!minute) {
        for (var j = i + 1; j < out.length; j++) {
          final p = out[j];
          if (p.k == _K.lit) continue;
          minute = (p.k == _K.date || p.k == _K.elapsed) && p.s == 's';
          break;
        }
      }
      if (minute) out[i] = _T(_K.date, 'M', t.n);
    }
    return _Section(out, s.cond, s.localeId);
  }

  /// LCID (hex) → locale id for month/day names.
  static String? _lcidLocale(String hex) {
    final v = int.tryParse(hex.trim(), radix: 16);
    if (v == null) return null;
    return _lcids[v & 0xffff];
  }

  static const Map<int, String> _lcids = {
    0x0401: 'ar_SA', 0x0402: 'bg_BG', 0x0403: 'ca_ES', 0x0404: 'zh_TW', 0x0405: 'cs_CZ', //
    0x0406: 'da_DK', 0x0407: 'de_DE', 0x0408: 'el_GR', 0x0409: 'en_US', 0x040A: 'es_ES', //
    0x040B: 'fi_FI', 0x040C: 'fr_FR', 0x040D: 'he_IL', 0x040E: 'hu_HU', 0x040F: 'is_IS', //
    0x0410: 'it_IT', 0x0411: 'ja_JP', 0x0412: 'ko_KR', 0x0413: 'nl_NL', 0x0414: 'nb_NO', //
    0x0415: 'pl_PL', 0x0416: 'pt_BR', 0x0418: 'ro_RO', 0x0419: 'ru_RU', 0x041A: 'hr_HR', //
    0x041B: 'sk_SK', 0x041D: 'sv_SE', 0x041E: 'th_TH', 0x041F: 'tr_TR', 0x0421: 'id_ID', //
    0x0422: 'uk_UA', 0x0424: 'sl_SI', 0x0425: 'et_EE', 0x0426: 'lv_LV', 0x0427: 'lt_LT', //
    0x042A: 'vi_VN', 0x0439: 'hi_IN', 0x043E: 'ms_MY', 0x0804: 'zh_CN', 0x0807: 'de_CH', //
    0x0809: 'en_GB', 0x080A: 'es_MX', 0x080C: 'fr_BE', 0x0810: 'it_CH', 0x0813: 'nl_BE', //
    0x0816: 'pt_PT', 0x0C07: 'de_AT', 0x0C09: 'en_AU', 0x0C0A: 'es_ES', 0x0C0C: 'fr_CA', //
    0x1009: 'en_CA', 0x100C: 'fr_CH', 0x1409: 'en_NZ', 0x1809: 'en_IE', 0x1C09: 'en_ZA', //
    0x4009: 'en_IN',
  };

  // ====================================================================== text

  _Section? get _textSection {
    if (sections.length == 4) return sections[3];
    if (sections.length > 1 && sections.last.hasAt) return sections.last;
    return null;
  }

  List<_Section> get _numberSections {
    if (sections.length == 4) return sections.sublist(0, 3);
    if (sections.length > 1 && sections.last.hasAt) return sections.sublist(0, sections.length - 1);
    if (sections.length == 1 && sections[0].hasAt) return const [];
    return sections;
  }

  String formatText(String text, FormulaLocale locale) {
    final ts = _textSection ?? (sections.length == 1 && sections[0].hasAt ? sections[0] : null);
    if (ts == null) return text;
    final b = StringBuffer();
    for (final t in ts.toks) {
      if (t.k == _K.lit) b.write(t.s);
      if (t.k == _K.at) b.write(text);
    }
    return b.toString();
  }

  // ====================================================================== numbers

  String formatNumber(double x, FormulaLocale locale) {
    final ns = _numberSections;
    if (ns.isEmpty) return _automatic(x, locale);
    _Section? section;
    var abs = false;
    if (ns.any((s) => s.cond != null)) {
      if (ns[0].cond?.test(x) ?? false) {
        section = ns[0];
      } else if (ns.length > 1 && ns[1].cond != null && ns[1].cond!.test(x)) {
        section = ns[1];
      } else {
        for (var i = 1; i < ns.length; i++) {
          if (ns[i].cond == null) {
            section = ns[i];
            break;
          }
        }
        if (section == null && ns[0].cond == null) section = ns[0];
      }
      if (section == null) return _automatic(x, locale);
    } else if (ns.length >= 2 && x < 0) {
      section = ns[1];
      abs = true;
    } else if (ns.length >= 3 && x == 0) {
      section = ns[2];
    } else {
      section = ns[0];
    }
    if (section.isEmpty) return '';
    final v = abs ? -x : x;
    if (section.isDate) return _formatDate(v, section, locale);
    return _formatPlain(v, section, locale);
  }

  // ---------------------------------------------------------------- plain numbers

  static String _formatPlain(double x, _Section s, FormulaLocale locale) {
    final toks = s.toks;
    final negative = x < 0;
    var v = x.abs();
    // literal-only / General sections
    final hasPh = toks.any((t) => t.k == _K.ph);
    if (!hasPh) {
      final b = StringBuffer();
      var wroteGeneral = false;
      for (final t in toks) {
        switch (t.k) {
          case _K.general:
            if (!wroteGeneral) b.write(_automatic(x, locale));
            wroteGeneral = true;
          case _K.lit || _K.digit:
            b.write(t.s);
          case _K.percent:
            b.write('%');
          case _K.permille:
            b.write('‰');
          case _K.dot:
            b.write(locale.decimal);
          case _K.comma:
            b.write(',');
          case _K.slash:
            b.write('/');
          case _K.exp:
            b.write('${t.s}${t.n == 1 ? '+' : '-'}');
          default:
            break;
        }
      }
      return b.toString();
    }
    for (final t in toks) {
      if (t.k == _K.percent) v *= 100;
      if (t.k == _K.permille) v *= 1000;
    }
    final slash = _fractionSlash(toks);
    if (slash >= 0) return _formatFraction(v, negative, toks, slash, locale);

    final expAt = toks.indexWhere((t) => t.k == _K.exp);
    final numEnd = expAt < 0 ? toks.length : expAt;
    var dotAt = -1;
    for (var i = 0; i < numEnd; i++) {
      if (toks[i].k == _K.dot) {
        dotAt = i;
        break;
      }
    }
    final intEnd = dotAt >= 0 ? dotAt : numEnd;
    final intPh = <int>[], decPh = <int>[], expPh = <int>[];
    for (var i = 0; i < toks.length; i++) {
      if (toks[i].k != _K.ph) continue;
      if (i < intEnd) {
        intPh.add(i);
      } else if (i < numEnd) {
        decPh.add(i);
      } else {
        expPh.add(i);
      }
    }
    // commas: grouping (between integer placeholders) or scaling (after the last placeholder)
    final commaRole = <int, int>{}; // 0 literal, 1 grouping, 2 scaling
    var grouping = false;
    var scale = 0;
    for (var i = 0; i < numEnd; i++) {
      if (toks[i].k != _K.comma) continue;
      var p = i - 1;
      while (p >= 0 && toks[p].k == _K.comma) {
        p--;
      }
      var n = i + 1;
      while (n < toks.length && toks[n].k == _K.comma) {
        n++;
      }
      final afterPh = p >= 0 && toks[p].k == _K.ph;
      if (!afterPh) {
        commaRole[i] = 0;
      } else if (n < intEnd && toks[n].k == _K.ph) {
        commaRole[i] = 1;
        grouping = true;
      } else if (n < toks.length && toks[n].k == _K.ph) {
        commaRole[i] = 1; // comma among decimal placeholders: ignored
      } else {
        commaRole[i] = 2;
        scale++;
      }
    }
    for (var k = 0; k < scale; k++) {
      v /= 1000;
    }

    String intDigits;
    String fracDigits;
    String? expText;
    if (expAt >= 0) {
      final et = toks[expAt];
      final (m, e) = _mantissa(v, intPh.map((i) => toks[i].s).toList(), decPh.length);
      intDigits = m.$1;
      fracDigits = m.$2;
      final minDigits = expPh.where((i) => toks[i].s == '0').length;
      final sign = e < 0 ? '-' : (et.n == 1 ? '+' : '');
      expText = '${et.s}$sign${e.abs().toString().padLeft(minDigits, '0')}';
    } else {
      (intDigits, fracDigits) = _Dec.of(v).fixed(decPh.length);
    }
    final intOut = _intPlaceholders(
      [for (final i in intPh) toks[i].s],
      intDigits,
      grouping && expAt < 0,
      locale.group,
    );
    final decOut = _decPlaceholders([for (final i in decPh) toks[i].s], fracDigits);
    final significant = '$intDigits$fracDigits'.replaceAll('0', '').isNotEmpty;

    final b = StringBuffer();
    var ip = 0, dp = 0;
    for (var i = 0; i < toks.length; i++) {
      final t = toks[i];
      switch (t.k) {
        case _K.ph:
          if (i < intEnd) {
            b.write(intOut[ip++]);
          } else if (i < numEnd) {
            b.write(decOut[dp++]);
          }
        case _K.dot:
          if (i == dotAt && intPh.isEmpty) b.write(intDigits);
          b.write(i == dotAt ? locale.decimal : '.');
        case _K.comma:
          if ((commaRole[i] ?? 0) == 0) b.write(',');
        case _K.exp:
          if (i == expAt) b.write(expText);
        case _K.percent:
          b.write('%');
        case _K.permille:
          b.write('‰');
        case _K.lit || _K.digit:
          b.write(t.s);
        case _K.slash:
          b.write('/');
        case _K.general:
          b.write(_automatic(x, locale));
        default:
          break;
      }
    }
    final out = b.toString();
    return negative && significant ? '-$out' : out;
  }

  /// Mantissa digits (integer, fraction) and exponent for scientific formats.
  static ((String, String), int) _mantissa(double v, List<String> intPh, int decimals) {
    if (v == 0) return (('', ''.padRight(decimals, '0')), 0);
    var d = _Dec.of(v);
    final n = intPh.length;
    int expFor(int point) {
      final e0 = point - 1;
      if (n > 1 && intPh.any((c) => c != '0')) return _floorDiv(e0, n) * n;
      if (n > 1) return e0 - (n - 1);
      if (n == 0) return point;
      return e0;
    }

    var e = expFor(d.point);
    var r = d.shift(-e).roundTo(decimals);
    // carry (9.99 → 10.0) moves the exponent
    final carried = r.point + e;
    if (carried != d.point && r.digits.isNotEmpty) {
      d = _Dec(r.digits, carried);
      e = expFor(d.point);
      r = d.shift(-e).roundTo(decimals);
    }
    return (r.split(decimals), e);
  }

  static int _floorDiv(int a, int b) => (a / b).floor();

  /// Output per integer placeholder (left to right), the leftmost taking overflow digits.
  static List<String> _intPlaceholders(List<String> ph, String digits, bool grouping, String group) {
    final n = ph.length;
    final out = List<String>.filled(n, '');
    if (n == 0) return out;
    final m = digits.length > n ? digits.length : n;
    final pad = m - digits.length;
    final buffers = List.generate(n, (_) => StringBuffer());
    for (var i = 0; i < m; i++) {
      final k = i - (m - n) < 0 ? 0 : i - (m - n);
      final pos = m - 1 - i;
      String ch;
      var isDigit = true;
      if (i < pad) {
        switch (ph[k]) {
          case '0':
            ch = '0';
          case '?':
            ch = ' ';
            isDigit = false;
          default:
            ch = '';
            isDigit = false;
        }
      } else {
        ch = digits[i - pad];
      }
      buffers[k].write(ch);
      if (grouping && isDigit && pos > 0 && pos % 3 == 0) buffers[k].write(group);
    }
    for (var k = 0; k < n; k++) {
      out[k] = buffers[k].toString();
    }
    return out;
  }

  /// Output per decimal placeholder: trailing zeros dropped for `#`, spaced for `?`.
  static List<String> _decPlaceholders(List<String> ph, String digits) {
    final n = ph.length;
    var last = -1;
    for (var k = 0; k < n; k++) {
      if (digits[k] != '0' || ph[k] == '0') last = k;
    }
    return [
      for (var k = 0; k < n; k++)
        k <= last
            ? digits[k]
            : switch (ph[k]) {
                '?' => ' ',
                _ => '',
              },
    ];
  }

  /// Index of a fraction slash (placeholder before, placeholder or digit after), or -1.
  static int _fractionSlash(List<_T> toks) {
    for (var i = 1; i < toks.length - 1; i++) {
      if (toks[i].k != _K.slash) continue;
      final before = toks[i - 1].k == _K.ph;
      final after = toks[i + 1].k == _K.ph || toks[i + 1].k == _K.digit;
      if (before && after) return i;
    }
    return -1;
  }

  static String _formatFraction(double v, bool negative, List<_T> toks, int slash, FormulaLocale locale) {
    var numStart = slash;
    while (numStart > 0 && toks[numStart - 1].k == _K.ph) {
      numStart--;
    }
    final numPh = [for (var i = numStart; i < slash; i++) toks[i].s];
    var denEnd = slash + 1;
    final fixedDen = toks[denEnd].k == _K.digit;
    final denText = StringBuffer();
    final denPh = <String>[];
    while (denEnd < toks.length && toks[denEnd].k == (fixedDen ? _K.digit : _K.ph)) {
      if (fixedDen) {
        denText.write(toks[denEnd].s);
      } else {
        denPh.add(toks[denEnd].s);
      }
      denEnd++;
    }
    if (fixedDen) {
      // digits may continue as '0' placeholders (e.g. ?/10 → digit 1, ph 0)
      while (denEnd < toks.length && toks[denEnd].k == _K.ph && toks[denEnd].s == '0') {
        denText.write('0');
        denEnd++;
      }
    }
    final intIdx = <int>[for (var i = 0; i < numStart; i++) if (toks[i].k == _K.ph) i];
    final hasInt = intIdx.isNotEmpty;
    final whole0 = hasInt ? v.floorToDouble() : 0.0;
    final f = v - whole0;
    int num, den;
    if (fixedDen) {
      den = int.parse(denText.toString());
      if (den == 0) den = 1;
      num = ((hasInt ? f : v) * den).round();
    } else {
      final maxDen = _pow10(denPh.length) - 1;
      (num, den) = _bestFraction(hasInt ? f : v, maxDen < 1 ? 1 : maxDen);
    }
    var whole = whole0;
    if (hasInt && num >= den && den > 0) {
      whole += num ~/ den;
      num = num % den;
    }
    final wholeDigits = _Dec.of(whole).fixed(0).$1;
    final intPh = [for (final i in intIdx) toks[i].s];
    var intOut = _intPlaceholders(intPh, wholeDigits, false, locale.group);
    final showFraction = !hasInt || num != 0;
    if (hasInt && !showFraction && intOut.every((s) => s.trim().isEmpty)) {
      intOut = [...intOut.sublist(0, intOut.length - 1), '0'];
    }
    final intEmpty = intOut.every((s) => s.trim().isEmpty);
    final lastInt = hasInt ? intIdx.last : -1;
    final b = StringBuffer();
    var ip = 0;
    for (var i = 0; i < toks.length; i++) {
      final t = toks[i];
      if (i < numStart) {
        if (t.k == _K.ph) {
          b.write(intOut[ip++]);
        } else if (!(i > lastInt && lastInt >= 0 && (intEmpty || !showFraction))) {
          b.write(_plain(t, locale));
        }
        continue;
      }
      if (i < denEnd) {
        if (!showFraction) continue;
        if (i == numStart) b.write(_padLeft(num.toString(), numPh));
        if (i == slash) b.write('/');
        if (i == slash + 1) {
          b.write(fixedDen ? den.toString() : _padRight(den.toString(), denPh));
        }
        continue;
      }
      b.write(_plain(t, locale));
    }
    final out = b.toString();
    final significant = whole != 0 || num != 0;
    return negative && significant ? '-$out' : out;
  }

  static String _plain(_T t, FormulaLocale locale) => switch (t.k) {
    _K.lit || _K.digit => t.s,
    _K.percent => '%',
    _K.permille => '‰',
    _K.dot => locale.decimal,
    _K.comma => ',',
    _K.slash => '/',
    _ => '',
  };

  static String _padLeft(String digits, List<String> ph) {
    if (digits.length >= ph.length) return digits;
    final b = StringBuffer();
    for (var k = 0; k < ph.length - digits.length; k++) {
      b.write(switch (ph[k]) {
        '0' => '0',
        '?' => ' ',
        _ => '',
      });
    }
    return '$b$digits';
  }

  static String _padRight(String digits, List<String> ph) {
    if (digits.length >= ph.length) return digits;
    final b = StringBuffer(digits);
    for (var k = digits.length; k < ph.length; k++) {
      if (ph[k] != '#') b.write(' ');
    }
    return b.toString();
  }

  static int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n && i < 9; i++) {
      r *= 10;
    }
    return r;
  }

  /// Best rational approximation of [f] with denominator ≤ [maxDen].
  static (int, int) _bestFraction(double f, int maxDen) {
    if (maxDen <= 100000) {
      var bestN = f.round(), bestD = 1;
      var bestErr = (f - bestN).abs();
      for (var d = 2; d <= maxDen && bestErr > 0; d++) {
        final n = (f * d).round();
        final err = (f - n / d).abs();
        if (err < bestErr - 1e-15) {
          bestErr = err;
          bestN = n;
          bestD = d;
        }
      }
      return (bestN, bestD);
    }
    // continued fractions for large bounds
    var h0 = 0, h1 = 1, k0 = 1, k1 = 0;
    var x = f;
    for (var i = 0; i < 64; i++) {
      final a = x.floor();
      final h2 = a * h1 + h0, k2 = a * k1 + k0;
      if (k2 > maxDen) break;
      h0 = h1;
      h1 = h2;
      k0 = k1;
      k1 = k2;
      final r = x - a;
      if (r < 1e-12) break;
      x = 1 / r;
    }
    return k1 == 0 ? (f.round(), 1) : (h1, k1);
  }

  // ---------------------------------------------------------------- dates

  static const double _minSerial = -693593; // 0001-01-01
  static const double _maxSerial = 2958466; // 10000-01-01

  static String _formatDate(double serial, _Section s, FormulaLocale locale) {
    if (serial < _minSerial || serial >= _maxSerial) return _automatic(serial, locale);
    final loc = s.localeId == null ? locale : FormulaLocale.forId(s.localeId!);
    final toks = s.toks;
    var sign = '';
    var value = serial;
    if (s.hasElapsed && value < 0) {
      sign = '-';
      value = -value;
    }
    var fd = 0;
    for (final t in toks) {
      if (t.k == _K.fracSec && t.n > fd) fd = t.n;
    }
    if (fd > 3) fd = 3;
    final scale = _pow10(fd);
    final perDay = 86400 * scale;
    final total = (value * perDay).round();
    final day = _floorDiv(total, perDay);
    final dayUnits = total - day * perDay;
    final secs = dayUnits ~/ scale;
    final frac = dayUnits % scale;
    final totalSecs = total ~/ scale;
    final ymd = DateSerial.toYmdInt(day);
    final h = secs ~/ 3600, mi = (secs % 3600) ~/ 60, se = secs % 60;
    final wd = ((day - 1) % 7 + 7) % 7;
    final twelve = toks.any((t) => t.k == _K.ampm);
    var elapsedUnit = '';
    String two(int n) => n.toString().padLeft(2, '0');
    final b = StringBuffer(sign);
    for (final t in toks) {
      switch (t.k) {
        case _K.lit:
          b.write(t.s);
        case _K.elapsed:
          elapsedUnit = t.s;
          final n = switch (t.s) {
            'h' => totalSecs ~/ 3600,
            'm' => totalSecs ~/ 60,
            _ => totalSecs,
          };
          b.write(n.toString().padLeft(t.n, '0'));
        case _K.ampm:
          final pm = h >= 12;
          b.write(switch (t.s) {
            'AM/PM' => loc.amPm[pm ? 1 : 0],
            'am/pm' => loc.amPm[pm ? 1 : 0].toLowerCase(),
            'A/P' => pm ? 'P' : 'A',
            _ => pm ? 'p' : 'a',
          });
        case _K.fracSec:
          final digits = frac.toString().padLeft(fd, '0');
          b
            ..write(loc.decimal)
            ..write(t.n <= fd ? digits.substring(0, t.n) : digits.padRight(t.n, '0'));
        case _K.date:
          final n = t.n;
          switch (t.s) {
            case 'y':
              b.write(n <= 2 ? two(ymd.year % 100) : ymd.year.toString().padLeft(4, '0'));
            case 'd':
              b.write(switch (n) {
                1 => '${ymd.day}',
                2 => two(ymd.day),
                3 => loc.shortWeekdays[wd],
                _ => loc.weekdays[wd],
              });
            case 'm':
              final name = loc.months[ymd.month - 1];
              b.write(switch (n) {
                1 => '${ymd.month}',
                2 => two(ymd.month),
                3 => loc.shortMonths[ymd.month - 1],
                5 => name.isEmpty ? '' : String.fromCharCode(name.runes.first).toUpperCase(),
                _ => name,
              });
            case 'M':
              final m = elapsedUnit == 'h' ? (totalSecs % 3600) ~/ 60 : mi;
              b.write(n == 1 ? '$m' : two(m));
            case 'h':
              final hh = twelve ? (h + 11) % 12 + 1 : h;
              b.write(n == 1 ? '$hh' : two(hh));
            case 's':
              final ss = elapsedUnit.isNotEmpty ? totalSecs % 60 : se;
              b.write(n == 1 ? '$ss' : two(ss));
          }
        default:
          break;
      }
    }
    return b.toString();
  }
}

// ======================================================================== automatic

String _automatic(double x, FormulaLocale locale) {
  if (x == 0) return '0';
  if (!x.isFinite) return x.isNaN ? 'NaN' : (x > 0 ? 'Infinity' : '-Infinity');
  final ax = x.abs();
  if (x == x.truncateToDouble() && ax < 1e15) return x.toInt().toString();
  final neg = x < 0 ? '-' : '';
  if (ax >= 1e15 || ax < 1e-9) {
    final d = _Dec.of(ax, 6);
    final e = d.point - 1;
    final mant = d.shift(-e).fixed(5);
    final frac = mant.$2.replaceFirst(RegExp(r'0+$'), '');
    final m = frac.isEmpty ? mant.$1 : '${mant.$1}${locale.decimal}$frac';
    return '$neg${m}E${e < 0 ? '-' : '+'}${e.abs().toString().padLeft(2, '0')}';
  }
  final d = _Dec.of(ax, 10);
  final decimals = d.digits.length - d.point;
  final (i, f) = d.fixed(decimals < 0 ? 0 : decimals);
  final ip = i.isEmpty ? '0' : i;
  return f.isEmpty ? '$neg$ip' : '$neg$ip${locale.decimal}$f';
}

// ======================================================================== decimals

/// Decimal digits of a non-negative double rounded to 15 significant digits:
/// value = 0.[digits] × 10^[point]; [digits] has no leading or trailing zeros (empty = 0).
final class _Dec {
  final String digits;
  final int point;
  const _Dec(this.digits, this.point);

  static _Dec of(double x, [int precision = 15]) {
    x = x.abs();
    if (x == 0 || !x.isFinite) return const _Dec('', 0);
    final s = x.toStringAsPrecision(precision);
    var mantissa = s;
    var exp = 0;
    final e = s.indexOf('e');
    if (e >= 0) {
      mantissa = s.substring(0, e);
      exp = int.parse(s.substring(e + 1));
    }
    final dot = mantissa.indexOf('.');
    final intPart = dot < 0 ? mantissa : mantissa.substring(0, dot);
    final fracPart = dot < 0 ? '' : mantissa.substring(dot + 1);
    return _normalize('$intPart$fracPart', intPart.length + exp);
  }

  static _Dec _normalize(String all, int point) {
    var start = 0;
    while (start < all.length && all.codeUnitAt(start) == 0x30) {
      start++;
      point--;
    }
    var end = all.length;
    while (end > start && all.codeUnitAt(end - 1) == 0x30) {
      end--;
    }
    if (start >= end) return const _Dec('', 0);
    return _Dec(all.substring(start, end), point);
  }

  /// Multiplies by 10^[n].
  _Dec shift(int n) => digits.isEmpty ? this : _Dec(digits, point + n);

  /// Rounds half away from zero to [decimals] decimal places.
  _Dec roundTo(int decimals) {
    final keep = point + decimals;
    if (keep >= digits.length) return this;
    if (keep < 0) return const _Dec('', 0);
    final up = digits.codeUnitAt(keep) >= 0x35;
    final kept = digits.substring(0, keep).codeUnits.toList();
    var p = point;
    if (up) {
      var i = kept.length - 1;
      while (i >= 0 && kept[i] == 0x39) {
        kept[i] = 0x30;
        i--;
      }
      if (i >= 0) {
        kept[i]++;
      } else {
        kept.insert(0, 0x31);
        p++;
      }
    }
    return _normalize(String.fromCharCodes(kept), p);
  }

  /// Integer digits ('' for 0) and exactly [decimals] fraction digits, unrounded.
  (String, String) split(int decimals) {
    final ib = StringBuffer();
    for (var i = 0; i < point; i++) {
      ib.write(i < digits.length ? digits[i] : '0');
    }
    final fb = StringBuffer();
    for (var k = 0; k < decimals; k++) {
      final i = point + k;
      fb.write(i >= 0 && i < digits.length ? digits[i] : '0');
    }
    return (ib.toString(), fb.toString());
  }

  /// Rounded to [decimals] places, split into integer and fraction digits.
  (String, String) fixed(int decimals) => roundTo(decimals).split(decimals);
}
