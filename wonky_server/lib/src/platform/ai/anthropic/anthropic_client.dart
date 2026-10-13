import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'anthropic_types.dart';
import 'message_accumulator.dart';
import 'sse_parser.dart';

export 'anthropic_types.dart';
export 'message_accumulator.dart';

/// Calls the Claude Messages API (`POST /v1/messages`, streamed). Dart has
/// no official Anthropic SDK, so the server speaks HTTP + SSE itself
/// (suite 10 §1). Tests use `FakeAnthropicClient`, which replays scripted
/// SSE through the same parser.
abstract class AnthropicClient {
  /// The raw events of one streamed request. Retries (429, 5xx, 529,
  /// connection errors) happen before the first event is delivered.
  Stream<AnthropicStreamEvent> stream(
    AnthropicRequest request, {
    AiCancelToken? cancel,
  });

  /// Streams [request] and returns the complete message, reporting text,
  /// thinking (progress) and tool starts as they arrive. Throws
  /// [AiCancelledException] when [cancel] fires.
  Future<AnthropicMessage> send(
    AnthropicRequest request, {
    AiCancelToken? cancel,
    void Function(String delta)? onText,
    void Function(int index, String delta)? onThinking,
    void Function(String id, String name)? onToolStart,
  }) async {
    final acc = MessageAccumulator(
      onText: onText,
      onThinking: onThinking,
      onToolStart: onToolStart,
    );
    await for (final e in stream(request, cancel: cancel)) {
      if (e is StreamErrorEvent) {
        throw AnthropicApiException(0, e.type, e.message);
      }
      acc.add(e);
      if (cancel?.isCancelled ?? false) throw const AiCancelledException();
    }
    if (cancel?.isCancelled ?? false) throw const AiCancelledException();
    if (!acc.isComplete && !acc.hasContent) {
      throw AnthropicApiException(
        0,
        'connection_error',
        'The response ended early.',
      );
    }
    return acc.build();
  }
}

/// Retry policy: exponential backoff with jitter, honouring `retry-after`.
class AnthropicRetryPolicy {
  const AnthropicRetryPolicy({
    this.maxRetries = 4,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
  });

  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;

  static bool retryableStatus(int status) =>
      status == 408 ||
      status == 409 ||
      status == 429 ||
      status == 529 ||
      status >= 500;

  static bool retryableType(String type) =>
      type == 'overloaded_error' ||
      type == 'api_error' ||
      type == 'rate_limit_error';

  /// The delay before retry [attempt] (0-based) given a `retry-after`
  /// header value.
  Duration delay(int attempt, {Duration? retryAfter, math.Random? random}) {
    if (retryAfter != null) {
      return retryAfter > maxDelay * 4 ? maxDelay * 4 : retryAfter;
    }
    final base = initialDelay * math.pow(2, attempt).toInt();
    final capped = base > maxDelay ? maxDelay : base;
    final jitter = (random ?? math.Random()).nextDouble() * 0.25 + 0.875;
    return capped * jitter;
  }

  /// Parses `retry-after-ms` / `retry-after` (seconds or an HTTP date).
  static Duration? retryAfterOf(Map<String, String> headers) {
    final ms = int.tryParse(headers['retry-after-ms'] ?? '');
    if (ms != null) return Duration(milliseconds: ms);
    final raw = headers['retry-after'];
    if (raw == null) return null;
    final s = double.tryParse(raw);
    if (s != null) return Duration(milliseconds: (s * 1000).round());
    try {
      final at = HttpDate.parse(raw);
      final d = at.difference(DateTime.now().toUtc());
      return d.isNegative ? Duration.zero : d;
    } on FormatException {
      return null;
    }
  }
}

/// The production client: `package:http` + SSE.
class HttpAnthropicClient extends AnthropicClient {
  HttpAnthropicClient({
    required this.apiKey,
    this.baseUrl = 'https://api.anthropic.com',
    this.retry = const AnthropicRetryPolicy(),
    this.requestTimeout = const Duration(minutes: 10),
    this.idleTimeout = const Duration(minutes: 3),
    http.Client Function()? httpClient,
    this.log,
    Future<void> Function(Duration)? sleep,
  }) : _newClient = httpClient ?? http.Client.new,
       _sleep = sleep ?? Future<void>.delayed;

  static const apiVersion = '2023-06-01';

  final String apiKey;
  final String baseUrl;
  final AnthropicRetryPolicy retry;

  /// Wall-clock limit of one request (suite 10 §1: 10 min).
  final Duration requestTimeout;

  /// Longest silence between two events.
  final Duration idleTimeout;
  final http.Client Function() _newClient;
  final Future<void> Function(Duration) _sleep;
  final void Function(String message)? log;

  /// Optional features the API rejected; off for the rest of the process.
  static final Set<AnthropicFeature> disabledFeatures = {};

  static Set<AnthropicFeature> get enabledFeatures => {
    for (final f in AnthropicFeature.values)
      if (!disabledFeatures.contains(f)) f,
  };

