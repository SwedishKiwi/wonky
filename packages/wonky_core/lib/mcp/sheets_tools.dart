import '../src/commands/json_schema.dart';
import 'mcp_tool.dart';

/// Shared argument types of the headless `sheets.*` tools (Sheets 12 §3).
abstract final class SheetsSchemas {
  static const spreadsheet = JsonSchema.string(
    minLength: 1,
    maxLength: 500,
    description:
        'The spreadsheet: its drive item uuid (as in /sheets/s/<uuid> URLs), '
        'a full app URL or the spreadsheet (space) uuid.',
  );

  static const a1 = JsonSchema.string(
    minLength: 1,
    maxLength: 500,
    description:
        'An A1 range: "Sheet1!A1:C10", "\'Q3 Plan\'!B:B", "Data!5:5", "B4", '
        'a sheet name, or a named range. The sheet may be omitted only when '
        'the spreadsheet has one sheet.',
  );

  static const ranges = JsonSchema.array(
    a1,
    minItems: 1,
    maxItems: 20,
    description: 'One or more A1 ranges (max 20).',
  );

  static const sheet = JsonSchema.string(
    minLength: 1,
    maxLength: 200,
    description: 'Sheet name (case-insensitive) or sheet id.',
  );

  static const cellValue = JsonSchema.nullable(
    JsonSchema.anyOf([
      JsonSchema.string(),
      JsonSchema.number(),
      JsonSchema.boolean(),
    ]),
  );

  static const values = JsonSchema.array(
    JsonSchema.array(cellValue),
    description:
        'Row-major 2-D array. Strings starting with "=" are formulas '
        '(English function names, "," separators, "." decimals). null clears '
        'the content (keeps formats).',
  );

  static const input = JsonSchema.string(
    enumValues: ['user_entered', 'raw'],
    defaultValue: 'user_entered',
    description:
        '"user_entered" (default): strings are parsed like typing (numbers, '
        'dates, percentages, =formulas; a leading \' forces text). "raw": '
        'strings stay text, numbers stay numbers.',
  );

  static const parseLocale = JsonSchema.string(
    maxLength: 20,
    description:
        'Locale for parsing user_entered values (default: the spreadsheet '
        'locale), e.g. "de_DE". Formulas always use the English syntax.',
  );

  static const dimension = JsonSchema.string(enumValues: ['rows', 'columns']);

  static const index = JsonSchema.anyOf([
    JsonSchema.integer(minimum: 1),
    JsonSchema.string(minLength: 1, maxLength: 4),
  ], description: '1-based row/column number, or a column letter ("C").');

  static const color = JsonSchema.string(
    maxLength: 40,
    description: '"#RRGGBB" or "theme:accent1" … "theme:accent6".',
  );

  static const borderSide = JsonSchema.object(
    properties: {
      'style': JsonSchema.string(
        enumValues: [
          'none',
          'thin',
          'medium',
          'thick',
          'dashed',
          'dotted',
          'double',
        ],
      ),
      'color': color,
    },
    required: ['style'],
  );

  static const format = JsonSchema.object(
    description:
        'Format attributes. Each listed key is set; null resets it to the '
        'default (inherit).',
    properties: {
      'number_format': JsonSchema.nullable(
        JsonSchema.string(
          maxLength: 200,
          description:
              'A pattern ("#,##0.00", "yyyy-mm-dd", "0.0%") or a preset: '
              'automatic, number, percent, currency, accounting, date, time, '
              'datetime, duration, scientific, text.',
        ),
      ),
      'bold': JsonSchema.nullable(JsonSchema.boolean()),
      'italic': JsonSchema.nullable(JsonSchema.boolean()),
      'underline': JsonSchema.nullable(JsonSchema.boolean()),
      'strikethrough': JsonSchema.nullable(JsonSchema.boolean()),
      'font_family': JsonSchema.nullable(JsonSchema.string(maxLength: 100)),
      'font_size': JsonSchema.nullable(
        JsonSchema.number(minimum: 1, maximum: 400),
      ),
      'text_color': JsonSchema.nullable(color),
      'fill_color': JsonSchema.nullable(color),
      'h_align': JsonSchema.nullable(
        JsonSchema.string(enumValues: ['left', 'center', 'right', 'general']),
      ),
      'v_align': JsonSchema.nullable(
        JsonSchema.string(enumValues: ['top', 'middle', 'bottom']),
      ),
      'wrap': JsonSchema.nullable(
        JsonSchema.string(enumValues: ['overflow', 'wrap', 'clip']),
      ),
      'rotation': JsonSchema.nullable(
        JsonSchema.integer(minimum: -90, maximum: 255),
      ),
      'link_url': JsonSchema.nullable(JsonSchema.string(maxLength: 2000)),
      'borders': JsonSchema.object(
        properties: {
          'top': borderSide,
          'bottom': borderSide,
          'left': borderSide,
          'right': borderSide,
          'inner_horizontal': borderSide,
          'inner_vertical': borderSide,
          'outer': borderSide,
        },
      ),
    },
  );

  /// `{type, values}` of a condition (CF, DV, filters).
  static const condition = JsonSchema.object(
    properties: {
      'type': JsonSchema.string(
        description:
            'NUMBER_GREATER, NUMBER_GREATER_THAN_EQ, NUMBER_LESS, '
            'NUMBER_LESS_THAN_EQ, NUMBER_EQ, NUMBER_NOT_EQ, NUMBER_BETWEEN, '
            'NUMBER_NOT_BETWEEN, TEXT_CONTAINS, TEXT_NOT_CONTAINS, '
            'TEXT_STARTS_WITH, TEXT_ENDS_WITH, TEXT_EQ, TEXT_IS_EMAIL, '
            'TEXT_IS_URL, DATE_EQ, DATE_BEFORE, DATE_AFTER, '
            'DATE_ON_OR_BEFORE, DATE_ON_OR_AFTER, DATE_BETWEEN, '
            'DATE_NOT_BETWEEN, DATE_IS_VALID, BLANK, NOT_BLANK, '
            'CUSTOM_FORMULA (camelCase ids like "numberGreater" work too).',
      ),
      'values': JsonSchema.array(
        JsonSchema.string(),
        maxItems: 2,
        description:
            'Condition values as strings: "100", "=B1*2" (formula relative '
            'to the top-left cell of the range), or relative dates "today", '
            '"yesterday", "tomorrow", "past_week", "past_month", "past_year".',
      ),
    },
    required: ['type'],
  );

