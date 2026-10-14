import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show McpToolDefinition;

import '../common/models.dart';
import '../mcp/tool_executor.dart';
import '../mcp/tool_support.dart';
import 'llm/ai_client.dart';

/// One MCP tool as the assistant sees it.
class AssistantTool {
  AssistantTool._(this.definition, this.api, this.bound);

  final McpToolDefinition definition;

  /// The definition sent to the model (name without dots, bound keys
  /// removed).
  final AiToolSpec api;

  /// Argument keys the server fills in (`document_uuid`, `uuid`, `mode`).
  final Set<String> bound;

  String get name => definition.name;
  String get apiName => api.name;

  /// Whether the tool changes the document or its comments.
  bool get mutating => !definition.annotations.readOnly;
}

/// The tools of the assistant, generated from the MCP tool registry with
/// the same JSON schemas (suite 10 §1, Write 09 §5.2), **bound to the open
/// document**: `document_uuid` / `uuid` are removed from the schemas sent
/// to the model and injected on execution, so the model cannot target other
/// files; `mode` follows the panel's apply mode. Sharing, deletion, raw
/// Delta / whole-document replacement, URL images, `changes.revert`,
/// theme-library mutations and `ui.*` are never exposed (13 §1).
class AssistantToolset {
  AssistantToolset._(this.tools);

  /// Write 09 §5.2 allowlist (tools that are not registered are skipped).
  static const writeAllowlist = [
    'write.get_document',
    'write.get_outline',
    'write.get_stats',
    'write.search',
    'write.get_page_setup',
    'write.insert_markdown',
    'write.replace_text',
    'write.replace_range',
    'write.delete_range',
    'write.apply_format',
    'write.set_block_type',
    'write.insert_table',
    'write.update_table',
    'write.list_suggestions',
    'write.suggest_edit',
    'write.accept_suggestion',
    'write.reject_suggestion',
    'comments.list',
    'comments.create',
    'comments.reply',
    'versions.list',
    'versions.get',
    'write.compare_versions',
    'write.list_themes',
    'write.get_theme',
    'write.apply_theme',
    'write.update_page_setup',
  ];

  /// Never exposed, whatever the allowlist says.
  static const denied = {
    'drive.share',
    'drive.unshare',
    'drive.set_link_sharing',
    'drive.trash',
    'drive.delete',
    'write.set_markdown',
    'write.apply_delta',
    'write.insert_image',
    'changes.revert',
    'write.create_theme',
    'write.update_theme',
  };

  /// Keys bound to the open document.
  static const _documentKeys = {'document_uuid', 'uuid', 'spreadsheet'};

  final List<AssistantTool> tools;

  late final Map<String, AssistantTool> _byApiName = {
    for (final t in tools) t.apiName: t,
  };

  /// The toolset of a Write document from [executor]'s registry.
  /// `accept_suggestion` / `reject_suggestion` only for Editors+.
  factory AssistantToolset.write(
    ToolExecutor executor, {
    required bool canDecideSuggestions,
  }) {
    final defs = <McpToolDefinition>[];
    for (final name in writeAllowlist) {
      if (denied.contains(name) || name.startsWith('ui.')) continue;
      if (!canDecideSuggestions &&
          (name == 'write.accept_suggestion' ||
              name == 'write.reject_suggestion')) {
        continue;
      }
      final t = executor[name];
      if (t != null) defs.add(t.definition);
    }
    return AssistantToolset.of(defs);
  }

