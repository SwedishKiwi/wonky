import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_mcp_stdio/wonky_mcp_stdio.dart';

import 'support/fake_mcp_server.dart';

/// Runs a [StdioHttpProxy] against a [FakeMcpServer] with in-memory stdio.
class ProxyHarness {
  ProxyHarness._(this.server, this.proxy, this._input, this._output) {
    _output.stream.listen((bytes) {
      final chunk = utf8.decode(bytes);
      raw.write(chunk);
      _pending += chunk;
      while (_pending.contains('\n')) {
        final end = _pending.indexOf('\n');
        messages.add(jsonDecode(_pending.substring(0, end)) as Map);
        _pending = _pending.substring(end + 1);
      }
      _changes.add(null);
    });
    exitCode = proxy.run();
  }

  static Future<ProxyHarness> start({
    String token = FakeMcpServer.validToken,
    bool streamNotifications = false,
    bool expireSessions = false,
  }) async {
    final server = await FakeMcpServer.start(
      streamNotifications: streamNotifications,
      expireSessions: expireSessions,
    );
    final input = StreamController<List<int>>();
    final output = StreamController<List<int>>();
    final proxy = StdioHttpProxy(
      url: server.url,
      token: token,
      input: input.stream,
      output: output.sink,
      log: StringBuffer(),
      reconnectDelay: Duration.zero,
    );
    return ProxyHarness._(server, proxy, input, output);
  }

  final FakeMcpServer server;
  final StdioHttpProxy proxy;
  final StreamController<List<int>> _input;
  final StreamController<List<int>> _output;
  late final Future<int> exitCode;

  /// Everything written to stdout.
  final StringBuffer raw = StringBuffer();

  /// Every stdout line, decoded.
  final List<Map<dynamic, dynamic>> messages = [];

  final StreamController<void> _changes = StreamController<void>.broadcast();
  String _pending = '';

  void sendLine(String line) => _input.add(utf8.encode('$line\n'));

  void send(Map<String, Object?> message) => sendLine(jsonEncode(message));

  /// Waits until a stdout message matches [test] and returns it.
  Future<Map<dynamic, dynamic>> waitFor(
    bool Function(Map<dynamic, dynamic>) test,
  ) async {
    while (true) {
      for (final message in messages) {
        if (test(message)) return message;
      }
      await _changes.stream.first;
    }
  }

  Future<Map<dynamic, dynamic>> waitForId(Object id) =>
      waitFor((m) => m['id'] == id);

  Future<Map<dynamic, dynamic>> initialize() {
    send(initializeRequest);
    return waitForId(1);
  }

  /// Closes stdin and waits for the proxy to exit.
  Future<int> closeInput() async {
    if (!_input.isClosed) await _input.close();
    return exitCode;
  }

  Future<void> dispose() async {
    await closeInput();
    await server.close();
  }
}

const initializeRequest = {
  'jsonrpc': '2.0',
  'id': 1,
  'method': 'initialize',
  'params': {
    'protocolVersion': FakeMcpServer.protocolVersion,
    'capabilities': <String, Object?>{},
    'clientInfo': {'name': 'test', 'version': '1.0.0'},
  },
};

const initializedNotification = {
  'jsonrpc': '2.0',
  'method': 'notifications/initialized',
};

Map<String, Object?> ping(int id) => {
  'jsonrpc': '2.0',
  'id': id,
  'method': 'ping',
};

Map<String, Object?> toolCall(int id, String name) => {
  'jsonrpc': '2.0',
  'id': id,
  'method': 'tools/call',
  'params': {'name': name, 'arguments': <String, Object?>{}},
};

Map<String, Object?> toolResult(int id, String text) => {
  'jsonrpc': '2.0',
  'id': id,
  'result': {
    'content': [
      {'type': 'text', 'text': text},
    ],
  },
};

