import '../src/commands/json_schema.dart';
import 'mcp_tool.dart';

/// Wonky Sheets UI-bridge tools (`ui.sheets.*`, Sheets 12 §5), executed in
/// the live Wonky Sheets window on the open spreadsheet. Actions are
/// commands (`ui.invoke_command` with `sheets.*` ids); these tools cover
/// window state and things that aren't commands.
abstract final class UiSheetsTools {
  static const _scopes = {McpScope.uiControl};
  static const _session = JsonSchema.string(
    description:
        'Target window from ui.list_sessions; defaults to the most recently '
        'focused Wonky Sheets window.',
  );

  static ObjectSchema _schema([
    Map<String, JsonSchema> props = const {},
    List<String> required = const [],
  ]) => ObjectSchema(
    properties: {'session_id': _session, ...props},
    required: required,
  );

  static const _a1 = JsonSchema.string(
    minLength: 1,
    maxLength: 500,
    description:
        'A1 reference: "B4", "A1:C10", "Sheet2!B:B", "\'Q3 Plan\'!5:5" or a '
        'named range.',
  );

  /// Panel names of [openPanel].
  static const panels = [
    'chartEditor',
    'conditionalFormatting',
    'dataValidation',
    'pivotEditor',
    'namedRanges',
    'protectedRanges',
    'comments',
    'history',
    'assistant',
    'explore',
    'executions',
    'scriptSidebar',
    'slicer',
  ];

