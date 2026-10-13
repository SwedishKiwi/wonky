import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'anthropic_client.dart';
import 'sse_parser.dart';

/// A scripted response: either SSE text (parsed by the real [SseParser]) or
/// an error to throw.
class FakeResponse {
  FakeResponse.sse(this.sse) : error = null;
  FakeResponse.error(Object this.error) : sse = null;

  final String? sse;
  final Object? error;
}

/// An [AnthropicClient] for tests: replays scripted SSE responses in order
/// and records every request (body as sent, with all features enabled).
class FakeAnthropicClient extends AnthropicClient {
  FakeAnthropicClient([Iterable<FakeResponse> responses = const []])
    : _queue = Queue.of(responses);

  final Queue<FakeResponse> _queue;

  /// Bodies of the requests made (`AnthropicRequest.toJson`).
  final List<Map<String, Object?>> requests = [];

  /// The typed requests.
  final List<AnthropicRequest> typedRequests = [];

  /// Called before a response is replayed (e.g. to edit the document
  /// concurrently, or to cancel).
  FutureOr<void> Function(AnthropicRequest request)? beforeResponse;

  /// Adds responses.
  void enqueue(FakeResponse r) => _queue.add(r);

  void enqueueSse(String sse) => _queue.add(FakeResponse.sse(sse));

  int get pending => _queue.length;

  @override
  Stream<AnthropicStreamEvent> stream(
    AnthropicRequest request, {
    AiCancelToken? cancel,
  }) async* {
    requests.add(
      jsonDecode(jsonEncode(request.toJson(AnthropicFeature.values.toSet())))
          as Map<String, Object?>,
    );
    typedRequests.add(request);
    await beforeResponse?.call(request);
    if (_queue.isEmpty) {
      throw StateError('FakeAnthropicClient: no scripted response left');
    }
    final r = _queue.removeFirst();
    if (r.error != null) throw r.error!;
    final lines = const LineSplitter().convert(r.sse!);
    await for (final ev in SseParser.parseLines(Stream.fromIterable(lines))) {
      if (cancel?.isCancelled ?? false) return;
      yield ev;
      // Let the consumer react between events (cancellation, streaming).
      await Future<void>.delayed(Duration.zero);
    }
  }
}

/// Builds Messages API SSE streams for tests ("recorded" fixtures).
class SseScript {
  SseScript({this.model = 'claude-opus-5-5', this.id = 'msg_test'});

  final String model;
  final String id;
  final List<String> _blocks = [];
  int _index = 0;
  String _stop = 'end_turn';
  Map<String, Object?>? _stopDetails;
  int inputTokens = 100;
  int outputTokens = 20;
  int cacheReadTokens = 0;
  int cacheWriteTokens = 0;
  String? _midStreamError;

  static String _event(String name, Map<String, Object?> data) =>
      'event: $name\ndata: ${jsonEncode(data)}\n\n';

  /// A text block streamed in [chunks].
  SseScript text(String text, {int chunks = 3}) {
    final i = _index++;
    final b = StringBuffer()
      ..write(
        _event('content_block_start', {
          'type': 'content_block_start',
          'index': i,
          'content_block': {'type': 'text', 'text': ''},
        }),
      );
    final size = (text.length / chunks).ceil().clamp(1, 1 << 20);
    for (var s = 0; s < text.length; s += size) {
      b.write(
        _event('content_block_delta', {
          'type': 'content_block_delta',
          'index': i,
          'delta': {
            'type': 'text_delta',
            'text': text.substring(s, (s + size).clamp(0, text.length)),
          },
        }),
      );
    }
    b.write(
      _event('content_block_stop', {'type': 'content_block_stop', 'index': i}),
    );
    _blocks.add(b.toString());
    return this;
  }

