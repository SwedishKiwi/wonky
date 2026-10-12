import '../src/commands/json_schema.dart';
import 'mcp_tool.dart';

const _session = JsonSchema.string(
  description:
      'Target window from ui.list_sessions; defaults to the most recently '
      'focused window of the user.',
);

ObjectSchema _withSession([
  Map<String, JsonSchema> props = const {},
  List<String> required = const [],
]) => ObjectSchema(properties: {'session_id': _session, ...props}, required: required);

/// Shared UI-bridge `ui.*` tools (suite 09 §6.2). Executed by the live app
/// window through `wonky_app`'s bridge client.
abstract final class UiTools {
  static const _scopes = {McpScope.uiControl};

  static const listSessions = McpToolDefinition(
    name: 'ui.list_sessions',
    title: 'List app windows',
    description:
        'Lists the user\'s live Wonky Write / Wonky Sheets windows that allow '
        'MCP control: session id, app, current route, open item, whether it '
        'is focused and when it was last active.',
    inputSchema: ObjectSchema(),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final getState = McpToolDefinition(
    name: 'ui.get_state',
    title: 'Get window state',
    description:
        'Returns the window\'s route, open item, mode (edit/suggest/view), '
        'selection summary, open dialog and panel, zoom, theme, online '
        'status and undo/redo labels.',
    inputSchema: _withSession(),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final navigate = McpToolDefinition(
    name: 'ui.navigate',
    title: 'Navigate',
    description:
        'Navigates the window to a route (e.g. "/d/<uuid>", '
        '"/settings/appearance") or opens an item by uuid. Items of the other '
        'app open that app in the same window.',
    inputSchema: _withSession({
      'route': JsonSchema.string(),
      'open_item_uuid': McpSchemas.uuid,
    }),
    scopes: _scopes,
  );

  static final listCommands = McpToolDefinition(
    name: 'ui.list_commands',
    title: 'List commands',
    description:
        'Lists every command available in the current context with id, '
        'title, description, args JSON schema, enabled, checked, shortcut and '
        'menu path. Use the ids with ui.invoke_command.',
    inputSchema: _withSession({
      'query': JsonSchema.string(description: 'Optional fuzzy filter.'),
    }),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final invokeCommand = McpToolDefinition(
    name: 'ui.invoke_command',
    title: 'Invoke a command',
    description:
        'Runs a command exactly as if the user picked it from a menu. The '
        'change lands on the user\'s undo stack as one step (labelled as an '
        'MCP action). Arguments must match the command\'s schema.',
    inputSchema: _withSession(
      {
        'command_id': JsonSchema.string(minLength: 1),
        'args': JsonSchema.object(additionalProperties: true),
      },
      ['command_id'],
    ),
    scopes: _scopes,
  );

  static final getMenuTree = McpToolDefinition(
    name: 'ui.get_menu_tree',
    title: 'Get the menu tree',
    description:
        'Returns the full menubar tree with each item\'s command id, label, '
        'enabled and checked state.',
    inputSchema: _withSession(),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final undo = McpToolDefinition(
    name: 'ui.undo',
    title: 'Undo',
    description: 'Undoes the last step on the user\'s undo stack (Edit › Undo).',
    inputSchema: _withSession(),
    scopes: _scopes,
  );

  static final redo = McpToolDefinition(
    name: 'ui.redo',
    title: 'Redo',
    description: 'Redoes the last undone step (Edit › Redo).',
    inputSchema: _withSession(),
    scopes: _scopes,
  );

  static final getDialog = McpToolDefinition(
    name: 'ui.get_dialog',
    title: 'Describe the open dialog',
    description:
        'Describes the open dialog: title, fields (id, label, type, value, '
        'options) and buttons. Returns null when no dialog is open.',
    inputSchema: _withSession(),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final fillDialog = McpToolDefinition(
    name: 'ui.fill_dialog',
    title: 'Fill dialog fields',
    description: 'Sets dialog fields by id: {"values": {"field_id": value}}.',
    inputSchema: _withSession(
      {'values': JsonSchema.object(additionalProperties: true)},
      ['values'],
    ),
    scopes: _scopes,
  );

  static final pressDialogButton = McpToolDefinition(
    name: 'ui.press_dialog_button',
    title: 'Press a dialog button',
    description: 'Presses a button of the open dialog by its id.',
    inputSchema: _withSession(
      {'button_id': JsonSchema.string(minLength: 1)},
      ['button_id'],
    ),
    scopes: _scopes,
  );

  static final closeDialog = McpToolDefinition(
    name: 'ui.close_dialog',
    title: 'Close the dialog',
    description: 'Closes the open dialog (like pressing Esc).',
    inputSchema: _withSession(),
    scopes: _scopes,
  );

  static final openPanel = McpToolDefinition(
    name: 'ui.open_panel',
    title: 'Open a side panel',
    description:
        'Opens a side panel by id (outline, comments, history, assistant, '
        'details, …).',
    inputSchema: _withSession(
      {'panel_id': JsonSchema.string(minLength: 1)},
      ['panel_id'],
    ),
    scopes: _scopes,
  );

  static final closePanel = McpToolDefinition(
    name: 'ui.close_panel',
    title: 'Close a side panel',
    description: 'Closes a side panel by id.',
    inputSchema: _withSession(
      {'panel_id': JsonSchema.string(minLength: 1)},
      ['panel_id'],
    ),
    scopes: _scopes,
  );

  static final setAppTheme = McpToolDefinition(
    name: 'ui.set_app_theme',
    title: 'Set the app theme',
    description: 'Switches the app theme: system, light or dark.',
    inputSchema: _withSession(
      {
        'mode': JsonSchema.string(enumValues: ['system', 'light', 'dark']),
      },
      ['mode'],
    ),
    annotations: McpToolAnnotations(idempotent: true),
    scopes: _scopes,
  );

  static final screenshot = McpToolDefinition(
    name: 'ui.screenshot',
    title: 'Take a screenshot',
    description:
        'Returns a PNG of the window (MCP image content). Optional region '
        '{x, y, width, height} in logical pixels and scale (0.1–2).',
    inputSchema: _withSession({
      'region': JsonSchema.object(
        properties: {
          'x': JsonSchema.number(),
          'y': JsonSchema.number(),
          'width': JsonSchema.number(minimum: 1),
          'height': JsonSchema.number(minimum: 1),
        },
        required: ['x', 'y', 'width', 'height'],
      ),
      'scale': JsonSchema.number(minimum: 0.1, maximum: 2),
    }),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final getSemantics = McpToolDefinition(
    name: 'ui.get_semantics',
    title: 'Get the accessibility tree',
    description:
        'Dumps the accessibility tree (role, label, value, bounds) for '
        'generic inspection.',
    inputSchema: _withSession(),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final typeText = McpToolDefinition(
    name: 'ui.type_text',
    title: 'Type text',
    description:
        'Types text into the focused element. Last resort: prefer commands.',
    inputSchema: _withSession({'text': JsonSchema.string()}, ['text']),
    scopes: _scopes,
  );

  static final pressKeys = McpToolDefinition(
    name: 'ui.press_keys',
    title: 'Press keys',
    description:
        'Sends key chords to the focused element, e.g. ["Mod+B", "Enter"]. '
        '"Mod" is ⌘ on macOS and Ctrl elsewhere. Last resort: prefer commands.',
    inputSchema: _withSession(
      {'keys': JsonSchema.array(JsonSchema.string(), minItems: 1)},
      ['keys'],
    ),
    scopes: _scopes,
  );

  static final waitFor = McpToolDefinition(
    name: 'ui.wait_for',
    title: 'Wait for a condition',
    description:
        'Waits until a condition holds or the timeout elapses: idle, synced, '
        'dialog_open, route_matches (with pattern).',
    inputSchema: _withSession(
      {
        'condition': JsonSchema.string(
          enumValues: ['idle', 'synced', 'dialog_open', 'route_matches'],
        ),
        'pattern': JsonSchema.string(),
        'timeout_ms': JsonSchema.integer(minimum: 0, maximum: 120000),
      },
      ['condition'],
    ),
    annotations: McpToolAnnotations.read,
    timeout: Duration(seconds: 120),
    scopes: _scopes,
  );

  static final events = McpToolDefinition(
    name: 'ui.events',
    title: 'Poll window events',
    description:
        'Returns events since cursor (command invocations, route changes, '
        'errors) for polling agents, plus the next cursor.',
    inputSchema: _withSession({'cursor': JsonSchema.integer(minimum: 0)}),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final all = [
    listSessions,
    getState,
    navigate,
    listCommands,
    invokeCommand,
    getMenuTree,
    undo,
    redo,
    getDialog,
    fillDialog,
    pressDialogButton,
    closeDialog,
    openPanel,
    closePanel,
    setAppTheme,
    screenshot,
    getSemantics,
    typeText,
    pressKeys,
    waitFor,
    events,
  ];
}