  static final getSelection = McpToolDefinition(
    name: 'ui.sheets.get_selection',
    title: 'Get the selection',
    description:
        'Returns the selection of the open spreadsheet: sheet, active cell, '
        'selected A1 ranges, whether a cell is being edited (and the editor '
        'text), the selected chart/image, up to 100 values of the active '
        'range and the status-bar statistics (sum, average, count).',
    inputSchema: _schema(),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final selectRange = McpToolDefinition(
    name: 'ui.sheets.select_range',
    title: 'Select ranges',
    description:
        'Selects A1 ranges (on one sheet; the sheet of the first range, or '
        '`sheet`) and scrolls them into view. Example: {"ranges": '
        '["B2:D9", "F2"], "active_cell": "C4"}.',
    inputSchema: _schema(
      {
        'ranges': const JsonSchema.array(_a1, minItems: 1, maxItems: 50),
        'active_cell': _a1,
        'sheet': const JsonSchema.string(minLength: 1),
      },
      ['ranges'],
    ),
    scopes: _scopes,
  );

  static final getVisibleRange = McpToolDefinition(
    name: 'ui.sheets.get_visible_range',
    title: 'Get the visible range',
    description:
        'Returns the sheet and A1 range visible in the grid, the frozen rows '
        'and columns and the zoom (percent).',
    inputSchema: _schema(),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final activateSheet = McpToolDefinition(
    name: 'ui.sheets.activate_sheet',
    title: 'Activate a sheet',
    description: 'Shows a sheet (by name or id) in the grid.',
    inputSchema: _schema(
      {'sheet': const JsonSchema.string(minLength: 1)},
      ['sheet'],
    ),
    scopes: _scopes,
  );

  static final scrollTo = McpToolDefinition(
    name: 'ui.sheets.scroll_to',
    title: 'Scroll to a cell',
    description:
        'Scrolls the grid so that a cell is visible (align top_left or '
        'center) without changing the selection.',
    inputSchema: _schema(
      {
        'cell': _a1,
        'align': const JsonSchema.string(enumValues: ['top_left', 'center']),
      },
      ['cell'],
    ),
    scopes: _scopes,
  );

  static final openPanel = McpToolDefinition(
    name: 'ui.sheets.open_panel',
    title: 'Open a panel',
    description:
        'Opens a Sheets side panel: ${panels.join(', ')}. `target` selects '
        'what the panel edits ({"chart_id"}, {"pivot_id"} or {"rule_id"}).',
    inputSchema: _schema(
      {
        'panel': const JsonSchema.string(enumValues: panels),
        'target': const JsonSchema.object(
          properties: {
            'chart_id': JsonSchema.string(),
            'pivot_id': JsonSchema.string(),
            'rule_id': JsonSchema.string(),
          },
        ),
      },
      ['panel'],
    ),
    scopes: _scopes,
  );

  static final closePanel = McpToolDefinition(
    name: 'ui.sheets.close_panel',
    title: 'Close a panel',
    description:
        'Collapses the open side panel (or `panel`, a name of '
        'ui.sheets.open_panel) to the icon rail.',
    inputSchema: _schema({
      'panel': const JsonSchema.string(enumValues: panels),
    }),
    scopes: _scopes,
  );

  static final startCellEdit = McpToolDefinition(
    name: 'ui.sheets.start_cell_edit',
    title: 'Start editing a cell',
    description:
        'Opens the cell editor on `cell` (default: the active cell), '
        'optionally replacing its text with `initial_text`. For demos and '
        'tests; prefer the command sheets.cell.setInput {a1, input} to '
        'write.',
    inputSchema: _schema({
      'cell': _a1,
      'initial_text': const JsonSchema.string(maxLength: 50000),
    }),
    scopes: _scopes,
  );

  static final typeInCell = McpToolDefinition(
    name: 'ui.sheets.type_in_cell',
    title: 'Type into a cell',
    description:
        'Types text into the cell editor of `cell` through the same path as '
        'the keyboard (formula autocomplete, point mode) and commits with '
        'Enter or Tab (commit: none leaves the editor open). Last resort.',
    inputSchema: _schema(
      {
        'cell': _a1,
        'text': const JsonSchema.string(maxLength: 50000),
        'commit': const JsonSchema.string(
          enumValues: ['enter', 'tab', 'none'],
          defaultValue: 'enter',
        ),
      },
      ['cell', 'text'],
    ),
    scopes: _scopes,
  );

  static final screenshotRange = McpToolDefinition(
    name: 'ui.sheets.screenshot_range',
    title: 'Screenshot a range',
    description:
        'Returns a PNG of a range as rendered (formats, conditional '
        'formatting, gridlines), drawn offscreen independent of the scroll '
        'position; at most 4,000 × 4,000 px. Optional row/column headers.',
    inputSchema: _schema(
      {
        'range': _a1,
        'scale': const JsonSchema.integer(minimum: 1, maximum: 2),
        'include_headers': const JsonSchema.boolean(defaultValue: false),
      },
      ['range'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final highlightRange = McpToolDefinition(
    name: 'ui.sheets.highlight_range',
    title: 'Highlight a range',
    description:
        'Flashes an outline around a range to draw the user\'s attention '
        '(activates its sheet and scrolls it into view). Color #RRGGBB.',
    inputSchema: _schema(
      {
        'range': _a1,
        'duration_ms': const JsonSchema.integer(minimum: 200, maximum: 20000),
        'color': const JsonSchema.string(pattern: r'^#[0-9A-Fa-f]{6}$'),
      },
      ['range'],
    ),
    scopes: _scopes,
  );

  static final waitForRecalc = McpToolDefinition(
    name: 'ui.sheets.wait_for_recalc',
    title: 'Wait for recalculation',
    description:
        'Resolves when the formula engine is idle (pending recalculation and '
        'local writes are done) or after timeout_ms.',
    inputSchema: _schema({
      'timeout_ms': const JsonSchema.integer(minimum: 0, maximum: 60000),
    }),
    annotations: McpToolAnnotations.read,
    timeout: const Duration(seconds: 65),
    scopes: _scopes,
  );

  static final all = [
    getSelection,
    selectRange,
    getVisibleRange,
    activateSheet,
    scrollTo,
    openPanel,
    closePanel,
    startCellEdit,
    typeInCell,
    screenshotRange,
    highlightRange,
    waitForRecalc,
  ];
}