  /// A thinking block (a progress note with display "updates").
  SseScript thinking(String text, {String signature = 'sig_test'}) {
    final i = _index++;
    _blocks.add(
      _event('content_block_start', {
            'type': 'content_block_start',
            'index': i,
            'content_block': {
              'type': 'thinking',
              'thinking': '',
              'signature': '',
            },
          }) +
          _event('content_block_delta', {
            'type': 'content_block_delta',
            'index': i,
            'delta': {'type': 'thinking_delta', 'thinking': text},
          }) +
          _event('content_block_delta', {
            'type': 'content_block_delta',
            'index': i,
            'delta': {'type': 'signature_delta', 'signature': signature},
          }) +
          _event('content_block_stop', {
            'type': 'content_block_stop',
            'index': i,
          }),
    );
    return this;
  }

  /// A tool use whose input is streamed as JSON fragments ([rawJson]
  /// overrides the encoded [input], e.g. to send invalid JSON).
  SseScript toolUse(
    String id,
    String name,
    Map<String, Object?> input, {
    String? rawJson,
  }) {
    final i = _index++;
    final json = rawJson ?? jsonEncode(input);
    final b = StringBuffer()
      ..write(
        _event('content_block_start', {
          'type': 'content_block_start',
          'index': i,
          'content_block': {
            'type': 'tool_use',
            'id': id,
            'name': name,
            'input': <String, Object?>{},
          },
        }),
      );
    final half = json.length ~/ 2;
    for (final part in [json.substring(0, half), json.substring(half)]) {
      if (part.isEmpty) continue;
      b.write(
        _event('content_block_delta', {
          'type': 'content_block_delta',
          'index': i,
          'delta': {'type': 'input_json_delta', 'partial_json': part},
        }),
      );
    }
    b.write(
      _event('content_block_stop', {'type': 'content_block_stop', 'index': i}),
    );
    _blocks.add(b.toString());
    return this;
  }

  /// A `fallback` marker (server-side refusal fallback).
  SseScript fallback(String from, String to) {
    final i = _index++;
    _blocks.add(
      _event('content_block_start', {
            'type': 'content_block_start',
            'index': i,
            'content_block': {
              'type': 'fallback',
              'from': {'model': from},
              'to': {'model': to},
            },
          }) +
          _event('content_block_stop', {
            'type': 'content_block_stop',
            'index': i,
          }),
    );
    return this;
  }

  /// An `error` event after the blocks (mid-stream failure).
  SseScript streamError(String type, String message) {
    _midStreamError = _event('error', {
      'type': 'error',
      'error': {'type': type, 'message': message},
    });
    return this;
  }

  SseScript stop(String reason, {Map<String, Object?>? details}) {
    _stop = reason;
    _stopDetails = details;
    return this;
  }

  SseScript usage({int? input, int? output, int? cacheRead, int? cacheWrite}) {
    inputTokens = input ?? inputTokens;
    outputTokens = output ?? outputTokens;
    cacheReadTokens = cacheRead ?? cacheReadTokens;
    cacheWriteTokens = cacheWrite ?? cacheWriteTokens;
    return this;
  }

  /// The SSE text.
  String build() {
    final b = StringBuffer()
      ..write(
        _event('message_start', {
          'type': 'message_start',
          'message': {
            'id': id,
            'type': 'message',
            'role': 'assistant',
            'model': model,
            'content': <Object?>[],
            'stop_reason': null,
            'usage': {
              'input_tokens': inputTokens,
              'output_tokens': 1,
              'cache_read_input_tokens': cacheReadTokens,
              'cache_creation_input_tokens': cacheWriteTokens,
            },
          },
        }),
      )
      ..write(_event('ping', {'type': 'ping'}));
    _blocks.forEach(b.write);
    if (_midStreamError != null) {
      b.write(_midStreamError);
      return b.toString();
    }
    b
      ..write(
        _event('message_delta', {
          'type': 'message_delta',
          'delta': {'stop_reason': _stop, 'stop_details': ?_stopDetails},
          'usage': {'output_tokens': outputTokens},
        }),
      )
      ..write(_event('message_stop', {'type': 'message_stop'}));
    return b.toString();
  }

  /// [build] wrapped as a [FakeResponse].
  FakeResponse get response => FakeResponse.sse(build());
}
