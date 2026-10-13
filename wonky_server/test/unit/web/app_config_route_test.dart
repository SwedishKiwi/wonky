import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/config/wonky_config.dart';
import 'package:wonky_server/src/web/routes/app_config_route.dart';

void main() {
  ServerConfig server(String host) => ServerConfig(
    port: 8080,
    publicScheme: 'https',
    publicHost: host,
    publicPort: 443,
  );

  group('Given production on Serverpod Cloud with the wonky.work domain', () {
    test(
      'when building config.json then the apps and pages are on wonky.work '
      'and the Google redirect is its /auth/callback',
      () {
        final route = AppConfigRoute(
          apiConfig: server('wonkywork.api.serverpod.space'),
          webOrigin: Uri.parse('https://wonky.work'),
          cookieAuth: false,
          googleClientId: 'abc.apps.googleusercontent.com',
        );

        final json = jsonDecode(route.widget.render()) as Map<String, dynamic>;

        expect(json, {
          'apiUrl': 'https://wonkywork.api.serverpod.space',
          'webUrl': 'https://wonky.work/',
          'apps': {
            'write': 'https://wonky.work/write/',
            'sheets': 'https://wonky.work/sheets/',
          },
          'cookieAuth': false,
          'google': {
            'clientId': 'abc.apps.googleusercontent.com',
            'redirectUri': 'https://wonky.work/auth/callback',
          },
        });
      },
    );

    test('when Google sign-in is not configured then config.json has no '
        'google entry', () {
      final route = AppConfigRoute(
        apiConfig: server('api.example.com'),
        webOrigin: Uri.parse('https://app.example.com'),
        cookieAuth: true,
      );

      final json = jsonDecode(route.widget.render()) as Map<String, dynamic>;

      expect(json['cookieAuth'], isTrue);
      expect(json.containsKey('google'), isFalse);
    });
  });

  group('Given the public web origin', () {
    final config = ServerpodConfig(
      apiServer: server('api.example.com'),
      webServer: server('wonkywork.serverpod.space'),
    );

    test('when running in production then it defaults to wonky.work', () {
      final c = WonkyConfig.fromMap(
        const {},
        defaultPublicWebUrl: WonkyConfig.productionWebUrl,
      );

      expect(c.webOrigin(config).toString(), 'https://wonky.work/');
    });

    test('when WONKY_PUBLIC_WEB_URL is set then it wins', () {
      final c = WonkyConfig.fromMap(
        const {},
        environment: const {
          'WONKY_PUBLIC_WEB_URL': 'https://staging.wonky.work',
        },
        defaultPublicWebUrl: WonkyConfig.productionWebUrl,
      );

      expect(c.webOrigin(config).toString(), 'https://staging.wonky.work/');
    });

    test('when nothing is set then the web server public URL is used', () {
      final c = WonkyConfig.fromMap(const {});

      expect(
        c.webOrigin(config).toString(),
        'https://wonkywork.serverpod.space/',
      );
    });
  });
}
