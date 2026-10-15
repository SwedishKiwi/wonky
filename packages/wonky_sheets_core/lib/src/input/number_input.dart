import 'package:wonky_numfmt/wonky_numfmt.dart';

import '../format/number_format/inference.dart';

/// A number recognized in typed input (03 §8.6).
final class NumberInputMatch {
  /// Creates a match.
  const NumberInputMatch(
    this.value,
    this.format, {
    this.kind = NumberInputKind.plain,
  });

  /// The value (percent already divided by 100).
  final double value;

  /// The auto-detected pattern (06 §5.9), or null for Automatic.
  final String? format;

  /// What was recognized.
  final NumberInputKind kind;
}

/// Kinds of recognized numbers.
enum NumberInputKind {
  /// Plain or grouped number.
  plain,

  /// Scientific notation.
  scientific,

  /// Percent.
  percent,

  /// Currency amount.
  currency,
}

/// Locale-aware recognizer for typed numbers: grouping, decimals, exponent,
/// percent (with spaces), currency symbols before/after, signs and
/// parentheses for negatives.
final class NumberInputRecognizer {
  NumberInputRecognizer._(this.locale, this._groupChars, this._symbols);

  /// Locale data.
  final LocaleFormatData locale;
  final Set<String> _groupChars;

  /// Currency symbols, longest first.
  final List<String> _symbols;

  static final Map<String, NumberInputRecognizer> _cache = {};

  /// Common currency symbols accepted in every locale.
  static const List<String> commonSymbols = [
    r'$',
    '€',
    '£',
    '¥',
    '₹',
    '₩',
    '₽',
    '₺',
    '₪',
    '₫',
    '฿',
    '₴',
    '₱',
    '₦',
    '¢', //
  ];

  /// Recognizer for [locale].
  static NumberInputRecognizer forLocale(LocaleFormatData locale) =>
      _cache[locale.id] ??= _build(locale);

  static NumberInputRecognizer _build(LocaleFormatData locale) {
    final g = locale.group;
    final groups = <String>{g};
    if (g == ' ' || g == ' ' || g == ' ') groups.addAll(const [' ', ' ', ' ']);
    if (g == "'" || g == '’') groups.addAll(const ["'", '’']);
    final symbols = <String>{...commonSymbols, locale.currencySymbol}.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return NumberInputRecognizer._(locale, groups, symbols);
  }

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  static bool _isSpace(String c) => c == ' ' || c == ' ' || c == ' ';

  static final RegExp _mixedFraction = RegExp(
    r'^([+\-\u2212]?)(\d+) +(\d+)/(\d+)$',
  );

  /// `0 1/2`, `-1 3/16`: a mixed fraction (03 §8.6; a bare `1/2` is a
  /// date). The format shows a fraction with as many `?` as the typed
  /// denominator has digits (`# ?/?`, `# ??/??`).
  static NumberInputMatch? _fraction(String s) {
    final m = _mixedFraction.firstMatch(s);
    if (m == null) return null;
    final whole = int.parse(m.group(2)!);
    final num = int.parse(m.group(3)!);
    final den = int.parse(m.group(4)!);
    if (den == 0) return null;
    final v = whole + num / den;
    final q = '?' * m.group(4)!.length;
    return NumberInputMatch(
      m.group(1)!.isEmpty || m.group(1) == '+' ? v : -v,
      '# $q/$q',
    );
  }

