import 'package:intl/date_symbol_data_local.dart' as date_data;
import 'package:intl/date_symbols.dart';
import 'package:intl/number_symbols.dart';
import 'package:intl/number_symbols_data.dart' as number_data;

import 'formula_language.dart';

/// Order of day, month and year in numeric dates of a locale.
enum DateOrder { mdy, dmy, ymd }

/// Formula separators and parsing conventions of a spreadsheet locale (05 §3.2, §6.3).
///
/// Data comes from the CLDR tables bundled with `intl` (never from the OS) so every replica
/// parses identically.
final class FormulaLocale {
  /// Locale id as stored in `Spreadsheet.locale` (`en_US`, `de_DE`).
  final String id;

  /// Decimal separator (`.` or `,`).
  final String decimal;

  /// Grouping separator used in text coercion (`,`, `.`, NBSP, …).
  final String group;

  /// Function argument separator (`,` or `;`).
  final String argSeparator;

  /// Array literal column separator (`,` or `\`).
  final String arrayColSeparator;

  /// Array literal row separator (`;`).
  final String arrayRowSeparator;

  /// Numeric date order.
  final DateOrder dateOrder;

  /// Full month names (January first), locale language.
  final List<String> months;

  /// Abbreviated month names, locale language.
  final List<String> shortMonths;

  /// Weekday names starting with Sunday.
  final List<String> weekdays;
  final List<String> shortWeekdays;

  /// AM/PM markers.
  final List<String> amPm;

  /// Default currency code (`USD`) and symbol (`$`).
  final String currencyCode;
  final String currencySymbol;

  /// Display language of function names and booleans (null = English;
  /// `Spreadsheet.displayLanguage`, see [withLanguage]).
  final FormulaLanguage? language;

  const FormulaLocale._({
    required this.id,
    required this.decimal,
    required this.group,
    required this.argSeparator,
    required this.arrayColSeparator,
    required this.arrayRowSeparator,
    required this.dateOrder,
    required this.months,
    required this.shortMonths,
    required this.weekdays,
    required this.shortWeekdays,
    required this.amPm,
    required this.currencyCode,
    required this.currencySymbol,
    this.language,
  });

  /// Canonical en_US locale (the stored form always uses these separators).
  static const FormulaLocale enUS = FormulaLocale._(
    id: 'en_US',
    decimal: '.',
    group: ',',
    argSeparator: ',',
    arrayColSeparator: ',',
    arrayRowSeparator: ';',
    dateOrder: DateOrder.mdy,
    months: englishMonths,
    shortMonths: englishShortMonths,
    weekdays: englishWeekdays,
    shortWeekdays: englishShortWeekdays,
    amPm: ['AM', 'PM'],
    currencyCode: 'USD',
    currencySymbol: r'$',
  );

