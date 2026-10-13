import 'dart:async';

import '../ai_models.dart';

/// Optional request features. A feature the API rejects with a 400 is
/// switched off for the rest of the process (see `HttpAnthropicClient`), so
/// a beta that is not (or no longer) available degrades instead of breaking
/// the assistant.
enum AnthropicFeature {
  /// `fallbacks: "default"` + beta `server-side-fallback-2026-07-01`.
  fallbacks('server-side-fallback-2026-07-01'),

  /// `thinking.display: "updates"` + beta `thinking-display-updates-2026-08-18`.
  displayUpdates('thinking-display-updates-2026-08-18'),

  /// `thinking.block_binding.prefix_mismatch_behavior: "drop_block"` + beta
  /// `thinking-binding-controls-2026-08-01`: a history prefix change drops
  /// thinking blocks instead of failing the request.
  blockBinding('thinking-binding-controls-2026-08-01'),

  /// `strict: true` on tools whose schemas allow it.
  strictTools(null),

  /// `eager_input_streaming: true` on tools.
  eagerInputStreaming(null),

  /// Top-level `cache_control` (automatic breakpoint on the last block).
  autoCache(null);

  const AnthropicFeature(this.beta);

  /// The `anthropic-beta` value the feature needs (null = GA).
  final String? beta;
}

/// A tool for the Messages API.
class AnthropicTool {
  const AnthropicTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    this.strictCompatible = false,
  });

  /// `^[a-zA-Z0-9_-]{1,64}$`.
  final String name;
  final String description;
  final Map<String, Object?> inputSchema;

  /// Whether [inputSchema] satisfies the strict-mode subset (every object
  /// closed, no numeric/length constraints).
  final bool strictCompatible;

  Map<String, Object?> toJson(Set<AnthropicFeature> features) => {
    'name': name,
    'description': description,
    'input_schema': inputSchema,
    if (strictCompatible && features.contains(AnthropicFeature.strictTools))
      'strict': true,
    if (features.contains(AnthropicFeature.eagerInputStreaming))
      'eager_input_streaming': true,
  };
}

/// One streamed Messages API request.
class AnthropicRequest {
  const AnthropicRequest({
    required this.model,
    required this.messages,
    this.system = const [],
    this.tools = const [],
    this.effort = AiEffort.medium,
    this.maxTokens = 64000,
    this.cacheConversation = true,
    this.userId,
    this.feature = 'chat',
  });

  final String model;

  /// System prompt blocks (`[{type: text, text, cache_control?}]`).
  final List<Map<String, Object?>> system;

  /// The conversation, replayed verbatim (append-only).
  final List<Map<String, Object?>> messages;

  /// Tools, already in a deterministic order (prompt caching).
  final List<AnthropicTool> tools;
  final String effort;
  final int maxTokens;

  /// Top-level `cache_control` (the API puts it on the last cacheable
  /// block, caching the conversation so far without editing history).
  final bool cacheConversation;

  /// Opaque user id for abuse monitoring (`metadata.user_id`).
  final String? userId;

  /// Usage accounting label (chat, rewrite, proofread, …).
  final String feature;

  /// The JSON body with [features] enabled.
  Map<String, Object?> toJson(Set<AnthropicFeature> features) {
    final fallback =
        features.contains(AnthropicFeature.fallbacks) &&
        AiModels.supportsServerFallback(model);
    final updates =
        tools.isNotEmpty &&
        features.contains(AnthropicFeature.displayUpdates) &&
        AiModels.supportsDisplayUpdates(model);
    final binding = features.contains(AnthropicFeature.blockBinding);
    return {
      'model': model,
      'max_tokens': maxTokens,
      'stream': true,
      'thinking': {
        'type': 'adaptive',
        if (updates) 'display': 'updates',
        if (binding)
          'block_binding': {'prefix_mismatch_behavior': 'drop_block'},
      },
      'output_config': {'effort': effort},
      if (system.isNotEmpty) 'system': system,
      if (tools.isNotEmpty) ...{
        'tools': [for (final t in tools) t.toJson(features)],
        'tool_choice': {'type': 'auto'},
      },
      'messages': messages,
      if (cacheConversation && features.contains(AnthropicFeature.autoCache))
        'cache_control': {'type': 'ephemeral'},
      if (fallback) 'fallbacks': 'default',
      if (userId != null) 'metadata': {'user_id': userId},
    };
  }

  /// The `anthropic-beta` header values for [features].
  List<String> betas(Set<AnthropicFeature> features) => [
    if (features.contains(AnthropicFeature.fallbacks) &&
        AiModels.supportsServerFallback(model))
      AnthropicFeature.fallbacks.beta!,
    if (tools.isNotEmpty &&
        features.contains(AnthropicFeature.displayUpdates) &&
        AiModels.supportsDisplayUpdates(model))
      AnthropicFeature.displayUpdates.beta!,
    if (features.contains(AnthropicFeature.blockBinding))
      AnthropicFeature.blockBinding.beta!,
  ];
}

