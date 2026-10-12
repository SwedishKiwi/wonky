import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// JSON-RPC error code for malformed input lines.
const int jsonRpcParseError = -32700;

/// JSON-RPC error code for input that is valid JSON but not a message.
const int jsonRpcInvalidRequest = -32600;

/// JSON-RPC error code used for transport failures (network errors, HTTP
/// errors other than 401/403, expired sessions).
const int proxyTransportError = -32000;

/// JSON-RPC error code used when the server rejects the token (HTTP 401/403).
const int proxyUnauthorizedError = -32001;

/// Proxies newline-delimited JSON-RPC messages between stdio and an MCP
/// Streamable HTTP endpoint.
///
/// Every line read from [input] is POSTed to [url]; the responses (plain
/// JSON or a `text/event-stream`) are written to [output] as one JSON-RPC
/// message per line. Requests are processed concurrently, but every output
/// line is written with a single `add`, so lines never interleave.
///
/// Once the server has assigned a session (`Mcp-Session-Id`), one background
/// `GET` stream receives server-initiated messages. When [input] ends, the
/// proxy waits for in-flight requests, ends the session with a `DELETE` and
/// closes [output].
///
/// Diagnostics go to [log] only, never to [output].
class StdioHttpProxy {
  /// Creates a proxy for the MCP endpoint at [url], authenticating with the
  /// personal access [token].
  ///
  /// [input], [output] and [log] default to `stdin`, `stdout` and `stderr`.
  /// When [client] is omitted, the proxy creates (and closes) its own.
  StdioHttpProxy({
    required this.url,
    required this.token,
    http.Client? client,
    Stream<List<int>>? input,
    StreamSink<List<int>>? output,
    StringSink? log,
    this.verbose = false,
    this.reconnectDelay = const Duration(seconds: 2),
    this.maxReconnectAttempts = 5,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _input = input ?? stdin,
       _output = output ?? stdout,
       _log = log ?? stderr;

  /// The MCP Streamable HTTP endpoint, e.g. `http://localhost:8082/mcp`.
  final Uri url;

  /// The personal access token (`wkpat_…`), sent as a bearer token.
  final String token;

  /// Whether to log every request and response status to the log sink.
  final bool verbose;

  /// Delay before reopening the server-initiated message stream after it
  /// ended or failed.
  final Duration reconnectDelay;

  /// How many times in a row the server-initiated message stream is
  /// (re)opened without receiving a message before the proxy gives up.
  final int maxReconnectAttempts;

  final http.Client _client;
  final bool _ownsClient;
  final Stream<List<int>> _input;
  final StreamSink<List<int>> _output;
  final StringSink _log;

  final Set<Future<void>> _inFlight = {};
  Completer<void>? _initGate;
  String? _sessionId;
  String? _protocolVersion;

  bool _ran = false;
  bool _closing = false;
  bool _outputClosed = false;

  bool _listening = false;
  bool _getUnsupported = false;
  Future<void>? _listenFuture;
  Completer<void>? _getAbort;
  Timer? _reconnectTimer;
  Completer<void>? _reconnectWait;

  /// The session id assigned by the server, if any.
  String? get sessionId => _sessionId;

  /// The protocol version negotiated by `initialize`, if any.
  String? get protocolVersion => _protocolVersion;

  /// Runs the proxy until [input] ends and returns the process exit code.
  ///
  /// May only be called once.
  Future<int> run() async {
    if (_ran) throw StateError('StdioHttpProxy.run() may only be called once');
    _ran = true;

    var exitCode = 0;
    try {
      final lines = _input
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter());
      await for (final line in lines) {
        _onLine(line);
      }
    } on Object catch (e) {
      _logLine('Failed to read input: $e');
      exitCode = 1;
    }
    await _shutdown();
    return exitCode;
  }

  // ---------------------------------------------------------------------------
  // Input

  void _onLine(String line) {
    final body = line.trim();
    if (body.isEmpty) return;

    final Object? message;
    try {
      message = jsonDecode(body);
    } on FormatException {
      _writeMessage(_errorResponse(null, jsonRpcParseError, 'Parse error'));
      return;
    }
    if (message is! Map && message is! List) {
      _writeMessage(
        _errorResponse(null, jsonRpcInvalidRequest, 'Invalid Request'),
      );
      return;
    }

    final future = _forward(body, message!);
    _inFlight.add(future);
    unawaited(future.whenComplete(() => _inFlight.remove(future)));
  }

  /// Forwards one input message. Never throws.
  ///
  /// Runs synchronously up to its first `await`, so the init gate is captured
  /// in input order: everything after an `initialize` waits for its response
  /// (and with it the session id), everything else runs concurrently.
  Future<void> _forward(String body, Object message) async {
    final isInitialize = _isInitialize(message);
    final previousGate = _initGate;
    Completer<void>? gate;
    if (isInitialize) {
      gate = Completer<void>();
      _initGate = gate;
    }
    try {
      if (!isInitialize && previousGate != null) await previousGate.future;
      await _post(body, message, isInitialize: isInitialize);
    } on Object catch (e) {
      _logLine('Unexpected error while forwarding a message: $e');
    } finally {
      gate?.complete();
    }
  }

  // ---------------------------------------------------------------------------
  // POST

  Future<void> _post(
    String body,
    Object message, {
    required bool isInitialize,
  }) async {
    final label = _describe(message);
    final pending = _requestIds(message).toSet();
    final sessionAtSend = _sessionId;

    final request = http.Request('POST', url)
      ..headers.addAll(_headers(accept: 'application/json, text/event-stream'))
      ..headers['Content-Type'] = 'application/json'
      ..bodyBytes = utf8.encode(body);

    try {
      _verboseLog('POST $label');
      final response = await _client.send(request);
      final status = response.statusCode;
      final contentType = response.headers['content-type'] ?? '';
      _verboseLog('POST $label -> HTTP $status $contentType'.trimRight());

      final newSession = response.headers['mcp-session-id'];
      if (newSession != null && newSession.isNotEmpty) _sessionId = newSession;

      if (status >= 400) {
        final excerpt = await _bodyExcerpt(response);
        var reason = switch (status) {
          401 => 'Unauthorized: check the token',
          403 => 'Forbidden: the token lacks the required scope',
          _ => 'HTTP error',
        };
        if (status == 404 && sessionAtSend != null) {
          if (_sessionId == sessionAtSend) _dropSession();
          reason = 'Session expired; the client must initialize again';
        }
        final text =
            '$reason (HTTP $status)${excerpt.isEmpty ? '' : ': $excerpt'}';
        if (pending.isEmpty) _logLine('$label failed: $text');
        final code = status == 401 || status == 403
            ? proxyUnauthorizedError
            : proxyTransportError;
        for (final id in pending) {
          _writeMessage(
            _errorResponse(id, code, text, data: {'httpStatus': status}),
          );
        }
        return;
      }

      if (status == 202 || status == 204) {
        await response.stream.drain<void>();
      } else if (contentType.startsWith('text/event-stream')) {
        await for (final data in _sseData(response.stream)) {
          _emitPayload(data, pending, isInitialize: isInitialize);
        }
      } else {
        final text = await response.stream.bytesToString();
        _emitPayload(text, pending, isInitialize: isInitialize);
      }

      for (final id in pending) {
        _writeMessage(
          _errorResponse(
            id,
            proxyTransportError,
            'The server answered HTTP $status without a response for this '
            'request',
          ),
        );
      }
      if (!isInitialize) _maybeStartListening();
    } on Object catch (e) {
      _logLine('$label failed: $e');
      for (final id in pending) {
        _writeMessage(
          _errorResponse(id, proxyTransportError, 'Request to $url failed: $e'),
        );
      }
    }
  }

  /// Writes the JSON-RPC message(s) in [text] to the output.
  void _emitPayload(
    String text,
    Set<Object?> pending, {
    bool isInitialize = false,
  }) {
    if (text.trim().isEmpty) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      _logLine('Ignoring non-JSON payload from the server: ${_excerpt(text)}');
      return;
    }
    final messages = decoded is List ? decoded : [decoded];
    for (final message in messages) {
      if (message is! Map) {
        _logLine('Ignoring non-object message from the server: $message');
        continue;
      }
      if (isInitialize) {
        final result = message['result'];
        if (result is Map && result['protocolVersion'] is String) {
          _protocolVersion = result['protocolVersion'] as String;
        }
      }
      if (message.containsKey('result') || message.containsKey('error')) {
        pending.remove(message['id']);
      }
      _writeMessage(message);
    }
  }

