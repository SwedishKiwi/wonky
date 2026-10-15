import 'package:flutter/widgets.dart';
import 'package:wonky_client/wonky_client.dart';

import '../shell/shell_services.dart';
import 'mcp_bridge_client.dart';
import 'ui_tool.dart';

/// The bridge of each shell (for the settings section).
final Expando<McpBridgeClient> _bridges = Expando('mcpBridge');

/// The UI bridge of [services], once the shell built its [McpBridgeScope].
McpBridgeClient? mcpBridgeOf(ShellServices services) => _bridges[services];

/// Hosts the MCP UI bridge for the whole window (suite 09 §6): wraps the app
/// in the `RepaintBoundary` ([ShellServices.screenshotBoundary]) used by
/// `ui.screenshot` and `captureAppScreenshot`, runs the bridge while
/// the user is signed in and "Allow MCP to control this window" is on (and
/// the server enables the bridge), and reports route, open item and window
/// focus changes to the hub.
class McpBridgeScope extends StatefulWidget {
  const McpBridgeScope({
    super.key,
    required this.services,
    required this.child,
    this.appTools = const {},
  });

  final ShellServices services;

  /// App-specific tools (`ui.write.*`).
  final Map<String, UiToolHandler> appTools;
  final Widget child;

  @override
  State<McpBridgeScope> createState() => _McpBridgeScopeState();
}

class _McpBridgeScopeState extends State<McpBridgeScope> {
  late final McpBridgeClient _bridge;
  late final AppLifecycleListener _lifecycle;

  ShellServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    _bridge = McpBridgeClient(
      s,
      boundaryKey: s.screenshotBoundary,
      appTools: widget.appTools,
    );
    _bridges[s] = _bridge;
    s.mcp.onStop = _bridge.stopControl;
    s.auth.addListener(_sync);
    s.mcp.addListener(_sync);
    s.serverInfo.addListener(_onServerInfo);
    s.currentItem.addListener(_bridge.reportStatus);
    s.router.routerDelegate.addListener(_bridge.reportStatus);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final focused = state == AppLifecycleState.resumed;
        if (focused == _bridge.focused) return;
        _bridge.focused = focused;
        _bridge.reportStatus();
      },
    );
    _onServerInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  /// Development servers default the bridge to on (suite 09 §6.1) unless
  /// the user chose otherwise on this device.
  void _onServerInfo() {
    final info = s.serverInfo.value;
    if (info == null) return;
    if (s.prefs.device<bool>('mcp.uiBridge') == null &&
        info.runMode == 'development' &&
        !s.mcp.enabled) {
      s.mcp.setEnabled(true);
    }
    _sync();
  }

  bool get _allowedByServer {
    final ProtocolInfo? info = s.serverInfo.value;
    return info == null || info.features.mcpUiBridge;
  }

  void _sync() {
    if (!mounted) return;
    final run = s.auth.isSignedIn && s.mcp.enabled && _allowedByServer;
    if (run && !_bridge.started) {
      _bridge.start();
    } else if (!run && _bridge.started) {
      _bridge.stop();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    s.auth.removeListener(_sync);
    s.mcp.removeListener(_sync);
    s.serverInfo.removeListener(_onServerInfo);
    s.currentItem.removeListener(_bridge.reportStatus);
    s.router.routerDelegate.removeListener(_bridge.reportStatus);
    if (s.mcp.onStop == _bridge.stopControl) s.mcp.onStop = null;
    _bridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(key: s.screenshotBoundary, child: widget.child);
}
