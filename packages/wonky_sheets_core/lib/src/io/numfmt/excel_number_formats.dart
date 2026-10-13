/// Excel number formats ⇄ Wonky patterns (11 §5.2): built-in ids, locale
/// tags, presets and date detection.
abstract final class ExcelNumberFormats {
  /// Built-in format ids 0–49 (ECMA-376 §18.8.30, en-US). Id 0 is General
  /// (Wonky: Automatic).
  static const Map<int, String> builtIn = {
    0: 'General',
    1: '0',
    2: '0.00',
    3: '#,##0',
    4: '#,##0.00',
    5: r'"$"#,##0_);("$"#,##0)',
    6: r'"$"#,##0_);[Red]("$"#,##0)',
    7: r'"$"#,##0.00_);("$"#,##0.00)',
    8: r'"$"#,##0.00_);[Red]("$"#,##0.00)',
    9: '0%',
    10: '0.00%',
    11: '0.00E+00',
    12: '# ?/?',
    13: '# ??/??',
    14: 'm/d/yyyy',
    15: 'd-mmm-yy',
    16: 'd-mmm',
    17: 'mmm-yy',
    18: 'h:mm AM/PM',
    19: 'h:mm:ss AM/PM',
    20: 'h:mm',
    21: 'h:mm:ss',
    22: 'm/d/yyyy h:mm',
    37: '#,##0 ;(#,##0)',
    38: '#,##0 ;[Red](#,##0)',
    39: '#,##0.00;(#,##0.00)',
    40: '#,##0.00;[Red](#,##0.00)',
    41: r'_(* #,##0_);_(* \(#,##0\);_(* "-"_);_(@_)',
    42: r'_("$"* #,##0_);_("$"* \(#,##0\);_("$"* "-"_);_(@_)',
    43: r'_(* #,##0.00_);_(* \(#,##0.00\);_(* "-"??_);_(@_)',
    44: r'_("$"* #,##0.00_);_("$"* \(#,##0.00\);_("$"* "-"??_);_(@_)',
    45: 'mm:ss',
    46: '[h]:mm:ss',
    47: 'mm:ss.0',
    48: '##0.0E+0',
    49: '@',
  };

  /// Ids whose rendering follows the system locale in Excel: imported as
  /// locale-dependent presets.
  static const Map<int, String> presetIds = {
    14: 'preset:date',
    22: 'preset:dateTime',
  };

  /// Ids 27–36 and 50–81 are East Asian locale formats: date-like fallbacks.
  static String? _eastAsian(int id) {
    if ((id >= 27 && id <= 31) || (id >= 50 && id <= 58)) return 'yyyy-mm-dd';
    if (id >= 32 && id <= 36) return 'h:mm:ss';
    return null;
  }

  /// Pattern (or `preset:` id, or null for General) of an imported
  /// `numFmtId` with optional custom [custom] format codes.
  static String? importId(
    int id,
    Map<int, String> custom, {
    void Function(String message)? warn,
  }) {
    final c = custom[id];
    if (c != null) return importPattern(c, warn: warn);
    final preset = presetIds[id];
    if (preset != null) return preset;
    final b = builtIn[id];
    if (b != null) return id == 0 ? null : b;
    final ea = _eastAsian(id);
    if (ea != null) {
      warn?.call('Locale-specific number format $id was approximated');
      return ea;
    }
    return null;
  }

  static final RegExp _bracket = RegExp(r'\[([^\]]*)\]');

  /// Converts an Excel format code: `General` → null; pure locale tags
  /// (`[$-409]`, `[$-F800]`, `[$-x-sysdate]`) are removed; currency tags
  /// (`[$€-407]`) kept; `[DBNum1]`-style tags removed with a warning.
  static String? importPattern(
    String code, {
    void Function(String message)? warn,
  }) {
    if (code.trim().isEmpty || code.toLowerCase() == 'general') return null;
    final out = StringBuffer();
    var i = 0;
    var inQuote = false;
    while (i < code.length) {
      final ch = code[i];
      if (ch == '"') {
        inQuote = !inQuote;
        out.write(ch);
        i++;
        continue;
      }
      if (!inQuote && ch == r'\' && i + 1 < code.length) {
        out.write(code.substring(i, i + 2));
        i += 2;
        continue;
      }
      if (!inQuote && ch == '[') {
        final m = _bracket.matchAsPrefix(code, i);
        if (m != null) {
          final inner = m.group(1)!;
          if (inner.startsWith(r'$')) {
            final dash = inner.indexOf('-');
            final symbol = dash < 0
                ? inner.substring(1)
                : inner.substring(1, dash);
            if (symbol.isNotEmpty) out.write(m.group(0));
          } else if (RegExp(
            r'^(DBNum\d|NatNum\d+|ENG|JPN|TWN|KOR|CHN|\$)',
            caseSensitive: false,
          ).hasMatch(inner)) {
            warn?.call('Number format tag [$inner] was removed');
          } else {
            out.write(m.group(0));
          }
          i = m.end;
          continue;
        }
      }
      out.write(ch);
      i++;
    }
    final s = out.toString();
    if (s.toLowerCase() == 'general') return null;
    return s;
  }

