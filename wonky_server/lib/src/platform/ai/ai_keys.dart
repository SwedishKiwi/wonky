import 'package:serverpod/serverpod.dart';

import '../common/errors.dart';
import '../common/models.dart';
import '../common/time.dart';
import 'ai_config.dart';
import 'ai_models.dart';
import 'llm/ai_client.dart';

/// Whose API key a request uses.
enum AiKeySource { server, user }

/// The provider and key a user's AI requests go out with.
class AiCredentials {
  const AiCredentials(this.provider, this.apiKey, this.source);

  final AiProvider provider;
  final String apiKey;
  final AiKeySource source;
}

/// The resolved model backend of one user: credentials, the client and the
/// model ids of the provider.
class AiBackend {
  AiBackend(this.credentials, this.client, this.config);

  final AiCredentials credentials;
  final AiModelClient client;
  final AiConfig config;

  AiProvider get provider => credentials.provider;

  /// The model id of [tier] for this provider.
  String model(AiTier tier) => config.modelFor(provider, tier.size);
}

/// API keys of the AI features (suite 10 §1 "Keys"): the server's keys
/// (Serverpod passwords) win; without any, a user's own key
/// ([AiUserKey], Settings › AI providers) is used for that user's requests.
/// User keys are stored server-side, readable only through this class for
/// the owner's requests, and never returned to a client (only the provider
/// and the last four characters).
abstract final class AiKeys {
  static const minKeyLength = 16;
  static const maxKeyLength = 512;

  /// Server key > user key > none.
  static AiCredentials? resolve(AiConfig config, {AiUserKey? userKey}) {
    final p = config.serverProvider;
    if (p != null) {
      return AiCredentials(p, config.serverKeys[p]!, AiKeySource.server);
    }
    if (!config.allowUserKeys || userKey == null) return null;
    final key = userKey.apiKey.trim();
    if (key.isEmpty) return null;
    return AiCredentials(userKey.provider, key, AiKeySource.user);
  }

  /// The stored key of [userId] (server-side only).
  static Future<AiUserKey?> userKey(Session session, int userId) =>
      AiUserKey.db.findFirstRow(session, where: (t) => t.userId.equals(userId));

  /// The credentials of [userId]'s requests (null = not configured).
  static Future<AiCredentials?> forUser(Session session, int userId) async {
    final config = AiConfig.current;
    if (config.configured) return resolve(config);
    if (!config.allowUserKeys) return null;
    return resolve(config, userKey: await userKey(session, userId));
  }

  /// The backend of [userId] (null = not configured).
  static Future<AiBackend?> backendFor(Session session, int userId) async {
    final c = await forUser(session, userId);
    if (c == null) return null;
    return AiBackend(
      c,
      AiConfig.clientFor(c.provider, c.apiKey),
      AiConfig.current,
    );
  }

  /// The last four characters of [key].
  static String last4(String key) {
    final k = key.trim();
    return k.length <= 4 ? k : k.substring(k.length - 4);
  }

  static AiProviderKeyView view(AiUserKey k) => AiProviderKeyView(
    provider: k.provider,
    last4: last4(k.apiKey),
    updatedAt: k.updatedAt,
  );

  /// Stores [apiKey] for [provider] as the user's key (replacing any
  /// earlier one). Only while the server has no key of its own.
  static Future<void> setUserKey(
    Session session,
    int userId,
    AiProvider provider,
    String apiKey,
  ) async {
    final config = AiConfig.current;
    if (!config.enabled) {
      throw WonkyException(
        code: WonkyErrorCode.unavailable,
        message: 'AI is turned off on this server.',
      );
    }
    if (!config.userKeysAllowed) {
      throw Errors.invalid(
        config.configured
            ? 'This server already provides AI; your own key is not needed.'
            : 'This server does not allow personal API keys.',
      );
    }
    final key = apiKey.trim();
    if (key.length < minKeyLength ||
        key.length > maxKeyLength ||
        RegExp(r'\s').hasMatch(key)) {
      throw Errors.invalid('That does not look like an API key.');
    }
    final existing = await userKey(session, userId);
    final now = nowUtc();
    if (existing == null) {
      await AiUserKey.db.insertRow(
        session,
        AiUserKey(
          userId: userId,
          provider: provider,
          apiKey: key,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await AiUserKey.db.updateRow(
        session,
        existing.copyWith(provider: provider, apiKey: key, updatedAt: now),
      );
    }
  }

  /// Removes the user's key.
  static Future<void> removeUserKey(Session session, int userId) =>
      AiUserKey.db.deleteWhere(session, where: (t) => t.userId.equals(userId));
}
