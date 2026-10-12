/// MCP tool definitions shared by the server, the apps and the AI assistant
/// (suite 09 §3): one file per namespace. The Write tools (`write.*`,
/// `ui.write.*`) live here too so the server can list them without
/// depending on the Write app.
library;

import 'mcp/comments_tools.dart';
import 'mcp/drive_tools.dart';
import 'mcp/mcp_tool.dart';
import 'mcp/ui_tools.dart';
import 'mcp/write_tools.dart';

export 'mcp/comments_tools.dart';
export 'mcp/drive_tools.dart';
export 'mcp/mcp_tool.dart';
export 'mcp/ui_tools.dart';
export 'mcp/write_tools.dart';

/// All shared tool definitions.
abstract final class McpToolCatalog {
  /// Headless + UI-bridge tools defined in `wonky_core`.
  static final List<McpToolDefinition> shared = [
    ...DriveTools.all,
    ...CommentsTools.all,
    ...VersionsTools.all,
    ...ChangesTools.all,
    ...UiTools.all,
  ];

  /// Every tool the Wonky Write server and app offer: the shared tools plus
  /// `write.*` and `ui.write.*` (Sheets tools are paused).
  static final List<McpToolDefinition> write = [
    ...shared,
    ...WriteTools.all,
    ...UiWriteTools.all,
  ];

  /// Looks up a shared tool by name.
  static McpToolDefinition? byName(String name) {
    for (final t in write) {
      if (t.name == name) return t;
    }
    return null;
  }
}
