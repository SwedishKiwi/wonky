import 'package:flutter/foundation.dart';

/// UI-bridge hook (suite 03 §4, 09 §6): the MCP bridge client reports when an
/// agent is driving this window; the shell shows the control pill with
/// *Stop*, which calls [onStop] (disconnect the bridge for this session).
class McpControl extends ChangeNotifier {
  int _active = 0;
  String? _agentName;
  bool _enabled = kDebugMode;

  /// Called by *Stop* (and `shell.mcp.stopControl`).
  VoidCallback? onStop;

  /// Called when the user toggles "Allow MCP to control this window".
  ValueChanged<bool>? onEnabledChanged;

  /// Whether an agent call is in progress.
  bool get controlling => _active > 0;

  String? get agentName => _agentName;

  /// "Allow MCP to control this window" (per device; default on in debug).
  bool get enabled => _enabled;

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (!value) stop();
    onEnabledChanged?.call(value);
    notifyListeners();
  }

  /// A UI-bridge tool call started.
  void begin({String? agentName}) {
    _active++;
    _agentName = agentName ?? _agentName;
    notifyListeners();
  }

  /// A UI-bridge tool call finished.
  void end() {
    if (_active == 0) return;
    _active--;
    notifyListeners();
  }

  /// Stops agent control now.
  void stop() {
    _active = 0;
    onStop?.call();
    notifyListeners();
  }
}
