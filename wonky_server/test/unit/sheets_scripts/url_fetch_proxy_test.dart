import 'dart:io';

import 'package:test/test.dart';
import 'package:wonky_server/src/sheets/scripts/url_fetch_proxy.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

/// SSRF protection of the URL fetch proxy (Sheets 09 §8.3, §21.3).
void main() {
  group('Given resolved addresses', () {
    for (final a in [
      '127.0.0.1',
      '10.0.0.5',
      '172.16.3.4',
      '192.168.1.1',
      '169.254.169.254',
      '100.64.0.1',
      '0.0.0.0',
      '224.0.0.1',
      '255.255.255.255',
      '::1',
      '::',
      'fe80::1',
      'fd00:ec2::254',
      'fc00::5',
      'ff02::1',
      '::ffff:10.0.0.1',
      '::ffff:127.0.0.1',
      '2002:0a00:0001::1',
      '64:ff9b::a00:1',
    ]) {
      test('when the address is $a then it is blocked', () {
        expect(UrlFetchProxy.isBlockedAddress(InternetAddress(a)), isTrue);
      });
    }
    for (final a in [
      '8.8.8.8',
      '1.1.1.1',
      '2606:4700:4700::1111',
      '::ffff:8.8.8.8',
    ]) {
      test('when the address is $a then it is allowed', () {
        expect(UrlFetchProxy.isBlockedAddress(InternetAddress(a)), isFalse);
      });
    }
  });

  group('Given the proxy with a fake resolver', () {
    final dns = <String, List<String>>{
      'example.com': ['93.184.216.34'],
      'internal.example.com': ['10.0.0.5'],
      'mixed.example.com': ['93.184.216.34', '192.168.0.1'],
      '2130706433': ['127.0.0.1'],
      '0177.0.0.1': ['127.0.0.1'],
    };
    UrlFetchProxy proxy({bool allowHttp = false}) => UrlFetchProxy(
      allowHttp: allowHttp,
      lookup: (host) async => [
        for (final a in dns[host] ?? const <String>[]) InternetAddress(a),
      ],
    );

    Future<String> failure(
      String url, {
      List<String> allowlist = const [],
      bool customFunction = false,
      UrlFetchProxy? p,
    }) async {
      try {
        await (p ?? proxy()).fetch(
          FetchRequestData(url: url),
          allowlist: allowlist,
          customFunction: customFunction,
        );
        return 'fetched';
      } on FetchFailure catch (e) {
        return e.message;
      }
    }

    final blocked = {
      'http://169.254.169.254/latest/meta-data': 'only https',
      'https://169.254.169.254/': 'private',
      'https://localhost/': 'not a public host',
      'https://metadata.google.internal/': 'not a public host',
      'https://internal.example.com/': 'private',
      'https://mixed.example.com/': 'private',
      'https://2130706433/': 'ambiguous numeric host',
      'https://0177.0.0.1/': 'ambiguous numeric host',
      'https://0x7f.0.0.1/': 'ambiguous numeric host',
      'https://[::1]/': 'private',
      'https://example.com:22/': 'port 22',
      'https://user:pw@example.com/': 'credentials',
      'ftp://example.com/': 'only https',
    };
    for (final e in blocked.entries) {
      test('when fetching ${e.key} then it is blocked', () async {
        expect(await failure(e.key), contains(e.value));
      });
    }

    test('when the host is not in the allowlist then it is blocked', () async {
      expect(
        await failure('https://example.com/', allowlist: ['*.other.org']),
        contains('allowlist'),
      );
    });

    test(
      'when a custom function fetches without an allowlist then it is blocked',
      () async {
        expect(
          await failure('https://example.com/', customFunction: true),
          contains('allowlist'),
        );
      },
    );

    test('when allowlist patterns are checked then subdomains match', () {
      expect(
        UrlFetchProxy.hostMatches('api.example.com', '*.example.com'),
        isTrue,
      );
      expect(UrlFetchProxy.hostMatches('example.com', '*.example.com'), isTrue);
      expect(
        UrlFetchProxy.hostMatches('evilexample.com', '*.example.com'),
        isFalse,
      );
      expect(UrlFetchProxy.hostMatches('example.com', 'example.com'), isTrue);
    });
  });

  group('Given a local test server', () {
    late HttpServer server;
    late UrlFetchProxy proxy;
    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        switch (req.uri.path) {
          case '/ok':
            req.response.headers.contentType = ContentType.json;
            req.response.headers.add('set-cookie', 'secret=1');
            req.response.write(
              '{"cookie": "${req.headers.value('cookie')}", "ua": "${req.headers.value('user-agent')}"}',
            );
          case '/redirect-private':
            req.response.statusCode = 302;
            req.response.headers.set(
              'location',
              'http://internal.test:${server.port}/ok',
            );
          case '/redirect-ok':
            req.response.statusCode = 302;
            req.response.headers.set('location', '/ok');
          case '/big':
            req.response.add(List.filled(2048, 65));
          case '/loop':
            req.response.statusCode = 302;
            req.response.headers.set('location', '/loop');
        }
        await req.response.close();
      });
      proxy = UrlFetchProxy(
        allowHttp: true,
        lookup: (host) async => host == 'public.test'
            ? [InternetAddress.loopbackIPv4]
            : [InternetAddress('10.0.0.5')],
        allowedAddressesForTests: {'127.0.0.1'},
        ports: {server.port},
        maxResponseBytes: 1024,
      );
    });
    tearDown(() => server.close(force: true));

    String url(String path) => 'http://public.test:${server.port}$path';

    test('when fetching then the body comes back without cookies', () async {
      final r = await proxy.fetch(
        FetchRequestData(url: url('/ok'), headers: const {'Cookie': 'a=b'}),
      );
      expect(r.statusCode, 200);
      expect(r.contentText, contains('"cookie": "null"'));
      expect(r.contentText, contains('WonkySheets-Script/1.0'));
      expect(r.headers.containsKey('set-cookie'), isFalse);
    });

    test(
      'when a redirect points to a private address then it is blocked',
      () async {
        expect(
          () => proxy.fetch(FetchRequestData(url: url('/redirect-private'))),
          throwsA(
            isA<FetchFailure>().having(
              (e) => e.message,
              'message',
              contains('private'),
            ),
          ),
        );
      },
    );

    test('when a redirect stays public then it is followed', () async {
      final r = await proxy.fetch(FetchRequestData(url: url('/redirect-ok')));
      expect(r.statusCode, 200);
    });

    test('when redirects loop then the proxy gives up', () async {
      expect(
        () => proxy.fetch(FetchRequestData(url: url('/loop'))),
        throwsA(
          isA<FetchFailure>().having(
            (e) => e.message,
            'message',
            contains('Too many redirects'),
          ),
        ),
      );
    });

    test(
      'when the response is too large then the download is aborted',
      () async {
        expect(
          () => proxy.fetch(FetchRequestData(url: url('/big'))),
          throwsA(
            isA<FetchFailure>().having(
              (e) => e.message,
              'message',
              contains('larger than'),
            ),
          ),
        );
      },
    );
  });
}
