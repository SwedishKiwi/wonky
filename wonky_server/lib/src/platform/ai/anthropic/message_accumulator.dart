import 'dart:convert';

import 'anthropic_types.dart';

/// A complete (streamed) response.
class AnthropicMessage {
  AnthropicMessage({
    required this.content,
    required this.usage,
    this.id,
    this.model,
    this.stopReason,
    this.stopDetails,
    this.invalidToolInputs = const {},
  });

  final String? id;

  /// The model that produced the message (the fallback model after a
  /// server-side fallback).
  final String? model;

  /// Content blocks exactly as received (thinking blocks with signatures,
  /// `fallback` markers, tool uses with parsed inputs).
  final List<Map<String, Object?>> content;
  final String? stopReason;

  /// Set only for `refusal` (`{type, category, explanation}`).
  final Map<String, Object?>? stopDetails;
  final AnthropicUsage usage;

  /// Tool-use ids whose streamed input was not valid JSON (eager input
  /// streaming does not validate): id → the raw text received.
  final Map<String, String> invalidToolInputs;

  List<Map<String, Object?>> get toolUses => [
    for (final b in content)
      if (b['type'] == 'tool_use') b,
  ];

  /// The concatenated text blocks.
  String get text => [
    for (final b in content)
      if (b['type'] == 'text') b['text'] as String? ?? '',
  ].join();

  /// The content to append to the history (append-only replay): after a
  /// server-side fallback, `thinking`, `redacted_thinking` and `tool_use`
  /// blocks (and other model-internal blocks) before the last `fallback`
  /// marker are dropped; the marker itself is dropped too. Text blocks are
  /// kept.
  List<Map<String, Object?>> get replayContent {
    final lastFallback = content.lastIndexWhere((b) => b['type'] == 'fallback');
    final out = <Map<String, Object?>>[];
    for (var i = 0; i < content.length; i++) {
      final b = content[i];
      final type = b['type'];
      if (type == 'fallback') continue;
      if (i < lastFallback && type != 'text') continue;
      if (type == 'text' && (b['text'] as String? ?? '').isEmpty) continue;
      out.add(b);
    }
    return out;
  }
}

/// Builds an [AnthropicMessage] from stream events and reports deltas.
class MessageAccumulator {
  MessageAccumulator({
    this.onText,
    this.onThinking,
    this.onToolStart,
    this.onBlockDone,
  });

  /// A text delta of the answer.
  final void Function(String delta)? onText;

  /// A thinking delta (with `display: "updates"`: progress notes).
  final void Function(int index, String delta)? onThinking;

  /// A tool use started streaming.
  final void Function(String id, String name)? onToolStart;

  /// A content block finished.
  final void Function(Map<String, Object?> block)? onBlockDone;

  final Map<int, Map<String, Object?>> _blocks = {};
  final Map<int, StringBuffer> _json = {};
  final Map<String, String> _invalid = {};
  String? _id;
  String? _model;
  String? _stopReason;
  Map<String, Object?>? _stopDetails;
  AnthropicUsage _usage = const AnthropicUsage();
  bool _stopped = false;

  /// Whether `message_stop` arrived.
  bool get isComplete => _stopped;

  /// Whether any content arrived (text, thinking, tool input).
  bool get hasContent => _blocks.isNotEmpty;

  void add(AnthropicStreamEvent e) {
    switch (e) {
      case MessageStartEvent():
        _id = e.id ?? _id;
        _model = e.model ?? _model;
        _usage = _usage.merge(e.usage);
      case ContentBlockStartEvent():
        final block = Map<String, Object?>.of(e.block);
        _blocks[e.index] = block;
        switch (block['type']) {
          case 'tool_use':
            _json[e.index] = StringBuffer();
            onToolStart?.call('${block['id']}', '${block['name']}');
          case 'text':
            final t = block['text'] as String? ?? '';
            if (t.isNotEmpty) onText?.call(t);
          case 'thinking':
            final t = block['thinking'] as String? ?? '';
            if (t.isNotEmpty) onThinking?.call(e.index, t);
        }
      case ContentBlockDeltaEvent():
        final block = _blocks[e.index];
        if (block == null) return;
        final d = e.delta;
        switch (d['type']) {
          case 'text_delta':
            final t = d['text'] as String? ?? '';
            block['text'] = '${block['text'] ?? ''}$t';
            if (block['type'] == 'text') onText?.call(t);
          case 'input_json_delta':
            _json[e.index]?.write(d['partial_json'] as String? ?? '');
          case 'thinking_delta':
            final t = d['thinking'] as String? ?? '';
            block['thinking'] = '${block['thinking'] ?? ''}$t';
            onThinking?.call(e.index, t);
          case 'signature_delta':
            block['signature'] =
                '${block['signature'] ?? ''}${d['signature'] ?? ''}';
          case 'citations_delta':
            final c = d['citation'];
            if (c != null) {
              block['citations'] = [...?(block['citations'] as List?), c];
            }
        }
      case ContentBlockStopEvent():
        final block = _blocks[e.index];
        if (block == null) return;
        final buf = _json.remove(e.index);
        if (buf != null) _finishToolInput(block, buf.toString());
        onBlockDone?.call(block);
      case MessageDeltaEvent():
        _stopReason = e.stopReason ?? _stopReason;
        _stopDetails = e.stopDetails ?? _stopDetails;
        _usage = _usage.merge(e.usage);
      case MessageStopEvent():
        _stopped = true;
      case PingEvent() || StreamErrorEvent():
        break;
    }
  }

  void _finishToolInput(Map<String, Object?> block, String raw) {
    if (raw.trim().isEmpty) {
      block['input'] = block['input'] is Map ? block['input'] : {};
      return;
    }
    try {
      final v = jsonDecode(raw);
      if (v is Map) {
        block['input'] = v.cast<String, Object?>();
        return;
      }
    } on FormatException {
      // Falls through: invalid input.
    }
    block['input'] = <String, Object?>{};
    _invalid['${block['id']}'] = raw;
  }

  /// The message so far (blocks still streaming are finished as they are).
  AnthropicMessage build() {
    for (final entry in _json.entries.toList()) {
      final block = _blocks[entry.key];
      if (block != null) _finishToolInput(block, entry.value.toString());
    }
    _json.clear();
    final keys = _blocks.keys.toList()..sort();
    return AnthropicMessage(
      id: _id,
      model: _model,
      content: [for (final k in keys) _blocks[k]!],
      stopReason: _stopReason,
      stopDetails: _stopDetails,
      usage: _usage,
      invalidToolInputs: Map.unmodifiable(_invalid),
    );
  }
}
