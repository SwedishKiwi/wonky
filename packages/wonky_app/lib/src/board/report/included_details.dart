import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart' show ShadTheme;

import '../../bootstrap/app_urls.dart';
import '../../shell/bug_report.dart';
import '../../shell/overlays/shell_overlays.dart' show clientVersion;
import '../../shell/shell_services.dart';
import 'board_report_services.dart';

/// The details a bug report includes (specs/16 §4.2.4), public with the
/// post (`contextJson`): app and version, platform and browser family,
/// theme, locale, window size and the route with ids replaced by `:id`;
/// the last error only when opted in.
@immutable
class BoardIncludedDetails {
  const BoardIncludedDetails({
    required this.app,
    required this.version,
    required this.platform,
    this.browser,
    required this.dark,
    required this.locale,
    required this.window,
    required this.route,
  });

  /// Collects the details of [s] as [context] shows them.
  factory BoardIncludedDetails.collect(ShellServices s, BuildContext context) {
    final size = MediaQuery.maybeSizeOf(context) ?? Size.zero;
    String location;
    try {
      location = s.router.state.uri.toString();
    } catch (_) {
      try {
        location = s.router.routeInformationProvider.value.uri.toString();
      } catch (_) {
        location = '/';
      }
    }
    return BoardIncludedDetails(
      app: s.config.app,
      version: clientVersion,
      platform: BugReportLink.currentPlatform,
      browser: s.crossApp.browserLabel(),
      dark: ShadTheme.maybeOf(context)?.brightness == Brightness.dark,
      locale: Localizations.maybeLocaleOf(context)?.toLanguageTag() ?? 'en',
      window: '${size.width.round()}×${size.height.round()}',
      route: stripRouteIds(location),
    );
  }

  final WonkyAppKind app;
  final String version;
  final String platform;
  final String? browser;
  final bool dark;
  final String locale;
  final String window;
  final String route;

  /// `{app, version, platform, browser?, theme, locale, window, route,
  /// error?}`; [error] is added when the user opted in.
  Map<String, Object?> toJson({BoardLastError? error}) => {
    'app': app.name,
    'version': version,
    'platform': platform,
    'browser': ?browser,
    'theme': dark ? 'dark' : 'light',
    'locale': locale,
    'window': window,
    'route': route,
    if (error != null) 'error': error.toJson(),
  };

  String encode({BoardLastError? error}) => jsonEncode(toJson(error: error));

  /// "Sheets 2.3.1 · web · Chrome 131 · dark theme · en · 1440×900 · /s/:id"
  /// with [themeLabel] the localized "dark theme" / "light theme".
  String summary(String themeLabel) => [
    '${app.shortName} $version',
    platform,
    ?browser,
    themeLabel,
    locale,
    window,
    route,
  ].join(' · ');
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _number = RegExp(r'^\d+$');
final _token = RegExp(r'^[A-Za-z0-9_-]{16,}$');

/// [location]'s path with ids replaced by `:id` (UUIDs, numbers and long
/// opaque tokens) and the query string and fragment dropped (specs/16
/// §4.2.4): `/s/0190…?range=A1` → `/s/:id`.
String stripRouteIds(String location) {
  Uri uri;
  try {
    uri = Uri.parse(location);
  } on FormatException {
    return '/';
  }
  final segments = [
    for (final seg in uri.pathSegments)
      if (_uuid.hasMatch(seg) ||
          _number.hasMatch(seg) ||
          (_token.hasMatch(seg) && seg.contains(RegExp(r'\d'))))
        ':id'
      else
        seg,
  ];
  return '/${segments.join('/')}';
}