  // ---------------------------------------------------------------------------
  // Server-initiated messages (GET)

  void _maybeStartListening() {
    if (_listening || _getUnsupported || _closing || _sessionId == null) {
      return;
    }
    _listening = true;
    _listenFuture = _listen(_sessionId!);
  }

  Future<void> _listen(String session) async {
    var attempts = 0;
    while (!_closing && _sessionId == session) {
      if (attempts >= maxReconnectAttempts) {
        _logLine(
          'Giving up on the server message stream after $attempts attempts',
        );
        return;
      }
      attempts++;
      final abort = Completer<void>();
      _getAbort = abort;
      final request = http.AbortableRequest(
        'GET',
        url,
        abortTrigger: abort.future,
      )..headers.addAll(_headers(accept: 'text/event-stream'));
      try {
        final response = await _client.send(request);
        final status = response.statusCode;
        final contentType = response.headers['content-type'] ?? '';
        _verboseLog('GET -> HTTP $status $contentType'.trimRight());
        if (status < 200 ||
            status >= 300 ||
            !contentType.startsWith('text/event-stream')) {
          // The server does not offer a stream (405) or refuses it: stop
          // trying, silently.
          if (status == 405) _getUnsupported = true;
          unawaited(response.stream.drain<void>().catchError((Object _) {}));
          return;
        }
        await for (final data in _sseData(response.stream)) {
          attempts = 0;
          _emitPayload(data, {});
        }
        _verboseLog('GET stream ended');
      } on Object catch (e) {
        if (_closing) return;
        _verboseLog('GET stream failed: $e');
      } finally {
        if (identical(_getAbort, abort)) _getAbort = null;
      }
      if (_closing || _sessionId != session) return;
      await _waitBeforeReconnect();
    }
  }