  /// The built-in id of [pattern] (exact match), or null.
  static int? builtInIdOf(String pattern) {
    for (final e in builtIn.entries) {
      if (e.value == pattern) return e.key;
    }
    return null;
  }

  /// Export: Wonky pattern or preset → (`numFmtId` when built-in, format
  /// code). Automatic → id 0.
  static ({int? id, String code}) export(
    String? patternOrPreset, {
    String locale = 'en_US',
  }) {
    final p = patternOrPreset;
    if (p == null || p == 'preset:automatic' || p.toLowerCase() == 'general') {
      return (id: 0, code: 'General');
    }
    for (final e in presetIds.entries) {
      if (e.value == p) return (id: e.key, code: builtIn[e.key]!);
    }
    final resolved = p.startsWith('preset:') ? presetPattern(p, locale) : p;
    final id = builtInIdOf(resolved);
    return (id: id, code: resolved);
  }

  /// A concrete pattern for a locale-dependent preset (used where the
  /// target format has no equivalent).
  static String presetPattern(String preset, String locale) {
    final lang = locale.split(RegExp('[_-]')).first.toLowerCase();
    final us = locale == 'en_US' || locale == 'en_CA' || locale == 'es_MX';
    final sym = _currencySymbol(locale);
    final symbolFirst =
        lang == 'en' ||
        lang == 'ja' ||
        lang == 'zh' ||
        lang == 'ko' ||
        locale == 'nl_NL';
    String money(String num) => symbolFirst ? '"$sym"$num' : '$num [\$$sym]';
    return switch (preset) {
      'preset:date' =>
        us ? 'm/d/yyyy' : (lang == 'en' ? 'dd/mm/yyyy' : 'dd.mm.yyyy'),
      'preset:time' => us || lang == 'en' ? 'h:mm:ss AM/PM' : 'hh:mm:ss',
      'preset:dateTime' => us ? 'm/d/yyyy h:mm:ss' : 'dd.mm.yyyy hh:mm:ss',
      'preset:currency' => money('#,##0.00'),
      'preset:currencyRounded' => money('#,##0'),
      'preset:accounting' =>
        symbolFirst
            ? '_("$sym"* #,##0.00_);_("$sym"* \\(#,##0.00\\);_("$sym"* "-"??_);_(@_)'
            : '_-* #,##0.00 [\$$sym]_-;-* #,##0.00 [\$$sym]_-;_-* "-"?? [\$$sym]_-;_-@_-',
      _ => 'General',
    };
  }

  static String _currencySymbol(String locale) {
    const m = {
      'en_US': r'$',
      'en_CA': r'$',
      'es_MX': r'$',
      'en_AU': r'$',
      'pt_BR': r'R$', //
      'en_GB': '£', 'ja_JP': '¥', 'zh_CN': '¥', 'ko_KR': '₩', 'en_IN': '₹', //
      'sv_SE': 'kr',
      'da_DK': 'kr',
      'nb_NO': 'kr',
      'de_CH': 'CHF',
      'pl_PL': 'zł',
      'ru_RU': '₽',
    };
    return m[locale] ?? '€';
  }

  /// Whether [pattern] displays a calendar date (contains y or d tokens, or
  /// m outside of a time context). Durations (`[h]`) and time-only formats
  /// are not dates.
  static bool isDatePattern(String? pattern) {
    if (pattern == null) return false;
    if (pattern == 'preset:date' || pattern == 'preset:dateTime') return true;
    if (pattern.startsWith('preset:')) return false;
    final t = _tokens(pattern);
    if (t.contains('y') || t.contains('d')) return true;
    if (t.contains('m') && !t.contains('h') && !t.contains('s')) return true;
    if (t.contains('m') && RegExp(r'm{3,}').hasMatch(_stripped(pattern))) {
      return true;
    }
    return false;
  }

  /// Whether [pattern] shows a time of day or duration.
  static bool isTimePattern(String? pattern) {
    if (pattern == null) return false;
    if (pattern == 'preset:time' || pattern == 'preset:dateTime') return true;
    if (pattern.startsWith('preset:')) return false;
    final t = _tokens(pattern);
    return t.contains('h') || t.contains('s');
  }

  static String _stripped(String pattern) {
    final b = StringBuffer();
    var inQuote = false;
    for (var i = 0; i < pattern.length; i++) {
      final ch = pattern[i];
      if (ch == '"') {
        inQuote = !inQuote;
        continue;
      }
      if (inQuote) continue;
      if (ch == r'\' || ch == '_' || ch == '*') {
        i++;
        continue;
      }
      if (ch == '[') {
        final end = pattern.indexOf(']', i);
        if (end < 0) break;
        final inner = pattern.substring(i + 1, end).toLowerCase();
        if (RegExp(r'^(h+|m+|s+)$').hasMatch(inner)) b.write(inner);
        i = end;
        continue;
      }
      b.write(ch.toLowerCase());
    }
    return b.toString();
  }

  static Set<String> _tokens(String pattern) {
    final s = _stripped(pattern).replaceAll('am/pm', '').replaceAll('a/p', '');
    return {
      for (final c in s.split(''))
        if ('ymdhs'.contains(c)) c,
    };
  }
}
