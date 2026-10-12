import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A request received by [FakeMcpServer].
class RecordedRequest {
  RecordedRequest(this.method, this.headers, this.body);

  /// The HTTP method.
  final String method;

  /// Request headers, names lower-cased, values joined with `,`.
  final Map<String, String> headers;

  /// The decoded JSON body, or `null` when empty.
  final Object? body;

  /// The JSON-RPC method of a single-message body.
  Object? get rpcMethod => body is Map ? (body as Map)['method'] : null;
}

/// An in-process fake MCP Streamable HTTP endpoint on the loopback interface.
///
/// - Rejects every request without `Authorization: Bearer <validToken>` with
///   401 and a plain text body.
/// - `initialize` → JSON result with an `mcp-session-id` header.
/// - Notifications → 202.
/// - `ping` → JSON result; releases a pending `slow` tool call afterwards.
/// - `tools/call` `echo` → SSE with a progress notification and the result
///   (the result spread over several `data:` lines).
/// - `tools/call` `slow` → JSON result once a `ping` has been answered.
/// - `GET` → 405, or (with [streamNotifications]) one SSE stream with a
///   `notifications/message` on the first GET.
/// - `DELETE` → 200.
/// - With [expireSessions], every POST carrying a session id → 404.
class FakeMcpServer {
  FakeMcpServer._(
    this._server, {
    required this.streamNotifications,
    required this.expireSessions,
  }) {
    _server.listen(_handle);
  }

  static const validToken = 'wkpat_valid';
  static const sessionId = 'session-1';
  static const protocolVersion = '2025-11-25';

  static Future<FakeMcpServer> start({
    bool streamNotifications = false,
    bool expireSessions = false,
  }) async => FakeMcpServer._(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    streamNotifications: streamNotifications,
    expireSessions: expireSessions,
  );

  final HttpServer _server;
  final bool streamNotifications;
  final bool expireSessions;

  final List<RecordedRequest> requests = [];
  final Completer<void> _pingAnswered = Completer<void>();
  var _getCount = 0;

  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}/mcp');

  /// The recorded POST whose JSON-RPC method is [method].
  RecordedRequest post(String method) =>
      requests.singleWhere((r) => r.method == 'POST' && r.rpcMethod == method);

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final headers = <String, String>{};
    request.headers.forEach((name, values) {
      headers[name.toLowerCase()] = values.join(',');
    });
    final text = await utf8.decoder.bind(request).join();
    final body = text.isEmpty ? null : jsonDecode(text);
    requests.add(RecordedRequest(request.method, headers, body));

    final response = request.response;
    if (headers['authorization'] != 'Bearer $validToken') {
      response
        ..statusCode = HttpStatus.unauthorized
        ..write('invalid token');
      await response.close();
      return;
    }

    switch (request.method) {
      case 'GET':
        await _handleGet(response);
      case 'DELETE':
        await response.close();
      case 'POST':
        await _handlePost(response, headers, body as Map<String, Object?>);
      default:
        response.statusCode = HttpStatus.methodNotAllowed;
        await response.close();
    }
  }

  Future<void> _handleGet(HttpResponse response) async {
    _getCount++;
    if (!streamNotifications || _getCount > 1) {
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }
    response.headers.contentType = ContentType('text', 'event-stream');
    response.write(
      'data: ${jsonEncode({
        'jsonrpc': '2.0',
        'method': 'notifications/message',
        'params': {'level': 'info', 'data': 'hello'},
      })}\n\n',
    );
    await response.close();
  }

  Future<void> _handlePost(
    HttpResponse response,
    Map<String, String> headers,
    Map<String, Object?> body,
  ) async {
    final id = body['id'];
    final method = body['method'];

    if (expireSessions && headers.containsKey('mcp-session-id')) {
      response
        ..statusCode = HttpStatus.notFound
        ..write('session not found');
      await response.close();
      return;
    }

    if (id == null) {
      response.statusCode = HttpStatus.accepted;
      await response.close();
      return;
    }

    switch (method) {
      case 'initialize':
        response.headers.set('mcp-session-id', sessionId);
        await _json(response, {
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'protocolVersion': protocolVersion,
            'capabilities': <String, Object?>{},
            'serverInfo': {'name': 'fake', 'version': '1.0.0'},
          },
        });
      case 'ping':
        await _json(response, {
          'jsonrpc': '2.0',
          'id': id,
          'result': <String, Object?>{},
        });
        if (!_pingAnswered.isCompleted) _pingAnswered.complete();
      case 'tools/call':
        final name = (body['params'] as Map)['name'];
        if (name == 'slow') {
          await _pingAnswered.future;
          await _json(response, _toolResult(id, 'slow done'));
        } else {
          await _sse(response, id);
        }
      default:
        await _json(response, {
          'jsonrpc': '2.0',
          'id': id,
          'error': {'code': -32601, 'message': 'Method not found'},
        });
    }
  }

  Future<void> _json(HttpResponse response, Object body) async {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  Future<void> _sse(HttpResponse response, Object id) async {
    response.headers.contentType = ContentType('text', 'event-stream');
    response.write(': keep-alive comment\n');
    response.write('event: message\nid: 1\nretry: 1000\n');
    response.write(
      'data: ${jsonEncode({
        'jsonrpc': '2.0',
        'method': 'notifications/progress',
        'params': {'progressToken': 't', 'progress': 1},
      })}\n\n',
    );
    await response.flush();
    // The result spread over several data lines (joined with \n).
    final result = const JsonEncoder.withIndent(
      ' ',
    ).convert(_toolResult(id, 'echoed'));
    response.write('event: message\r\n');
    for (final line in const LineSplitter().convert(result)) {
      response.write('data: $line\r\n');
    }
    response.write('\r\n');
    await response.close();
  }

  static Map<String, Object?> _toolResult(Object id, String text) => {
    'jsonrpc': '2.0',
    'id': id,
    'result': {
      'content': [
        {'type': 'text', 'text': text},
      ],
    },
  };
}
