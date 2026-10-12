import 'package:wonky_client/wonky_client.dart';

import 'api.dart';

/// Sharing and permissions (suite 06 §4). Sharing changes are not undoable.
abstract class SharingRepository {
  Future<SharingInfo> getSharing(UuidValue itemUuid);

  Future<SharingInfo> share(
    UuidValue itemUuid, {
    required List<String> emails,
    required AccessRole role,
    bool notify = true,
    String? message,
    DateTime? expiresAt,
  });

  Future<SharingInfo> updateRole(
    UuidValue itemUuid, {
    int? userId,
    String? invitedEmail,
    required AccessRole role,
    DateTime? expiresAt,
  });

  Future<SharingInfo> remove(UuidValue itemUuid, {int? userId, String? invitedEmail});

  Future<SharingInfo> transferOwnership(UuidValue itemUuid, int newOwnerUserId);

  Future<DriveItemView> respondToOwnershipTransfer(int transferId, bool accept);

  /// `role == null` turns link sharing off ("Restricted").
  Future<SharingInfo> setLink(UuidValue itemUuid, AccessRole? role);

  Future<SharingInfo> rotateLink(UuidValue itemUuid);

  Future<SharingInfo> updateSettings(UuidValue itemUuid, ItemSharingSettings settings);

  Future<void> requestAccess(UuidValue itemUuid, AccessRole role, String? message);

  Future<SharingInfo> handleAccessRequest(int requestId, bool approve, AccessRole? role);

  Future<InviteResolution> resolveInvite(String token);
}

/// [SharingRepository] backed by the `sharing` endpoint.
class ServerSharingRepository implements SharingRepository {
  ServerSharingRepository(this.api);

  final Api api;
  static const _e = 'sharing';

  @override
  Future<SharingInfo> getSharing(UuidValue itemUuid) =>
      api.call<SharingInfo>(_e, 'getSharing', {'itemUuid': itemUuid});

  @override
  Future<SharingInfo> share(
    UuidValue itemUuid, {
    required List<String> emails,
    required AccessRole role,
    bool notify = true,
    String? message,
    DateTime? expiresAt,
  }) => api.call<SharingInfo>(_e, 'share', {
    'itemUuid': itemUuid,
    'emails': emails,
    'role': role,
    'notify': notify,
    'message': message,
    'expiresAt': expiresAt,
  });

  @override
  Future<SharingInfo> updateRole(
    UuidValue itemUuid, {
    int? userId,
    String? invitedEmail,
    required AccessRole role,
    DateTime? expiresAt,
  }) => api.call<SharingInfo>(_e, 'updateRole', {
    'itemUuid': itemUuid,
    'userId': userId,
    'invitedEmail': invitedEmail,
    'role': role,
    'expiresAt': expiresAt,
  });

  @override
  Future<SharingInfo> remove(UuidValue itemUuid, {int? userId, String? invitedEmail}) =>
      api.call<SharingInfo>(_e, 'remove', {
        'itemUuid': itemUuid,
        'userId': userId,
        'invitedEmail': invitedEmail,
      });

  @override
  Future<SharingInfo> transferOwnership(UuidValue itemUuid, int newOwnerUserId) =>
      api.call<SharingInfo>(_e, 'transferOwnership', {
        'itemUuid': itemUuid,
        'newOwnerUserId': newOwnerUserId,
      });

  @override
  Future<DriveItemView> respondToOwnershipTransfer(int transferId, bool accept) =>
      api.call<DriveItemView>(_e, 'respondToOwnershipTransfer', {
        'transferId': transferId,
        'accept': accept,
      });

  @override
  Future<SharingInfo> setLink(UuidValue itemUuid, AccessRole? role) =>
      api.call<SharingInfo>(_e, 'setLink', {'itemUuid': itemUuid, 'role': role});

  @override
  Future<SharingInfo> rotateLink(UuidValue itemUuid) =>
      api.call<SharingInfo>(_e, 'rotateLink', {'itemUuid': itemUuid});

  @override
  Future<SharingInfo> updateSettings(UuidValue itemUuid, ItemSharingSettings settings) =>
      api.call<SharingInfo>(_e, 'updateSettings', {'itemUuid': itemUuid, 'settings': settings});

  @override
  Future<void> requestAccess(UuidValue itemUuid, AccessRole role, String? message) =>
      api.call<void>(_e, 'requestAccess', {
        'itemUuid': itemUuid,
        'role': role,
        'message': message,
      });

  @override
  Future<SharingInfo> handleAccessRequest(int requestId, bool approve, AccessRole? role) =>
      api.call<SharingInfo>(_e, 'handleAccessRequest', {
        'requestId': requestId,
        'approve': approve,
        'role': role,
      });

  @override
  Future<InviteResolution> resolveInvite(String token) =>
      api.call<InviteResolution>(_e, 'resolveInvite', {'token': token});
}
