import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_write_core/wonky_write_core.dart' show AddressException;

import '../common/models.dart';
import 'tool_support.dart';

/// Sliding-window rate limit per token (suite 09 §2: 600 tool calls per
/// minute per token).
class McpRateLimiter {
  McpRateLimiter({this.limit = 600, this.window = const Duration(minutes: 1)});

  final int limit;
  final Duration window;
  final Map<Object, List<DateTime>> _calls = {};

  /// Records a call for [key]; returns the retry delay when over the limit.
  Duration? hit(Object key) {
    final now = clock.now();
    final list = _calls.putIfAbsent(key, () => []);
    list.removeWhere((t) => now.difference(t) >= window);
    if (list.length >= limit) {
      return window - now.difference(list.first);
    }
    list.add(now);
    if (_calls.length > 10000) {
      _calls.removeWhere((_, v) => v.isEmpty);
    }
    return null;
  }

  void reset() => _calls.clear();
}

/// A registered tool: its shared definition plus the implementation.
class RegisteredMcpTool {
  const RegisteredMcpTool(this.definition, this.handler);

  final McpToolDefinition definition;
  final ToolHandler handler;
}

/// Dispatches tool calls by name (suite 09 §3): looks the tool up, checks
/// the token's scopes, validates the arguments against the shared JSON
/// schema, applies the rate limit, runs the handler and maps every failure
/// to a structured error (`{code, message, details}`, suite 09 §7).
///
/// Handlers do their own permission checks through `AccessService` (the
/// effective role on the target item), exactly like the endpoints the apps
/// use.
class ToolExecutor {
  ToolExecutor(Iterable<RegisteredMcpTool> tools, {McpRateLimiter? rateLimiter})
    : _tools = {for (final t in tools) t.definition.name: t},
      rateLimiter = rateLimiter ?? McpRateLimiter();

  final Map<String, RegisteredMcpTool> _tools;
  final McpRateLimiter rateLimiter;

  /// The tools in registration order.
  Iterable<RegisteredMcpTool> get tools => _tools.values;

  RegisteredMcpTool? operator [](String name) => _tools[name];

  /// Calls [name] with [arguments] as the token user of [ctx].
  Future<ToolOutcome> call(
    ToolContext ctx,
    String name,
    Map<String, Object?> arguments,
  ) async {
    final tool = _tools[name];
    if (tool == null) {
      return ToolOutcome.failure(
        McpToolException(
          McpErrorCode.notFound,
          'Unknown tool "$name". Call tools/list for the available tools.',
        ),
      );
    }
    final def = tool.definition;
    if (!ctx.hasAnyScope(def.scopes)) {
      return ToolOutcome.failure(
        McpToolException(
          McpErrorCode.forbidden,
          'The access token lacks the scope for $name '
          '(needs one of: ${def.scopes.join(', ')}).',
          details: {'required_scopes': def.scopes.toList()},
        ),
      );
    }
    final violations = def.inputSchema.validate(arguments);
    if (violations.isNotEmpty) {
      return ToolOutcome.failure(
        McpToolException.invalidArgs(
          'Invalid arguments for $name: ${violations.first}',
          violations: violations,
        ),
      );
    }
    final retry = rateLimiter.hit(ctx.tokenId ?? 'user:${ctx.actor.userId}');
    if (retry != null) {
      return ToolOutcome.failure(
        McpToolException(
          McpErrorCode.rateLimited,
          'Too many tool calls; retry in ${retry.inSeconds + 1} s.',
          details: {'retry_after_ms': retry.inMilliseconds},
        ),
      );
    }
    try {
      final result = await tool.handler(ctx, ToolArgs(arguments));
      return ToolOutcome.success(result);
    } on McpToolException catch (e) {
      return ToolOutcome.failure(e);
    } on AddressException catch (e) {
      return ToolOutcome.failure(
        McpToolException(e.code, e.message, details: e.details),
      );
    } on WonkyException catch (e) {
      return ToolOutcome.failure(McpToolException.fromWonky(e));
    } on Exception catch (e, st) {
      ctx.session.log(
        'MCP tool $name failed: $e',
        level: LogLevel.error,
        stackTrace: st,
      );
      return ToolOutcome.failure(
        McpToolException(McpErrorCode.internal, 'The tool failed: $e'),
      );
    } on Error catch (e, st) {
      ctx.session.log(
        'MCP tool $name crashed: $e',
        level: LogLevel.error,
        stackTrace: st,
      );
      return ToolOutcome.failure(
        McpToolException(McpErrorCode.internal, 'The tool failed.'),
      );
    }
  }
}