  static const filterCriteria = JsonSchema.object(
    additionalProperties: true,
    description:
        'Per column letter: {"C": {"hidden_values": ["x"]}} or '
        '{"D": {"condition": {"type": "NUMBER_GREATER", "values": ["10"]}}}.',
  );

  static const sortSpec = JsonSchema.object(
    properties: {
      'column': JsonSchema.string(
        minLength: 1,
        maxLength: 4,
        description: 'Column letter ("B").',
      ),
      'ascending': JsonSchema.boolean(defaultValue: true),
    },
    required: ['column'],
  );

  static const mutationResult = JsonSchema.object(
    additionalProperties: true,
    properties: {
      'change_id': JsonSchema.string(),
      'cells_affected': JsonSchema.integer(),
      'warnings': JsonSchema.array(JsonSchema.string()),
      'sync_version': JsonSchema.string(),
    },
  );

  /// Builds a tool input schema with the common `spreadsheet` property.
  static ObjectSchema of(
    Map<String, JsonSchema> props, {
    List<String> required = const [],
    String? description,
  }) => ObjectSchema(
    properties: {'spreadsheet': spreadsheet, ...props},
    required: ['spreadsheet', ...required],
    description: description,
  );
}

const _a1Note =
    ' Ranges use A1 notation ("Sheet1!A1:C10", "\'My sheet\'!B:B", a named '
    'range). Every mutating call is one undoable change: it returns a '
    'change_id that changes.revert undoes for 24 h.';

/// Headless `sheets.*` tools (Sheets 12 §3).
abstract final class SheetsTools {
  static const _read = {McpScope.sheetsRead};
  static const _edit = {McpScope.sheetsEdit};
  static const _destructive = McpToolAnnotations(destructive: true);

  // ------------------------------------------------------------ metadata

