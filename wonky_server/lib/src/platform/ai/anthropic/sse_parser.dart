import 'dart:async';
import 'dart:convert';

import 'anthropic_types.dart';

/// Parses a Messages API server-sent-event byte stream into typed events.
///
/// SSE framing: `event:` / `data:` lines, a blank line ends an event,
/// lines starting with `:` are comments. The event type is read from the
/// JSON `type` (the `event:` line carries the same value). Unknown event
/// types are skipped so new API events don't break the client.
abstract final class SseParser {
  /// Events of [bytes].
  static Stream<AnthropicStreamEvent> parse(Stream<List<int>> bytes) =>
      parseLines(bytes.transform(utf8.decoder).transform(const LineSplitter()));

  /// Events of already split [lines].
  static Stream<AnthropicStreamEvent> parseLines(Stream<String> lines) async* {
    String? eventName;
    final data = StringBuffer();
    var hasData = false;
    await for (final line in lines) {
      if (line.isEmpty) {
        if (hasData) {
          final ev = decode(eventName, data.toString());
          if (ev != null) yield ev;
        }
        eventName = null;
        data.clear();
        hasData = false;
        continue;
      }
      if (line.startsWith(':')) continue;
      final colon = line.indexOf(':');
      final field = colon < 0 ? line : line.substring(0, colon);
      var value = colon < 0 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      switch (field) {
        case 'event':
          eventName = value;
        case 'data':
          if (hasData) data.write('\n');
          data.write(value);
          hasData = true;
      }
    }
    if (hasData) {
      final ev = decode(eventName, data.toString());
      if (ev != null) yield ev;
    }
  }

  /// Decodes one event's data; null for unknown or unparseable events.
  static AnthropicStreamEvent? decode(String? eventName, String data) {
    Object? json;
    try {
      json = jsonDecode(data);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final m = json.cast<String, Object?>();
    final type = (m['type'] as String?) ?? eventName;
    Map<String, Object?> map(Object? v) =>
        v is Map ? v.cast<String, Object?>() : <String, Object?>{};
    int index() => (m['index'] as num?)?.toInt() ?? 0;
    switch (type) {
      case 'message_start':
        final msg = map(m['message']);
        return MessageStartEvent(
          msg['id'] as String?,
          msg['model'] as String?,
          AnthropicUsage.fromJson(map(msg['usage'])),
        );
      case 'content_block_start':
        return ContentBlockStartEvent(index(), map(m['content_block']));
      case 'content_block_delta':
        return ContentBlockDeltaEvent(index(), map(m['delta']));
      case 'content_block_stop':
        return ContentBlockStopEvent(index());
      case 'message_delta':
        final delta = map(m['delta']);
        final details = delta['stop_details'];
        return MessageDeltaEvent(
          delta['stop_reason'] as String?,
          details is Map ? details.cast<String, Object?>() : null,
          AnthropicUsage.fromJson(map(m['usage'])),
        );
      case 'message_stop':
        return const MessageStopEvent();
      case 'ping':
        return const PingEvent();
      case 'error':
        final e = map(m['error']);
        return StreamErrorEvent(
          (e['type'] as String?) ?? 'api_error',
          (e['message'] as String?) ?? 'The model returned an error.',
        );
    }
    return null;
  }
}
