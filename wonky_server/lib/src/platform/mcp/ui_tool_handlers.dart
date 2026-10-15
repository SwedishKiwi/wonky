import 'package:wonky_core/wonky_core.dart'
    show
        McpToolDefinition,
        UiDriveTools,
        UiSheetsTools,
        UiSlidesTools,
        UiTools,
        UiWriteTools;

import 'tool_executor.dart';
import 'tool_support.dart';
import 'ui_bridge/ui_bridge_hub.dart';

/// UI-bridge tools (suite 09 §6, Write 09 §3, Sheets 12 §5, Drive 04 §13,
/// Slides 11 §5):
/// `ui.list_sessions` is answered by the hub; every other `ui.*` tool is
/// relayed to a live window of the token's user, which executes it
/// (commands run through its `CommandDispatcher` with source `mcp`).
abstract final class UiToolHandlers {
  static List<RegisteredMcpTool> get all => [
    RegisteredMcpTool(UiTools.listSessions, listSessions),
    for (final d in UiTools.all)
      if (d.name != UiTools.listSessions.name) _relay(d),
    for (final d in UiWriteTools.all) _relay(d, app: 'write'),
    for (final d in UiSheetsTools.all) _relay(d, app: 'sheets'),
    // (v2, P1) Implemented by Wonky Drive windows (Drive 04 §13).
    for (final d in UiDriveTools.all) _relay(d, app: 'drive'),
    // (v2) Implemented by Wonky Slides windows (Slides 11 §5, SL-42).
    for (final d in UiSlidesTools.all) _relay(d, app: 'slides'),
  ];

  static Future<ToolResult> listSessions(ToolContext ctx, ToolArgs a) async {
    final windows = await UiBridgeHub.listWindows(
      ctx.session,
      ctx.actor.userId,
    );
    return ToolResult(
      {
        'sessions': [for (final w in windows) w.toJson()],
      },
      text: windows.isEmpty
          ? 'No window allows MCP control. Open a Wonky Work app (Write, '
                'Sheets, Slides, Drive) and enable '
                'Settings › Developer › "Allow MCP to control this window".'
          : [
              for (final w in windows)
                '- ${w.sessionId}: ${w.app} ${w.json['route'] ?? ''}'
                    '${w.focused ? ' (focused)' : ''} — ${w.json['device']}',
            ].join('\n'),
    );
  }

  static RegisteredMcpTool _relay(McpToolDefinition d, {String? app}) =>
      RegisteredMcpTool(d, (ctx, a) async {
        final r = await UiBridgeHub.call(
          ctx.session,
          ctx.actor.userId,
          d.name,
          a.values,
          sessionId: a.string('session_id'),
          app: app,
          timeout: _timeout(d, a),
          agentName: ctx.agentLabel,
        );
        final structured = <String, Object?>{
          'session_id': r.window.sessionId,
          if (r.result is Map) ...(r.result! as Map).cast<String, Object?>(),
          if (r.result != null && r.result is! Map) 'result': r.result,
        };
        return ToolResult(
          structured,
          text: r.text,
          images: [if (r.imageBase64 != null) ToolImage(r.imageBase64!)],
        );
      });

  static Duration _timeout(McpToolDefinition d, ToolArgs a) {
    if (d.name == UiTools.waitFor.name) {
      final ms = a.integer('timeout_ms') ?? 30000;
      return Duration(milliseconds: ms + 5000);
    }
    return d.timeout ?? UiBridgeHub.defaultTimeout;
  }
}
