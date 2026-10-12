import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_client/wonky_client.dart';

import '../commands/command_dispatcher.dart';
import '../shell/shell_services.dart';
import 'shared_ui_tools.dart';
import 'ui_tool.dart';

/// Connection state of the UI bridge (Settings › Developer status).
enum McpBridgeState {
  /// Off ("Allow MCP to control this window" is off or signed out).
  off,

  /// Connecting / reconnecting.
  connecting,

  /// Registered with the server's hub.
  connected,
}

/// The client side of the MCP UI bridge (suite 09 §6): keeps the
/// `uiBridge.connect` stream open while the user allows MCP control,
/// registers the window (app, route, open item, focus, supported tools),
/// executes relayed `ui.*` tool calls and reports results, and drives the
/// MCP control pill (`McpControl`) while calls run.
class McpBridgeClient {
  McpBridgeClient(
    this.services, {
    required this.boundaryKey,
    Map<String, UiToolHandler> appTools = const {},
  }) : tools = {...SharedUiTools.all, ...appTools};

  static const supervisorKey = 'mcp.uiBridge';

  /// How long *Stop* blocks further calls to this window.
  static const stopPause = Duration(seconds: 30);

  final ShellServices services;
  final GlobalKey boundaryKey;

  /// Tool name → implementation (shared `ui.*` plus app extensions).
  final Map<String, UiToolHandler> tools;

  final UiEventLog events = UiEventLog();

  final ValueNotifier<McpBridgeState> state = ValueNotifier(McpBridgeState.off);

  /// The hub's id of this window while connected.
  final ValueNotifier<String?> sessionId = ValueNotifier(null);

  StreamController<UiBridgeMessage>? _out;
  StreamSubscription<CommandInvoked>? _commands;
  final Map<String, _Running> _running = {};
  bool _started = false;
  bool focused = true;
  Timer? _statusDebounce;
  String? _lastStatus;

  bool get started => _started;

  /// Starts the bridge (idempotent).
  void start() {
    final client = services.client;
    if (_started || client == null) return;
    _started = true;
    state.value = McpBridgeState.connecting;
    _commands = services.dispatcher.events.listen(_onCommand);
    services.supervisor.supervise<UiBridgeMessage>(
      supervisorKey,
      () {
        final out = StreamController<UiBridgeMessage>();
        _out?.close();
        _out = out;
        state.value = McpBridgeState.connecting;
        out.add(_hello());
        return client.uiBridge.connect(out.stream);
      },
      _onMessage,
      onError: (e) {
        state.value = McpBridgeState.connecting;
        sessionId.value = null;
      },
    );
  }

