import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/web/routes/app_config_route.dart';

void main() {
  ServerConfig server(String host) => ServerConfig(
    port: 8080,
    publicScheme: 'https',
    publicHost: host,
    publicPort: 443,
  );

  group('Given a server deployed on separate API and web hosts', () {
    test(
      'when building config.json then it lists the API and both app URLs',
      () {
        final route = AppConfigRoute(
          apiConfig: server('wonkywork.api.serverpod.space'),
          webConfig: server('wonkywork.serverpod.space'),
          cookieAuth: false,
        );

        final json = jsonDecode(route.widget.render()) as Map<String, dynamic>;

        expect(json, {
          'apiUrl': 'https://wonkywork.api.serverpod.space',
          'apps': {
            'write': 'https://wonkywork.serverpod.space/write/',
            'sheets': 'https://wonkywork.serverpod.space/sheets/',
          },
          'cookieAuth': false,
        });
      },
    );

    test(
      'when the server is configured for cookie auth then config.json says so',
      () {
        final route = AppConfigRoute(
          apiConfig: server('api.example.com'),
          webConfig: server('app.example.com'),
          cookieAuth: true,
        );

        final json = jsonDecode(route.widget.render()) as Map<String, dynamic>;

        expect(json['cookieAuth'], isTrue);
      },
    );
  });
}
