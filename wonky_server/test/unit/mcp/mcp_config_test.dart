import 'package:test/test.dart';
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
}