  @override
  Stream<AnthropicStreamEvent> stream(
    AnthropicRequest request, {
    AiCancelToken? cancel,
  }) {
    late final StreamController<AnthropicStreamEvent> out;
    http.Client? client;
    var closed = false;
    void abort() {
      closed = true;
      client?.close();
    }

    var timedOut = false;
    Future<void> runAttempts() async {
      var attempt = 0;
      var featureStrips = 0;
      while (!closed) {
        if (cancel?.isCancelled ?? false) break;
        final features = enabledFeatures;
        client = _newClient();
        final req = http.Request('POST', Uri.parse('$baseUrl/v1/messages'))
          ..headers.addAll({
            'x-api-key': apiKey,
            'anthropic-version': apiVersion,
            'content-type': 'application/json',
            'accept': 'text/event-stream',
          })
          ..body = jsonEncode(request.toJson(features));
        final betas = request.betas(features);
        if (betas.isNotEmpty) req.headers['anthropic-beta'] = betas.join(',');
        http.StreamedResponse resp;
        try {
          resp = await client!.send(req).timeout(const Duration(seconds: 60));
        } on Object catch (e) {
          client?.close();
          if (closed || (cancel?.isCancelled ?? false)) break;
          if (attempt < retry.maxRetries && _isConnectionError(e)) {
            await _backoff(attempt++, null, 'connection: $e');
            continue;
          }
          throw AnthropicApiException(0, 'connection_error', '$e');
        }
        if (resp.statusCode != 200) {
          final body = await resp.stream.bytesToString().catchError((_) => '');
          client?.close();
          final (type, message) = _errorOf(body);
          if (resp.statusCode == 400 &&
              featureStrips < AnthropicFeature.values.length) {
            final strip = _featureToStrip(message, features);
            if (strip.isNotEmpty) {
              disabledFeatures.addAll(strip);
              featureStrips++;
              log?.call(
                'Anthropic API rejected ${strip.map((f) => f.name)}; '
                'retrying without: $message',
              );
              continue;
            }
          }
          if (attempt < retry.maxRetries &&
              AnthropicRetryPolicy.retryableStatus(resp.statusCode)) {
            await _backoff(
              attempt++,
              AnthropicRetryPolicy.retryAfterOf(resp.headers),
              '${resp.statusCode} $type',
            );
            continue;
          }
          throw AnthropicApiException(resp.statusCode, type, message);
        }
        var delivered = false;
        try {
          await for (final ev in SseParser.parse(
            resp.stream,
          ).timeout(idleTimeout)) {
            if (closed) break;
            if (ev is StreamErrorEvent &&
                !delivered &&
                AnthropicRetryPolicy.retryableType(ev.type) &&
                attempt < retry.maxRetries) {
              throw _RetryStream(ev.type);
            }
            if (ev is! PingEvent) delivered = true;
            out.add(ev);
          }
          client?.close();
          break;
        } on _RetryStream catch (r) {
          client?.close();
          await _backoff(attempt++, null, 'stream ${r.type}');
          continue;
        } on Object catch (e) {
          client?.close();
          if (closed || (cancel?.isCancelled ?? false)) break;
          if (!delivered &&
              attempt < retry.maxRetries &&
              _isConnectionError(e)) {
            await _backoff(attempt++, null, 'stream: $e');
            continue;
          }
          throw AnthropicApiException(
            0,
            e is TimeoutException ? 'timeout' : 'connection_error',
            e is TimeoutException
                ? 'The model did not respond in time.'
                : 'The connection to the model was interrupted.',
          );
        }
      }
    }

    Future<void> run() async {
      final deadline = Timer(requestTimeout, () {
        timedOut = true;
        abort();
      });
      try {
        await runAttempts();
      } finally {
        deadline.cancel();
      }
      if (timedOut) {
        throw AnthropicApiException(
          0,
          'timeout',
          'The model did not finish in time.',
        );
      }
    }

    out = StreamController<AnthropicStreamEvent>(
      onListen: () {
        cancel?.whenCancelled.then((_) => abort());
        run().then(
          (_) => out.close(),
          onError: (Object e, StackTrace st) {
            if (!out.isClosed) {
              out.addError(e, st);
              out.close();
            }
          },
        );
      },
      onCancel: abort,
    );
    return out.stream;
  }

  Future<void> _backoff(int attempt, Duration? after, String why) async {
    final d = retry.delay(attempt, retryAfter: after);
    log?.call(
      'Anthropic request retry ${attempt + 1} in ${d.inMilliseconds} ms ($why)',
    );
    await _sleep(d);
  }

  static bool _isConnectionError(Object e) =>
      e is SocketException ||
      e is http.ClientException ||
      e is TimeoutException ||
      e is HttpException ||
      e is HandshakeException;

  static (String, String) _errorOf(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json['error'] is Map) {
        final e = json['error'] as Map;
        return ('${e['type'] ?? 'api_error'}', '${e['message'] ?? body}');
      }
    } on FormatException {
      // Not JSON.
    }
    return ('api_error', body.isEmpty ? 'Request failed.' : body);
  }

  /// Which optional features a 400 [message] complains about.
  static Set<AnthropicFeature> _featureToStrip(
    String message,
    Set<AnthropicFeature> enabled,
  ) {
    final m = message.toLowerCase();
    final out = <AnthropicFeature>{};
    void check(AnthropicFeature f, List<String> words) {
      if (enabled.contains(f) && words.any(m.contains)) out.add(f);
    }

    check(AnthropicFeature.fallbacks, ['fallback']);
    check(AnthropicFeature.displayUpdates, ['display', 'thinking-display']);
    check(AnthropicFeature.blockBinding, ['block_binding', 'thinking-binding']);
    check(AnthropicFeature.strictTools, ['strict']);
    check(AnthropicFeature.eagerInputStreaming, ['eager_input_streaming']);
    check(AnthropicFeature.autoCache, ['cache_control']);
    if (out.isEmpty && m.contains('beta')) {
      for (final f in enabled) {
        if (f.beta != null) out.add(f);
      }
    }
    return out;
  }
}

class _RetryStream implements Exception {
  _RetryStream(this.type);
  final String type;
}
