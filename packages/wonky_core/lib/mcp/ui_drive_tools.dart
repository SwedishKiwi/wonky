import '../src/commands/json_schema.dart';
import 'mcp_tool.dart';

/// (v2, P1) Wonky Drive UI-bridge tools (`ui.drive.*`, Drive 04 §13),
/// executed in the live Wonky Drive window. Actions are commands
/// (`ui.invoke_command` with `drive.*` / `shell.*` ids); these tools cover
/// window state that isn't a command. Uploading bytes goes through the
/// headless `drive.upload_file`, not the bridge. The handlers live in
/// `wonky_drive/lib/mcp/` (D-17); until a Drive window implements a tool,
/// calls answer `no_session`.
abstract final class UiDriveTools {
  static const _scopes = {McpScope.uiControl};
  static const _session = JsonSchema.string(
    description:
        'Target window from ui.list_sessions; defaults to the most recently '
        'focused Wonky Drive window.',
  );

  static ObjectSchema _schema([
    Map<String, JsonSchema> props = const {},
    List<String> required = const [],
  ]) => ObjectSchema(
    properties: {'session_id': _session, ...props},
    required: required,
  );

  static final getSelection = McpToolDefinition(
    name: 'ui.drive.get_selection',
    title: 'Get the selection',
    description:
        'Returns the Drive window\'s current folder (uuid, name, path), the '
        'view (my drive, recent, starred, shared, trash, search, storage) '
        'and the selected items (uuid, name, kind, file_category, '
        'size_bytes).',
    inputSchema: _schema(),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final selectItems = McpToolDefinition(
    name: 'ui.drive.select_items',
    title: 'Select items',
    description:
        'Selects items of the current listing by uuid (replacing the '
        'selection) and scrolls the first one into view. Items that are not '
        'in the listing are reported in not_found.',
    inputSchema: _schema(
      {
        'uuids': const JsonSchema.array(
          JsonSchema.string(format: 'uuid'),
          maxItems: 500,
        ),
      },
      ['uuids'],
    ),
    scopes: _scopes,
  );

  static final getUploadQueue = McpToolDefinition(
    name: 'ui.drive.get_upload_queue',
    title: 'Get the upload queue',
    description:
        'Returns the window\'s upload queue: per upload the item uuid, name, '
        'size_bytes, state (queued, waitingForNetwork, starting, uploading, '
        'verifying, done, failed, cancelled), sent_bytes and '
        'the error, plus totals.',
    inputSchema: _schema(),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final openPreview = McpToolDefinition(
    name: 'ui.drive.open_preview',
    title: 'Open a file preview',
    description:
        'Opens the preview of an uploaded file (/file/<uuid>) in the Drive '
        'window.',
    inputSchema: _schema(
      {'uuid': const JsonSchema.string(format: 'uuid')},
      ['uuid'],
    ),
    scopes: _scopes,
  );

  static final getPreviewState = McpToolDefinition(
    name: 'ui.drive.get_preview_state',
    title: 'Get the preview state',
    description:
        'Describes the open file preview: uuid, viewer type (image, text, '
        'csv, unsupported, error; PDFs are unsupported), zoom (percent) and '
        'the error, if any.',
    inputSchema: _schema(),
    annotations: McpToolAnnotations.read,
    scopes: _scopes,
  );

  static final all = [
    getSelection,
    selectItems,
    getUploadQueue,
    openPreview,
    getPreviewState,
  ];
}
