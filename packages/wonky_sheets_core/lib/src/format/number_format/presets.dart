import '../../content/cell_content.dart';
import 'locale_data.dart';
import 'number_formatter.dart';

/// An entry of the Format › Number menu (06 §5.1, 04 §3.5).
final class NumberFormatMenuItem {
  /// Creates a menu item.
  const NumberFormatMenuItem(
    this.id,
    this.label,
    this.stored,
    this.exampleValue,
  );

  /// Stable id (`number`, `currency`, …).
  final String id;

  /// English label (UI localizes by [id]).
  final String label;

  /// What is stored in `Cell.numberFormat`: a pattern or a `preset:` id.
  final String stored;

  /// Value used to render the menu's example column.
  final double exampleValue;

  /// The example column text in [locale] (`$1,000.12`, `9/26/2008`).
  String example({String locale = 'en_US', NumberFormatter? formatter}) =>
      (formatter ?? NumberFormatter.instance).formatText(
        NumberValue(exampleValue),
        stored,
        locale: locale,
      );
}

/// Number format presets and their locale resolution (06 §5.1).
///
/// Preset ids (`preset:<name>`) are stored for formats whose pattern depends
/// on the spreadsheet locale, so changing the locale re-renders them.
abstract final class NumberFormatPresets {
  /// Prefix of preset ids.
  static const String prefix = 'preset:';

  /// `preset:automatic`.
  static const String automatic = 'preset:automatic';

  /// `preset:accounting`.
  static const String accounting = 'preset:accounting';

  /// `preset:currency`.
  static const String currency = 'preset:currency';

  /// `preset:currencyRounded`.
  static const String currencyRounded = 'preset:currencyRounded';

  /// `preset:date`.
  static const String date = 'preset:date';

  /// `preset:time`.
  static const String time = 'preset:time';

  /// `preset:dateTime`.
  static const String dateTime = 'preset:dateTime';

  /// Plain text.
  static const String plainText = '@';

  /// Number with two decimals and grouping (toolbar "123" › Number).
  static const String number = '#,##0.00';

  /// Percent with two decimals (toolbar `%`).
  static const String percent = '0.00%';

  /// Scientific.
  static const String scientific = '0.00E+00';

  /// Financial (negatives in parentheses).
  static const String financial = '#,##0.00;(#,##0.00)';

  /// Duration.
  static const String duration = '[h]:mm:ss';

  /// All preset ids.
  static const List<String> presetIds = [
    automatic, accounting, currency, currencyRounded, date, time, dateTime, //
  ];

  /// Format-hint presets the formula engine reports for formula results with
  /// Automatic format (`CellSource.numberFormatAt`: `preset:` +
  /// `FormatHint.code`, 05 §6.2); [date], [time] and [dateTime] are shared.
  /// Never stored in cells.
  static const String hintDuration = 'preset:duration';

  /// Percent hint (`=A1*10%`) → [percent].
  static const String hintPercent = 'preset:percent';

  /// Scientific hint → [scientific].
  static const String hintScientific = 'preset:scientific';

  /// Currency hint in the locale currency (`preset:cur`), or with an ISO
  /// code (`preset:cur:EUR`).
  static const String hintCurrency = 'preset:cur';

  /// Format › Number menu, in menu order.
  static const List<NumberFormatMenuItem> menu = [
    NumberFormatMenuItem('automatic', 'Automatic', automatic, 1234.5),
    NumberFormatMenuItem('plainText', 'Plain text', plainText, 12),
    NumberFormatMenuItem('number', 'Number', number, 1000.12),
    NumberFormatMenuItem('percent', 'Percent', percent, 0.1012),
    NumberFormatMenuItem('scientific', 'Scientific', scientific, 1012),
    NumberFormatMenuItem('accounting', 'Accounting', accounting, -1000.12),
    NumberFormatMenuItem('financial', 'Financial', financial, -1000.12),
    NumberFormatMenuItem('currency', 'Currency', currency, 1000.12),
    NumberFormatMenuItem(
      'currencyRounded',
      'Currency rounded',
      currencyRounded,
      1000.12,
    ),
    NumberFormatMenuItem('date', 'Date', date, 39717.66597222222),
    NumberFormatMenuItem('time', 'Time', time, 39717.66597222222),
    NumberFormatMenuItem('dateTime', 'Date time', dateTime, 39717.66597222222),
    NumberFormatMenuItem('duration', 'Duration', duration, 1.000694444444444),
  ];

