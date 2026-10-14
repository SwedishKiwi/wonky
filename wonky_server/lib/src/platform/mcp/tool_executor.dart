import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_write_core/wonky_write_core.dart' show AddressException;

import '../common/models.dart';
import 'tool_support.dart';

/// A counter shared by all instances (specs/13 §4).
abstract interface class RateCounter {
  /// Increments [key] and returns the new count; the key expires after
  /// [ttl] (set when it is created). Throws when unreachable.
  Future<int> increment(String key, Duration ttl);
}

/// [RateCounter] in Redis (`INCR` + `PEXPIRE`).
class RedisRateCounter implements RateCounter {
  RedisRateCounter(this.redis);

  final RedisController redis;

  @override
  Future<int> increment(String key, Duration ttl) async {
    final command = await redis.getConnection();
    if (command == null) throw StateError('Redis is unreachable.');
    try {
      final count = await command.send_object(['INCR', key]);
      if (count is! int) throw StateError('Unexpected INCR reply: $count');
      if (count == 1) {
        await command.send_object(['PEXPIRE', key, '${ttl.inMilliseconds}']);
      }
      return count;
    } on Object {
      // Lets the controller drop a broken connection and reconnect.
      await redis.ping();
      rethrow;
    }
  }
}

/// Rate limit per token (suite 09 §2: 600 tool calls per minute per
/// token). On a single instance a sliding window in memory; with several
/// instances (Redis enabled, specs/13 §4) a fixed one-minute window counted
/// in Redis, so the limit holds across instances (at a window boundary up
/// to twice the limit can pass within a minute). When the counter cannot
/// be reached the in-memory window applies.
class McpRateLimiter {
  McpRateLimiter({
    this.limit = 600,
    this.window = const Duration(minutes: 1),
    RateCounter? counter,
    // ignore: prefer_initializing_formals
  }) : _counter = counter;

  final int limit;
  final Duration window;
  final Map<Object, List<DateTime>> _calls = {};
  final RateCounter? _counter;
  RedisRateCounter? _redisCounter;

  RateCounter? get counter {
    if (_counter != null) return _counter;
    final redis = Serverpod.instance.redisController;
    if (redis == null) return null;
    if (_redisCounter?.redis != redis) _redisCounter = RedisRateCounter(redis);
    return _redisCounter;
  }

  /// Records a call for [key]; returns the retry delay when over the limit.
  Future<Duration?> check(Object key) async {
    final shared = counter;
    if (shared == null) return hit(key);
    final now = clock.now();
    final ms = window.inMilliseconds;
    final slot = now.millisecondsSinceEpoch ~/ ms;
    try {
      final count = await shared.increment(
        'wonky:mcp:rate:$key:$slot',
        window * 2,
      );
      if (count <= limit) return null;
      return Duration(
        milliseconds: (slot + 1) * ms - now.millisecondsSinceEpoch,
      );
    } on Object {
      return hit(key);
    }
  }

  /// Records a call for [key] in this instance's sliding window; returns
  /// the retry delay when over the limit.
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
  ToolExecutor(
    Iterable<RegisteredMcpTool> tools, {
    McpRateLimiter? rateLimiter,
    McpRateLimiter? targetWriteLimiter,
  }) : _tools = {for (final t in tools) t.definition.name: t},
       rateLimiter = rateLimiter ?? McpRateLimiter(),
       targetWriteLimiter =
           targetWriteLimiter ?? McpRateLimiter(limit: targetWriteLimit);

  final Map<String, RegisteredMcpTool> _tools;
  final McpRateLimiter rateLimiter;

  /// Mutating calls per minute per token and target file (Sheets 12 §3.14:
  /// 60 per spreadsheet), on top of the per-token limit.
  final McpRateLimiter targetWriteLimiter;

  static const targetWriteLimit = 60;

  /// Argument keys naming the file a mutating call writes to.
  static const _targetKeys = ['spreadsheet'];
  static final _uuid = RegExp(
    '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
  );

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
    final retry = await rateLimiter.check(
      ctx.tokenId ?? 'user:${ctx.actor.userId}',
    );
    if (retry != null) {
      return ToolOutcome.failure(
        McpToolException(
          McpErrorCode.rateLimited,
          'Too many tool calls; retry in ${retry.inSeconds + 1} s.',
          details: {'retry_after_ms': retry.inMilliseconds},
        ),
      );
    }
    final target = _writeTarget(def, arguments);
    if (target != null && ctx.tokenId != null) {
      final wait = await targetWriteLimiter.check(
        'token:${ctx.tokenId}:target:$target',
      );
      if (wait != null) {
        return ToolOutcome.failure(
          McpToolException(
            McpErrorCode.rateLimited,
            'Too many changes to this file (at most $targetWriteLimit per '
            'minute); retry in ${wait.inSeconds + 1} s.',
            details: {
              'retry_after_ms': wait.inMilliseconds,
              'limit': targetWriteLimit,
            },
          ),
        );
      }
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

  /// The file a mutating call of [def] writes to (null for read-only tools
  /// and tools without a target argument).
  static String? _writeTarget(
    McpToolDefinition def,
    Map<String, Object?> arguments,
  ) {
    if (def.annotations.readOnly) return null;
    for (final k in _targetKeys) {
      final v = arguments[k];
      if (v is String && v.trim().isNotEmpty) {
        // A URL and the bare uuid count as the same file.
        final t = v.trim().toLowerCase();
        return _uuid.firstMatch(t)?.group(0) ?? t;
      }
    }
    return null;
  }
}
