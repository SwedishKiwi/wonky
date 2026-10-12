import 'package:flutter/widgets.dart';

import '../shell/shell_services.dart';

/// A failure of a UI-bridge tool, reported to the MCP client as
/// `{code, message, details}` (suite 09 §7).
class UiToolException implements Exception {
  const UiToolException(this.code, this.message, {this.details});

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => 'UiToolException($code: $message)';
}

/// The result of a UI-bridge tool.
class UiToolResult {
  const UiToolResult(this.result, {this.text, this.imageBase64});

  /// JSON-serializable structured result.
  final Map<String, Object?> result;

  /// Short human-readable summary.
  final String? text;

  /// Base64 PNG (screenshots).
  final String? imageBase64;
}

/// Everything a UI tool can use while running in this window.
class UiToolContext {
  UiToolContext({
    required this.services,
    required this.boundaryKey,
    required this.events,
    this.agentName,
  });

  final ShellServices services;

  /// The `RepaintBoundary` around the whole app (`ui.screenshot`).
  final GlobalKey boundaryKey;

  /// The window's event log (`ui.events`).
  final UiEventLog events;

  /// Who is calling ("Claude Code (MCP)").
  final String? agentName;

  BuildContext? get context => services.navigatorContext;

  /// The navigator context or a `no_context` failure.
  BuildContext requireContext() {
    final c = context;
    if (c == null || !c.mounted) {
      throw const UiToolException(
        'unavailable',
        'The window is not ready yet.',
      );
    }
    return c;
  }
}

/// A `ui.*` tool implementation.
typedef UiToolHandler =
    Future<UiToolResult> Function(UiToolContext ctx, Map<String, Object?> args);

/// One entry of the window's event log.
class UiEvent {
  UiEvent(this.seq, this.at, this.type, this.data);

  final int seq;
  final DateTime at;

  /// `command`, `route`, `dialog`, `error`, `tool`.
  final String type;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {
    'seq': seq,
    'at': at.toUtc().toIso8601String(),
    'type': type,
    ...data,
  };
}

/// Ring buffer of window events for `ui.events` (polling agents).
class UiEventLog {
  UiEventLog({this.capacity = 500});

  final int capacity;
  final List<UiEvent> _events = [];
  int _seq = 0;

  int get lastSeq => _seq;

  void add(String type, Map<String, Object?> data) {
    _seq++;
    _events.add(UiEvent(_seq, DateTime.now(), type, data));
    if (_events.length > capacity) _events.removeAt(0);
  }

  /// Events after [cursor] (all retained ones when null).
  List<UiEvent> since(int? cursor) => [
    for (final e in _events)
      if (cursor == null || e.seq > cursor) e,
  ];
}

/// Waits for the next frame so a UI change is visible to the following
/// read; bounded, since headless test bindings don't pump frames.
Future<void> uiSettle() => WidgetsBinding.instance.endOfFrame.timeout(
  const Duration(milliseconds: 500),
  onTimeout: () {},
);
