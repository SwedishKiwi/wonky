import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show McpToolDefinition;

import '../common/models.dart';
import '../mcp/tool_executor.dart';
import '../mcp/tool_support.dart';
import 'anthropic/anthropic_types.dart';

/// One MCP tool as the assistant sees it.
class AssistantTool {
  AssistantTool._(this.definition, this.api, this.bound);

  final McpToolDefinition definition;

  /// The Messages API definition (name without dots, bound keys removed).
  final AnthropicTool api;

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
  static const _documentKeys = {'document_uuid', 'uuid'};

  /// At most this many tools are marked `strict` (schema compilation cost
  /// and API limits); mutating tools first.
  static const maxStrictTools = 16;

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
  /// keeps the prompt cache prefix stable).
  factory AssistantToolset.of(List<McpToolDefinition> definitions) {
    final built = <(McpToolDefinition, Map<String, Object?>, Set<String>, bool)>[];
    for (final d in definitions) {
      final schema = jsonDecode(jsonEncode(d.inputSchema.toJson())) as Map;
      final props = (schema['properties'] as Map?)?.cast<String, Object?>() ??
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
      final strictOk = _strictCompatible(out);
      built.add((d, strictOk ? _stripForStrict(out) : out, bound, strictOk));
    }
    // Strict budget: mutating tools first, then by name.
    final strictNames = (built.where((b) => b.$4).toList()
          ..sort((a, b) {
            final ma = a.$1.annotations.readOnly ? 1 : 0;
            final mb = b.$1.annotations.readOnly ? 1 : 0;
            return ma != mb ? ma - mb : a.$1.name.compareTo(b.$1.name);
          }))
        .take(maxStrictTools)
        .map((b) => b.$1.name)
        .toSet();
    final tools = [
      for (final b in built)
        AssistantTool._(
          b.$1,
          AnthropicTool(
            name: apiNameOf(b.$1.name),
            description: _describe(b.$1),
            inputSchema: b.$2,
            strictCompatible: strictNames.contains(b.$1.name),
          ),
          b.$3,
        ),
    ]..sort((a, b) => a.apiName.compareTo(b.apiName));
    return AssistantToolset._(tools);
  }

  /// `write.get_document` → `write_get_document` (API tool names allow
  /// `[a-zA-Z0-9_-]` only).
  static String apiNameOf(String mcpName) =>
      mcpName.replaceAll('.', '_').replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');

  static String _describe(McpToolDefinition d) {
    final b = StringBuffer(d.description);
    if (d.inputSchema.properties.containsKey('document_uuid') ||
        d.inputSchema.properties.containsKey('uuid')) {
      b.write(' Operates on the open document.');
    }
    return b.toString();
  }

  /// The API definitions.
  List<AnthropicTool> get apiTools => [for (final t in tools) t.api];

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

  /// Whether [schema] fits the strict-mode subset: every object closed
  /// (`additionalProperties: false`) and no recursion.
  static bool _strictCompatible(Object? schema) {
    if (schema is List) return schema.every(_strictCompatible);
    if (schema is! Map) return true;
    if (schema['type'] == 'object' || schema['properties'] is Map) {
      if (schema['additionalProperties'] != false) return false;
    }
    if (schema.containsKey(r'$ref')) return false;
    for (final v in schema.values) {
      if (v is Map || v is List) {
        if (!_strictCompatible(v)) return false;
      }
    }
    return true;
  }

  static const _unsupported = {
    'minimum',
    'maximum',
    'exclusiveMinimum',
    'exclusiveMaximum',
    'multipleOf',
    'minLength',
    'maxLength',
    'minItems',
    'maxItems',
    'pattern',
  };

  /// Removes keywords strict mode does not support (the executor still
  /// validates them against the original schema).
  static Map<String, Object?> _stripForStrict(Map<String, Object?> schema) {
    Object? walk(Object? v, {bool isProperties = false}) {
      if (v is List) return [for (final e in v) walk(e)];
      if (v is! Map) return v;
      return <String, Object?>{
        for (final e in v.entries)
          if (isProperties || !_unsupported.contains(e.key))
            '${e.key}': walk(e.value, isProperties: e.key == 'properties'),
      };
    }

    return walk(schema) as Map<String, Object?>;
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
