import '../src/commands/json_schema.dart';

/// Personal-access-token scopes (suite 09 §2).
abstract final class McpScope {
  static const driveRead = 'drive:read';
  static const driveWrite = 'drive:write';
  static const writeRead = 'write:read';
  static const writeEdit = 'write:edit';
  static const sheetsRead = 'sheets:read';
  static const sheetsEdit = 'sheets:edit';
  static const scriptsRun = 'scripts:run';
  static const uiControl = 'ui:control';

  /// (v2) Read presentations (Slides 11 §2.4): read tools, exports, renders.
  static const slidesRead = 'slides:read';

  /// (v2) Edit presentations (Slides 11 §2.4).
  static const slidesEdit = 'slides:edit';

  /// Every scope, in display order.
  static const all = [
    driveRead,
    driveWrite,
    writeRead,
    writeEdit,
    sheetsRead,
    sheetsEdit,
    slidesRead,
    slidesEdit,
    scriptsRun,
    uiControl,
  ];
}

/// MCP tool behavior hints (`annotations` in `tools/list`).
class McpToolAnnotations {
  const McpToolAnnotations({
    this.readOnly = false,
    this.destructive = false,
    this.idempotent = false,
    this.openWorld = false,
  });

  final bool readOnly;
  final bool destructive;
  final bool idempotent;
  final bool openWorld;

  static const read = McpToolAnnotations(readOnly: true, idempotent: true);

  Map<String, Object?> toJson() => {
    'readOnlyHint': readOnly,
    'destructiveHint': destructive,
    'idempotentHint': idempotent,
    'openWorldHint': openWorld,
  };
}

/// The definition of one MCP tool: name, LLM-facing description and JSON
/// schemas. Shared by the server (`ToolExecutor`), the apps (UI bridge) and the
/// AI assistant. Names are public API: never rename, deprecate instead.
class McpToolDefinition {
  const McpToolDefinition({
    required this.name,
    required this.title,
    required this.description,
    required this.inputSchema,
    this.outputSchema,
    this.annotations = const McpToolAnnotations(),
    this.scopes = const {},
    this.timeout,
    this.deprecated = false,
  });

  /// `namespace.verb_noun` in snake_case.
  final String name;
  final String title;
  final String description;
  final ObjectSchema inputSchema;
  final JsonSchema? outputSchema;
  final McpToolAnnotations annotations;

  /// Any of these scopes grants access.
  final Set<String> scopes;

  /// Overrides the default 30 s UI-bridge timeout (e.g. `ui.wait_for`).
  final Duration? timeout;
  final bool deprecated;

  /// The namespace (`drive`, `ui`, …).
  String get namespace => name.substring(0, name.indexOf('.'));

  /// The `tools/list` entry.
  Map<String, Object?> toJson() => {
    'name': name,
    'title': title,
    'description': description,
    'inputSchema': inputSchema.toJson(),
    if (outputSchema != null) 'outputSchema': outputSchema!.toJson(),
    'annotations': annotations.toJson(),
  };
}

/// Common schema pieces for tool definitions.
abstract final class McpSchemas {
  static const uuid = JsonSchema.string(format: 'uuid');
  static const limit = JsonSchema.integer(
    minimum: 1,
    maximum: 200,
    defaultValue: 50,
    description: 'Maximum number of results (default 50).',
  );
  static const cursor = JsonSchema.string(
    description:
        'Opaque pagination cursor returned as next_cursor by a '
        'previous call.',
  );
  static const role = JsonSchema.string(
    enumValues: ['viewer', 'commenter', 'editor'],
    description: 'Access role to grant.',
  );
  static const kind = JsonSchema.string(
    enumValues: ['folder', 'document', 'spreadsheet', 'presentation', 'file'],
    description:
        'Item kind: folder, document (Wonky Write), spreadsheet (Wonky '
        'Sheets), presentation (Wonky Slides) or file (an uploaded file).',
  );

  /// (v2) Several kinds (`drive.search`, `drive.list_folder`).
  static const kinds = JsonSchema.array(
    kind,
    minItems: 1,
    description: 'Only items of these kinds (folders are kept only if listed).',
  );

  /// (v2) The category of an uploaded file (Drive 02 §1.2).
  static const fileCategory = JsonSchema.string(
    enumValues: [
      'image',
      'pdf',
      'text',
      'audio',
      'video',
      'archive',
      'document',
      'spreadsheet',
      'presentation',
      'other',
    ],
    description:
        'Uploaded files only: restrict file items to this category '
        '(document/spreadsheet/presentation = office files such as docx, '
        'xlsx, pptx). Other kinds are not affected.',
  );

  /// (v2) The caller's storage in results of byte-adding tools (suite 09 §4).
  static const storage = JsonSchema.object(
    additionalProperties: true,
    properties: {
      'used_bytes': JsonSchema.integer(),
      'quota_bytes': JsonSchema.integer(),
      'available_bytes': JsonSchema.integer(),
    },
  );

  /// The shape of a drive item in results.
  static const item = JsonSchema.object(
    additionalProperties: true,
    properties: {
      'uuid': uuid,
      'kind': kind,
      'name': JsonSchema.string(),
      'role': JsonSchema.string(),
      'owner': JsonSchema.string(),
      'modified_at': JsonSchema.string(format: 'date-time'),
      'url': JsonSchema.string(),
      'size_bytes': JsonSchema.integer(),
      'mime_type': JsonSchema.string(),
      'file_category': JsonSchema.string(),
      'upload_state': JsonSchema.string(),
    },
  );

  static const items = JsonSchema.object(
    additionalProperties: true,
    properties: {
      'items': JsonSchema.array(item),
      'next_cursor': JsonSchema.nullable(JsonSchema.string()),
    },
  );

  static const changeResult = JsonSchema.object(
    additionalProperties: true,
    properties: {
      'change_id': JsonSchema.string(),
      'item': item,
      'storage': storage,
    },
  );
}
