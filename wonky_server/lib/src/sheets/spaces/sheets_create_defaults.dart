import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../../generated/protocol.dart';

/// The Settings › Sheets defaults of new spreadsheets (04 §11.24,
/// `UserPreferences.sheetsDefaults`) for spreadsheets the server creates
/// (blank and built-in template spreadsheets without a reserved space,
/// imports, MCP). The keys are the app's `SheetsUserDefaults` keys.
class SheetsCreateDefaults {
  const SheetsCreateDefaults({
    this.locale,
    this.timeZone,
    this.fontFamily,
    this.fontSize,
  });

  /// `defaultLocale` (null = `en_US`).
  final String? locale;

  /// `defaultTimeZone` (null = UTC).
  final String? timeZone;

  /// `defaultFontFamily` (null = the theme's, Inter).
  final String? fontFamily;

  /// `defaultFontSize` (null = 10).
  final double? fontSize;

  static const none = SheetsCreateDefaults();

  /// Decodes the `sheetsDefaults` JSON (invalid JSON or values are ignored).
  static SheetsCreateDefaults decode(String? json) {
    if (json == null || json.isEmpty) return none;
    Object? m;
    try {
      m = jsonDecode(json);
    } on FormatException {
      return none;
    }
    if (m is! Map) return none;
    final map = m;
    String? str(String k) {
      final v = map[k];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final size = map['defaultFontSize'];
    return SheetsCreateDefaults(
      locale: str('defaultLocale'),
      timeZone: str('defaultTimeZone'),
      fontFamily: str('defaultFontFamily'),
      fontSize: size is num && size >= 6 && size <= 400
          ? size.toDouble()
          : null,
    );
  }

  /// The defaults of [userId] (UserProfile id).
  static Future<SheetsCreateDefaults> of(Session session, int userId) async {
    final prefs = await UserPreferences.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(userId),
    );
    return decode(prefs?.sheetsDefaults);
  }
}
