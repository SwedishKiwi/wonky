import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/config/wonky_config.dart';
import 'package:wonky_server/src/platform/mcp/mcp_config.dart';

void main() {
  group('Given an MCP config with allowed hosts and origins', () {
    final config = McpConfig(
      allowedHosts: {'localhost', 'wonky.example'},
      allowedOrigins: {'https://wonky.example'},
    );

    for (final (host, ok) in [
      ('localhost:8082', true),
      ('wonky.example', true),
      ('WONKY.example:443', true),
      ('evil.example', false),
      ('', false),
    ]) {
      test(
        'when the host is "$host" then it is ${ok ? 'allowed' : 'refused'}',
        () {
          expect(config.hostAllowed(host), ok);
        },
      );
    }

    for (final (origin, ok) in [
      (null, true),
      ('https://wonky.example', true),
      ('https://wonky.example/', true),
      ('http://wonky.example', false),
      ('https://evil.example', false),
    ]) {
      test(
        'when the origin is $origin then it is ${ok ? 'allowed' : 'refused'}',
        () {
          expect(config.originAllowed(origin), ok);
        },
      );
    }
  });

  group('Given production on Serverpod Cloud with custom domains', () {
    ServerConfig server(String host) => ServerConfig(
      port: 8080,
      publicScheme: 'https',
      publicHost: host,
      publicPort: 443,
    );
    final config = ServerpodConfig(
      apiServer: server('wonkywork.api.serverpod.space'),
      webServer: server('wonkywork.serverpod.space'),
    );
    final wonky = WonkyConfig.fromMap(
      const {},
      defaultPublicWebUrl: WonkyConfig.productionWebUrl,
      defaultPublicApiUrl: WonkyConfig.productionApiUrl,
    );

    test('when no hosts are configured then /mcp answers on wonky.work, '
        'api.wonky.work and the generated hosts', () {
      final mcp = McpConfig(
        allowedHosts: McpConfig.defaultAllowedHosts(config, wonky),
      );

      for (final host in [
        'wonky.work',
        'api.wonky.work',
        'wonkywork.serverpod.space',
        'wonkywork.api.serverpod.space',
        'localhost:8082',
      ]) {
        expect(mcp.hostAllowed(host), isTrue, reason: host);
      }
      expect(mcp.hostAllowed('evil.example'), isFalse);
    });
  });
}
