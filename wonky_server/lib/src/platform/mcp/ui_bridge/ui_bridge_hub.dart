import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';

import '../../common/models.dart';
import '../tool_support.dart';

/// One live app window connected through `uiBridge.connect`.
class UiBridgeWindow {
  UiBridgeWindow({
    required this.sessionId,
    required this.userId,
    required this.app,
    required this.deviceLabel,
    required this.platform,
    required this.tools,
    required this.send,
    this.route,
    this.openItemUuid,
    this.title,
    this.focused = false,
  }) : connectedAt = clock.now(),
       lastActiveAt = clock.now(),
       lastFocusedAt = focused ? clock.now() : null;

  final String sessionId;
  final int userId;
  final String app;
  final String deviceLabel;
  final String platform;
  final Set<String> tools;
  final void Function(UiBridgeMessage message) send;
  final DateTime connectedAt;

  String? route;
  String? openItemUuid;
  String? title;
  bool focused;
  DateTime lastActiveAt;
  DateTime? lastFocusedAt;

  /// Calls fail until then (the user pressed *Stop*).
  DateTime? pausedUntil;

  final Map<String, Completer<UiBridgeResponse>> pending = {};

  Map<String, Object?> toJson() => {
    'session_id': sessionId,
    'app': app,
    'device': deviceLabel,
    'platform': platform,
    'route': route,
    'open_item_uuid': openItemUuid,
    'title': title,
    'focused': focused,
    'last_active_at': lastActiveAt.toUtc().toIso8601String(),
    'last_focused_at': lastFocusedAt?.toUtc().toIso8601String(),
    'connected_at': connectedAt.toUtc().toIso8601String(),
    if (pausedUntil != null && pausedUntil!.isAfter(clock.now()))
      'paused_until': pausedUntil!.toUtc().toIso8601String(),
  };
}

/// The result of a relayed `ui.*` call.
class UiBridgeResult {
  const UiBridgeResult({
    required this.window,
    this.result,
    this.text,
    this.imageBase64,
  });

  final UiBridgeWindow window;
  final Object? result;
  final String? text;
  final String? imageBase64;
}

/// Registry of the live app windows of every user and relay of `ui.*` tool
/// calls to them (suite 09 §6.1). In-memory per server instance: windows
/// connect to the instance that serves their stream, so with several
/// instances an MCP client reaches the windows connected to the instance
/// that serves its `/mcp` requests.
abstract final class UiBridgeHub {
  static const defaultTimeout = Duration(seconds: 30);

  static final Map<int, Map<String, UiBridgeWindow>> _byUser = {};
  static var _counter = 0;

  /// Registers a window from its hello message.
  static UiBridgeWindow register(
    int userId,
    UiBridgeHello hello,
    void Function(UiBridgeMessage) send,
  ) {
    _counter++;
    final id =
        'w${_counter.toRadixString(36)}-${const Uuid().v4().substring(0, 8)}';
    final window = UiBridgeWindow(
      sessionId: id,
      userId: userId,
      app: hello.app,
      deviceLabel: hello.deviceLabel,
      platform: hello.platform,
      tools: hello.tools.toSet(),
      send: send,
      route: hello.route,
      openItemUuid: hello.openItemUuid,
      title: hello.title,
      focused: hello.focused,
    );
    _byUser.putIfAbsent(userId, () => {})[id] = window;
    if (hello.focused) _focus(window);
    return window;
  }

  /// Applies a status update.
  static void update(UiBridgeWindow window, UiBridgeStatus status) {
    window
      ..route = status.route
      ..openItemUuid = status.openItemUuid
      ..title = status.title
      ..lastActiveAt = clock.now();
    if (status.focused) {
      _focus(window);
    } else {
      window.focused = false;
    }
  }

  static void _focus(UiBridgeWindow window) {
    for (final w in _byUser[window.userId]?.values ?? <UiBridgeWindow>[]) {
      if (w != window) w.focused = false;
    }
    window
      ..focused = true
      ..lastFocusedAt = clock.now();
  }

  /// Removes a window; its pending calls fail.
  static void unregister(UiBridgeWindow window) {
    final windows = _byUser[window.userId];
    windows?.remove(window.sessionId);
    if (windows != null && windows.isEmpty) _byUser.remove(window.userId);
    for (final c in window.pending.values) {
      if (!c.isCompleted) {
        c.completeError(
          McpToolException(
            McpErrorCode.noSession,
            'The window was closed or lost its connection.',
          ),
        );
      }
    }
    window.pending.clear();
  }

