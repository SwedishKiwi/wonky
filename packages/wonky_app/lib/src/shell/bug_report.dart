import 'package:flutter/foundation.dart';

import '../bootstrap/app_urls.dart';

/// The prefilled GitHub "new issue" link of *Report a bug* (suite 03 §3.4,
/// v2 review Q8): the issue form `.github/ISSUE_TEMPLATE/bug_report.yml`
/// with the app, the build version, the platform and the browser family —
/// **never** user content, ids, emails or document URLs.
abstract final class BugReportLink {
  /// The issue list of the repository (`wonky.help.bugReportUrl`).
  static const defaultIssuesUrl = 'https://github.com/serverpod/wonky/issues';

  /// Longer links fall back to the issue list.
  static const maxLength = 2000;

  /// The issue form's file name in `.github/ISSUE_TEMPLATE/`.
  static const template = 'bug_report.yml';

  /// `{issuesUrl}/new?template=bug_report.yml&app=write&version=2.0.3`
  /// `&platform=web&browser=Chrome%20131`; [issuesUrl] itself when the
  /// link would be longer than [maxLength].
  static String build({
    String issuesUrl = defaultIssuesUrl,
    required WonkyAppKind app,
    required String version,
    required String platform,
    String? browser,
  }) {
    final base = issuesUrl.endsWith('/')
        ? issuesUrl.substring(0, issuesUrl.length - 1)
        : issuesUrl;
    final query = <String, String>{
      'template': template,
      'app': app.name,
      'version': version,
      'platform': platform,
      if (browser != null && browser.isNotEmpty) 'browser': browser,
    };
    final q = [
      for (final e in query.entries)
        '${Uri.encodeQueryComponent(e.key)}='
            '${Uri.encodeComponent(e.value)}',
    ].join('&');
    final url = '$base/new?$q';
    return url.length > maxLength ? base : url;
  }

  /// The platform field: `web`, `macos`, `windows`, `linux`, …
  static String get currentPlatform =>
      kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
}

/// The browser family and major version of a user agent ("Chrome 131",
/// "Firefox 132", "Safari 18", "Edge 131"), or null when unknown. Only the
/// family and the major version leave the device.
String? browserFromUserAgent(String userAgent) {
  String? major(String token) {
    final m = RegExp('$token/(\\d+)').firstMatch(userAgent);
    return m?.group(1);
  }

  for (final (token, name) in const [
    ('Edg', 'Edge'),
    ('EdgA', 'Edge'),
    ('OPR', 'Opera'),
    ('Firefox', 'Firefox'),
    ('FxiOS', 'Firefox'),
    ('CriOS', 'Chrome'),
    ('Chrome', 'Chrome'),
  ]) {
    final v = major(token);
    if (v != null) return '$name $v';
  }
  if (userAgent.contains('Safari/')) {
    final v = major('Version');
    return v == null ? 'Safari' : 'Safari $v';
  }
  return null;
}
