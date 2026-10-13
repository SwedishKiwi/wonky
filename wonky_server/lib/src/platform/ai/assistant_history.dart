import 'dart:convert';

import 'llm/ai_client.dart';

/// The stored form of assistant turns (`AssistantMessage.contentJson`).
///
/// Turns are stored as `dartantic_ai` messages (`ChatMessage.toJson()`: a
/// JSON object with `role`, `parts`, `metadata`), so a thread replays with
/// any provider. Threads from before the provider switch hold raw Anthropic
/// content blocks (a JSON array); [decode] converts their text, tool calls
/// and tool results and drops thinking blocks.
abstract final class AssistantHistory {
  static String encode(ChatMessage message) => jsonEncode(message.toJson());

  /// The message of a stored row (null = nothing to replay). [toolNames]
  /// carries tool names from calls to the results of later rows (legacy
  /// results only have the call id).
  static ChatMessage? decode(
    String role,
    String? contentJson,
    Map<String, String> toolNames,
  ) {
    Object? json;
    try {
      json = jsonDecode(contentJson ?? '[]');
    } on FormatException {
      return null;
    }
    if (json is Map) {
      final m = ChatMessage.fromJson(json.cast<String, Object?>());
      for (final c in m.toolCalls) {
        toolNames[c.callId] = c.toolName;
      }
      return m.parts.isEmpty ? null : m;
    }
    if (json is! List || json.isEmpty) return null;
    final parts = <StandardPart>[];
    for (final b in json) {
      if (b is! Map) continue;
      switch (b['type']) {
        case 'text':
          final t = '${b['text'] ?? ''}';
          if (t.isNotEmpty) parts.add(TextPart(t));
        case 'tool_use':
          final id = '${b['id']}';
          final name = '${b['name']}';
          toolNames[id] = name;
          final input = b['input'];
          parts.add(
            ToolPart.call(
              callId: id,
              toolName: name,
              arguments: input is Map ? input.cast<String, Object?>() : {},
            ),
          );
        case 'tool_result':
          final id = '${b['tool_use_id']}';
          final content = b['content'];
          parts.add(
            ToolPart.result(
              callId: id,
              toolName: toolNames[id] ?? 'tool',
              result: content is String ? content : jsonEncode(content),
            ),
          );
      }
    }
    if (parts.isEmpty) return null;
    return ChatMessage(
      role: role == 'assistant' ? ChatMessageRole.model : ChatMessageRole.user,
      parts: parts,
    );
  }
}
