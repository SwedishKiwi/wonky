import '../src/commands/json_schema.dart';
import 'mcp_tool.dart';

/// Headless `drive.*` tools (suite 09 §4).
abstract final class DriveTools {
  static const search = McpToolDefinition(
    name: 'drive.search',
    title: 'Search the drive',
    description:
        'Full-text search over the names, descriptions and content of every '
        'drive item the user can access. Use it to find documents, '
        'spreadsheets or folders before reading or editing them. All filters '
        'are optional and combined with AND. Results are paginated: pass the '
        'returned next_cursor to get more.',
    inputSchema: ObjectSchema(
      properties: {
        'query': JsonSchema.string(description: 'Search text.'),
        'kind': McpSchemas.kind,
        'folder_uuid': McpSchemas.uuid,
        'owned_by_me': JsonSchema.boolean(),
        'shared_with_me': JsonSchema.boolean(),
        'starred': JsonSchema.boolean(),
        'modified_after': JsonSchema.string(
          format: 'date-time',
          description: 'ISO-8601 timestamp.',
        ),
        'limit': McpSchemas.limit,
        'cursor': McpSchemas.cursor,
      },
    ),
    outputSchema: McpSchemas.items,
    annotations: McpToolAnnotations.read,
    scopes: {McpScope.driveRead},
  );

  static const listFolder = McpToolDefinition(
    name: 'drive.list_folder',
    title: 'List a folder',
    description:
        'Lists the children of a folder. Omit folder_uuid to list the root '
        'of "My Drive". Folders are listed first.',
    inputSchema: ObjectSchema(
      properties: {
        'folder_uuid': JsonSchema.nullable(McpSchemas.uuid),
        'limit': McpSchemas.limit,
        'cursor': McpSchemas.cursor,
      },
    ),
    outputSchema: McpSchemas.items,
    annotations: McpToolAnnotations.read,
    scopes: {McpScope.driveRead},
  );