void main() {
  group('Given a proxy for a server that accepts the token', () {
    late ProxyHarness harness;
    setUp(() async => harness = await ProxyHarness.start());
    tearDown(() => harness.dispose());

    test('when initializing then the JSON response is written as one line '
        'and the session is established', () async {
      await harness.initialize();
      await harness.closeInput();

      expect(
        harness.raw.toString(),
        equals(
          '${jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'result': {
              'protocolVersion': FakeMcpServer.protocolVersion,
              'capabilities': <String, Object?>{},
              'serverInfo': {'name': 'fake', 'version': '1.0.0'},
            },
          })}\n',
        ),
      );
      expect(harness.proxy.sessionId, equals(FakeMcpServer.sessionId));
      expect(
        harness.proxy.protocolVersion,
        equals(FakeMcpServer.protocolVersion),
      );
    });

    test(
      'when initializing then the request is sent with the token, '
      'content type and both accepted types, and the body verbatim',
      () async {
        await harness.initialize();

        final request = harness.server.post('initialize');
        expect(request.headers['authorization'], 'Bearer wkpat_valid');
        expect(request.headers['content-type'], startsWith('application/json'));
        expect(
          request.headers['accept'],
          equals('application/json, text/event-stream'),
        );
        expect(request.headers.containsKey('mcp-session-id'), isFalse);
        expect(request.body, equals(initializeRequest));
      },
    );

    test('when sending a request after initialize then the session id and '
        'protocol version headers are sent', () async {
      await harness.initialize();

      harness.send(ping(2));
      await harness.waitForId(2);

      final request = harness.server.post('ping');
      expect(request.headers['mcp-session-id'], FakeMcpServer.sessionId);
      expect(
        request.headers['mcp-protocol-version'],
        FakeMcpServer.protocolVersion,
      );
    });

    test('when a tool call is answered with SSE then each event is written '
        'as its own line in order', () async {
      await harness.initialize();

      harness.send(toolCall(3, 'echo'));
      await harness.waitForId(3);

      expect(
        harness.messages.skip(1),
        equals([
          {
            'jsonrpc': '2.0',
            'method': 'notifications/progress',
            'params': {'progressToken': 't', 'progress': 1},
          },
          toolResult(3, 'echoed'),
        ]),
      );
    });

    test('when a notification is answered with 202 then nothing is '
        'written', () async {
      await harness.initialize();

      harness.send(initializedNotification);
      await harness.closeInput();

      expect(harness.server.post('notifications/initialized'), isNotNull);
      expect(harness.messages, hasLength(1));
    });

    test('when a slow tool call is in flight then a later ping is answered '
        'first', () async {
      await harness.initialize();

      harness.send(toolCall(5, 'slow'));
      harness.send(ping(6));
      await harness.waitForId(5);

      expect(
        harness.messages.skip(1),
        equals([
          {'jsonrpc': '2.0', 'id': 6, 'result': <String, Object?>{}},
          toolResult(5, 'slow done'),
        ]),
      );
    });

    test('when a line is malformed JSON then a parse error is written and '
        'blank lines are skipped', () async {
      harness.sendLine('');
      harness.sendLine('{"jsonrpc": "2.0", "id": 1,');
      await harness.closeInput();

      expect(
        harness.raw.toString(),
        equals(
          '{"jsonrpc":"2.0","id":null,"error":'
          '{"code":-32700,"message":"Parse error"}}\n',
        ),
      );
      expect(harness.server.requests, isEmpty);
    });

    test('when stdin closes then a DELETE with the session id is sent and '
        'the exit code is 0', () async {
      await harness.initialize();

      final exitCode = await harness.closeInput();

      expect(exitCode, equals(0));
      final last = harness.server.requests.last;
      expect(last.method, equals('DELETE'));
      expect(last.headers['mcp-session-id'], FakeMcpServer.sessionId);
      expect(last.headers['authorization'], 'Bearer wkpat_valid');
    });

    test(
      'when stdin closes before initialize then no DELETE is sent',
      () async {
        final exitCode = await harness.closeInput();

        expect(exitCode, equals(0));
        expect(harness.server.requests, isEmpty);
      },
    );
  });

  group('Given a proxy with a token the server rejects', () {
    late ProxyHarness harness;
    setUp(() async => harness = await ProxyHarness.start(token: 'wkpat_bad'));
    tearDown(() => harness.dispose());

    test('when sending a request then an unauthorized JSON-RPC error with '
        'the request id is written', () async {
      final response = await harness.initialize();

      expect(response['id'], equals(1));
      expect(
        response['error'],
        isA<Map<dynamic, dynamic>>()
            .having((e) => e['code'], 'code', proxyUnauthorizedError)
            .having(
              (e) => e['message'],
              'message',
              allOf(contains('Unauthorized'), contains('401')),
            ),
      );
    });

    test('when sending a notification then nothing is written', () async {
      harness.send(initializedNotification);
      await harness.closeInput();

      expect(harness.messages, isEmpty);
    });
  });

  group('Given a server that streams server-initiated messages', () {
    late ProxyHarness harness;
    setUp(
      () async => harness = await ProxyHarness.start(streamNotifications: true),
    );
    tearDown(() => harness.dispose());

    test('when the session is initialized then the GET stream messages are '
        'forwarded to stdout', () async {
      await harness.initialize();

      harness.send(initializedNotification);
      final message = await harness.waitFor(
        (m) => m['method'] == 'notifications/message',
      );

      expect(message['params'], equals({'level': 'info', 'data': 'hello'}));
      final get = harness.server.requests.firstWhere((r) => r.method == 'GET');
      expect(get.headers['accept'], equals('text/event-stream'));
      expect(get.headers['mcp-session-id'], FakeMcpServer.sessionId);
      expect(get.headers['authorization'], 'Bearer wkpat_valid');
    });
  });

  group('Given a server that expires the session', () {
    late ProxyHarness harness;
    setUp(() async => harness = await ProxyHarness.start(expireSessions: true));
    tearDown(() => harness.dispose());

    test('when a request gets 404 then a session expired error is written '
        'and later requests are sent without the session id', () async {
      await harness.initialize();

      harness.send(ping(2));
      final expired = await harness.waitForId(2);
      harness.send(ping(3));
      await harness.waitForId(3);
      await harness.closeInput();

      expect(
        expired['error'],
        isA<Map<dynamic, dynamic>>()
            .having((e) => e['code'], 'code', proxyTransportError)
            .having((e) => e['message'], 'message', contains('404')),
      );
      final pings = harness.server.requests.where((r) => r.rpcMethod == 'ping');
      expect(
        pings.map((r) => r.headers['mcp-session-id']),
        equals([FakeMcpServer.sessionId, null]),
      );
      expect(
        harness.server.requests.map((r) => r.method),
        isNot(contains('DELETE')),
      );
    });
  });
}
