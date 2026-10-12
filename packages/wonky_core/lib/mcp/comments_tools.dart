import '../src/commands/json_schema.dart';
import 'mcp_tool.dart';

const _anchor = JsonSchema.object(
  additionalProperties: true,
  description:
      'Where the comment attaches. Write: {"quote": "text", "occurrence": 1} '
      'or {"start": <0-based Delta offset>, "length": n}. Sheets: '
      '{"sheet": "Sheet1", "a1": "B4"} or a range "B4:C9". Omit for a '
      'document-level comment.',
  properties: {
    'quote': JsonSchema.string(),
    'occurrence': JsonSchema.integer(minimum: 1),
    'start': JsonSchema.integer(minimum: 0),
    'length': JsonSchema.integer(minimum: 0),
    'sheet': JsonSchema.string(),
    'a1': JsonSchema.string(),
    'document': JsonSchema.boolean(
      description: 'true for a comment on the whole document.',
    ),
  },
);

const _thread = JsonSchema.object(
  additionalProperties: true,
  properties: {'thread_uuid': McpSchemas.uuid, 'status': JsonSchema.string()},
);

/// Headless `comments.*` tools (suite 09 §4).
abstract final class CommentsTools {
  static const list = McpToolDefinition(
    name: 'comments.list',
    title: 'List comments',
    description:
        'Lists comment threads of a document or spreadsheet with their '
        'replies. Filter by status (open, resolved).',
    inputSchema: ObjectSchema(
      properties: {
        'uuid': McpSchemas.uuid,
        'status': JsonSchema.string(enumValues: ['open', 'resolved', 'all']),
      },
      required: ['uuid'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: {McpScope.writeRead, McpScope.sheetsRead},
  );

  static const create = McpToolDefinition(
    name: 'comments.create',
    title: 'Create a comment',
    description:
        'Starts a comment thread anchored to text (Write) or a cell/range '
        '(Sheets). Mention people with @email in the body (Markdown).',
    inputSchema: ObjectSchema(
      properties: {
        'uuid': McpSchemas.uuid,
        'anchor': _anchor,
        'body': JsonSchema.string(minLength: 1),
      },
      required: ['uuid', 'body'],
    ),
    outputSchema: _thread,
    scopes: {McpScope.writeEdit, McpScope.sheetsEdit},
  );

  static const reply = McpToolDefinition(
    name: 'comments.reply',
    title: 'Reply to a comment',
    description: 'Adds a reply to a comment thread.',
    inputSchema: ObjectSchema(
      properties: {
        'thread_uuid': McpSchemas.uuid,
        'body': JsonSchema.string(minLength: 1),
      },
      required: ['thread_uuid', 'body'],
    ),
    scopes: {McpScope.writeEdit, McpScope.sheetsEdit},
  );

  static const resolve = McpToolDefinition(
    name: 'comments.resolve',
    title: 'Resolve a thread',
    description: 'Marks a comment thread as resolved.',
    inputSchema: ObjectSchema(
      properties: {'thread_uuid': McpSchemas.uuid},
      required: ['thread_uuid'],
    ),
    annotations: McpToolAnnotations(idempotent: true),
    scopes: {McpScope.writeEdit, McpScope.sheetsEdit},
  );

  static const reopen = McpToolDefinition(
    name: 'comments.reopen',
    title: 'Reopen a thread',
    description: 'Reopens a resolved comment thread.',
    inputSchema: ObjectSchema(
      properties: {'thread_uuid': McpSchemas.uuid},
      required: ['thread_uuid'],
    ),
    annotations: McpToolAnnotations(idempotent: true),
    scopes: {McpScope.writeEdit, McpScope.sheetsEdit},
  );

  static const delete = McpToolDefinition(
    name: 'comments.delete',
    title: 'Delete a comment',
    description:
        'Deletes one comment (comment_id) or a whole thread (thread_uuid). '
        'Authors can delete their own comments; editors can delete threads.',
    inputSchema: ObjectSchema(
      properties: {
        'thread_uuid': McpSchemas.uuid,
        'comment_id': JsonSchema.integer(),
      },
    ),
    annotations: McpToolAnnotations(destructive: true),
    scopes: {McpScope.writeEdit, McpScope.sheetsEdit},
  );

  static const all = [list, create, reply, resolve, reopen, delete];
}

/// Headless `versions.*` tools (suite 09 §4).
abstract final class VersionsTools {
  static const list = McpToolDefinition(
    name: 'versions.list',
    title: 'List versions',
    description:
        'Lists saved versions (auto and named) of a document or spreadsheet, '
        'newest first. Requires Editor access.',
    inputSchema: ObjectSchema(
      properties: {
        'uuid': McpSchemas.uuid,
        'named_only': JsonSchema.boolean(defaultValue: false),
      },
      required: ['uuid'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: {McpScope.writeRead, McpScope.sheetsRead},
  );

  static const nameCurrent = McpToolDefinition(
    name: 'versions.name_current',
    title: 'Name the current version',
    description: 'Saves the current state as a named version.',
    inputSchema: ObjectSchema(
      properties: {
        'uuid': McpSchemas.uuid,
        'name': JsonSchema.string(minLength: 1, maxLength: 200),
      },
      required: ['uuid', 'name'],
    ),
    scopes: {McpScope.writeEdit, McpScope.sheetsEdit},
  );

  static const get = McpToolDefinition(
    name: 'versions.get',
    title: 'Read a version',
    description:
        'Returns the content of a version: Write as Markdown; Sheets as a '
        'values JSON for range (A1 notation, default the used range of the '
        'first sheet).',
    inputSchema: ObjectSchema(
      properties: {
        'uuid': McpSchemas.uuid,
        'version_id': JsonSchema.integer(),
        'format': JsonSchema.string(
          enumValues: ['markdown', 'text', 'delta', 'values'],
        ),
        'range': JsonSchema.string(),
      },
      required: ['uuid', 'version_id'],
    ),
    annotations: McpToolAnnotations.read,
    scopes: {McpScope.writeRead, McpScope.sheetsRead},
  );

  static const restore = McpToolDefinition(
    name: 'versions.restore',
    title: 'Restore a version',
    description:
        'Restores a version as a new forward edit (a restore point of the '
        'current state is saved first). Revert with changes.revert.',
    inputSchema: ObjectSchema(
      properties: {'uuid': McpSchemas.uuid, 'version_id': JsonSchema.integer()},
      required: ['uuid', 'version_id'],
    ),
    outputSchema: McpSchemas.changeResult,
    scopes: {McpScope.writeEdit, McpScope.sheetsEdit},
  );

  static const all = [list, nameCurrent, get, restore];
}

/// Headless `changes.*` tools (suite 09 §4).
abstract final class ChangesTools {
  static const revert = McpToolDefinition(
    name: 'changes.revert',
    title: 'Revert a change',
    description:
        'Reverts a change made by a previous headless tool call, identified by '
        'the change_id it returned (24 h window). Columns or text edited by '
        'someone else since are left untouched.',
    inputSchema: ObjectSchema(
      properties: {'change_id': JsonSchema.string(minLength: 1)},
      required: ['change_id'],
    ),
    scopes: {McpScope.writeEdit, McpScope.sheetsEdit, McpScope.driveWrite},
  );

  static const all = [revert];
}
