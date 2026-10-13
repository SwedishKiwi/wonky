import 'dart:async';
import 'dart:collection';

import '../../common/models.dart' show AiProvider;
import 'ai_client.dart';

/// A scripted model turn: streamed deltas and the resulting response, or
/// an error to throw.
class FakeAiResponse {
  FakeAiResponse._(this.script, this.error);

  final AiScript? script;
  final Object? error;

  factory FakeAiResponse.error(Object error) => FakeAiResponse._(null, error);
}

/// An [AiModelClient] for tests: replays scripted turns in order and
/// records every request. Never calls a provider.
class FakeAiModelClient implements AiModelClient {
  FakeAiModelClient({
    this.provider = AiProvider.anthropic,
    Iterable<FakeAiResponse> responses = const [],
  }) : _queue = Queue.of(responses);

  @override
  final AiProvider provider;

  final Queue<FakeAiResponse> _queue;

  /// The requests made, in order.
  final List<AiRequest> requests = [];

  /// Called before a response is replayed (e.g. to edit the document
  /// concurrently, or to stop the run).
  FutureOr<void> Function(AiRequest request)? beforeResponse;

  void enqueue(FakeAiResponse r) => _queue.add(r);

  int get pending => _queue.length;

  @override
  Future<AiResponse> send(
    AiRequest request, {
    AiCancelToken? cancel,
    void Function(String delta)? onText,
    void Function(String delta)? onThinking,
  }) async {
    requests.add(request);
    await beforeResponse?.call(request);
    if (cancel?.isCancelled ?? false) throw const AiCancelledException();
    if (_queue.isEmpty) {
      throw StateError('FakeAiModelClient: no scripted response left');
    }
    final r = _queue.removeFirst();
    if (r.error != null) throw r.error!;
    final s = r.script!;
    for (final d in s._deltas) {
      if (cancel?.isCancelled ?? false) throw const AiCancelledException();
      if (d.$1) {
        onThinking?.call(d.$2);
      } else {
        onText?.call(d.$2);
      }
      // Let the consumer react between deltas (cancellation, streaming).
      await Future<void>.delayed(Duration.zero);
    }
    if (cancel?.isCancelled ?? false) throw const AiCancelledException();
    return s.build();
  }
}

/// Builds a scripted model turn for [FakeAiModelClient].
class AiScript {
  AiScript({this.model});

  /// The model reported back (null = none).
  final String? model;

  final List<(bool, String)> _deltas = [];
  final StringBuffer _text = StringBuffer();
  final StringBuffer _thinking = StringBuffer();
  final List<ToolPart> _calls = [];
  String? _stop;
  AiTokenUsage _usage = const AiTokenUsage(inputTokens: 100, outputTokens: 20);

  /// Answer text streamed in [chunks].
  AiScript text(String text, {int chunks = 3}) {
    final size = (text.length / chunks).ceil().clamp(1, 1 << 20);
    for (var s = 0; s < text.length; s += size) {
      _deltas.add((false, text.substring(s, (s + size).clamp(0, text.length))));
    }
    _text.write(text);
    return this;
  }

  /// Reasoning text (shown as progress notes).
  AiScript thinking(String text) {
    _deltas.add((true, text));
    _thinking.write(text);
    return this;
  }

  /// A tool call.
  AiScript toolUse(String id, String name, Map<String, Object?> input) {
    _calls.add(ToolPart.call(callId: id, toolName: name, arguments: input));
    return this;
  }

  /// The stop reason ([AiStopReason]); default: `tool_use` with tool
  /// calls, else `end_turn`.
  AiScript stop(String reason) {
    _stop = reason;
    return this;
  }

  AiScript usage({int? input, int? output, int? cacheRead, int? cacheWrite}) {
    _usage = AiTokenUsage(
      inputTokens: input ?? _usage.inputTokens,
      outputTokens: output ?? _usage.outputTokens,
      cacheReadTokens: cacheRead ?? _usage.cacheReadTokens,
      cacheWriteTokens: cacheWrite ?? _usage.cacheWriteTokens,
    );
    return this;
  }

  AiResponse build() => AiResponse(
    message: ChatMessage(
      role: ChatMessageRole.model,
      parts: [
        if (_text.isNotEmpty) TextPart(_text.toString()),
        if (_thinking.isNotEmpty) ThinkingPart(_thinking.toString()),
        ..._calls,
      ],
    ),
    stopReason:
        _stop ?? (_calls.isEmpty ? AiStopReason.endTurn : AiStopReason.toolUse),
    usage: _usage,
    model: model,
  );

  /// This script as a [FakeAiResponse].
  FakeAiResponse get response => FakeAiResponse._(this, null);
}
