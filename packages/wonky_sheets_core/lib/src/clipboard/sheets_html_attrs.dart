import 'dart:convert';

import '../content/cell_content.dart';

/// Google Sheets–compatible `data-sheets-*` attribute values (03 §12.2).
abstract final class SheetsHtmlAttrs {
  /// `data-sheets-value` JSON of a typed value: `{"1":2,"2":"text"}`,
  /// `{"1":3,"3":1.5}`, `{"1":4,"4":1}`; null for empty values and errors.
  static String? encodeValue(CellValue v) => switch (v) {
    TextValue(:final text) => jsonEncode({'1': 2, '2': text}),
    NumberValue(:final number) => jsonEncode({'1': 3, '3': _num(number)}),
    BoolValue(:final value) => jsonEncode({'1': 4, '4': value ? 1 : 0}),
    _ => null,
  };

  static num _num(double d) =>
      d == d.truncateToDouble() && d.abs() < 9007199254740992 ? d.toInt() : d;

  /// Parses `data-sheets-value`; null when absent/unknown.
  static CellValue? decodeValue(String? json) {
    final m = _map(json);
    if (m == null) return null;
    final type = m['1'];
    switch (type) {
      case 2:
        final s = m['2'];
        return s is String ? TextValue(s) : null;
      case 3:
        final n = m['3'];
        return n is num && n.isFinite ? NumberValue(n.toDouble()) : null;
      case 4:
        final b = m['4'];
        return b is num ? BoolValue(b != 0) : (b is bool ? BoolValue(b) : null);
    }
    return null;
  }

  /// `data-sheets-numberformat` JSON for a pattern: `{"1":2,"2":"0.00","3":1}`
  /// (type 2 number, 3 percent, 4 currency, 5 date, 6 time, 7 date-time,
  /// 8 scientific, 1 text).
  static String encodeNumberFormat(String pattern) =>
      jsonEncode({'1': _typeOf(pattern), '2': pattern, '3': 1});

  /// The pattern of a `data-sheets-numberformat` value.
  static String? decodeNumberFormat(String? json) {
    final m = _map(json);
    final p = m?['2'];
    if (p is String && p.isNotEmpty) return p;
    if (m?['1'] == 1) return '@';
    return null;
  }

  static int _typeOf(String p) {
    if (p == '@') return 1;
    final stripped = p.replaceAll(RegExp(r'"[^"]*"|\\.'), '');
    if (stripped.contains('%')) return 3;
    if (RegExp(r'[eE][+-]').hasMatch(stripped)) return 8;
    final lower = stripped.toLowerCase();
    final hasDate =
        RegExp('[dy]').hasMatch(lower) || RegExp('m{3,}').hasMatch(lower);
    final hasTime = RegExp('[hs]').hasMatch(lower) || lower.contains('am/pm');
    if (hasDate && hasTime) return 7;
    if (hasDate) return 5;
    if (hasTime) return 6;
    if (p.contains(r'$') ||
        p.contains('€') ||
        p.contains('£') ||
        p.contains('[\$')) {
      return 4;
    }
    return 2;
  }

  /// en_US patterns of the locale-dependent presets (06 §5.1), used for the
  /// interchange attribute (other apps don't know `preset:*` ids).
  static const Map<String, String> presetPatterns = {
    'preset:accounting':
        r'_("$"* #,##0.00_);_("$"* \(#,##0.00\);_("$"* "-"??_);_(@_)',
    'preset:currency': r'"$"#,##0.00',
    'preset:currencyRounded': r'"$"#,##0',
    'preset:date': 'M/d/yyyy',
    'preset:time': 'h:mm:ss AM/PM',
    'preset:dateTime': 'M/d/yyyy H:mm:ss',
  };

  /// Pattern for interchange, or null for Automatic/unknown presets.
  static String? interchangePattern(String? numberFormat) {
    if (numberFormat == null || numberFormat == 'preset:automatic') return null;
    if (numberFormat.startsWith('preset:')) return presetPatterns[numberFormat];
    return numberFormat;
  }

  static Map<String, Object?>? _map(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final m = jsonDecode(json);
      return m is Map ? m.cast<String, Object?>() : null;
    } on FormatException {
      return null;
    }
  }
}