  /// A toolset of [definitions] (sorted by API name: a deterministic order
  /// keeps provider-side prompt caches warm).
  factory AssistantToolset.of(List<McpToolDefinition> definitions) {
    final tools = <AssistantTool>[];
    for (final d in definitions) {
      final schema = jsonDecode(jsonEncode(d.inputSchema.toJson())) as Map;
      final props =
          (schema['properties'] as Map?)?.cast<String, Object?>() ??
          <String, Object?>{};
      final bound = <String>{
        for (final k in props.keys)
          if (_documentKeys.contains(k) || k == 'mode') k,
      };
      for (final k in bound) {
        props.remove(k);
      }
      final required = [
        for (final r in (schema['required'] as List?) ?? const [])
          if (!bound.contains(r)) r,
      ];
      final out = <String, Object?>{
        ...schema.cast<String, Object?>(),
        'properties': props,
      };
      if (required.isEmpty) {
        out.remove('required');
      } else {
        out['required'] = required;
      }
      tools.add(
        AssistantTool._(
          d,
          AiToolSpec(
            name: apiNameOf(d.name),
            description: _describe(d),
            inputSchema: out,
          ),
          bound,
        ),
      );
    }
    tools.sort((a, b) => a.apiName.compareTo(b.apiName));
    return AssistantToolset._(tools);
  }

  /// `write.get_document` → `write_get_document` (API tool names allow
  /// `[a-zA-Z0-9_-]` only).
  static String apiNameOf(String mcpName) =>
      mcpName.replaceAll('.', '_').replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');

  static String _describe(McpToolDefinition d) {
    final b = StringBuffer(d.description);
    if (d.inputSchema.properties.containsKey('spreadsheet')) {
      b.write(' Operates on the open spreadsheet.');
    } else if (d.inputSchema.properties.containsKey('document_uuid') ||
        d.inputSchema.properties.containsKey('uuid')) {
      b.write(' Operates on the open document.');
    }
    return b.toString();
  }

  /// The API definitions.
  List<AiToolSpec> get apiTools => [for (final t in tools) t.api];

  AssistantTool? byApiName(String name) => _byApiName[name];

  /// The MCP arguments of a model call: the model's [input] plus the bound
  /// keys.
  Map<String, Object?> bindArgs(
    AssistantTool tool,
    Map<String, Object?> input, {
    required UuidValue itemUuid,
    required AiApplyMode applyMode,
  }) {
    final args = <String, Object?>{
      for (final e in input.entries)
        if (!tool.bound.contains(e.key)) e.key: e.value,
    };
    for (final k in tool.bound) {
      if (_documentKeys.contains(k)) {
        args[k] = itemUuid.uuid;
      } else if (k == 'mode') {
        args[k] = applyMode == AiApplyMode.suggest ? 'suggest' : 'edit';
      }
    }
    return args;
  }
}

/// Executes the assistant's tool calls through the shared [ToolExecutor]
/// (same validation, permission checks and structured errors as MCP).
class AssistantToolRunner {
  AssistantToolRunner({
    required this.executor,
    required this.toolset,
    required this.itemUuid,
    required this.itemId,
  });

  final ToolExecutor executor;
  final AssistantToolset toolset;
  final UuidValue itemUuid;
  final int itemId;

  /// Runs one call. Unknown and disallowed tools fail with `forbidden` even
  /// if the model tries them.
  Future<ToolOutcome> run(
    ToolContext ctx,
    String apiName,
    Map<String, Object?> input, {
    required AiApplyMode applyMode,
  }) async {
    final tool = toolset.byApiName(apiName);
    if (tool == null) {
      return ToolOutcome.failure(
        McpToolException(
          McpErrorCode.forbidden,
          'The tool "$apiName" is not available to the assistant.',
        ),
      );
    }
    final args = toolset.bindArgs(
      tool,
      input,
      itemUuid: itemUuid,
      applyMode: applyMode,
    );
    // Threads of other files are out of reach (comments.reply).
    final thread = args['thread_uuid'];
    if (thread is String) {
      UuidValue? id;
      try {
        id = UuidValue.withValidation(thread);
      } on FormatException {
        id = null;
      }
      final row = id == null
          ? null
          : await CommentThread.db.findFirstRow(
              ctx.session,
              where: (t) => t.uuid.equals(id),
            );
      if (row == null || row.itemId != itemId) {
        return ToolOutcome.failure(
          McpToolException(
            McpErrorCode.notFound,
            'No comment thread $thread on this document.',
          ),
        );
      }
    }
    return executor.call(ctx, tool.name, args);
  }
}
