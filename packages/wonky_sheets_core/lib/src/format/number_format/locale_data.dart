import 'package:intl/date_symbol_data_local.dart' as date_data;
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:intl/number_symbols.dart';
import 'package:intl/number_symbols_data.dart' as number_data;

/// Order of day, month and year in numeric dates of a locale.
enum DatePartOrder {
  /// Month, day, year (`10/12/2026`, en_US).
  mdy,

  /// Day, month, year (`12.10.2026`, de_DE).
  dmy,

  /// Year, month, day (`2026/10/12`, ja_JP).
  ymd,
}

/// Locale symbols used by number formats, presets and input parsing
/// (06 §5.8). All data comes from the CLDR tables bundled with `intl` (never
/// from the OS), so every replica formats identically.
final class LocaleFormatData {
  LocaleFormatData._({
    required this.id,
    required this.decimal,
    required this.group,
    required this.percent,
    required this.indianGrouping,
    required this.months,
    required this.shortMonths,
    required this.standaloneMonths,
    required this.standaloneShortMonths,
    required this.weekdays,
    required this.shortWeekdays,
    required this.am,
    required this.pm,
    required this.currencyCode,
    required this.currencySymbol,
    required this.currencyDecimals,
    required this.currencyBefore,
    required this.currencySpaced,
    required this.dateOrder,
    required this.shortDatePattern,
    required this.mediumDatePattern,
    required this.longDatePattern,
    required this.fullDatePattern,
    required this.mediumTimePattern,
    required this.shortTimePattern,
    required this.lcid,
  });

  /// Locale id as stored in `Spreadsheet.locale` (`en_US`, `de_DE`).
  final String id;

  /// Language subtag (`en`, `de`).
  String get language => id.split('_').first.toLowerCase();

  /// Decimal separator.
  final String decimal;

  /// Grouping separator (`,` `.` U+202F `'` U+00A0 …).
  final String group;

  /// Percent sign.
  final String percent;

  /// Per mille sign.
  String get permille => '‰';

  /// Minus sign: always ASCII `-` for predictable copy/paste (06 §5.8).
  String get minus => '-';

  /// Exponent symbol: always `E`.
  String get exponent => 'E';

  /// Whether digits group as 3 then 2 (`12,34,567`, hi_IN / en_IN).
  final bool indianGrouping;

  /// Month names in format context (January first).
  final List<String> months;

  /// Abbreviated month names in format context.
  final List<String> shortMonths;

  /// Stand-alone month names (nominative; January first).
  final List<String> standaloneMonths;

  /// Stand-alone abbreviated month names.
  final List<String> standaloneShortMonths;

  /// Weekday names, Sunday first.
  final List<String> weekdays;

  /// Abbreviated weekday names, Sunday first.
  final List<String> shortWeekdays;

  /// AM marker.
  final String am;

  /// PM marker.
  final String pm;

  /// Default currency (ISO 4217 code, e.g. `EUR`).
  final String currencyCode;

  /// Default currency symbol (`€`).
  final String currencySymbol;

  /// Decimal digits of the default currency (JPY: 0).
  final int currencyDecimals;

  /// Whether the currency symbol precedes the amount.
  final bool currencyBefore;

  /// Whether a space separates symbol and amount.
  final bool currencySpaced;

  /// Order of numeric date parts.
  final DatePartOrder dateOrder;

  /// ICU short date pattern (`M/d/yy`).
  final String shortDatePattern;

  /// ICU medium date pattern (`MMM d, y`).
  final String mediumDatePattern;

  /// ICU long date pattern (`MMMM d, y`).
  final String longDatePattern;

  /// ICU full date pattern (`EEEE, MMMM d, y`).
  final String fullDatePattern;

  /// ICU medium time pattern, with seconds (`h:mm:ss a`).
  final String mediumTimePattern;

  /// ICU short time pattern (`h:mm a`).
  final String shortTimePattern;

  /// Windows LCID of the locale, if known (0x409 for en_US).
  final int? lcid;

  /// Whether the locale's times use a 12-hour clock.
  bool get uses12HourClock => mediumTimePattern.contains('h') || mediumTimePattern.contains('K');

  static final Map<String, LocaleFormatData> _cache = {};
  static Map<String, DateSymbols>? _dateSymbols;

  /// en_US data.
  static LocaleFormatData get enUS => forId('en_US');

  /// Data for a locale id (`en_US`, `de-DE`, `de`). Unknown ids fall back to
  /// the language, then to en_US.
  static LocaleFormatData forId(String id) {
    final cached = _cache[id];
    if (cached != null) return cached;
    final data = _build(id);
    _cache[id] = data;
    return data;
  }

