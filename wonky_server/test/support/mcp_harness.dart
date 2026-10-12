import 'dart:convert';

import 'package:wonky_core/wonky_core.dart' show McpScope;
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/platform/mcp/tool_support.dart';
import 'package:wonky_server/src/platform/mcp/wonky_mcp_server.dart';
import 'package:wonky_server/src/platform/users/account_service.dart';

import 'test_users.dart';

/// Calls MCP tools through the real [ToolExecutor] as a token-resolved user
/// (specs/15 §6 MCP).
class McpHarness {
  McpHarness(this.user, this.secret, this.ctx);

  final TestUser user;

  /// The personal access token secret (`wkpat_…`).
  final String secret;
  final ToolContext ctx;

  /// Creates a token with [scopes] for [user] and resolves it like the
  /// `/mcp` route does.
  static Future<McpHarness> forUser(
    TestUser user, {
    List<String> scopes = McpScope.all,
    String clientName = 'Test agent',
  }) async {
    final session = user.session;
    final created = await AccountService.createToken(
      session,
      user.actor,
      name: 'test',
      scopes: scopes,
    );
    final resolved = await AccountService.authenticate(session, created.secret);
    final (token, actor) = resolved!;
    return McpHarness(
      user,
      created.secret,
      ToolContext(
        session: session,
        actor: actor,
        scopes: token.scopes.toSet(),
        tokenId: token.id,
        clientName: clientName,
      ),
    );
  }

  /// Calls [tool]; returns the structured result, or throws [McpCallError].
  Future<Map<String, dynamic>> call(
    String tool, [
    Map<String, Object?> args = const {},
  ]) async {
    final outcome = await WonkyMcpServer.executor.call(ctx, tool, args);
    if (outcome.isError) throw McpCallError(outcome.error!.toJson());
    final r = WonkyMcpServer.toCallToolResult(outcome);
    return (jsonDecode(jsonEncode(r.structuredContent ?? {})) as Map)
        .cast<String, dynamic>();
  }

  /// Calls [tool] and returns the error payload (fails when it succeeds).
  Future<Map<String, dynamic>> error(
    String tool, [
    Map<String, Object?> args = const {},
  ]) async {
    final outcome = await WonkyMcpServer.executor.call(ctx, tool, args);
    if (!outcome.isError) {
      throw StateError('$tool succeeded: ${outcome.result!.text}');
    }
    return (jsonDecode(jsonEncode(outcome.error!.toJson())) as Map)
        .cast<String, dynamic>();
  }
}

/// A tool error `{code, message, details}`.
class McpCallError implements Exception {
  McpCallError(this.payload);
  final Map<String, Object?> payload;
  String get code => payload['code']! as String;
  @override
  String toString() => 'McpCallError($payload)';
}

/// The document uuid of a drive item view.
String docOf(DriveItemView v) => v.uuid.uuid;
