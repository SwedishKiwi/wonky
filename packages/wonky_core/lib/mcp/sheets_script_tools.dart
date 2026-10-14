import '../src/commands/json_schema.dart';
import 'mcp_tool.dart';
import 'sheets_tools.dart';

/// The script tools of the `sheets.*` namespace (Sheets 09 §18, Sheets 12
/// §3.12): list and run functions, read and edit script files, read the
/// executions log.
abstract final class SheetsScriptTools {
  static const listFunctions = McpToolDefinition(
    name: 'sheets.list_script_functions',
    title: 'List script functions',
    description:
        'Lists the functions of the spreadsheet\'s script (last successful '
        'build): runnable functions, custom functions usable in formulas '
        '(e.g. =TO_F(A1)), simple triggers (onOpen, onEdit…) and macros, '
        'plus the installable triggers and the status of the latest build.',
    inputSchema: ObjectSchema(
      properties: {'spreadsheet': SheetsSchemas.spreadsheet},
      required: ['spreadsheet'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: {McpScope.sheetsRead},
  );

  static const runFunction = McpToolDefinition(
    name: 'sheets.run_function',
    title: 'Run a script function',
    description:
        'Runs a function of the spreadsheet\'s script on the server as the '
        'token\'s user and returns its result (JSON), logs and a change_id '
        'that changes.revert undoes. The user must have authorized the '
        'script once in the app (otherwise: authorization_required). No UI: '
        'SpreadsheetApp.ui throws. Example: {"spreadsheet": "…", '
        '"function": "archive"}.',
    inputSchema: ObjectSchema(
      properties: {
        'spreadsheet': SheetsSchemas.spreadsheet,
        'function': JsonSchema.string(minLength: 1, maxLength: 200),
        'args': JsonSchema.array(
          JsonSchema.any(),
          maxItems: 20,
          description: 'Positional arguments (JSON values).',
        ),
        'timeout_s': JsonSchema.integer(
          minimum: 1,
          maximum: 360,
          description: 'Time limit in seconds (default and maximum 360).',
        ),
      },
      required: ['spreadsheet', 'function'],
    ),
    annotations: McpToolAnnotations(destructive: true, openWorld: true),
    scopes: {McpScope.scriptsRun},
    timeout: Duration(minutes: 7),
  );

  static const getFiles = McpToolDefinition(
    name: 'sheets.get_script_files',
    title: 'Get script files',
    description:
        'Returns the Dart source files of the spreadsheet\'s script with '
        'their content hashes (pass one as base_hash to '
        'sheets.update_script_file).',
    inputSchema: ObjectSchema(
      properties: {
        'spreadsheet': SheetsSchemas.spreadsheet,
        'names': JsonSchema.array(
          JsonSchema.string(minLength: 1, maxLength: 70),
          maxItems: 50,
          description: 'File names (default: all).',
        ),
      },
      required: ['spreadsheet'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: {McpScope.sheetsRead},
  );

  static const updateFile = McpToolDefinition(
    name: 'sheets.update_script_file',
    title: 'Update a script file',
    description:
        'Writes a Dart source file of the spreadsheet\'s script (creating '
        'the script project and file when create_if_missing is true), then '
        'builds the script and returns the diagnostics. Scripts use the '
        'Wonky Dart subset (no mixins, extensions, late, typedefs, '
        'generators, switch expressions) and import '
        'package:wonky/wonky.dart. Fails with conflict when base_hash does '
        'not match the current content. Needs sheets:edit and scripts:run.',
    inputSchema: ObjectSchema(
      properties: {
        'spreadsheet': SheetsSchemas.spreadsheet,
        'name': JsonSchema.string(
          pattern: r'^[a-z][a-z0-9_]{0,63}\.dart$',
          description: 'File name, e.g. "main.dart".',
        ),
        'source': JsonSchema.string(maxLength: 500 * 1024),
        'base_hash': JsonSchema.string(maxLength: 64),
        'create_if_missing': JsonSchema.boolean(defaultValue: false),
      },
      required: ['spreadsheet', 'name', 'source'],
    ),
    annotations: McpToolAnnotations(destructive: true),
    scopes: {McpScope.scriptsRun},
    timeout: Duration(seconds: 90),
  );

  static const deleteFile = McpToolDefinition(
    name: 'sheets.delete_script_file',
    title: 'Delete a script file',
    description:
        'Deletes a file of the spreadsheet\'s script and rebuilds it. Needs '
        'sheets:edit and scripts:run.',
    inputSchema: ObjectSchema(
      properties: {
        'spreadsheet': SheetsSchemas.spreadsheet,
        'name': JsonSchema.string(minLength: 1, maxLength: 70),
      },
      required: ['spreadsheet', 'name'],
    ),
    annotations: McpToolAnnotations(destructive: true),
    scopes: {McpScope.scriptsRun},
  );

  static const getExecutions = McpToolDefinition(
    name: 'sheets.get_executions',
    title: 'Get script executions',
    description:
        'Returns recent executions of the spreadsheet\'s script, newest '
        'first, with status, duration, error and logs (truncated to 10 KB '
        'each). Editors see everyone\'s executions, others their own.',
    inputSchema: ObjectSchema(
      properties: {
        'spreadsheet': SheetsSchemas.spreadsheet,
        'function': JsonSchema.string(maxLength: 200),
        'status': JsonSchema.string(
          enumValues: [
            'completed',
            'failed',
            'timedOut',
            'cancelled',
            'quotaExceeded',
            'skipped',
          ],
        ),
        'limit': JsonSchema.integer(minimum: 1, maximum: 100, defaultValue: 20),
        'cursor': JsonSchema.string(
          maxLength: 64,
          description: 'next_cursor of the previous page.',
        ),
      },
      required: ['spreadsheet'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: {McpScope.sheetsRead},
  );

  static const all = [
    listFunctions,
    runFunction,
    getFiles,
    updateFile,
    deleteFile,
    getExecutions,
  ];
}
