import 'package:intl/date_symbol_data_local.dart' as date_data;
import 'package:intl/date_symbols.dart';
import 'package:intl/number_symbols.dart';
import 'package:intl/number_symbols_data.dart' as number_data;

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

  @override
  bool operator ==(Object other) => other is FormulaLocale && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FormulaLocale($id)';
}
