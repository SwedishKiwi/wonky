import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:wonky_client/wonky_client.dart' show DriveItemKind;

/// The apps of the suite (v2: Drive, Write, Sheets, Slides; suite 01
/// §2.4). The order is the left menu's order: Drive, the landing app,
/// first, then the editors (Drive 04 §2).
enum WonkyAppKind {
  drive,
  write,
  sheets,
  slides;

  /// "Wonky Drive", "Wonky Write", … (product name, not localized).
  String get productName => switch (this) {
    drive => 'Wonky Drive',
    write => 'Wonky Write',
    sheets => 'Wonky Sheets',
    slides => 'Wonky Slides',
  };

  /// "Drive", "Write", … (the left menu's app names, not localized).
  String get shortName => switch (this) {
    drive => 'Drive',
    write => 'Write',
    sheets => 'Sheets',
    slides => 'Slides',
  };

  /// The drive item kind the app edits; null for Drive (it previews
  /// files and has no editor of its own).
  DriveItemKind? get editorKind => switch (this) {
    drive => null,
    write => DriveItemKind.document,
    sheets => DriveItemKind.spreadsheet,
    slides => DriveItemKind.presentation,
  };

  /// The web dev origin of `flutter run` (`serverpod: flutter_apps:`, suite
  /// 01 §2.4), used when `config.json` doesn't list the app.
  String get devOrigin => switch (this) {
    drive => 'http://localhost:8100/',
    write => 'http://localhost:8101/',
    sheets => 'http://localhost:8102/',
    slides => 'http://localhost:8104/',
  };

  /// The desktop URL scheme (`wonkywrite://…`; desktop is deferred in v2,
  /// suite 03 §6).
  String get urlScheme => 'wonky$name';

  /// The app that opens items of [kind]: documents → Write, spreadsheets →
  /// Sheets, presentations → Slides, files → Drive (its preview). Folders
  /// open in the current app's home, so they map to [current].
  static WonkyAppKind forItemKind(
    DriveItemKind kind, {
    WonkyAppKind current = WonkyAppKind.drive,
  }) => switch (kind) {
    DriveItemKind.folder => current,
    DriveItemKind.document => write,
    DriveItemKind.spreadsheet => sheets,
    DriveItemKind.presentation => slides,
    DriveItemKind.file => drive,
  };

  /// The in-app path of a non-folder item in the app of its kind:
  /// `/d/<uuid>` (Write), `/s/<uuid>` (Sheets), `/p/<uuid>` (Slides),
  /// `/file/<uuid>` (Drive preview); folders `/f/<uuid>` in the current
  /// app's home (the v1 `/drive/<uuid>` redirects there).
  static String itemPathFor(DriveItemKind kind, String uuid) => switch (kind) {
    DriveItemKind.folder => '/f/$uuid',
    DriveItemKind.document => '/d/$uuid',
    DriveItemKind.spreadsheet => '/s/$uuid',
    DriveItemKind.presentation => '/p/$uuid',
    DriveItemKind.file => '/file/$uuid',
  };

  /// The app whose editor routes start [path] (`/d/…` → Write, `/s/…` →
  /// Sheets, `/p/…` → Slides, `/file/…` → Drive), or null for shared
  /// routes (`/`, `/drive/…`, `/settings/…`, …).
  static WonkyAppKind? ownerOfPath(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    if (p.startsWith('/d/')) return write;
    if (p.startsWith('/s/')) return sheets;
    if (p.startsWith('/p/')) return slides;
    if (p.startsWith('/file/')) return drive;
    return null;
  }
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
/// `{"apiUrl": "...", "webUrl": "...", "apps": {"drive": "...", "write":
/// "...", "sheets": "...", "slides": "..."}, "cookieAuth": true, "google": {"clientId": "...",
/// "redirectUri": "..."}, "board": false}` (`board` only when Bugs &
/// Improvements is off).
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
    this.bugReportUrl = defaultBugReportUrl,
    this.board = true,
  });

  final String apiUrl;

  /// The web server (legal pages `/privacy`, `/terms`), ending with `/`.
  final String webUrl;

  /// Sign in with Google, when the server has a Google OAuth client.
  final GoogleSignInConfig? google;

  static const fallbackWebUrl = 'http://localhost:8082/';

  /// The repository's issue list (`wonky.help.bugReportUrl`, suite 03
  /// §3.4); *Report a bug* opens `<bugReportUrl>/new?template=…`.
  final String bugReportUrl;

  static const defaultBugReportUrl =
      'https://github.com/serverpod/wonky/issues';

  /// Whether the server runs Bugs & improvements (`board`, specs/16 §4.1;
  /// true when absent). False: `shell.board.report` falls back to the
  /// GitHub link of [bugReportUrl].
  final bool board;

  /// The URL of a page on the web server, e.g. `page('terms')`.
  String page(String path) => '$webUrl$path';

  /// Whether the API accepts cookie auth (suite 01 §2.5); set by the
  /// server's `AppConfigRoute` when `authCookie` is configured. When false
  /// (e.g. Serverpod Cloud), web uses token auth: the session is stored per
  /// origin, which `/write/` and `/sheets/` share.
  final bool cookieAuth;

  /// Base URL of each app, always ending with `/`. Parsed configs always
  /// list all four apps (missing ones fall back to their dev origin).
  final Map<WonkyAppKind, String> apps;

  static const fallbackApiUrl = 'http://localhost:8080/';

  /// Parses the config JSON. Missing apps fall back to the dev ports.
  factory AppUrls.fromJson(Map<String, Object?> json) {
    final api = json['apiUrl'] as String? ?? fallbackApiUrl;
    final rawApps = json['apps'];
    final apps = <WonkyAppKind, String>{
      for (final k in WonkyAppKind.values) k: k.devOrigin,
    };
    if (rawApps is Map) {
      for (final k in WonkyAppKind.values) {
        final v = rawApps[k.name];
        if (v is String && v.isNotEmpty) apps[k] = _slash(v);
      }
    }
    final web = json['webUrl'];
    final help = json['help'];
    final bugs = help is Map ? help['bugReportUrl'] : null;
    return AppUrls(
      apiUrl: _slash(api),
      apps: apps,
      cookieAuth: json['cookieAuth'] == true,
      webUrl: web is String && web.isNotEmpty ? _slash(web) : fallbackWebUrl,
      google: GoogleSignInConfig.fromJson(json['google']),
      bugReportUrl: bugs is String && bugs.startsWith('https://')
          ? bugs
          : defaultBugReportUrl,
      board: json['board'] != false,
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
            bugReportUrl: urls.bugReportUrl,
            board: urls.board,
          );
  }

  /// Absolute URL of [path] (e.g. `/s/<uuid>`) in [app].
  String urlFor(WonkyAppKind app, String path) {
    final base = apps[app] ?? app.devOrigin;
    final p = path.startsWith('/') ? path.substring(1) : path;
    return '$base$p';
  }
}