  /// Recognizes [text] (already trimmed), or returns null.
  NumberInputMatch? match(String text) {
    var s = text;
    if (s.isEmpty) return null;
    final fraction = _fraction(s);
    if (fraction != null) return fraction;
    var negative = false;
    if (s.length >= 2 && s.startsWith('(') && s.endsWith(')')) {
      negative = true;
      s = s.substring(1, s.length - 1).trim();
    }
    String? symbol;
    var symbolBefore = true;
    var spaced = false;
    var percent = false;
    var signSeen = false;

    bool takeSign() {
      if (s.isEmpty || signSeen) return false;
      final c = s[0];
      if (c == '-' || c == '−' || c == '+') {
        if (c != '+') negative = !negative;
        signSeen = true;
        s = s.substring(1).trimLeft();
        return true;
      }
      return false;
    }

    takeSign();
    for (final sym in _symbols) {
      if (s.startsWith(sym)) {
        symbol = sym;
        s = s.substring(sym.length);
        if (s.isNotEmpty && _isSpace(s[0])) spaced = true;
        s = s.trimLeft();
        break;
      }
    }
    if (symbol != null) takeSign();
    if (symbol == null) {
      for (final sym in _symbols) {
        if (s.endsWith(sym)) {
          symbol = sym;
          symbolBefore = false;
          s = s.substring(0, s.length - sym.length);
          if (s.isNotEmpty && _isSpace(s[s.length - 1])) spaced = true;
          s = s.trimRight();
          break;
        }
      }
    }
    if (symbol == null && (s.endsWith('%') || s.endsWith(locale.percent))) {
      percent = true;
      s = s.substring(0, s.length - 1).trimRight();
    }
    if (symbol != null && symbolBefore && s.endsWith('%')) return null;
    if (s.isEmpty) return null;
    // Trailing minus after a suffix symbol is not accepted; sign after the
    // number (`5-`) neither.
    final core = _core(s);
    if (core == null) return null;
    if (core.exponent != null && (percent || symbol != null)) return null;
    final shift = percent ? -2 : 0;
    final str = StringBuffer(negative ? '-' : '')
      ..write(core.intDigits.isEmpty ? '0' : core.intDigits)
      ..write('.')
      ..write(core.fracDigits.isEmpty ? '0' : core.fracDigits)
      ..write('e')
      ..write((core.exponent ?? 0) + shift);
    final value = double.tryParse(str.toString());
    if (value == null || !value.isFinite) return null;
    final decimals = core.fracDigits.length;
    if (core.exponent != null) {
      return NumberInputMatch(
        value,
        FormatInference.scientific,
        kind: NumberInputKind.scientific,
      );
    }
    if (percent) {
      return NumberInputMatch(
        value,
        FormatInference.percent(decimals, grouped: core.grouped),
        kind: NumberInputKind.percent,
      );
    }
    if (symbol != null) {
      return NumberInputMatch(
        value,
        FormatInference.currency(
          symbol,
          decimals,
          before: symbolBefore,
          spaced: spaced,
        ),
        kind: NumberInputKind.currency,
      );
    }
    return NumberInputMatch(
      value,
      core.grouped ? FormatInference.grouped(decimals) : null,
    );
  }

  ({String intDigits, String fracDigits, int? exponent, bool grouped})? _core(
    String s,
  ) {
    final dec = locale.decimal;
    var i = 0;
    final n = s.length;
    final intB = StringBuffer();
    var grouped = false;
    final groupLens = <int>[];
    var run = 0;
    while (i < n) {
      final c = s.codeUnitAt(i);
      if (_isDigit(c)) {
        intB.writeCharCode(c);
        run++;
        i++;
        continue;
      }
      final ch = s[i];
      if (_groupChars.contains(ch) &&
          ch != dec &&
          i + 1 < n &&
          _isDigit(s.codeUnitAt(i + 1))) {
        if (run == 0) return null;
        groupLens.add(run);
        run = 0;
        grouped = true;
        i++;
        continue;
      }
      break;
    }
    if (grouped) {
      groupLens.add(run);
      if (!_validGroups(groupLens)) return null;
    }
    final fracB = StringBuffer();
    var hasPoint = false;
    if (i < n && s.startsWith(dec, i)) {
      hasPoint = true;
      i += dec.length;
      while (i < n && _isDigit(s.codeUnitAt(i))) {
        fracB.writeCharCode(s.codeUnitAt(i));
        i++;
      }
    }
    if (intB.isEmpty && fracB.isEmpty) return null;
    if (hasPoint && intB.isEmpty && fracB.isEmpty) return null;
    int? exponent;
    if (i < n && (s[i] == 'e' || s[i] == 'E')) {
      var j = i + 1;
      var expNeg = false;
      if (j < n && (s[j] == '+' || s[j] == '-')) {
        expNeg = s[j] == '-';
        j++;
      }
      final start = j;
      while (j < n && _isDigit(s.codeUnitAt(j))) {
        j++;
      }
      if (j == start || j - start > 4) return null;
      exponent = int.parse(s.substring(start, j)) * (expNeg ? -1 : 1);
      if (grouped) return null;
      i = j;
    }
    if (i != n) return null;
    return (
      intDigits: intB.toString(),
      fracDigits: fracB.toString(),
      exponent: exponent,
      grouped: grouped,
    );
  }

  bool _validGroups(List<int> lens) {
    if (lens.first < 1 || lens.first > 3 || lens.last != 3) return false;
    final middleTwo = locale.indianGrouping;
    for (var k = 1; k < lens.length - 1; k++) {
      final l = lens[k];
      if (l == 3) continue;
      if (middleTwo && l == 2) continue;
      return false;
    }
    if (middleTwo && lens.length > 2 && lens.first > 2) {
      // Indian grouping: leading group of 1–2 digits before 2-digit groups.
      if (lens[1] == 2) return false;
    }
    return true;
  }
}