  /// Data for a Windows LCID (`0x407` → de_DE), or null when unknown.
  static LocaleFormatData? forLcid(int lcid) {
    final id = localeIdForLcid(lcid);
    return id == null ? null : forId(id);
  }

  /// Locale id for a Windows LCID (low 16 bits are used), or null.
  static String? localeIdForLcid(int lcid) => lcidLocales[lcid & 0xFFFF];

  /// Windows LCID for a locale id, or null.
  static int? lcidOf(String localeId) {
    final norm = _normalize(localeId);
    final direct = _lcidByLocale[norm];
    if (direct != null) return direct;
    return _lcidByLocale[_defaultRegion[norm] ?? ''];
  }

  static String _normalize(String id) {
    final parts = id.replaceAll('-', '_').split('_');
    if (parts.length == 1) return parts.first.toLowerCase();
    return '${parts.first.toLowerCase()}_${parts.sublist(1).join('_').toUpperCase()}';
  }

  static T? _lookup<T>(Map<String, T> map, String id) {
    final norm = _normalize(id);
    return map[norm] ?? map[norm.split('_').first];
  }

  static String _clean(String s) =>
      s.replaceAll(RegExp('[‎‏؜]'), '');

  static LocaleFormatData _build(String rawId) {
    final id = _normalize(rawId);
    final NumberSymbols? ns = _lookup(number_data.numberFormatSymbols.cast<String, NumberSymbols>(), id);
    if (ns == null) return id == 'en_US' ? _fallbackEnUs() : forId('en_US');
    _dateSymbols ??= date_data.dateTimeSymbolMap().cast<String, DateSymbols>();
    final DateSymbols ds = _lookup(_dateSymbols!, id) ?? _dateSymbols!['en_US']!;
    final shortDate = ds.DATEFORMATS[3];
    final code = ns.DEF_CURRENCY_CODE;
    var symbol = code;
    var decimals = 2;
    try {
      final nf = NumberFormat.simpleCurrency(locale: _intlLocale(id), name: code);
      symbol = nf.currencySymbol;
      decimals = nf.decimalDigits ?? 2;
    } catch (_) {
      // Unknown to intl's currency tables: keep the ISO code.
    }
    final curPattern = _clean(ns.CURRENCY_PATTERN.split(';').first);
    final cur = curPattern.indexOf('¤');
    final firstDigit = curPattern.indexOf(RegExp('[#0]'));
    final before = cur >= 0 && (firstDigit < 0 || cur < firstDigit);
    var spaced = false;
    if (cur >= 0) {
      final neighbor = before ? cur + 1 : cur - 1;
      if (neighbor >= 0 && neighbor < curPattern.length) {
        spaced = const {' ', ' ', ' '}.contains(curPattern[neighbor]);
      }
    }
    var group = _clean(ns.GROUP_SEP);
    if (group.isEmpty) group = ',';
    var percent = _clean(ns.PERCENT);
    if (percent.isEmpty) percent = '%';
    return LocaleFormatData._(
      id: rawId,
      decimal: _clean(ns.DECIMAL_SEP),
      group: group,
      percent: percent,
      indianGrouping: ns.DECIMAL_PATTERN.contains('#,##,##0'),
      months: List.unmodifiable(ds.MONTHS),
      shortMonths: List.unmodifiable(ds.SHORTMONTHS),
      standaloneMonths: List.unmodifiable(ds.STANDALONEMONTHS),
      standaloneShortMonths: List.unmodifiable(ds.STANDALONESHORTMONTHS),
      weekdays: List.unmodifiable(ds.WEEKDAYS),
      shortWeekdays: List.unmodifiable(ds.SHORTWEEKDAYS),
      am: ds.AMPMS[0],
      pm: ds.AMPMS[1],
      currencyCode: code,
      currencySymbol: _clean(symbol),
      currencyDecimals: decimals,
      currencyBefore: before,
      currencySpaced: spaced,
      dateOrder: _orderOf(shortDate),
      shortDatePattern: _clean(shortDate),
      mediumDatePattern: _clean(ds.DATEFORMATS[2]),
      longDatePattern: _clean(ds.DATEFORMATS[1]),
      fullDatePattern: _clean(ds.DATEFORMATS[0]),
      mediumTimePattern: _clean(ds.TIMEFORMATS[2]),
      shortTimePattern: _clean(ds.TIMEFORMATS[3]),
      lcid: lcidOf(id),
    );
  }

  static String _intlLocale(String id) {
    if (NumberFormat.localeExists(id)) return id;
    final lang = id.split('_').first;
    return NumberFormat.localeExists(lang) ? lang : 'en_US';
  }

