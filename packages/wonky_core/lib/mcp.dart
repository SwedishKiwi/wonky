/// MCP tool definitions shared by the server, the apps and the AI assistant
/// (suite 09 §3). App-specific tools (`write.*`, `sheets.*`, `ui.write.*`,
/// `ui.sheets.*`) are defined next to the app cores.
library;

import 'mcp/comments_tools.dart';
import 'mcp/drive_tools.dart';
import 'mcp/mcp_tool.dart';
import 'mcp/ui_tools.dart';

export 'mcp/comments_tools.dart';
export 'mcp/drive_tools.dart';
export 'mcp/mcp_tool.dart';
export 'mcp/ui_tools.dart';

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

  /// Looks up a shared tool by name.
  static McpToolDefinition? byName(String name) {
    for (final t in shared) {
      if (t.name == name) return t;
    }
    return null;
  }
}