/// Token usage of one response.
class AnthropicUsage {
  const AnthropicUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheReadTokens = 0,
    this.cacheWriteTokens = 0,
  });

  factory AnthropicUsage.fromJson(Map<String, Object?>? json) {
    int v(String k) => (json?[k] as num?)?.toInt() ?? 0;
    return AnthropicUsage(
      inputTokens: v('input_tokens'),
      outputTokens: v('output_tokens'),
      cacheReadTokens: v('cache_read_input_tokens'),
      cacheWriteTokens: v('cache_creation_input_tokens'),
    );
  }

  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;

  /// Tokens counted against the daily budget.
  int get total =>
      inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens;

  /// Merges a `message_delta` usage (cumulative counts) into this one.
  AnthropicUsage merge(AnthropicUsage o) => AnthropicUsage(
    inputTokens: o.inputTokens > 0 ? o.inputTokens : inputTokens,
    outputTokens: o.outputTokens > 0 ? o.outputTokens : outputTokens,
    cacheReadTokens: o.cacheReadTokens > 0
        ? o.cacheReadTokens
        : cacheReadTokens,
    cacheWriteTokens: o.cacheWriteTokens > 0
        ? o.cacheWriteTokens
        : cacheWriteTokens,
  );

  AnthropicUsage operator +(AnthropicUsage o) => AnthropicUsage(
    inputTokens: inputTokens + o.inputTokens,
    outputTokens: outputTokens + o.outputTokens,
    cacheReadTokens: cacheReadTokens + o.cacheReadTokens,
    cacheWriteTokens: cacheWriteTokens + o.cacheWriteTokens,
  );

  @override
  String toString() =>
      'in=$inputTokens out=$outputTokens cacheRead=$cacheReadTokens '
      'cacheWrite=$cacheWriteTokens';
}

/// Server-sent events of a streamed response.
sealed class AnthropicStreamEvent {
  const AnthropicStreamEvent();
}

class MessageStartEvent extends AnthropicStreamEvent {
  const MessageStartEvent(this.id, this.model, this.usage);
  final String? id;
  final String? model;
  final AnthropicUsage usage;
}

class ContentBlockStartEvent extends AnthropicStreamEvent {
  const ContentBlockStartEvent(this.index, this.block);
  final int index;

  /// The block as started (`{type: text, text: ""}`, `{type: tool_use, id,
  /// name, input: {}}`, `{type: thinking, thinking: "", signature: ""}`, …).
  final Map<String, Object?> block;
}

class ContentBlockDeltaEvent extends AnthropicStreamEvent {
  const ContentBlockDeltaEvent(this.index, this.delta);
  final int index;

  /// `{type: text_delta, text}`, `{type: input_json_delta, partial_json}`,
  /// `{type: thinking_delta, thinking}`, `{type: signature_delta, signature}`.
  final Map<String, Object?> delta;
}

class ContentBlockStopEvent extends AnthropicStreamEvent {
  const ContentBlockStopEvent(this.index);
  final int index;
}

class MessageDeltaEvent extends AnthropicStreamEvent {
  const MessageDeltaEvent(this.stopReason, this.stopDetails, this.usage);
  final String? stopReason;
  final Map<String, Object?>? stopDetails;
  final AnthropicUsage usage;
}

class MessageStopEvent extends AnthropicStreamEvent {
  const MessageStopEvent();
}

class PingEvent extends AnthropicStreamEvent {
  const PingEvent();
}

/// An `error` event in the stream (e.g. `overloaded_error`).
class StreamErrorEvent extends AnthropicStreamEvent {
  const StreamErrorEvent(this.type, this.message);
  final String type;
  final String message;
}

/// A failed request (after retries).
class AnthropicApiException implements Exception {
  AnthropicApiException(this.statusCode, this.type, this.message);

  /// HTTP status; 0 for connection failures and stream errors.
  final int statusCode;

  /// API error type (`invalid_request_error`, `overloaded_error`, …) or
  /// `connection_error` / `timeout`.
  final String type;
  final String message;

  bool get isAuth => statusCode == 401 || statusCode == 403;
  bool get isRateLimit => statusCode == 429;
  bool get isOverloaded => statusCode == 529 || type == 'overloaded_error';

  @override
  String toString() => 'AnthropicApiException($statusCode $type: $message)';
}

/// Cancels a running request (the user pressed Stop).
class AiCancelToken {
  final Completer<void> _done = Completer<void>();

  bool get isCancelled => _done.isCompleted;

  /// Completes when cancelled.
  Future<void> get whenCancelled => _done.future;

  void cancel() {
    if (!_done.isCompleted) _done.complete();
  }
}

/// Thrown when an [AiCancelToken] stops a request.
class AiCancelledException implements Exception {
  const AiCancelledException();

  @override
  String toString() => 'AiCancelledException';
}