  static const getItem = McpToolDefinition(
    name: 'drive.get_item',
    title: 'Get a drive item',
    description:
        'Returns one item with the caller\'s role, its folder path and a '
        'sharing summary.',
    inputSchema: ObjectSchema(
      properties: {'uuid': McpSchemas.uuid},
      required: ['uuid'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: {McpScope.driveRead},
  );

  static const createFolder = McpToolDefinition(
    name: 'drive.create_folder',
    title: 'Create a folder',
    description: 'Creates a folder. Omit parent_uuid to create it at the root.',
    inputSchema: ObjectSchema(
      properties: {
        'name': JsonSchema.string(minLength: 1, maxLength: 255),
        'parent_uuid': JsonSchema.nullable(McpSchemas.uuid),
      },
      required: ['name'],
    ),
    outputSchema: McpSchemas.changeResult,
    scopes: {McpScope.driveWrite},
  );

  static const createDocument = McpToolDefinition(
    name: 'drive.create_document',
    title: 'Create a document',
    description:
        'Creates a Wonky Write document, optionally with initial Markdown '
        'content or from a template. Returns the new item; open it at '
        '/d/<uuid> in Wonky Write.',
    inputSchema: ObjectSchema(
      properties: {
        'name': JsonSchema.string(minLength: 1, maxLength: 255),
        'parent_uuid': JsonSchema.nullable(McpSchemas.uuid),
        'markdown': JsonSchema.string(
          description: 'Initial content as GitHub-flavored Markdown.',
        ),
        'template_uuid': McpSchemas.uuid,
      },
      required: ['name'],
    ),
    outputSchema: McpSchemas.changeResult,
    scopes: {McpScope.driveWrite},
  );

  static const createSpreadsheet = McpToolDefinition(
    name: 'drive.create_spreadsheet',
    title: 'Create a spreadsheet',
    description:
        'Creates a Wonky Sheets spreadsheet, optionally with named sheets and '
        'initial values (row-major 2-D arrays starting at A1; strings that '
        'start with "=" are formulas).',
    inputSchema: ObjectSchema(
      properties: {
        'name': JsonSchema.string(minLength: 1, maxLength: 255),
        'parent_uuid': JsonSchema.nullable(McpSchemas.uuid),
        'template_uuid': McpSchemas.uuid,
        'sheets': JsonSchema.array(
          JsonSchema.object(
            properties: {
              'name': JsonSchema.string(),
              'values': JsonSchema.array(JsonSchema.array(JsonSchema.any())),
            },
            required: ['name'],
          ),
        ),
      },
      required: ['name'],
    ),
    outputSchema: McpSchemas.changeResult,
    scopes: {McpScope.driveWrite},
  );

  static const rename = McpToolDefinition(
    name: 'drive.rename',
    title: 'Rename an item',
    description:
        'Renames a document, spreadsheet or folder (1–255 chars, no "/").',
    inputSchema: ObjectSchema(
      properties: {
        'uuid': McpSchemas.uuid,
        'name': JsonSchema.string(minLength: 1, maxLength: 255),
      },
      required: ['uuid', 'name'],
    ),
    outputSchema: McpSchemas.changeResult,
    annotations: McpToolAnnotations(idempotent: true),
    scopes: {McpScope.driveWrite},
  );

  static const move = McpToolDefinition(
    name: 'drive.move',
    title: 'Move items',
    description:
        'Moves one or more items into a folder (omit folder_uuid for the root '
        'of My Drive). Requires Editor on the target folder.',
    inputSchema: ObjectSchema(
      properties: {
        'uuids': JsonSchema.array(McpSchemas.uuid, minItems: 1),
        'folder_uuid': JsonSchema.nullable(McpSchemas.uuid),
      },
      required: ['uuids'],
    ),
    annotations: McpToolAnnotations(idempotent: true),
    scopes: {McpScope.driveWrite},
  );

  static const copy = McpToolDefinition(
    name: 'drive.copy',
    title: 'Copy an item',
    description: 'Makes a copy of a document or spreadsheet.',
    inputSchema: ObjectSchema(
      properties: {
        'uuid': McpSchemas.uuid,
        'name': JsonSchema.string(),
        'parent_uuid': JsonSchema.nullable(McpSchemas.uuid),
        'copy_comments': JsonSchema.boolean(defaultValue: false),
        'copy_sharing': JsonSchema.boolean(defaultValue: false),
      },
      required: ['uuid'],
    ),
    outputSchema: McpSchemas.changeResult,
    scopes: {McpScope.driveWrite},
  );

  static const trash = McpToolDefinition(
    name: 'drive.trash',
    title: 'Move to trash',
    description:
        'Moves items to the trash (restorable for 30 days with drive.restore).',
    inputSchema: ObjectSchema(
      properties: {'uuids': JsonSchema.array(McpSchemas.uuid, minItems: 1)},
      required: ['uuids'],
    ),
    annotations: McpToolAnnotations(destructive: true, idempotent: true),
    scopes: {McpScope.driveWrite},
  );

  static const restore = McpToolDefinition(
    name: 'drive.restore',
    title: 'Restore from trash',
    description: 'Restores trashed items to their previous folder.',
    inputSchema: ObjectSchema(
      properties: {'uuids': JsonSchema.array(McpSchemas.uuid, minItems: 1)},
      required: ['uuids'],
    ),
    annotations: McpToolAnnotations(idempotent: true),
    scopes: {McpScope.driveWrite},
  );

  static const star = McpToolDefinition(
    name: 'drive.star',
    title: 'Star or unstar',
    description:
        'Stars (or unstars, with starred: false) an item for the user.',
    inputSchema: ObjectSchema(
      properties: {
        'uuid': McpSchemas.uuid,
        'starred': JsonSchema.boolean(defaultValue: true),
      },
      required: ['uuid'],
    ),
    annotations: McpToolAnnotations(idempotent: true),
    scopes: {McpScope.driveWrite},
  );

  static const share = McpToolDefinition(
    name: 'drive.share',
    title: 'Share with a person',
    description:
        'Grants a person access to an item by email. People without an '
        'account receive a pending invite. Sharing is not undoable.',
    inputSchema: ObjectSchema(
      properties: {
        'uuid': McpSchemas.uuid,
        'email': JsonSchema.string(format: 'email'),
        'role': McpSchemas.role,
        'notify': JsonSchema.boolean(defaultValue: true),
        'message': JsonSchema.string(),
      },
      required: ['uuid', 'email', 'role'],
    ),
    scopes: {McpScope.driveWrite},
  );

  static const unshare = McpToolDefinition(
    name: 'drive.unshare',
    title: 'Remove access',
    description: 'Removes a person\'s direct access to an item.',
    inputSchema: ObjectSchema(
      properties: {
        'uuid': McpSchemas.uuid,
        'email': JsonSchema.string(format: 'email'),
      },
      required: ['uuid', 'email'],
    ),
    annotations: McpToolAnnotations(destructive: true, idempotent: true),
    scopes: {McpScope.driveWrite},
  );

  static const setLinkSharing = McpToolDefinition(
    name: 'drive.set_link_sharing',
    title: 'Set link sharing',
    description:
        'Sets "Anyone with the link" access: off (restricted), viewer, '
        'commenter or editor. Signed-in users only.',
    inputSchema: ObjectSchema(
      properties: {
        'uuid': McpSchemas.uuid,
        'mode': JsonSchema.string(
          enumValues: ['off', 'viewer', 'commenter', 'editor'],
        ),
      },
      required: ['uuid', 'mode'],
    ),
    annotations: McpToolAnnotations(idempotent: true),
    scopes: {McpScope.driveWrite},
  );

  static const export = McpToolDefinition(
    name: 'drive.export',
    title: 'Export an item',
    description:
        'Exports a document (md, txt, html, pdf, docx, odt, rtf, epub) or '
        'spreadsheet (xlsx, ods, csv, pdf). Text formats (md, txt, csv) are '
        'returned inline; others as a signed download_url valid for 15 min.',
    inputSchema: ObjectSchema(
      properties: {
        'uuid': McpSchemas.uuid,
        'format': JsonSchema.string(
          enumValues: [
            'md',
            'txt',
            'html',
            'docx',
            'odt',
            'rtf',
            'pdf',
            'epub',
            'xlsx',
            'ods',
            'csv',
          ],
        ),
      },
      required: ['uuid', 'format'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: {McpScope.driveRead},
  );

  static const import = McpToolDefinition(
    name: 'drive.import',
    title: 'Import a file',
    description:
        'Creates a new document from file content (base64: docx, odt, rtf, '
        'html, md, txt) or plain text (md, txt, html). Spreadsheets are not '
        'available yet.',
    inputSchema: ObjectSchema(
      properties: {
        'name': JsonSchema.string(minLength: 1, maxLength: 255),
        'kind': JsonSchema.string(enumValues: ['document', 'spreadsheet']),
        'format': JsonSchema.string(),
        'content_base64': JsonSchema.string(),
        'text': JsonSchema.string(),
        'parent_uuid': JsonSchema.nullable(McpSchemas.uuid),
      },
      required: ['name', 'kind', 'format'],
    ),
    outputSchema: McpSchemas.changeResult,
    scopes: {McpScope.driveWrite},
  );

  static const all = [
    search,
    listFolder,
    getItem,
    createFolder,
    createDocument,
    createSpreadsheet,
    rename,
    move,
    copy,
    trash,
    restore,
    star,
    share,
    unshare,
    setLinkSharing,
    export,
    import,
  ];
}
