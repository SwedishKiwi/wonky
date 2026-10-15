import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/web/routes/root_redirect_route.dart';

/// The redirect never reads the session.
class _NoSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('RootRedirectRoute must not use the session');
}

void main() {
  group('Given the site root served by RootRedirectRoute', () {
    late RelicServer server;
    late HttpClient client;

    setUpAll(() async {
      final route = RootRedirectRoute();
      final app = RelicApp()
        ..get('/', (req) => route.handleCall(_NoSession(), req));
      server = await app.serve(port: 0);
      client = HttpClient();
    });

    tearDownAll(() async {
      client.close(force: true);
      await server.close();
    });

    Future<HttpClientResponse> getRoot({String? cookie}) async {
      final request = await client.get('localhost', server.port, '/');
      request.followRedirects = false;
      if (cookie != null) request.headers.set(HttpHeaders.cookieHeader, cookie);
      final response = await request.close();
      await response.drain<void>();
      return response;
    }

    test('when GET / without cookies then it answers 302 to /write/', () async {
      final response = await getRoot();

      expect(response.statusCode, HttpStatus.found);
      expect(response.headers.value(HttpHeaders.locationHeader), '/write/');
    });

    test(
      'when GET / with the v1 wonky_last_app=sheets cookie then it still '
      'answers 302 to /write/',
      () async {
        final response = await getRoot(cookie: 'wonky_last_app=sheets');

        expect(response.statusCode, HttpStatus.found);
        expect(response.headers.value(HttpHeaders.locationHeader), '/write/');
      },
    );
  });
}
