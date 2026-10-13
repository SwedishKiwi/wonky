import 'dart:convert';

import 'package:flutter/services.dart';

/// The two apps of the suite.
enum WonkyAppKind {
  write,
  sheets;

  /// The other app.
  WonkyAppKind get other => this == write ? sheets : write;
}

/// The Google OAuth web client of the server (suite 04 §1.6): the client id
/// and the redirect URI of the server's `/auth/callback` page.
class GoogleSignInConfig {
  const GoogleSignInConfig({required this.clientId, required this.redirectUri});

  final String clientId;
  final String redirectUri;

  static GoogleSignInConfig? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['clientId'];
    final redirect = json['redirectUri'];
    if (id is! String || id.isEmpty) return null;
    if (redirect is! String || redirect.isEmpty) return null;
    return GoogleSignInConfig(clientId: id, redirectUri: redirect);
  }
}

/// Contents of `assets/config.json` (suite 01 §2.4):
/// `{"apiUrl": "...", "webUrl": "...", "apps": {"write": "...",
/// "sheets": "..."}, "cookieAuth": true, "google": {"clientId": "...",
/// "redirectUri": "..."}}`.
///
/// In production the server's `AppConfigRoute` replaces the bundled file at
/// runtime; in development the bundled file lists the `flutter run` origins.
class AppUrls {
  const AppUrls({
    required this.apiUrl,
    required this.apps,
    this.cookieAuth = false,
    this.webUrl = fallbackWebUrl,
    this.google,
  });

  final String apiUrl;

  /// The web server (legal pages `/privacy`, `/terms`), ending with `/`.
  final String webUrl;

  /// Sign in with Google, when the server has a Google OAuth client.
  final GoogleSignInConfig? google;

  static const fallbackWebUrl = 'http://localhost:8082/';

  /// The URL of a page on the web server, e.g. `page('terms')`.
  String page(String path) => '$webUrl$path';

  /// Whether the API accepts cookie auth (suite 01 §2.5); set by the
  /// server's `AppConfigRoute` when `authCookie` is configured. When false
  /// (e.g. Serverpod Cloud), web uses token auth: the session is stored per
  /// origin, which `/write/` and `/sheets/` share.
  final bool cookieAuth;

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
    final web = json['webUrl'];
    return AppUrls(
      apiUrl: _slash(api),
      apps: apps,
      cookieAuth: json['cookieAuth'] == true,
      webUrl: web is String && web.isNotEmpty ? _slash(web) : fallbackWebUrl,
      google: GoogleSignInConfig.fromJson(json['google']),
    );
  }

  static String _slash(String s) => s.endsWith('/') ? s : '$s/';

  /// Loads `assets/config.json`. `--dart-define=SERVER_URL=…` overrides the
  /// API URL (as in the template app).
  static Future<AppUrls> load({AssetBundle? bundle}) async {
    const override = String.fromEnvironment('SERVER_URL');
    Map<String, Object?> json = const {};
    try {
      final text = await (bundle ?? rootBundle).loadString(
        'assets/config.json',
      );
      json = (jsonDecode(text) as Map).cast<String, Object?>();
    } catch (_) {
      // Fall back to defaults below.
    }
    final urls = AppUrls.fromJson(json);
    return override.isEmpty
        ? urls
        : AppUrls(
            apiUrl: _slash(override),
            apps: urls.apps,
            cookieAuth: urls.cookieAuth,
            webUrl: urls.webUrl,
            google: urls.google,
          );
  }

  /// Absolute URL of [path] (e.g. `/s/<uuid>`) in [app].
  String urlFor(WonkyAppKind app, String path) {
    final base = apps[app]!;
    final p = path.startsWith('/') ? path.substring(1) : path;
    return '$base$p';
  }
}