  /// Toolbar shortcuts (04 §4): currency, percent, "123" menu entries.
  static const String toolbarCurrency = currency;

  /// Toolbar percent shortcut.
  static const String toolbarPercent = percent;

  /// Keyboard shortcuts `Mod+Shift+1…6` (Google Sheets): digit → stored format.
  static const Map<int, String> shortcutFormats = {
    1: number,
    2: time,
    3: date,
    4: currency,
    5: percent,
    6: scientific,
  };

  /// Whether [format] is a preset id.
  static bool isPreset(String? format) =>
      format != null && format.startsWith(prefix);

  /// Whether [format] means Automatic (null, empty, `preset:automatic`,
  /// `General`).
  static bool isAutomatic(String? format) =>
      format == null ||
      format.isEmpty ||
      format == automatic ||
      format.toLowerCase() == 'general';

  static final Map<(String, String), String?> _cache = {};

  /// Resolves [format] for [locale]: preset ids → their locale pattern
  /// (null for Automatic and unknown presets); patterns are returned as is.
  static String? resolve(String? format, String locale) {
    if (format == null || format.isEmpty) return null;
    if (!format.startsWith(prefix)) return format;
    final key = (format, locale);
    if (_cache.containsKey(key)) return _cache[key];
    final loc = LocaleFormatData.forId(locale);
    final resolved = switch (format) {
      currency => currencyPattern(loc, decimals: loc.currencyDecimals),
      currencyRounded => currencyPattern(loc, decimals: 0),
      accounting => accountingPattern(loc),
      date => datePattern(loc),
      time => timePattern(loc),
      dateTime => dateTimePattern(loc),
      hintDuration => duration,
      hintPercent => percent,
      hintScientific => scientific,
      hintCurrency => currencyPattern(loc, decimals: loc.currencyDecimals),
      _ when format.startsWith('$hintCurrency:') => _currencyOf(
        format.substring(hintCurrency.length + 1),
        loc,
      ),
      _ => null,
    };
    _cache[key] = resolved;
    return resolved;
  }

  static String _currencyOf(String code, LocaleFormatData loc) =>
      code.isEmpty || code.toUpperCase() == loc.currencyCode
      ? currencyPattern(loc, decimals: loc.currencyDecimals)
      : currencyPattern(loc, symbol: currencySymbolFor(code));

  /// Display symbol of an ISO currency code (`EUR` → `€`); the code itself
  /// when no common symbol exists.
  static String currencySymbolFor(String code) =>
      _currencySymbols[code.toUpperCase()] ?? code;

  static const Map<String, String> _currencySymbols = {
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'CNY': '¥',
    'INR': '₹',
    'KRW': '₩',
    'BRL': r'R$',
    'RUB': '₽',
    'CHF': 'CHF',
    'SEK': 'kr',
    'NOK': 'kr',
    'DKK': 'kr',
    'PLN': 'zł',
    'CZK': 'Kč',
    'TRY': '₺',
    'AUD': r'A$',
    'CAD': r'CA$',
    'NZD': r'NZ$',
    'MXN': r'MX$',
    'ZAR': 'R',
    'ILS': '₪',
    'HUF': 'Ft',
    'UAH': '₴',
    'VND': '₫',
    'THB': '฿',
    'PHP': '₱',
    'NGN': '₦',
    'HKD': r'HK$',
    'SGD': r'S$',
    'TWD': r'NT$',
  };

  /// The currency symbol token of [locale] for patterns: `"$"` in en_US,
  /// else `[$sym-LCID]` (`[$€-407]`), or `[$sym]` without a known LCID.
  static String currencyToken(LocaleFormatData locale, {String? symbol}) {
    final sym = symbol ?? locale.currencySymbol;
    if (locale.lcid == 0x409 && sym == r'$') return r'"$"';
    final lcid = locale.lcid;
    if (lcid == null) return '[\$$sym]';
    return '[\$$sym-${lcid.toRadixString(16).toUpperCase()}]';
  }

  static String _digits(int decimals) =>
      decimals > 0 ? '#,##0.${'0' * decimals}' : '#,##0';

  /// Currency pattern of [locale] (symbol position and spacing from CLDR).
  static String currencyPattern(
    LocaleFormatData locale, {
    int decimals = 2,
    String? symbol,
  }) {
    final tok = currencyToken(locale, symbol: symbol);
    final num = _digits(decimals);
    final sp = locale.currencySpaced ? ' ' : '';
    return locale.currencyBefore ? '$tok$sp$num' : '$num$sp$tok';
  }

