import 'package:wonky_client/wonky_client.dart';

import 'api.dart';

/// The signed-in user's profile, preferences and access tokens (suite 04 §5).
abstract class UserRepository {
  Future<UserProfileView> getMe();

  Future<UserProfileView> updateProfile({
    String? displayName,
    String? locale,
    String? timeZone,
  });

  /// Sets the avatar from an uploaded (ready) file.
  Future<UserProfileView> setAvatar(UuidValue? fileUuid);

  Future<UserPreferences> getPreferences();

  Future<UserPreferences> updatePreferences(UserPreferencesPatch patch);

  /// Users who share at least one item with the caller, or exact email
  /// matches (share dialog, @mentions).
  Future<List<UserSummary>> searchUsers(String query, {int limit = 10});

  Future<AccountDeletionPreview> deleteAccountPreview();

  Future<void> deleteAccount(String confirmation);

  Future<List<AccessTokenView>> listTokens();

  Future<CreatedAccessToken> createToken({
    required String name,
    required List<String> scopes,
    DateTime? expiresAt,
  });

  Future<void> revokeToken(int id);
}

/// [UserRepository] backed by the `user` and `accessToken` endpoints.
class ServerUserRepository implements UserRepository {
  ServerUserRepository(this.api);

  final Api api;

  @override
  Future<UserProfileView> getMe() => api.guard((c) => c.user.getMe());

  @override
  Future<UserProfileView> updateProfile({
    String? displayName,
    String? locale,
    String? timeZone,
  }) => api.guard(
    (c) => c.user.updateProfile(
      displayName: displayName,
      locale: locale,
      timeZone: timeZone,
    ),
  );

  @override
  Future<UserProfileView> setAvatar(UuidValue? fileUuid) =>
      api.guard((c) => c.user.setAvatar(fileUuid));

  @override
  Future<UserPreferences> getPreferences() =>
      api.guard((c) => c.user.getPreferences());

  @override
  Future<UserPreferences> updatePreferences(UserPreferencesPatch patch) =>
      api.guard((c) => c.user.updatePreferences(patch));

  @override
  Future<List<UserSummary>> searchUsers(String query, {int limit = 10}) =>
      api.guard((c) => c.user.searchUsers(query, limit));

  @override
  Future<AccountDeletionPreview> deleteAccountPreview() =>
      api.guard((c) => c.user.accountDeletionPreview());

  @override
  Future<void> deleteAccount(String confirmation) =>
      api.guard((c) => c.user.deleteAccount(confirmation));

  @override
  Future<List<AccessTokenView>> listTokens() =>
      api.guard((c) => c.accessToken.list());

  @override
  Future<CreatedAccessToken> createToken({
    required String name,
    required List<String> scopes,
    DateTime? expiresAt,
  }) => api.guard((c) => c.accessToken.create(name, scopes, expiresAt));

  @override
  Future<void> revokeToken(int id) =>
      api.guard((c) => c.accessToken.revoke(id));
}