  static final getSpreadsheet = McpToolDefinition(
    name: 'sheets.get_spreadsheet',
    title: 'Spreadsheet info',
    description:
        'Returns the spreadsheet metadata: title, locale, time zone, your '
        'role, the sheets (name, grid size, used range, frozen rows/columns, '
        'filters), named ranges, charts, pivot tables, protections and the '
        'cell count. include selects sections (default: all except cf and '
        'dv). Call it first to learn the sheet names.',
    inputSchema: SheetsSchemas.of({
      'include': const JsonSchema.array(
        JsonSchema.string(
          enumValues: [
            'sheets',
            'named_ranges',
            'charts',
            'pivots',
            'filters',
            'protections',
            'cf',
            'dv',
          ],
        ),
      ),
    }),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final describeData = McpToolDefinition(
    name: 'sheets.describe_data',
    title: 'Describe data',
    description:
        'Profiles a table: detected header row, per-column type '
        '(number/text/date/bool/mixed/empty), counts, distinct values, '
        'numeric stats (min/max/mean/median/stdev/sum), top text values, and '
        'sample values, plus the detected tables of the sheet. Cheap: the '
        'recommended first call before reading or writing data. Pass range '
        'or sheet (default: the first sheet).',
    inputSchema: SheetsSchemas.of({
      'range': SheetsSchemas.a1,
      'sheet': SheetsSchemas.sheet,
      'sample_rows': const JsonSchema.integer(
        minimum: 0,
        maximum: 20,
        defaultValue: 5,
      ),
      'max_columns': const JsonSchema.integer(
        minimum: 1,
        maximum: 200,
        defaultValue: 50,
      ),
    }),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  // --------------------------------------------------------------- values

  static final getValues = McpToolDefinition(
    name: 'sheets.get_values',
    title: 'Read cell values',
    description:
        'Reads one or more ranges. render: "formatted" (default; display '
        'strings as shown in the app), "unformatted" (numbers, booleans, '
        'text; dates per date_render) or "formula" (A1 formulas for formula '
        'cells, else the unformatted value). Open-ended ranges ("A:C", a '
        'sheet name) are clipped to the used range; empty trailing rows and '
        'columns are trimmed. Errors are strings ("#N/A"). Large results are '
        'paged by whole rows: when truncated is true, call again with '
        'cursor = next_cursor. Example: {"ranges": ["Sheet1!A1:D20"], '
        '"render": "formula"}.',
    inputSchema: SheetsSchemas.of(
      {
        'ranges': SheetsSchemas.ranges,
        'render': const JsonSchema.string(
          enumValues: ['formatted', 'unformatted', 'formula'],
          defaultValue: 'formatted',
        ),
        'date_render': const JsonSchema.string(
          enumValues: ['serial', 'formatted', 'iso'],
          description:
              'Dates with render "unformatted"/"formula" (default "iso").',
        ),
        'major_dimension': const JsonSchema.string(
          enumValues: ['rows', 'columns'],
          defaultValue: 'rows',
        ),
        'max_cells': const JsonSchema.integer(
          minimum: 1,
          maximum: 100000,
          defaultValue: 10000,
        ),
        'cursor': McpSchemas.cursor,
      },
      required: ['ranges'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final setValues = McpToolDefinition(
    name: 'sheets.set_values',
    title: 'Write cell values',
    description:
        'Writes a 2-D array of values starting at range (a top-left cell or '
        'a full range whose size must match values). Strings starting with '
        '"=" are formulas in English syntax ("=SUM(B2:B10)"). The grid grows '
        'when values extend past the last row/column. Formats are kept. Max '
        '50,000 cells. Example: {"range": "Sheet1!A1", "values": [["Name", '
        '"Total"], ["Ann", "=SUM(C2:F2)"]]}.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'range': SheetsSchemas.a1,
        'values': SheetsSchemas.values,
        'input': SheetsSchemas.input,
        'parse_locale': SheetsSchemas.parseLocale,
      },
      required: ['range', 'values'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final batchSetValues = McpToolDefinition(
    name: 'sheets.batch_set_values',
    title: 'Write several ranges',
    description:
        'Like sheets.set_values for several ranges in one undoable change. '
        'Example: {"data": [{"range": "A1", "values": [["x"]]}, {"range": '
        '"Sheet2!B2", "values": [[1, 2]]}]}.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'data': const JsonSchema.array(
          JsonSchema.object(
            properties: {
              'range': SheetsSchemas.a1,
              'values': SheetsSchemas.values,
            },
            required: ['range', 'values'],
          ),
          minItems: 1,
          maxItems: 100,
        ),
        'input': SheetsSchemas.input,
        'parse_locale': SheetsSchemas.parseLocale,
      },
      required: ['data'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final appendRows = McpToolDefinition(
    name: 'sheets.append_rows',
    title: 'Append rows',
    description:
        'Appends rows after the last non-empty row of the table that '
        'contains (or follows) range (a cell in the table, a table range or '
        'a sheet name). insert_rows false (default) writes into existing '
        'empty rows and grows the grid if needed; true inserts new rows '
        'below the table first. Returns the table range and the written '
        'range.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'range': SheetsSchemas.a1,
        'values': SheetsSchemas.values,
        'input': SheetsSchemas.input,
        'parse_locale': SheetsSchemas.parseLocale,
        'insert_rows': const JsonSchema.boolean(defaultValue: false),
      },
      required: ['range', 'values'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final clearRange = McpToolDefinition(
    name: 'sheets.clear_range',
    title: 'Clear ranges',
    description:
        'Clears ranges. what: "contents" (default; values and formulas, '
        'formats kept), "formats", "all", "notes" or "validation".$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'ranges': SheetsSchemas.ranges,
        'what': const JsonSchema.string(
          enumValues: ['contents', 'formats', 'all', 'notes', 'validation'],
          defaultValue: 'contents',
        ),
      },
      required: ['ranges'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    annotations: _destructive,
    scopes: _edit,
  );

  // ----------------------------------------------------------- formatting

  static final formatRange = McpToolDefinition(
    name: 'sheets.format_range',
    title: 'Format cells',
    description:
        'Formats ranges: number format, font, colors, alignment, wrap, '
        'rotation, link and borders. Each key in format is set; null resets '
        'it. Whole rows/columns are formatted as row/column defaults. '
        'Example: {"ranges": ["A1:D1"], "format": {"bold": true, '
        '"fill_color": "#E8F0FE", "borders": {"bottom": {"style": '
        '"medium"}}}}.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {'ranges': SheetsSchemas.ranges, 'format': SheetsSchemas.format},
      required: ['ranges', 'format'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final clearFormats = McpToolDefinition(
    name: 'sheets.clear_formats',
    title: 'Clear formatting',
    description:
        'Removes formatting from ranges (same as clear_range with what '
        '"formats").$_a1Note',
    inputSchema: SheetsSchemas.of(
      {'ranges': SheetsSchemas.ranges},
      required: ['ranges'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final applyBanding = McpToolDefinition(
    name: 'sheets.apply_banding',
    title: 'Alternating colors',
    description:
        'Applies alternating row colors to a range. style: a preset color '
        '(e.g. "#4285F4" header color) or omitted for the default gray; '
        'header/footer rows get a stronger color.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'range': SheetsSchemas.a1,
        'style': const JsonSchema.string(maxLength: 40),
        'header': const JsonSchema.boolean(defaultValue: true),
        'footer': const JsonSchema.boolean(defaultValue: false),
      },
      required: ['range'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  // ------------------------------------------------------ rows / columns

  static final insertRows = McpToolDefinition(
    name: 'sheets.insert_rows',
    title: 'Insert rows',
    description:
        'Inserts count rows before row at (1-based). inherit_from copies '
        'formats from the row before (default) or after.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'sheet': SheetsSchemas.sheet,
        'at': const JsonSchema.integer(minimum: 1),
        'count': const JsonSchema.integer(
          minimum: 1,
          maximum: 10000,
          defaultValue: 1,
        ),
        'inherit_from': const JsonSchema.string(
          enumValues: ['before', 'after', 'none'],
          defaultValue: 'before',
        ),
      },
      required: ['sheet', 'at'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final deleteRows = McpToolDefinition(
    name: 'sheets.delete_rows',
    title: 'Delete rows',
    description:
        'Deletes count rows starting at row start (1-based). Formulas that '
        'referenced them are repaired or become #REF!.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'sheet': SheetsSchemas.sheet,
        'start': const JsonSchema.integer(minimum: 1),
        'count': const JsonSchema.integer(
          minimum: 1,
          maximum: 100000,
          defaultValue: 1,
        ),
      },
      required: ['sheet', 'start'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    annotations: _destructive,
    scopes: _edit,
  );

  static final insertColumns = McpToolDefinition(
    name: 'sheets.insert_columns',
    title: 'Insert columns',
    description:
        'Inserts count columns before column at (letter "C" or 1-based '
        'number).$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'sheet': SheetsSchemas.sheet,
        'at': SheetsSchemas.index,
        'count': const JsonSchema.integer(
          minimum: 1,
          maximum: 1000,
          defaultValue: 1,
        ),
        'inherit_from': const JsonSchema.string(
          enumValues: ['before', 'after', 'none'],
          defaultValue: 'before',
        ),
      },
      required: ['sheet', 'at'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final deleteColumns = McpToolDefinition(
    name: 'sheets.delete_columns',
    title: 'Delete columns',
    description:
        'Deletes count columns starting at start (letter or 1-based '
        'number).$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'sheet': SheetsSchemas.sheet,
        'start': SheetsSchemas.index,
        'count': const JsonSchema.integer(
          minimum: 1,
          maximum: 1000,
          defaultValue: 1,
        ),
      },
      required: ['sheet', 'start'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    annotations: _destructive,
    scopes: _edit,
  );

  static final moveDimension = McpToolDefinition(
    name: 'sheets.move_dimension',
    title: 'Move rows or columns',
    description:
        'Moves count rows/columns starting at start before destination '
        '(index in the numbering before the move).$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'sheet': SheetsSchemas.sheet,
        'dimension': SheetsSchemas.dimension,
        'start': SheetsSchemas.index,
        'count': const JsonSchema.integer(minimum: 1, defaultValue: 1),
        'destination': SheetsSchemas.index,
      },
      required: ['sheet', 'dimension', 'start', 'destination'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final resizeDimension = McpToolDefinition(
    name: 'sheets.resize_dimension',
    title: 'Resize rows or columns',
    description:
        'Sets the height/width of count rows/columns in pixels (size_px), '
        'fits them to their content (auto_fit) or resets them to the '
        'default (reset).$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'sheet': SheetsSchemas.sheet,
        'dimension': SheetsSchemas.dimension,
        'start': SheetsSchemas.index,
        'count': const JsonSchema.integer(minimum: 1, defaultValue: 1),
        'size_px': const JsonSchema.number(minimum: 2, maximum: 4000),
        'auto_fit': const JsonSchema.boolean(),
        'reset': const JsonSchema.boolean(),
      },
      required: ['sheet', 'dimension', 'start'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final hideDimension = McpToolDefinition(
    name: 'sheets.hide_dimension',
    title: 'Hide or show rows/columns',
    description:
        'Hides (hidden true) or shows count rows/columns from start.'
        '$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'sheet': SheetsSchemas.sheet,
        'dimension': SheetsSchemas.dimension,
        'start': SheetsSchemas.index,
        'count': const JsonSchema.integer(minimum: 1, defaultValue: 1),
        'hidden': const JsonSchema.boolean(),
      },
      required: ['sheet', 'dimension', 'start', 'hidden'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final groupDimension = McpToolDefinition(
    name: 'sheets.group_dimension',
    title: 'Group rows or columns',
    description:
        'Groups count rows/columns from start into an outline group (the '
        '+/- control), depth times nested (default 1, max 8 levels), '
        'optionally collapsed; or ungroups them (action ungroup), or '
        'collapses/expands the groups that span exactly those rows/columns. '
        'Example: {"sheet": "Data", "dimension": "rows", "start": 2, '
        '"count": 10, "collapsed": true}.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'sheet': SheetsSchemas.sheet,
        'dimension': SheetsSchemas.dimension,
        'start': SheetsSchemas.index,
        'count': const JsonSchema.integer(minimum: 1, defaultValue: 1),
        'action': const JsonSchema.string(
          enumValues: ['group', 'ungroup', 'collapse', 'expand'],
          defaultValue: 'group',
        ),
        'depth': const JsonSchema.integer(minimum: 1, maximum: 8),
        'collapsed': const JsonSchema.boolean(),
      },
      required: ['sheet', 'dimension', 'start'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final setFrozen = McpToolDefinition(
    name: 'sheets.set_frozen',
    title: 'Freeze rows/columns',
    description:
        'Sets the number of frozen rows and/or columns of a sheet (0 '
        'unfreezes).$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'sheet': SheetsSchemas.sheet,
        'rows': const JsonSchema.integer(minimum: 0, maximum: 100),
        'columns': const JsonSchema.integer(minimum: 0, maximum: 100),
      },
      required: ['sheet'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  // --------------------------------------------------------------- sheets

  static final addSheet = McpToolDefinition(
    name: 'sheets.add_sheet',
    title: 'Add a sheet',
    description:
        'Adds a sheet (default name "SheetN", at the end, 1000 × 26), '
        'optionally with initial values starting at A1.$_a1Note',
    inputSchema: SheetsSchemas.of({
      'name': const JsonSchema.string(minLength: 1, maxLength: 100),
      'index': const JsonSchema.integer(
        minimum: 1,
        description: '1-based tab position.',
      ),
      'rows': const JsonSchema.integer(
        minimum: 1,
        maximum: 100000,
        defaultValue: 1000,
      ),
      'columns': const JsonSchema.integer(
        minimum: 1,
        maximum: 1000,
        defaultValue: 26,
      ),
      'values': SheetsSchemas.values,
    }),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final renameSheet = McpToolDefinition(
    name: 'sheets.rename_sheet',
    title: 'Rename a sheet',
    description:
        'Renames a sheet; fails with duplicate_name when the name is taken. '
        'Formulas referencing the sheet follow.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'sheet': SheetsSchemas.sheet,
        'new_name': const JsonSchema.string(minLength: 1, maxLength: 100),
      },
      required: ['sheet', 'new_name'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final deleteSheet = McpToolDefinition(
    name: 'sheets.delete_sheet',
    title: 'Delete a sheet',
    description:
        'Deletes a sheet with all its data (the last visible sheet cannot '
        'be deleted).$_a1Note',
    inputSchema: SheetsSchemas.of(
      {'sheet': SheetsSchemas.sheet},
      required: ['sheet'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    annotations: _destructive,
    scopes: _edit,
  );

  static final duplicateSheet = McpToolDefinition(
    name: 'sheets.duplicate_sheet',
    title: 'Duplicate a sheet',
    description:
        'Copies a sheet with its data, formats and rules ("Copy of …" by '
        'default).$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'sheet': SheetsSchemas.sheet,
        'new_name': const JsonSchema.string(minLength: 1, maxLength: 100),
        'index': const JsonSchema.integer(minimum: 1),
      },
      required: ['sheet'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final reorderSheet = McpToolDefinition(
    name: 'sheets.reorder_sheet',
    title: 'Move a sheet tab',
    description: 'Moves a sheet tab to a 1-based position.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'sheet': SheetsSchemas.sheet,
        'index': const JsonSchema.integer(minimum: 1),
      },
      required: ['sheet', 'index'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final setSheetProperties = McpToolDefinition(
    name: 'sheets.set_sheet_properties',
    title: 'Sheet properties',
    description:
        'Sets the tab color (null removes it), hidden, gridlines and '
        'right-to-left of a sheet.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'sheet': SheetsSchemas.sheet,
        'tab_color': const JsonSchema.nullable(SheetsSchemas.color),
        'hidden': const JsonSchema.boolean(),
        'show_gridlines': const JsonSchema.boolean(),
        'right_to_left': const JsonSchema.boolean(),
      },
      required: ['sheet'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  // --------------------------------------------------------------- merges

  static final mergeCells = McpToolDefinition(
    name: 'sheets.merge_cells',
    title: 'Merge cells',
    description:
        'Merges a range: type "all" (one cell), "horizontal" (per row) or '
        '"vertical" (per column). Only the top-left value is kept.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'range': SheetsSchemas.a1,
        'type': const JsonSchema.string(
          enumValues: ['all', 'horizontal', 'vertical'],
          defaultValue: 'all',
        ),
      },
      required: ['range'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final unmergeCells = McpToolDefinition(
    name: 'sheets.unmerge_cells',
    title: 'Unmerge cells',
    description: 'Removes all merges intersecting a range.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {'range': SheetsSchemas.a1},
      required: ['range'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  // ------------------------------------------------------ sort and filter

  static final sortRange = McpToolDefinition(
    name: 'sheets.sort_range',
    title: 'Sort a range',
    description:
        'Sorts the rows of a range by one or more columns (stable). '
        'has_header keeps the first row in place. Example: {"range": '
        '"A1:F200", "specs": [{"column": "C", "ascending": false}], '
        '"has_header": true}.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'range': SheetsSchemas.a1,
        'specs': const JsonSchema.array(
          SheetsSchemas.sortSpec,
          minItems: 1,
          maxItems: 20,
        ),
        'has_header': const JsonSchema.boolean(defaultValue: false),
      },
      required: ['range', 'specs'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final setBasicFilter = McpToolDefinition(
    name: 'sheets.set_basic_filter',
    title: 'Set the filter',
    description:
        'Creates or replaces the basic filter of a sheet over range (header '
        'row first) with optional per-column criteria and sort. Rows not '
        'matching are hidden for everyone.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'range': SheetsSchemas.a1,
        'criteria': SheetsSchemas.filterCriteria,
        'sort': SheetsSchemas.sortSpec,
      },
      required: ['range'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final clearFilter = McpToolDefinition(
    name: 'sheets.clear_filter',
    title: 'Remove the filter',
    description: 'Removes the basic filter of a sheet.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {'sheet': SheetsSchemas.sheet},
      required: ['sheet'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final createFilterView = McpToolDefinition(
    name: 'sheets.create_filter_view',
    title: 'Create a filter view',
    description:
        'Creates a named filter view (a personal filter others do not see '
        'unless they open it). Returns its id and URL.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'range': SheetsSchemas.a1,
        'name': const JsonSchema.string(minLength: 1, maxLength: 100),
        'criteria': SheetsSchemas.filterCriteria,
        'sort': SheetsSchemas.sortSpec,
      },
      required: ['range', 'name'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final listFilterViews = McpToolDefinition(
    name: 'sheets.list_filter_views',
    title: 'List filter views',
    description: 'Lists the filter views of the spreadsheet (or one sheet).',
    inputSchema: SheetsSchemas.of({'sheet': SheetsSchemas.sheet}),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final deleteFilterView = McpToolDefinition(
    name: 'sheets.delete_filter_view',
    title: 'Delete a filter view',
    description: 'Deletes a filter view by id.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {'filter_view_id': const JsonSchema.string(minLength: 1)},
      required: ['filter_view_id'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  // ------------------------------------------------ conditional formatting

  static final addConditionalFormat = McpToolDefinition(
    name: 'sheets.add_conditional_format',
    title: 'Add conditional formatting',
    description:
        'Adds a conditional format rule to ranges of one sheet. rule: '
        '{"type": "boolean", "condition": {"type": "NUMBER_GREATER", '
        '"values": ["100"]}, "format": {"bold": true, "fill_color": '
        '"#F4CCCC"}} or {"type": "color_scale", "min_point": {"type": '
        '"min", "color": "#FFFFFF"}, "max_point": {"type": "max", "color": '
        '"#57BB8A"}}. CUSTOM_FORMULA values are relative to the top-left '
        'cell of the first range ("=\$C2>100"). index 0 = highest priority.'
        '$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'ranges': SheetsSchemas.ranges,
        'rule': const JsonSchema.object(
          properties: {
            'type': JsonSchema.string(enumValues: ['boolean', 'color_scale']),
            'condition': SheetsSchemas.condition,
            'format': JsonSchema.object(
              properties: {
                'bold': JsonSchema.boolean(),
                'italic': JsonSchema.boolean(),
                'underline': JsonSchema.boolean(),
                'strikethrough': JsonSchema.boolean(),
                'text_color': SheetsSchemas.color,
                'fill_color': SheetsSchemas.color,
              },
            ),
            'min_point': _scalePoint,
            'mid_point': _scalePoint,
            'max_point': _scalePoint,
          },
          required: ['type'],
        ),
        'index': const JsonSchema.integer(minimum: 0),
      },
      required: ['ranges', 'rule'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static const _scalePoint = JsonSchema.object(
    properties: {
      'type': JsonSchema.string(
        enumValues: ['min', 'max', 'number', 'percent', 'percentile'],
      ),
      'value': JsonSchema.string(),
      'color': SheetsSchemas.color,
    },
    required: ['type', 'color'],
  );

  static final listConditionalFormats = McpToolDefinition(
    name: 'sheets.list_conditional_formats',
    title: 'List conditional formats',
    description:
        'Lists the conditional format rules (all sheets or one) in '
        'priority order with their ranges.',
    inputSchema: SheetsSchemas.of({'sheet': SheetsSchemas.sheet}),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final updateConditionalFormat = McpToolDefinition(
    name: 'sheets.update_conditional_format',
    title: 'Update conditional formatting',
    description:
        'Changes a rule: new ranges, a new rule (same shape as '
        'add_conditional_format), enabled, or a new priority index.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'rule_id': const JsonSchema.string(minLength: 1),
        'ranges': SheetsSchemas.ranges,
        'rule': const JsonSchema.object(additionalProperties: true),
        'enabled': const JsonSchema.boolean(),
      },
      required: ['rule_id'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final deleteConditionalFormat = McpToolDefinition(
    name: 'sheets.delete_conditional_format',
    title: 'Delete conditional formatting',
    description: 'Deletes a conditional format rule by id.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {'rule_id': const JsonSchema.string(minLength: 1)},
      required: ['rule_id'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  // ----------------------------------- validation, names and protections

  static final setDataValidation = McpToolDefinition(
    name: 'sheets.set_data_validation',
    title: 'Data validation',
    description:
        'Sets data validation on ranges, or removes it (criteria null). '
        'criteria.type: list_of_items (values = items), list_from_range '
        '(values = [A1 range]), checkbox (checked_value/unchecked_value), '
        'number_between/number_not_between/number_greater/… (values), '
        'date_before/date_after/date_between/date_is_valid, text_contains/'
        'text_not_contains/text_eq, email, url, custom_formula (values = '
        '["=formula"]). strict rejects invalid input in the app (tool '
        'writes are never rejected).$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'ranges': SheetsSchemas.ranges,
        'criteria': const JsonSchema.nullable(
          JsonSchema.object(
            properties: {
              'type': JsonSchema.string(minLength: 1),
              'values': JsonSchema.array(JsonSchema.string()),
              'checked_value': JsonSchema.string(),
              'unchecked_value': JsonSchema.string(),
            },
            required: ['type'],
          ),
        ),
        'strict': const JsonSchema.boolean(defaultValue: false),
        'show_dropdown': const JsonSchema.boolean(defaultValue: true),
        'display_style': const JsonSchema.string(
          enumValues: ['chip', 'arrow', 'plain'],
        ),
        'help_text': const JsonSchema.string(maxLength: 500),
      },
      required: ['ranges', 'criteria'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final createNamedRange = McpToolDefinition(
    name: 'sheets.create_named_range',
    title: 'Create a named range',
    description:
        'Names a range ("Revenue" → "Data!B2:B100") or a formula. Names: '
        'letters, digits, underscores; not like a cell reference.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'name': const JsonSchema.string(minLength: 1, maxLength: 250),
        'range': SheetsSchemas.a1,
        'formula': const JsonSchema.string(maxLength: 8000),
      },
      required: ['name'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final listNamedRanges = McpToolDefinition(
    name: 'sheets.list_named_ranges',
    title: 'List named ranges',
    description: 'Lists named ranges with their A1 range or formula.',
    inputSchema: SheetsSchemas.of({}),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final updateNamedRange = McpToolDefinition(
    name: 'sheets.update_named_range',
    title: 'Update a named range',
    description:
        'Renames a named range (formulas follow) and/or points it at a new '
        'range.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'name': const JsonSchema.string(minLength: 1),
        'new_name': const JsonSchema.string(minLength: 1, maxLength: 250),
        'range': SheetsSchemas.a1,
      },
      required: ['name'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final deleteNamedRange = McpToolDefinition(
    name: 'sheets.delete_named_range',
    title: 'Delete a named range',
    description:
        'Deletes a named range (formulas using it show #NAME?).$_a1Note',
    inputSchema: SheetsSchemas.of(
      {'name': const JsonSchema.string(minLength: 1)},
      required: ['name'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final protectRange = McpToolDefinition(
    name: 'sheets.protect_range',
    title: 'Protect a range',
    description:
        'Protects a range or a whole sheet. Only the owner, you and editors '
        '(emails of users with edit access) can then edit it; warning_only '
        'lets everyone edit after a warning. except_ranges stay editable '
        '(sheet protections).$_a1Note',
    inputSchema: SheetsSchemas.of({
      'range': SheetsSchemas.a1,
      'sheet': SheetsSchemas.sheet,
      'description': const JsonSchema.string(maxLength: 500),
      'warning_only': const JsonSchema.boolean(defaultValue: false),
      'editors': const JsonSchema.array(
        JsonSchema.string(format: 'email'),
        maxItems: 100,
      ),
      'except_ranges': const JsonSchema.array(SheetsSchemas.a1, maxItems: 50),
    }),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final listProtections = McpToolDefinition(
    name: 'sheets.list_protections',
    title: 'List protections',
    description:
        'Lists protected ranges and sheets with their editors and whether '
        'you can edit them.',
    inputSchema: SheetsSchemas.of({'sheet': SheetsSchemas.sheet}),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final unprotect = McpToolDefinition(
    name: 'sheets.unprotect',
    title: 'Remove a protection',
    description:
        'Removes a protection by id (owner, its creator and its editors '
        'only).$_a1Note',
    inputSchema: SheetsSchemas.of(
      {'protection_id': const JsonSchema.string(minLength: 1)},
      required: ['protection_id'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  // ----------------------------------------------------- charts and pivots

  static const _chartTypes = [
    'column',
    'bar',
    'line',
    'area',
    'pie',
    'doughnut',
    'scatter',
    'combo',
    'stepped_area',
    'histogram',
    'scorecard',
    'table',
    'column_3d',
    'bar_3d',
    'line_3d',
    'area_3d',
    'pie_3d',
    'surface',
  ];

  static final createChart = McpToolDefinition(
    name: 'sheets.create_chart',
    title: 'Create a chart',
    description:
        'Creates a chart from data_ranges (first row = headers, first '
        'column = labels by default). Omit type for the recommended chart. '
        'options: {"title": "Revenue", "subtitle": "…", "stacking": '
        '"normal"|"percent", "legend": "bottom"|"none"|…, '
        '"switch_rows_columns": true, "headers": 1, "x_axis_title": "…", '
        '"y_axis_title": "…", "aggregate": "sum", "threeD": {"enabled": '
        'true, "azimuth": 20, "elevation": 20, "perspective": 15, "depth": '
        '100, "lighting": "soft"|"bright"|"flat", "wallsVisible": true, '
        '"shape": "box"|"cylinder"|"cone"|"pyramid", "explode": 0.1}}. '
        '3D works for column, bar, line, area and pie. Placed at anchor_cell '
        '(default: right of the data) on sheet, or on its own sheet. Types: '
        '${_chartTypes.join(', ')}.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'sheet': SheetsSchemas.sheet,
        'data_ranges': SheetsSchemas.ranges,
        'type': const JsonSchema.string(maxLength: 40),
        'options': const JsonSchema.object(additionalProperties: true),
        'anchor_cell': SheetsSchemas.a1,
        'width': const JsonSchema.number(minimum: 20, maximum: 4000),
        'height': const JsonSchema.number(minimum: 20, maximum: 4000),
        'own_sheet': const JsonSchema.boolean(defaultValue: false),
      },
      required: ['data_ranges'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final updateChart = McpToolDefinition(
    name: 'sheets.update_chart',
    title: 'Update a chart',
    description:
        'Changes a chart: patch is a JSON merge patch on the A1-form spec '
        'returned by sheets.get_chart (e.g. {"type": "line", "title": '
        '{"text": "New"}}) and/or the same options as create_chart; '
        'anchor_cell/width/height move or resize it.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'chart_id': const JsonSchema.string(minLength: 1),
        'patch': const JsonSchema.object(additionalProperties: true),
        'options': const JsonSchema.object(additionalProperties: true),
        'data_ranges': SheetsSchemas.ranges,
        'anchor_cell': SheetsSchemas.a1,
        'width': const JsonSchema.number(minimum: 20, maximum: 4000),
        'height': const JsonSchema.number(minimum: 20, maximum: 4000),
      },
      required: ['chart_id'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final deleteChart = McpToolDefinition(
    name: 'sheets.delete_chart',
    title: 'Delete a chart',
    description: 'Deletes a chart by id.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {'chart_id': const JsonSchema.string(minLength: 1)},
      required: ['chart_id'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    annotations: _destructive,
    scopes: _edit,
  );

  static final getChart = McpToolDefinition(
    name: 'sheets.get_chart',
    title: 'Read a chart',
    description:
        'Returns a chart\'s spec in A1 form (data ranges as A1), its '
        'placement, and a data summary (series names, point counts) plus '
        'a text description.',
    inputSchema: SheetsSchemas.of(
      {'chart_id': const JsonSchema.string(minLength: 1)},
      required: ['chart_id'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final exportChartPng = McpToolDefinition(
    name: 'sheets.export_chart_png',
    title: 'Chart image',
    description:
        'Renders a chart as a PNG image (image content) with the in-app '
        'renderer.',
    inputSchema: SheetsSchemas.of(
      {
        'chart_id': const JsonSchema.string(minLength: 1),
        'width': const JsonSchema.number(minimum: 50, maximum: 2000),
        'height': const JsonSchema.number(minimum: 50, maximum: 2000),
        'scale': const JsonSchema.integer(minimum: 1, maximum: 2),
        'dark': const JsonSchema.boolean(defaultValue: false),
      },
      required: ['chart_id'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static const _pivotGroup = JsonSchema.object(
    properties: {
      'source_column': JsonSchema.string(
        minLength: 1,
        description: 'Header name or column letter of the source.',
      ),
      'sort': JsonSchema.string(enumValues: ['asc', 'desc']),
      'show_totals': JsonSchema.boolean(),
    },
    required: ['source_column'],
  );

  static const _pivotValue = JsonSchema.object(
    properties: {
      'source_column': JsonSchema.string(minLength: 1),
      'summarize_by': JsonSchema.string(
        enumValues: [
          'sum',
          'count',
          'counta',
          'countunique',
          'average',
          'max',
          'min',
          'median',
          'product',
          'stdev',
          'stdevp',
          'var',
          'varp',
        ],
      ),
      'show_as': JsonSchema.string(
        enumValues: [
          'default',
          'percent_of_row',
          'percent_of_column',
          'percent_of_grand_total',
        ],
      ),
      'name': JsonSchema.string(maxLength: 200),
    },
    required: ['source_column'],
  );

  static const _pivotFilter = JsonSchema.object(
    properties: {
      'source_column': JsonSchema.string(minLength: 1),
      'visible_values': JsonSchema.array(JsonSchema.string()),
      'condition': SheetsSchemas.condition,
    },
    required: ['source_column'],
  );

  static final createPivotTable = McpToolDefinition(
    name: 'sheets.create_pivot_table',
    title: 'Create a pivot table',
    description:
        'Creates a pivot table over source (a table with a header row). '
        'target.sheet omitted = a new sheet "Pivot Table N"; target.cell '
        'defaults to A1. Example: {"source": "Data!A1:F500", "rows": '
        '[{"source_column": "Region"}], "values": [{"source_column": '
        '"Revenue", "summarize_by": "sum"}]}.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'source': SheetsSchemas.a1,
        'target': const JsonSchema.object(
          properties: {'sheet': SheetsSchemas.sheet, 'cell': SheetsSchemas.a1},
        ),
        'rows': const JsonSchema.array(_pivotGroup, maxItems: 10),
        'columns': const JsonSchema.array(_pivotGroup, maxItems: 10),
        'values': const JsonSchema.array(_pivotValue, maxItems: 20),
        'filters': const JsonSchema.array(_pivotFilter, maxItems: 20),
        'options': const JsonSchema.object(
          properties: {
            'repeat_row_labels': JsonSchema.boolean(),
            'values_in_rows': JsonSchema.boolean(),
          },
        ),
      },
      required: ['source'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final updatePivotTable = McpToolDefinition(
    name: 'sheets.update_pivot_table',
    title: 'Update a pivot table',
    description:
        'Changes a pivot table: any of source, rows, columns, values, '
        'filters (same shapes as create_pivot_table; given lists replace '
        'the current ones).$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'pivot_id': const JsonSchema.string(minLength: 1),
        'source': SheetsSchemas.a1,
        'rows': const JsonSchema.array(_pivotGroup, maxItems: 10),
        'columns': const JsonSchema.array(_pivotGroup, maxItems: 10),
        'values': const JsonSchema.array(_pivotValue, maxItems: 20),
        'filters': const JsonSchema.array(_pivotFilter, maxItems: 20),
      },
      required: ['pivot_id'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final deletePivotTable = McpToolDefinition(
    name: 'sheets.delete_pivot_table',
    title: 'Delete a pivot table',
    description: 'Deletes a pivot table by id.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {'pivot_id': const JsonSchema.string(minLength: 1)},
      required: ['pivot_id'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    annotations: _destructive,
    scopes: _edit,
  );

  // ------------------------------------------- find, evaluate and history

  static const _findOptions = <String, JsonSchema>{
    'sheet': SheetsSchemas.sheet,
    'range': SheetsSchemas.a1,
    'match_case': JsonSchema.boolean(defaultValue: false),
    'match_entire_cell': JsonSchema.boolean(defaultValue: false),
    'use_regex': JsonSchema.boolean(defaultValue: false),
    'search_formulas': JsonSchema.boolean(defaultValue: false),
  };

  static final find = McpToolDefinition(
    name: 'sheets.find',
    title: 'Find in the spreadsheet',
    description:
        'Finds cells whose displayed value (or formula, with '
        'search_formulas) matches query, in all sheets, one sheet or a '
        'range. Returns A1 addresses with values.',
    inputSchema: SheetsSchemas.of(
      {
        'query': const JsonSchema.string(minLength: 1, maxLength: 1000),
        ..._findOptions,
        'limit': const JsonSchema.integer(
          minimum: 1,
          maximum: 1000,
          defaultValue: 100,
        ),
      },
      required: ['query'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final findReplace = McpToolDefinition(
    name: 'sheets.find_replace',
    title: 'Find and replace',
    description:
        'Replaces matches of query with replacement (in values, or formulas '
        'with search_formulas; regex groups as \$1 with use_regex). Scope: '
        'range, sheet, or all sheets (default when neither is given).'
        '$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'query': const JsonSchema.string(minLength: 1, maxLength: 1000),
        'replacement': const JsonSchema.string(maxLength: 10000),
        ..._findOptions,
        'all_sheets': const JsonSchema.boolean(),
      },
      required: ['query', 'replacement'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  static final evaluate = McpToolDefinition(
    name: 'sheets.evaluate',
    title: 'Evaluate a formula',
    description:
        'Evaluates a formula against the spreadsheet without writing it '
        '(English syntax). sheet/cell give the context for relative '
        'references and ROW()/COLUMN(). Example: {"formula": '
        '"=SUMIF(A:A,\\"x\\",B:B)", "sheet": "Data"}.',
    inputSchema: SheetsSchemas.of(
      {
        'formula': const JsonSchema.string(minLength: 1, maxLength: 32768),
        'sheet': SheetsSchemas.sheet,
        'cell': SheetsSchemas.a1,
      },
      required: ['formula'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final validateFormula = McpToolDefinition(
    name: 'sheets.validate_formula',
    title: 'Check a formula',
    description:
        'Parses a formula (English syntax) and reports syntax errors with '
        'their position, the functions used and unknown functions. No '
        'spreadsheet needed.',
    inputSchema: const ObjectSchema(
      properties: {
        'formula': JsonSchema.string(minLength: 1, maxLength: 32768),
      },
      required: ['formula'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final explainFormula = McpToolDefinition(
    name: 'sheets.explain_formula',
    title: 'Explain a formula',
    description:
        'Returns the evaluation trace of the formula in a cell: each '
        'sub-expression with its value (max 50 nodes).',
    inputSchema: SheetsSchemas.of(
      {'cell': SheetsSchemas.a1},
      required: ['cell'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final getCell = McpToolDefinition(
    name: 'sheets.get_cell',
    title: 'Read one cell',
    description:
        'Everything about one cell: value, formatted value, formula, '
        'effective format, note, data validation and the conditional format '
        'rules covering it.',
    inputSchema: SheetsSchemas.of(
      {'cell': SheetsSchemas.a1},
      required: ['cell'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  static final getCellHistory = McpToolDefinition(
    name: 'sheets.get_cell_history',
    title: 'Cell history',
    description:
        'The edit history of one cell (newest first): who, when, before and '
        'after.',
    inputSchema: SheetsSchemas.of(
      {
        'cell': SheetsSchemas.a1,
        'limit': const JsonSchema.integer(
          minimum: 1,
          maximum: 100,
          defaultValue: 20,
        ),
        'cursor': McpSchemas.cursor,
      },
      required: ['cell'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: _read,
  );

  // --------------------------------------------------------------- import

  static final importCsv = McpToolDefinition(
    name: 'sheets.import_csv',
    title: 'Import CSV',
    description:
        'Imports CSV/TSV text (csv_text or content_base64). target.mode: '
        '"replace_at" (write at target.cell, default A1 of target.sheet), '
        '"append" (after the last row of target.sheet), "new_sheet" (named '
        'target.sheet_name) or "replace_sheet" (clears target.sheet first). '
        'convert (default true) parses numbers, dates and formulas. Max '
        '50,000 cells.$_a1Note',
    inputSchema: SheetsSchemas.of(
      {
        'csv_text': const JsonSchema.string(maxLength: 5000000),
        'content_base64': const JsonSchema.string(maxLength: 7000000),
        'target': const JsonSchema.object(
          properties: {
            'mode': JsonSchema.string(
              enumValues: [
                'replace_at',
                'append',
                'new_sheet',
                'replace_sheet',
              ],
            ),
            'sheet': SheetsSchemas.sheet,
            'cell': SheetsSchemas.a1,
            'sheet_name': JsonSchema.string(minLength: 1, maxLength: 100),
          },
          required: ['mode'],
        ),
        'delimiter': const JsonSchema.string(
          enumValues: ['auto', 'comma', 'semicolon', 'tab', 'pipe'],
          defaultValue: 'auto',
        ),
        'convert': const JsonSchema.boolean(defaultValue: true),
        'parse_locale': SheetsSchemas.parseLocale,
      },
      required: ['target'],
    ),
    outputSchema: SheetsSchemas.mutationResult,
    scopes: _edit,
  );

  /// Every headless `sheets.*` tool, in catalog order.
  static final List<McpToolDefinition> all = [
    getSpreadsheet,
    describeData,
    getValues,
    setValues,
    batchSetValues,
    appendRows,
    clearRange,
    formatRange,
    clearFormats,
    applyBanding,
    insertRows,
    deleteRows,
    insertColumns,
    deleteColumns,
    moveDimension,
    resizeDimension,
    hideDimension,
    groupDimension,
    setFrozen,
    addSheet,
    renameSheet,
    deleteSheet,
    duplicateSheet,
    reorderSheet,
    setSheetProperties,
    mergeCells,
    unmergeCells,
    sortRange,
    setBasicFilter,
    clearFilter,
    createFilterView,
    listFilterViews,
    deleteFilterView,
    addConditionalFormat,
    listConditionalFormats,
    updateConditionalFormat,
    deleteConditionalFormat,
    setDataValidation,
    createNamedRange,
    listNamedRanges,
    updateNamedRange,
    deleteNamedRange,
    protectRange,
    listProtections,
    unprotect,
    createChart,
    updateChart,
    deleteChart,
    getChart,
    exportChartPng,
    createPivotTable,
    updatePivotTable,
    deletePivotTable,
    find,
    findReplace,
    evaluate,
    validateFormula,
    explainFormula,
    getCell,
    getCellHistory,
    importCsv,
  ];
}
