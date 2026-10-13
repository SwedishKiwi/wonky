import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';

/// What another instance needs to resume an initialize-era MCP session
/// (suite 09 §1): the owning token and user, the client's name and its
/// `initialize` parameters (replayed to bring the protocol layer to the
/// same state). The tools themselves are stateless.
class McpSessionRecord {
  const McpSessionRecord({
    required this.tokenId,
    required this.userId,
    this.clientName,
    this.initializeParams,
  });

  final int tokenId;
  final int userId;
  final String? clientName;
  final Map<String, Object?>? initializeParams;

  Map<String, Object?> toJson() => {
    'tokenId': tokenId,
    'userId': userId,
    'clientName': clientName,
    'initializeParams': initializeParams,
  };

  static McpSessionRecord fromJson(Map<String, Object?> json) =>
      McpSessionRecord(
        tokenId: json['tokenId']! as int,
        userId: json['userId']! as int,
        clientName: json['clientName'] as String?,
        initializeParams: (json['initializeParams'] as Map?)
            ?.cast<String, Object?>(),
      );
}

/// Cluster-wide registry of MCP sessions (specs/13 §4), so a request with
/// an `Mcp-Session-Id` can land on any instance. Entries expire after the
/// session idle time unless refreshed.
abstract interface class McpSessionDirectory {
  Future<void> put(String id, McpSessionRecord record, Duration ttl);

  /// The record of [id], null when unknown or expired. Throws when the
  /// directory cannot be reached (callers then trust local state).
  Future<McpSessionRecord?> get(String id);

  Future<void> remove(String id);
}

/// [McpSessionDirectory] in Redis (string keys with a TTL).
class RedisMcpSessionDirectory implements McpSessionDirectory {
  RedisMcpSessionDirectory(this.redis);

  final RedisController redis;

  static String key(String id) => 'wonky:mcp:session:$id';

  @override
  Future<void> put(String id, McpSessionRecord record, Duration ttl) async {
    final ok = await redis.set(
      key(id),
      jsonEncode(record.toJson()),
      lifetime: ttl,
    );
    if (!ok) throw StateError('Redis is unreachable.');
  }

  @override
  Future<McpSessionRecord?> get(String id) async {
    final raw = await redis.get(key(id));
    if (raw == null) {
      // A miss and a failed command look the same; tell them apart.
      if (!await redis.ping()) throw StateError('Redis is unreachable.');
      return null;
    }
    return McpSessionRecord.fromJson(
      (jsonDecode(raw) as Map).cast<String, Object?>(),
    );
  }

  @override
  Future<void> remove(String id) async {
    await redis.del(key(id));
  }
}

/// In-memory [McpSessionDirectory]; tests share one between several
/// handlers to simulate instances.
class InMemoryMcpSessionDirectory implements McpSessionDirectory {
  final Map<String, (McpSessionRecord, DateTime)> _entries = {};

  @override
  Future<void> put(String id, McpSessionRecord record, Duration ttl) async {
    _entries[id] = (record, clock.now().add(ttl));
  }

  @override
  Future<McpSessionRecord?> get(String id) async {
    final entry = _entries[id];
    if (entry == null) return null;
    if (!entry.$2.isAfter(clock.now())) {
      _entries.remove(id);
      return null;
    }
    return entry.$1;
  }

  @override
  Future<void> remove(String id) async {
    _entries.remove(id);
  }
}
