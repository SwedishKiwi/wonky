import 'package:serverpod/serverpod.dart';

import '../common/models.dart';
import 'account_service.dart';
import 'user_service.dart';

/// Personal access tokens for MCP (specs/04 §5, 09 §2).
class AccessTokenEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<List<AccessTokenView>> list(Session session) async =>
      AccountService.listTokens(session, await UserService.actorOf(session));

  /// Creates a token; the secret is returned only here.
  Future<CreatedAccessToken> create(
    Session session,
    String name,
    List<String> scopes,
    DateTime? expiresAt,
  ) async => AccountService.createToken(
    session,
    await UserService.actorOf(session),
    name: name,
    scopes: scopes,
    expiresAt: expiresAt,
  );

  Future<AccessTokenView> revoke(Session session, int id) async =>
      AccountService.revokeToken(
        session,
        await UserService.actorOf(session),
        id,
      );
}
