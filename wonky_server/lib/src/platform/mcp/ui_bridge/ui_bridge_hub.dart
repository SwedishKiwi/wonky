import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';

import '../../cluster/cluster.dart';
import '../../common/models.dart';
import '../tool_support.dart';

/// One live app window connected through `uiBridge.connect`.
class UiBridgeWindow {
  UiBridgeWindow({
    required this.session,
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

  /// The `uiBridge.connect` stream session (bus listeners live on it).
  final Session session;
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

  /// Bus listeners answering other instances (specs/13 §4).
  void Function(SerializableModel)? onUserChannel;
  void Function(SerializableModel)? onWindowChannel;

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

/// A window as seen by the instance serving an MCP request: connected to
/// this instance ([local]) or to another one (specs/13 §4).
class UiBridgeWindowInfo {
  UiBridgeWindowInfo._({
    required this.sessionId,
    required this.app,
    required this.tools,
    required this.focused,
    required this.connectedAt,
    required this.json,
    this.lastFocusedAt,
    this.local,
  });

  factory UiBridgeWindowInfo.of(UiBridgeWindow w) => UiBridgeWindowInfo._(
    sessionId: w.sessionId,
    app: w.app,
    tools: w.tools,
    focused: w.focused,
    connectedAt: w.connectedAt,
    lastFocusedAt: w.lastFocusedAt,
    json: w.toJson(),
    local: w,
  );

  /// A window described by another instance ([UiBridgeHub.describe]).
  static UiBridgeWindowInfo? fromRelay(Map<String, Object?> json) {
    final id = json['session_id'];
    final app = json['app'];
    final connected = DateTime.tryParse('${json['connected_at']}');
    if (id is! String || app is! String || connected == null) return null;
    final lastFocused = json['last_focused_at'];
    return UiBridgeWindowInfo._(
      sessionId: id,
      app: app,
      tools: {...?(json['tools'] as List?)?.whereType<String>()},
      focused: json['focused'] == true,
      connectedAt: connected,
      lastFocusedAt: lastFocused is String
          ? DateTime.tryParse(lastFocused)
          : null,
      json: {...json}..remove('tools'),
    );
  }

  final String sessionId;
  final String app;
  final Set<String> tools;
  bool focused;
  final DateTime connectedAt;
  final DateTime? lastFocusedAt;

  /// The `ui.list_sessions` entry.
  final Map<String, Object?> json;

  /// The window when it is connected to this instance.
  final UiBridgeWindow? local;

  Map<String, Object?> toJson() => {...json, 'focused': focused};
}

/// The result of a relayed `ui.*` call.
class UiBridgeResult {
  const UiBridgeResult({
    required this.window,
    this.result,
    this.text,
    this.imageBase64,
  });

  final UiBridgeWindowInfo window;
  final Object? result;
  final String? text;
  final String? imageBase64;
}

/// Registry of the live app windows of every user and relay of `ui.*` tool
/// calls to them (suite 09 §6.1). Windows connect to the instance that
/// serves their stream and are registered in memory there. With several
/// instances (specs/13 §4) the MCP request may land on another instance:
/// it then asks on the bus — every window listens on
/// `uibridge:user:<userId>` (who is there?) and `uibridge:window:<id>`
/// (calls) — and gets the answers on `uibridge:reply:<requestId>`.
abstract final class UiBridgeHub {
  static const defaultTimeout = Duration(seconds: 30);

  /// How long a listing waits for windows on other instances.
  static Duration remoteListWait = const Duration(milliseconds: 300);

  /// The `tool` of a listing request on the user channel.
  static const listRequest = '_list';

  static String userChannel(int userId) => 'uibridge:user:$userId';
  static String windowChannel(String sessionId) => 'uibridge:window:$sessionId';
  static String replyChannel(String requestId) => 'uibridge:reply:$requestId';

  static final Map<int, Map<String, UiBridgeWindow>> _byUser = {};
  static var _counter = 0;

  /// Registers a window from its hello message; [session] is its stream's
  /// session.
  static UiBridgeWindow register(
    Session session,
    int userId,
    UiBridgeHello hello,
    void Function(UiBridgeMessage) send,
  ) {
    _counter++;
    final id =
        'w${_counter.toRadixString(36)}-${const Uuid().v4().substring(0, 8)}';
    final window = UiBridgeWindow(
      session: session,
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
    _listen(window);
    return window;
  }

  /// Answers listings and calls from other instances.
  static void _listen(UiBridgeWindow window) {
    void onUser(SerializableModel m) {
      if (m is! UiBridgeRequest || m.tool != listRequest) return;
      final args = _decodeArgs(m.argsJson);
      if (args['origin'] == Cluster.instanceId) return;
      unawaited(
        _reply(
          window.session,
          m.requestId,
          UiBridgeResponse(
            requestId: m.requestId,
            ok: true,
            resultJson: jsonEncode(describe(window)),
          ),
        ),
      );
    }

    void onWindow(SerializableModel m) {
      if (m is! UiBridgeRequest || m.tool == listRequest) return;
      unawaited(_serveRemote(window, m));
    }

    window
      ..onUserChannel = onUser
      ..onWindowChannel = onWindow;
    window.session.messages.addListener(userChannel(window.userId), onUser);
    window.session.messages.addListener(
      windowChannel(window.sessionId),
      onWindow,
    );
  }

  /// The description of [window] sent to other instances.
  static Map<String, Object?> describe(UiBridgeWindow window) => {
    ...window.toJson(),
    'tools': window.tools.toList(),
  };

  static Map<String, Object?> _decodeArgs(String json) {
    try {
      final v = jsonDecode(json);
      return v is Map ? v.cast<String, Object?>() : const {};
    } on FormatException {
      return const {};
    }
  }

  static Future<void> _reply(
    Session session,
    String requestId,
    UiBridgeResponse response,
  ) async {
    try {
      await session.messages.postMessage(replyChannel(requestId), response);
    } on Object catch (e) {
      session.log('UI bridge reply failed: $e', level: LogLevel.warning);
    }
  }

  /// Executes a call relayed from another instance on [window].
  static Future<void> _serveRemote(
    UiBridgeWindow window,
    UiBridgeRequest request,
  ) async {
    UiBridgeResponse response;
    try {
      final r = await _relay(
        window,
        request.tool,
        request.argsJson,
        Duration(milliseconds: request.timeoutMs),
        request.agentName,
      );
      response = r.copyWith(requestId: request.requestId);
    } on McpToolException catch (e) {
      response = UiBridgeResponse(
        requestId: request.requestId,
        ok: false,
        errorCode: e.code,
        errorMessage: e.message,
        errorDetailsJson: e.details == null ? null : jsonEncode(e.details),
      );
    }
    await _reply(window.session, request.requestId, response);
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
    final onUser = window.onUserChannel;
    final onWindow = window.onWindowChannel;
    window
      ..onUserChannel = null
      ..onWindowChannel = null;
    if (onUser != null) {
      window.session.messages.removeListener(
        userChannel(window.userId),
        onUser,
      );
    }
    if (onWindow != null) {
      window.session.messages.removeListener(
        windowChannel(window.sessionId),
        onWindow,
      );
    }
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

  /// The user's windows on this instance, most recently focused first.
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

  /// The user's windows on every instance, most recently focused first.
  /// Only the most recently focused window counts as focused (each
  /// instance only knows the focus among its own windows).
  static Future<List<UiBridgeWindowInfo>> listWindows(
    Session session,
    int userId,
  ) async {
    final all = <String, UiBridgeWindowInfo>{
      for (final w in windowsOf(userId)) w.sessionId: UiBridgeWindowInfo.of(w),
    };
    if (Cluster.distributed) {
      for (final remote in await _listRemote(session, userId)) {
        all.putIfAbsent(remote.sessionId, () => remote);
      }
    }
    DateTime focusTime(UiBridgeWindowInfo w) =>
        w.lastFocusedAt ?? w.connectedAt;
    final list = all.values.toList()
      ..sort((a, b) {
        if (a.focused != b.focused) return a.focused ? -1 : 1;
        return focusTime(b).compareTo(focusTime(a));
      });
    var seenFocused = false;
    for (final w in list) {
      if (w.focused && seenFocused) w.focused = false;
      if (w.focused) seenFocused = true;
    }
    return list;
  }

  /// Asks the other instances for the user's windows.
  static Future<List<UiBridgeWindowInfo>> _listRemote(
    Session session,
    int userId,
  ) async {
    final requestId = const Uuid().v4();
    final found = <UiBridgeWindowInfo>[];
    void onReply(SerializableModel m) {
      if (m is! UiBridgeResponse || !m.ok || m.resultJson == null) return;
      try {
        final json = jsonDecode(m.resultJson!);
        if (json is! Map) return;
        final info = UiBridgeWindowInfo.fromRelay(json.cast());
        if (info != null) found.add(info);
      } on FormatException {
        return;
      }
    }

    final channel = replyChannel(requestId);
    session.messages.addListener(channel, onReply);
    try {
      // Publishing on the reply channel first waits until this instance
      // is subscribed to it, so no early answer is lost.
      await session.messages.postMessage(
        channel,
        UiBridgeCancel(requestId: requestId),
      );
      await session.messages.postMessage(
        userChannel(userId),
        UiBridgeRequest(
          requestId: requestId,
          tool: listRequest,
          argsJson: jsonEncode({'origin': Cluster.instanceId}),
          timeoutMs: remoteListWait.inMilliseconds,
        ),
      );
      await Future<void>.delayed(remoteListWait);
    } finally {
      session.messages.removeListener(channel, onReply);
    }
    return found;
  }

  /// Picks the target window among [windows]: [sessionId], else the most
  /// recently focused window (of [app] when given) that implements [tool].
  static UiBridgeWindowInfo pick(
    List<UiBridgeWindowInfo> windows, {
    String? sessionId,
    String? app,
    required String tool,
  }) {
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

  /// Relays [tool] with [args] to a window of [userId] (on any instance)
  /// and waits for its response.
  static Future<UiBridgeResult> call(
    Session session,
    int userId,
    String tool,
    Map<String, Object?> args, {
    String? sessionId,
    String? app,
    Duration? timeout,
    String? agentName,
  }) async {
    final local = sessionId == null ? null : _byUser[userId]?[sessionId];
    final window = local != null
        ? UiBridgeWindowInfo.of(local)
        : pick(
            await listWindows(session, userId),
            sessionId: sessionId,
            app: app,
            tool: tool,
          );
    if (local != null && !local.tools.contains(tool)) {
      throw McpToolException(
        McpErrorCode.unsupported,
        'The ${local.app} window does not support $tool.',
      );
    }
    final limit = timeout ?? defaultTimeout;
    final argsJson = jsonEncode({...args}..remove('session_id'));
    final response = window.local != null
        ? await _relay(window.local!, tool, argsJson, limit, agentName)
        : await _relayRemote(session, window, tool, argsJson, limit, agentName);
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

  /// Sends a request to a window of this instance and waits for the app's
  /// response (which may report an error).
  static Future<UiBridgeResponse> _relay(
    UiBridgeWindow window,
    String tool,
    String argsJson,
    Duration limit,
    String? agentName,
  ) async {
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
    window.send(
      UiBridgeRequest(
        requestId: requestId,
        tool: tool,
        argsJson: argsJson,
        agentName: agentName,
        timeoutMs: limit.inMilliseconds,
      ),
    );
    try {
      return await completer.future.timeout(limit);
    } on TimeoutException {
      window.pending.remove(requestId);
      window.send(UiBridgeCancel(requestId: requestId));
      throw McpToolException(
        McpErrorCode.timeout,
        'The window did not answer $tool within ${limit.inSeconds} s.',
      );
    }
  }

  /// Sends a request to a window on another instance and waits for the
  /// answer relayed back over the bus.
  static Future<UiBridgeResponse> _relayRemote(
    Session session,
    UiBridgeWindowInfo window,
    String tool,
    String argsJson,
    Duration limit,
    String? agentName,
  ) async {
    final requestId = const Uuid().v4();
    final completer = Completer<UiBridgeResponse>();
    void onReply(SerializableModel m) {
      if (m is UiBridgeResponse &&
          m.requestId == requestId &&
          !completer.isCompleted) {
        completer.complete(m);
      }
    }

    final channel = replyChannel(requestId);
    session.messages.addListener(channel, onReply);
    try {
      await session.messages.postMessage(
        channel,
        UiBridgeCancel(requestId: requestId),
      );
      await session.messages.postMessage(
        windowChannel(window.sessionId),
        UiBridgeRequest(
          requestId: requestId,
          tool: tool,
          argsJson: argsJson,
          agentName: agentName,
          timeoutMs: limit.inMilliseconds,
        ),
      );
      // The window's instance times out first and answers `timeout`; the
      // extra time covers the relay (or an instance that went away).
      return await completer.future.timeout(limit + remoteGrace);
    } on TimeoutException {
      throw McpToolException(
        McpErrorCode.timeout,
        'The window did not answer $tool within ${limit.inSeconds} s.',
      );
    } finally {
      session.messages.removeListener(channel, onReply);
    }
  }

  /// Extra time a relayed call waits for the other instance.
  static Duration remoteGrace = const Duration(seconds: 5);

  /// Drops every window (tests).
  static void clear() => _byUser.clear();
}