  static const List<String> englishMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September', //
    'October', 'November', 'December',
  ];
  static const List<String> englishShortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec', //
  ];
  static const List<String> englishWeekdays = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday', //
  ];
  static const List<String> englishShortWeekdays = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', //
  ];

  static final Map<String, FormulaLocale> _cache = {'en_US': enUS};
  static Map<String, DateSymbols>? _dateSymbols;

  static const Map<String, String> _currencySymbols = {
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'CNY': '¥',
    'INR': '₹',
    'KRW': '₩', //
    'BRL': r'R$',
    'RUB': '₽',
    'CHF': 'CHF',
    'SEK': 'kr',
    'NOK': 'kr',
    'DKK': 'kr', //
    'PLN': 'zł',
    'CZK': 'Kč',
    'TRY': '₺',
    'AUD': r'$',
    'CAD': r'$',
    'NZD': r'$', //
    'MXN': r'$',
    'ZAR': 'R',
    'ILS': '₪',
    'HUF': 'Ft',
    'UAH': '₴',
    'VND': '₫',
    'THB': '฿', //
  };

  /// Locale for a `Spreadsheet.locale` id. Unknown ids fall back to the language, then en_US.
  static FormulaLocale forId(String id) {
    final cached = _cache[id];
    if (cached != null) return cached;
    final loc = _build(id);
    _cache[id] = loc;
    return loc;
  }

  static T? _lookup<T>(Map<String, T> map, String id) {
    final norm = id.replaceAll('-', '_');
    return map[norm] ?? map[norm.split('_').first];
  }

  static FormulaLocale _build(String id) {
    final NumberSymbols? ns = _lookup(number_data.numberFormatSymbols, id);
    if (ns == null) return enUS;
    _dateSymbols ??= date_data.dateTimeSymbolMap().cast<String, DateSymbols>();
    final DateSymbols? ds = _lookup(_dateSymbols!, id);
    final decimal = ns.DECIMAL_SEP == ',' ? ',' : '.';
    final commaDecimal = decimal == ',';
    var order = DateOrder.mdy;
    if (ds != null && ds.DATEFORMATS.length > 3) {
      final short = ds.DATEFORMATS[3].toLowerCase();
      final y = short.indexOf('y');
      final m = short.indexOf('m');
      final d = short.indexOf('d');
      if (y >= 0 && m >= 0 && d >= 0) {
        if (y < m && m < d) {
          order = DateOrder.ymd;
        } else if (d < m) {
          order = DateOrder.dmy;
        }
      }
    }
    final code = ns.DEF_CURRENCY_CODE;
    return FormulaLocale._(
      id: id,
      decimal: decimal,
      group: ns.GROUP_SEP,
      argSeparator: commaDecimal ? ';' : ',',
      arrayColSeparator: commaDecimal ? r'\' : ',',
      arrayRowSeparator: ';',
      dateOrder: order,
      months: ds?.STANDALONEMONTHS ?? englishMonths,
      shortMonths: ds?.STANDALONESHORTMONTHS ?? englishShortMonths,
      weekdays: ds?.STANDALONEWEEKDAYS ?? englishWeekdays,
      shortWeekdays: ds?.STANDALONESHORTWEEKDAYS ?? englishShortWeekdays,
      amPm: ds?.AMPMS ?? const ['AM', 'PM'],
      currencyCode: code,
      currencySymbol: _currencySymbols[code] ?? code,
    );
  }

  bool get usesCommaDecimal => decimal == ',';

  static final Map<String, FormulaLocale> _withLanguage = {};

  /// This locale with function names and booleans in display language
  /// [code] (`Spreadsheet.displayLanguage`: `de`, `fr`, `es`, `sv`; null or
  /// unsupported = English). The stored form stays English.
  FormulaLocale withLanguage(String? code) {
    final lang = FormulaLanguage.forCode(code);
    if (lang == language) return this;
    if (lang == null) return forId(id);
    return _withLanguage['$id|${lang.code}'] ??= FormulaLocale._(
      id: id,
      decimal: decimal,
      group: group,
      argSeparator: argSeparator,
      arrayColSeparator: arrayColSeparator,
      arrayRowSeparator: arrayRowSeparator,
      dateOrder: dateOrder,
      months: months,
      shortMonths: shortMonths,
      weekdays: weekdays,
      shortWeekdays: shortWeekdays,
      amPm: amPm,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
      language: lang,
    );
  }

  /// The English (stored) name of function [name] typed in this locale:
  /// a localized name maps to its English name, anything else is upper-cased.
  String canonicalFunction(String name) =>
      language?.englishName(name) ?? name.toUpperCase();

  /// The display name of English function [english] in this locale.
  String displayFunction(String english) =>
      language?.localName(english) ?? english;

  /// `TRUE`/`FALSE` in this locale's display language.
  String booleanText(bool value) => language == null
      ? (value ? 'TRUE' : 'FALSE')
      : (value ? language!.trueName : language!.falseName);

  /// Whether [word] is a boolean literal here (English always is).
  bool? booleanOf(String word) {
    final u = word.toUpperCase();
    if (u == 'TRUE') return true;
    if (u == 'FALSE') return false;
    return language?.booleanOf(u);
  }

  @override
  bool operator ==(Object other) =>
      other is FormulaLocale &&
      other.id == id &&
      other.language?.code == language?.code;

  @override
  int get hashCode => Object.hash(id, language?.code);

  @override
  String toString() => language == null
      ? 'FormulaLocale($id)'
      : 'FormulaLocale($id, ${language!.code})';
}