  static LocaleFormatData _fallbackEnUs() => LocaleFormatData._(
    id: 'en_US',
    decimal: '.',
    group: ',',
    percent: '%',
    indianGrouping: false,
    months: _enMonths,
    shortMonths: _enShortMonths,
    standaloneMonths: _enMonths,
    standaloneShortMonths: _enShortMonths,
    weekdays: _enWeekdays,
    shortWeekdays: _enShortWeekdays,
    am: 'AM',
    pm: 'PM',
    currencyCode: 'USD',
    currencySymbol: r'$',
    currencyDecimals: 2,
    currencyBefore: true,
    currencySpaced: false,
    dateOrder: DatePartOrder.mdy,
    shortDatePattern: 'M/d/yy',
    mediumDatePattern: 'MMM d, y',
    longDatePattern: 'MMMM d, y',
    fullDatePattern: 'EEEE, MMMM d, y',
    mediumTimePattern: 'h:mm:ss a',
    shortTimePattern: 'h:mm a',
    lcid: 0x409,
  );

  static const List<String> _enMonths = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', //
    'October', 'November', 'December',
  ];
  static const List<String> _enShortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];
  static const List<String> _enWeekdays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
  ];
  static const List<String> _enShortWeekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  static DatePartOrder _orderOf(String shortPattern) {
    final p = shortPattern.toLowerCase();
    final y = p.indexOf('y');
    final m = p.indexOf('m');
    final d = p.indexOf('d');
    if (y < 0 || m < 0 || d < 0) return DatePartOrder.mdy;
    if (y < m && m < d) return DatePartOrder.ymd;
    if (d < m) return DatePartOrder.dmy;
    return DatePartOrder.mdy;
  }

  /// Windows LCIDs of common locales (06 §5.7), LCID → locale id.
  static const Map<int, String> lcidLocales = {
    0x0401: 'ar_SA', 0x0402: 'bg_BG', 0x0403: 'ca_ES', 0x0404: 'zh_TW', 0x0405: 'cs_CZ', //
    0x0406: 'da_DK', 0x0407: 'de_DE', 0x0408: 'el_GR', 0x0409: 'en_US', 0x040A: 'es_ES', //
    0x040B: 'fi_FI', 0x040C: 'fr_FR', 0x040D: 'he_IL', 0x040E: 'hu_HU', 0x040F: 'is_IS', //
    0x0410: 'it_IT', 0x0411: 'ja_JP', 0x0412: 'ko_KR', 0x0413: 'nl_NL', 0x0414: 'nb_NO', //
    0x0415: 'pl_PL', 0x0416: 'pt_BR', 0x0417: 'rm_CH', 0x0418: 'ro_RO', 0x0419: 'ru_RU', //
    0x041A: 'hr_HR', 0x041B: 'sk_SK', 0x041C: 'sq_AL', 0x041D: 'sv_SE', 0x041E: 'th_TH', //
    0x041F: 'tr_TR', 0x0420: 'ur_PK', 0x0421: 'id_ID', 0x0422: 'uk_UA', 0x0423: 'be_BY', //
    0x0424: 'sl_SI', 0x0425: 'et_EE', 0x0426: 'lv_LV', 0x0427: 'lt_LT', 0x0429: 'fa_IR', //
    0x042A: 'vi_VN', 0x042B: 'hy_AM', 0x042C: 'az_AZ', 0x042D: 'eu_ES', 0x042F: 'mk_MK', //
    0x0436: 'af_ZA', 0x0437: 'ka_GE', 0x0438: 'fo_FO', 0x0439: 'hi_IN', 0x043A: 'mt_MT', //
    0x043E: 'ms_MY', 0x043F: 'kk_KZ', 0x0440: 'ky_KG', 0x0441: 'sw_KE', 0x0443: 'uz_UZ', //
    0x0445: 'bn_IN', 0x0446: 'pa_IN', 0x0447: 'gu_IN', 0x0449: 'ta_IN', 0x044A: 'te_IN', //
    0x044B: 'kn_IN', 0x044C: 'ml_IN', 0x044E: 'mr_IN', 0x0450: 'mn_MN', 0x0452: 'cy_GB', //
    0x0453: 'km_KH', 0x0454: 'lo_LA', 0x0456: 'gl_ES', 0x045B: 'si_LK', 0x045E: 'am_ET', //
    0x0461: 'ne_NP', 0x0462: 'fy_NL', 0x0463: 'ps_AF', 0x0464: 'fil_PH', 0x046E: 'lb_LU', //
    0x0481: 'mi_NZ', 0x0801: 'ar_IQ', 0x0804: 'zh_CN', 0x0807: 'de_CH', 0x0809: 'en_GB', //
    0x080A: 'es_MX', 0x080C: 'fr_BE', 0x0810: 'it_CH', 0x0813: 'nl_BE', 0x0814: 'nn_NO', //
    0x0816: 'pt_PT', 0x081A: 'sr_Latn_RS', 0x081D: 'sv_FI', 0x083C: 'ga_IE', 0x083E: 'ms_BN', //
    0x0845: 'bn_BD', 0x0C01: 'ar_EG', 0x0C04: 'zh_HK', 0x0C07: 'de_AT', 0x0C09: 'en_AU', //
    0x0C0A: 'es_ES', 0x0C0C: 'fr_CA', 0x0C1A: 'sr_RS', 0x1001: 'ar_LY', 0x1004: 'zh_SG', //
    0x1007: 'de_LU', 0x1009: 'en_CA', 0x100A: 'es_GT', 0x100C: 'fr_CH', 0x1401: 'ar_DZ', //
    0x1404: 'zh_MO', 0x1407: 'de_LI', 0x1409: 'en_NZ', 0x140A: 'es_CR', 0x140C: 'fr_LU', //
    0x1801: 'ar_MA', 0x1809: 'en_IE', 0x180A: 'es_PA', 0x180C: 'fr_MC', 0x1C01: 'ar_TN', //
    0x1C09: 'en_ZA', 0x1C0A: 'es_DO', 0x2001: 'ar_OM', 0x2009: 'en_JM', 0x200A: 'es_VE', //
    0x2401: 'ar_YE', 0x240A: 'es_CO', 0x2801: 'ar_SY', 0x2809: 'en_BZ', 0x280A: 'es_PE', //
    0x2C01: 'ar_JO', 0x2C09: 'en_TT', 0x2C0A: 'es_AR', 0x3001: 'ar_LB', 0x300A: 'es_EC', //
    0x3401: 'ar_KW', 0x3409: 'en_PH', 0x340A: 'es_CL', 0x3801: 'ar_AE', 0x380A: 'es_UY', //
    0x3C01: 'ar_BH', 0x3C0A: 'es_PY', 0x4001: 'ar_QA', 0x4009: 'en_IN', 0x400A: 'es_BO', //
    0x440A: 'es_SV', 0x4809: 'en_SG', 0x480A: 'es_HN', 0x4C0A: 'es_NI', 0x500A: 'es_PR', //
    0x540A: 'es_US', 0x5C0A: 'es_CU',
  };

  static final Map<String, int> _lcidByLocale = {
    for (final e in lcidLocales.entries)
      if (e.key != 0x040A) e.value: e.key,
  };

  /// Default region for bare language ids (`de` → `de_DE`).
  static const Map<String, String> _defaultRegion = {
    'ar': 'ar_SA', 'bg': 'bg_BG', 'ca': 'ca_ES', 'cs': 'cs_CZ', 'da': 'da_DK', 'de': 'de_DE', //
    'el': 'el_GR', 'en': 'en_US', 'es': 'es_ES', 'fi': 'fi_FI', 'fr': 'fr_FR', 'he': 'he_IL', //
    'iw': 'he_IL', 'hu': 'hu_HU', 'is': 'is_IS', 'it': 'it_IT', 'ja': 'ja_JP', 'ko': 'ko_KR', //
    'nl': 'nl_NL', 'nb': 'nb_NO', 'no': 'nb_NO', 'pl': 'pl_PL', 'pt': 'pt_BR', 'ro': 'ro_RO', //
    'ru': 'ru_RU', 'hr': 'hr_HR', 'sk': 'sk_SK', 'sq': 'sq_AL', 'sv': 'sv_SE', 'th': 'th_TH', //
    'tr': 'tr_TR', 'ur': 'ur_PK', 'id': 'id_ID', 'in': 'id_ID', 'uk': 'uk_UA', 'be': 'be_BY', //
    'sl': 'sl_SI', 'et': 'et_EE', 'lv': 'lv_LV', 'lt': 'lt_LT', 'fa': 'fa_IR', 'vi': 'vi_VN', //
    'hy': 'hy_AM', 'az': 'az_AZ', 'eu': 'eu_ES', 'mk': 'mk_MK', 'af': 'af_ZA', 'ka': 'ka_GE', //
    'hi': 'hi_IN', 'ms': 'ms_MY', 'kk': 'kk_KZ', 'sw': 'sw_KE', 'bn': 'bn_IN', 'ta': 'ta_IN', //
    'te': 'te_IN', 'mr': 'mr_IN', 'zh': 'zh_CN', 'fil': 'fil_PH', 'sr': 'sr_RS', 'ga': 'ga_IE', //
  };
}