  Future<void> _waitBeforeReconnect() {
    final wait = Completer<void>();
    _reconnectWait = wait;
    _reconnectTimer = Timer(reconnectDelay, () {
      if (!wait.isCompleted) wait.complete();
    });
    return wait.future;
  }

  void _stopListening() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final wait = _reconnectWait;
    if (wait != null && !wait.isCompleted) wait.complete();
    final abort = _getAbort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _listening = false;
  }

  void _dropSession() {
    _logLine('Session $_sessionId expired');
    _sessionId = null;
    _stopListening();
  }

  // ---------------------------------------------------------------------------
  // Shutdown

  Future<void> _shutdown() async {
    while (_inFlight.isNotEmpty) {
      await Future.wait(List.of(_inFlight));
    }
    _closing = true;
    _stopListening();
    await _listenFuture?.timeout(const Duration(seconds: 5), onTimeout: () {});

    final session = _sessionId;
    if (session != null) {
      try {
        final request = http.Request('DELETE', url)
          ..headers.addAll(_headers(accept: 'application/json'));
        final response = await _client
            .send(request)
            .timeout(const Duration(seconds: 5));
        await response.stream.drain<void>();
        _verboseLog('DELETE -> HTTP ${response.statusCode}');
      } on Object catch (e) {
        _verboseLog('DELETE failed: $e');
      }
    }

    if (_ownsClient) _client.close();
    _outputClosed = true;
    try {
      await _output.close();
    } on Object catch (e) {
      _logLine('Failed to close output: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers

  Map<String, String> _headers({required String accept}) => {
    'Authorization': 'Bearer $token',
    'Accept': accept,
    'Mcp-Session-Id': ?_sessionId,
    'MCP-Protocol-Version': ?_protocolVersion,
  };

  void _writeMessage(Object? message) {
    if (_outputClosed) return;
    // One `add` per line: concurrent writers can never interleave.
    _output.add(utf8.encode('${jsonEncode(message)}\n'));
  }

  void _logLine(String text) => _log.writeln('wonky_mcp_stdio: $text');

  void _verboseLog(String text) {
    if (verbose) _logLine(text);
  }

  static Map<String, Object?> _errorResponse(
    Object? id,
    int code,
    String message, {
    Map<String, Object?>? data,
  }) => {
    'jsonrpc': '2.0',
    'id': id,
    'error': {'code': code, 'message': message, 'data': ?data},
  };

  static bool _isInitialize(Object message) => switch (message) {
    Map() => message['method'] == 'initialize',
    List() => message.any((m) => m is Map && m['method'] == 'initialize'),
    _ => false,
  };

  /// Ids of the requests (not notifications or responses) in [message].
  static Iterable<Object?> _requestIds(Object message) sync* {
    final messages = message is List ? message : [message];
    for (final m in messages) {
      if (m is Map && m.containsKey('method') && m['id'] != null) {
        yield m['id'];
      }
    }
  }

  static String _describe(Object message) {
    if (message is List) return 'batch of ${message.length}';
    final map = message as Map;
    final method = map['method'];
    final id = map['id'];
    if (method == null) return 'response id=$id';
    return id == null ? '$method' : '$method id=$id';
  }

  static Future<String> _bodyExcerpt(http.StreamedResponse response) async {
    try {
      return _excerpt(await response.stream.bytesToString());
    } on Object {
      return '';
    }
  }

  static String _excerpt(String text, [int max = 200]) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.length <= max
        ? collapsed
        : '${collapsed.substring(0, max)}…';
  }
}

/// Parses a `text/event-stream` body and yields the data payload of every
/// event as it arrives. Multi-line data is joined with `\n`; `event:`, `id:`,
/// `retry:` and comment lines are ignored.
Stream<String> _sseData(Stream<List<int>> bytes) async* {
  final data = <String>[];
  final lines = bytes
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());
  await for (final line in lines) {
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        yield data.join('\n');
        data.clear();
      }
      continue;
    }
    if (line.startsWith(':')) continue;
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    if (field != 'data') continue;
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    data.add(value);
  }
  if (data.isNotEmpty) yield data.join('\n');
}
