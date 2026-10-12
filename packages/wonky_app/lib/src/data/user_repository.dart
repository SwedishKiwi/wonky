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
  Future<UserProfileView> getMe() => api.call<UserProfileView>('user', 'getMe');

  @override
  Future<UserProfileView> updateProfile({
    String? displayName,
    String? locale,
    String? timeZone,
  }) => api.call<UserProfileView>('user', 'updateProfile', {
    'displayName': displayName,
    'locale': locale,
    'timeZone': timeZone,
  });

  @override
  Future<UserProfileView> setAvatar(UuidValue? fileUuid) =>
      api.call<UserProfileView>('user', 'setAvatar', {'fileUuid': fileUuid});

  @override
  Future<UserPreferences> getPreferences() =>
      api.call<UserPreferences>('user', 'getPreferences');

  @override
  Future<UserPreferences> updatePreferences(UserPreferencesPatch patch) =>
      api.call<UserPreferences>('user', 'updatePreferences', {'patch': patch});

  @override
  Future<List<UserSummary>> searchUsers(String query, {int limit = 10}) =>
      api.call<List<UserSummary>>('user', 'searchUsers', {'query': query, 'limit': limit});

  @override
  Future<AccountDeletionPreview> deleteAccountPreview() =>
      api.call<AccountDeletionPreview>('user', 'deleteAccountPreview');

  @override
  Future<void> deleteAccount(String confirmation) =>
      api.call<void>('user', 'deleteAccount', {'confirmation': confirmation});

  @override
  Future<List<AccessTokenView>> listTokens() =>
      api.call<List<AccessTokenView>>('accessToken', 'list');

  @override
  Future<CreatedAccessToken> createToken({
    required String name,
    required List<String> scopes,
    DateTime? expiresAt,
  }) => api.call<CreatedAccessToken>('accessToken', 'create', {
    'name': name,
    'scopes': scopes,
    'expiresAt': expiresAt,
  });

  @override
  Future<void> revokeToken(int id) => api.call<void>('accessToken', 'revoke', {'id': id});
}