  /// Stops the bridge and fails running calls.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _statusDebounce?.cancel();
    for (final r in _running.values) {
      r.cancelled = true;
    }
    _running.clear();
    while (services.mcp.controlling) {
      services.mcp.end();
    }
    await _commands?.cancel();
    _commands = null;
    await services.supervisor.cancel(supervisorKey);
    await _out?.close();
    _out = null;
    sessionId.value = null;
    state.value = McpBridgeState.off;
  }

  /// The user pressed *Stop* on the control pill.
  void stopControl() {
    for (final r in _running.values) {
      r.cancelled = true;
      _send(
        UiBridgeResponse(
          requestId: r.requestId,
          ok: false,
          errorCode: 'stopped_by_user',
          errorMessage: 'The user stopped MCP control of this window.',
        ),
      );
    }
    _running.clear();
    _send(UiBridgeStop(pauseMs: stopPause.inMilliseconds));
    events.add('stopped', const {});
  }

  void _send(UiBridgeMessage m) {
    final out = _out;
    if (out != null && !out.isClosed) out.add(m);
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  static String _deviceLabel() {
    final os = switch (defaultTargetPlatform) {
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.android => 'Android',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
    return kIsWeb ? 'Browser on $os' : 'Desktop app on $os';
  }

  ({String route, String? item, String? title}) _location() {
    final route = SharedUiTools.routeOf(_ctx());
    final item = services.currentItem.value;
    return (route: route, item: item?.uuid.uuid, title: item?.name);
  }

  UiBridgeHello _hello() {
    final l = _location();
    return UiBridgeHello(
      app: services.config.app.name,
      deviceLabel: _deviceLabel(),
      platform: _platformName(),
      route: l.route,
      openItemUuid: l.item,
      title: l.title,
      focused: focused,
      tools: tools.keys.toList()..sort(),
    );
  }

  /// Reports route / open item / focus changes (debounced).
  void reportStatus() {
    if (!_started) return;
    _statusDebounce?.cancel();
    _statusDebounce = Timer(const Duration(milliseconds: 200), () {
      final l = _location();
      final key = '${l.route}|${l.item}|$focused';
      if (key == _lastStatus) return;
      if (_lastStatus != null && !_lastStatus!.startsWith('${l.route}|')) {
        events.add('route', {'route': l.route});
      }
      _lastStatus = key;
      _send(
        UiBridgeStatus(
          route: l.route,
          openItemUuid: l.item,
          title: l.title,
          focused: focused,
        ),
      );
    });
  }

  void _onCommand(CommandInvoked e) {
    events.add('command', {
      'command_id': e.id.value,
      'source': e.source.name,
      'status': e.result?.status.name ?? (e.error == null ? null : 'error'),
      if (e.error != null) 'error': '${e.error}',
    });
  }

  UiToolContext _ctx({String? agentName}) => UiToolContext(
    services: services,
    boundaryKey: boundaryKey,
    events: events,
    agentName: agentName,
  );

  void _onMessage(UiBridgeMessage m) {
    switch (m) {
      case UiBridgeWelcome():
        sessionId.value = m.sessionId;
        state.value = McpBridgeState.connected;
        _lastStatus = null;
        reportStatus();
      case UiBridgeRequest():
        unawaited(_run(m));
      case UiBridgeCancel():
        _running.remove(m.requestId)?.cancelled = true;
      default:
        break;
    }
  }

  Future<void> _run(UiBridgeRequest request) async {
    final running = _Running(request.requestId);
    _running[request.requestId] = running;
    final response = await execute(request);
    final stillRunning = _running.remove(request.requestId) != null;
    if (stillRunning && !running.cancelled) _send(response);
    reportStatus();
  }

  /// Runs one relayed tool call and builds its response (shows the control
  /// pill while it runs).
  Future<UiBridgeResponse> execute(UiBridgeRequest request) async {
    final handler = tools[request.tool];
    if (handler == null) {
      return UiBridgeResponse(
        requestId: request.requestId,
        ok: false,
        errorCode: 'unsupported',
        errorMessage: 'This window does not support ${request.tool}.',
      );
    }
    services.mcp.begin(agentName: request.agentName);
    events.add('tool', {'tool': request.tool, 'agent': request.agentName});
    try {
      final args = (jsonDecode(request.argsJson) as Map)
          .cast<String, Object?>();
      final r = await handler(_ctx(agentName: request.agentName), args);
      return UiBridgeResponse(
        requestId: request.requestId,
        ok: true,
        resultJson: jsonEncode(r.result, toEncodable: (o) => '$o'),
        text: r.text,
        imageBase64: r.imageBase64,
      );
    } on UiToolException catch (e) {
      return UiBridgeResponse(
        requestId: request.requestId,
        ok: false,
        errorCode: e.code,
        errorMessage: e.message,
        errorDetailsJson: e.details == null
            ? null
            : jsonEncode(e.details, toEncodable: (o) => '$o'),
      );
    } catch (e, st) {
      debugPrint('MCP UI tool ${request.tool} failed: $e\n$st');
      events.add('error', {'tool': request.tool, 'error': '$e'});
      return UiBridgeResponse(
        requestId: request.requestId,
        ok: false,
        errorCode: 'internal_error',
        errorMessage: '$e',
      );
    } finally {
      if (services.mcp.controlling) services.mcp.end();
    }
  }

  void dispose() {
    unawaited(stop());
    state.dispose();
    sessionId.dispose();
  }
}

class _Running {
  _Running(this.requestId);
  final String requestId;
  bool cancelled = false;
}