  /// A response from the app.
  static void complete(UiBridgeWindow window, UiBridgeResponse response) {
    window.lastActiveAt = clock.now();
    final c = window.pending.remove(response.requestId);
    if (c != null && !c.isCompleted) c.complete(response);
  }

  /// The user pressed *Stop*: pending calls fail and new ones are refused
  /// for [pause].
  static void stop(UiBridgeWindow window, Duration pause) {
    window.pausedUntil = clock.now().add(pause);
    for (final c in window.pending.values) {
      if (!c.isCompleted) {
        c.completeError(
          McpToolException(
            McpErrorCode.stoppedByUser,
            'The user stopped MCP control of this window.',
          ),
        );
      }
    }
    window.pending.clear();
  }

  /// The user's windows, most recently focused first.
  static List<UiBridgeWindow> windowsOf(int userId) {
    final list = [...?_byUser[userId]?.values];
    list.sort((a, b) {
      if (a.focused != b.focused) return a.focused ? -1 : 1;
      final fa = a.lastFocusedAt ?? a.connectedAt;
      final fb = b.lastFocusedAt ?? b.connectedAt;
      return fb.compareTo(fa);
    });
    return list;
  }

  /// Picks the target window: [sessionId], else the most recently focused
  /// window (of [app] when given) that implements [tool].
  static UiBridgeWindow pick(
    int userId, {
    String? sessionId,
    String? app,
    required String tool,
  }) {
    final windows = windowsOf(userId);
    if (sessionId != null) {
      final w = windows.where((w) => w.sessionId == sessionId).firstOrNull;
      if (w == null) {
        throw McpToolException(
          McpErrorCode.noSession,
          'No window with session_id "$sessionId". Call ui.list_sessions.',
        );
      }
      if (!w.tools.contains(tool)) {
        throw McpToolException(
          McpErrorCode.unsupported,
          'The ${w.app} window does not support $tool.',
        );
      }
      return w;
    }
    final candidates = [
      for (final w in windows)
        if ((app == null || w.app == app) && w.tools.contains(tool)) w,
    ];
    if (candidates.isEmpty) {
      throw McpToolException(
        McpErrorCode.noSession,
        windows.isEmpty
            ? 'No Wonky window of this user allows MCP control. Open Wonky '
                  'Write, sign in and turn on Settings › Developer › "Allow '
                  'MCP to control this window".'
            : 'None of the open windows supports $tool.',
      );
    }
    return candidates.first;
  }

  /// Relays [tool] with [args] to a window and waits for its response.
  static Future<UiBridgeResult> call(
    int userId,
    String tool,
    Map<String, Object?> args, {
    String? sessionId,
    String? app,
    Duration? timeout,
    String? agentName,
  }) async {
    final window = pick(userId, sessionId: sessionId, app: app, tool: tool);
    final paused = window.pausedUntil;
    if (paused != null && paused.isAfter(clock.now())) {
      throw McpToolException(
        McpErrorCode.stoppedByUser,
        'The user stopped MCP control of this window; try again later.',
        details: {'paused_until': paused.toUtc().toIso8601String()},
      );
    }
    final requestId = const Uuid().v4();
    final completer = Completer<UiBridgeResponse>();
    window.pending[requestId] = completer;
    final limit = timeout ?? defaultTimeout;
    window.send(
      UiBridgeRequest(
        requestId: requestId,
        tool: tool,
        argsJson: jsonEncode({...args}..remove('session_id')),
        agentName: agentName,
        timeoutMs: limit.inMilliseconds,
      ),
    );
    UiBridgeResponse response;
    try {
      response = await completer.future.timeout(limit);
    } on TimeoutException {
      window.pending.remove(requestId);
      window.send(UiBridgeCancel(requestId: requestId));
      throw McpToolException(
        McpErrorCode.timeout,
        'The window did not answer $tool within ${limit.inSeconds} s.',
      );
    }
    if (!response.ok) {
      Object? details;
      final raw = response.errorDetailsJson;
      if (raw != null) {
        try {
          details = jsonDecode(raw);
        } on FormatException {
          details = raw;
        }
      }
      throw McpToolException(
        response.errorCode ?? McpErrorCode.internal,
        response.errorMessage ?? '$tool failed in the app.',
        details: details,
      );
    }
    return UiBridgeResult(
      window: window,
      result: response.resultJson == null
          ? null
          : jsonDecode(response.resultJson!),
      text: response.text,
      imageBase64: response.imageBase64,
    );
  }

  /// Drops every window (tests).
  static void clear() => _byUser.clear();
}