  /// Accounting pattern of [locale].
  static String accountingPattern(
    LocaleFormatData locale, {
    int? decimals,
    String? symbol,
  }) {
    final d = decimals ?? locale.currencyDecimals;
    final tok = currencyToken(locale, symbol: symbol);
    final num = _digits(d);
    final dash = '"-"${'?' * d}';
    if (locale.currencyBefore) {
      return '_($tok* ${num}_);_($tok* \\($num\\);_($tok* ${dash}_);_(@_)';
    }
    return '_-* $num ${tok}_-;-* $num ${tok}_-;_-* $dash ${tok}_-;_-@_-';
  }

  /// Date preset: the locale's short date with a four-digit year.
  static String datePattern(LocaleFormatData locale) =>
      icuToPattern(locale.shortDatePattern, fourDigitYear: true);

  /// Time preset: the locale's medium time (with seconds).
  static String timePattern(LocaleFormatData locale) =>
      icuToPattern(locale.mediumTimePattern);

  /// Time without seconds (`h:mm AM/PM`, `HH:mm`).
  static String shortTimePattern(LocaleFormatData locale) =>
      icuToPattern(locale.shortTimePattern);

  /// Date time preset: date preset + 24-hour medium time.
  static String dateTimePattern(LocaleFormatData locale) =>
      '${datePattern(locale)} ${icuToPattern(locale.mediumTimePattern, force24h: true)}';

  /// Converts an ICU/CLDR date pattern (`M/d/yy`, `h:mm:ss a`) to the
  /// number-format language.
  static String icuToPattern(
    String icu, {
    bool fourDigitYear = false,
    bool force24h = false,
  }) {
    final b = StringBuffer();
    var i = 0;
    while (i < icu.length) {
      final c = icu[i];
      if (c == "'") {
        if (i + 1 < icu.length && icu[i + 1] == "'") {
          b.write(r"\'");
          i += 2;
          continue;
        }
        final text = StringBuffer();
        var j = i + 1;
        while (j < icu.length) {
          if (icu[j] == "'") {
            if (j + 1 < icu.length && icu[j + 1] == "'") {
              text.write("'");
              j += 2;
              continue;
            }
            break;
          }
          text.write(icu[j]);
          j++;
        }
        if (text.isNotEmpty) b.write('"$text"');
        i = j + 1;
        continue;
      }
      if (_isAsciiLetter(c)) {
        var j = i;
        while (j < icu.length && icu[j] == c) {
          j++;
        }
        final n = j - i;
        b.write(
          _icuField(c, n, fourDigitYear: fourDigitYear, force24h: force24h),
        );
        i = j;
        continue;
      }
      if (r'"\*_;[@#?%0123456789'.contains(c)) {
        b.write('\\$c');
      } else if (c == ' ' || c == ' ') {
        b.write(' ');
      } else {
        b.write(c);
      }
      i++;
    }
    return b.toString().replaceAll(RegExp(' {2,}'), ' ').trim();
  }

  static bool _isAsciiLetter(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 0x41 && u <= 0x5a) || (u >= 0x61 && u <= 0x7a);
  }

  static int _min2(int n) => n > 2 ? 2 : n;

  static String _icuField(
    String c,
    int n, {
    required bool fourDigitYear,
    required bool force24h,
  }) {
    switch (c) {
      case 'y' || 'Y' || 'u':
        return n == 2 && !fourDigitYear ? 'yy' : 'yyyy';
      case 'M' || 'L':
        return n <= 2
            ? 'M' * n
            : (n == 3 ? 'MMM' : (n == 4 ? 'MMMM' : 'MMMMM'));
      case 'd':
        return 'd' * _min2(n);
      case 'E' || 'c' || 'e':
        return n <= 3 ? 'ddd' : 'dddd';
      case 'h' || 'K':
        return force24h ? 'H' * _min2(n) : 'h' * _min2(n);
      case 'H' || 'k':
        return 'H' * _min2(n);
      case 'm':
        return 'm' * _min2(n);
      case 's':
        return 's' * _min2(n);
      case 'a' || 'b' || 'B':
        return force24h ? '' : 'AM/PM';
      case 'G' || 'z' || 'Z' || 'v' || 'V' || 'O' || 'X' || 'x':
        return '';
      default:
        return '"${c * n}"';
    }
  }
}
