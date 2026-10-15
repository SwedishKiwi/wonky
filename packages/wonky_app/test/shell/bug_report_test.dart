import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';

void main() {
  group('Given the bug report link builder', () {
    test('when building then it prefills app, version, platform and browser '
        'only', () {
      final url = BugReportLink.build(
        app: WonkyAppKind.write,
        version: '2.0.3',
        platform: 'web',
        browser: 'Chrome 131',
      );

      expect(
        url,
        'https://github.com/serverpod/wonky/issues/new?template=bug_report.yml'
        '&app=write&version=2.0.3&platform=web&browser=Chrome%20131',
      );
      final q = Uri.parse(url).queryParameters;
      expect(q.keys, {'template', 'app', 'version', 'platform', 'browser'});
      expect(q['browser'], 'Chrome 131');
    });

    test('when the issues URL ends with a slash or the browser is unknown '
        'then the link stays well-formed', () {
      final url = BugReportLink.build(
        issuesUrl: 'https://example.test/org/repo/issues/',
        app: WonkyAppKind.drive,
        version: '2.0.0',
        platform: 'macos',
      );

      expect(
        url,
        'https://example.test/org/repo/issues/new?template=bug_report.yml'
        '&app=drive&version=2.0.0&platform=macos',
      );
    });

    test('when the link would exceed 2,000 characters then it falls back to '
        'the issue list', () {
      final url = BugReportLink.build(
        app: WonkyAppKind.sheets,
        version: 'x' * 2000,
        platform: 'web',
      );

      expect(url, BugReportLink.defaultIssuesUrl);
    });

    test('when building for every app then no ids, emails or document URLs '
        'are included', () {
      for (final app in WonkyAppKind.values) {
        final url = BugReportLink.build(
          app: app,
          version: '2.0.0',
          platform: 'web',
          browser: 'Firefox 132',
        );
        expect(url, isNot(contains('@')));
        expect(url, isNot(contains('/d/')));
        expect(url, isNot(contains('/s/')));
        expect(url.length, lessThanOrEqualTo(BugReportLink.maxLength));
        expect(Uri.parse(url).queryParameters['app'], app.name);
      }
    });
  });

  group('Given a user agent', () {
    final vectors = {
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36':
          'Chrome 131',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, '
              'like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.2903.70':
          'Edge 131',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 14.7; rv:132.0) Gecko/20100101 '
              'Firefox/132.0':
          'Firefox 132',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
              '(KHTML, like Gecko) Version/18.1 Safari/605.1.15':
          'Safari 18',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, '
              'like Gecko) Chrome/130.0.0.0 Safari/537.36 OPR/115.0.0.0':
          'Opera 115',
    };
    for (final MapEntry(key: ua, value: expected) in vectors.entries) {
      test('when parsing "$expected" then only the family and the major '
          'version are kept', () {
        expect(browserFromUserAgent(ua), expected);
      });
    }

    test('when the user agent is unknown then there is no browser', () {
      expect(browserFromUserAgent('curl/8.0'), isNull);
    });
  });

  group('Given config.json', () {
    test('when it has help.bugReportUrl then that issue list is used', () {
      final urls = AppUrls.fromJson({
        'help': {'bugReportUrl': 'https://github.com/acme/wonky/issues'},
      });
      expect(urls.bugReportUrl, 'https://github.com/acme/wonky/issues');
    });

    test('when it has no or an unsafe help URL then the default is used', () {
      expect(AppUrls.fromJson({}).bugReportUrl, AppUrls.defaultBugReportUrl);
      expect(
        AppUrls.fromJson({
          'help': {'bugReportUrl': 'javascript:alert(1)'},
        }).bugReportUrl,
        AppUrls.defaultBugReportUrl,
      );
    });
  });
}
