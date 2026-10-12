import 'dart:convert';

import 'package:flutter/services.dart';

/// The two apps of the suite.
enum WonkyAppKind {
  write,
  sheets;

  /// The other app.
  WonkyAppKind get other => this == write ? sheets : write;
}

/// Contents of `assets/config.json` (suite 01 §2.4):
/// `{"apiUrl": "...", "apps": {"write": "...", "sheets": "..."}}`.
///
/// In production the server's `AppConfigRoute` replaces the bundled file at
/// runtime; in development the bundled file lists the `flutter run` origins.
class AppUrls {
  const AppUrls({required this.apiUrl, required this.apps});

  final String apiUrl;

  /// Base URL of each app, always ending with `/`.
  final Map<WonkyAppKind, String> apps;

  static const fallbackApiUrl = 'http://localhost:8080/';

  /// Parses the config JSON. Missing apps fall back to the dev ports.
  factory AppUrls.fromJson(Map<String, Object?> json) {
    final api = json['apiUrl'] as String? ?? fallbackApiUrl;
    final rawApps = json['apps'];
    final apps = <WonkyAppKind, String>{
      WonkyAppKind.write: 'http://localhost:8101/',
      WonkyAppKind.sheets: 'http://localhost:8102/',
    };
    if (rawApps is Map) {
      for (final k in WonkyAppKind.values) {
        final v = rawApps[k.name];
        if (v is String && v.isNotEmpty) apps[k] = _slash(v);
      }
    }
    return AppUrls(apiUrl: _slash(api), apps: apps);
  }

  static String _slash(String s) => s.endsWith('/') ? s : '$s/';

  /// Loads `assets/config.json`. `--dart-define=SERVER_URL=…` overrides the
  /// API URL (as in the template app).
  static Future<AppUrls> load({AssetBundle? bundle}) async {
    const override = String.fromEnvironment('SERVER_URL');
    Map<String, Object?> json = const {};
    try {
      final text = await (bundle ?? rootBundle).loadString('assets/config.json');
      json = (jsonDecode(text) as Map).cast<String, Object?>();
    } catch (_) {
      // Fall back to defaults below.
    }
    final urls = AppUrls.fromJson(json);
    return override.isEmpty
        ? urls
        : AppUrls(apiUrl: _slash(override), apps: urls.apps);
  }

  /// Absolute URL of [path] (e.g. `/s/<uuid>`) in [app].
  String urlFor(WonkyAppKind app, String path) {
    final base = apps[app]!;
    final p = path.startsWith('/') ? path.substring(1) : path;
    return '$base$p';
  }
}
