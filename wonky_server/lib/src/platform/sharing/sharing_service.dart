import 'dart:convert';
import 'dart:math';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;

import '../activity/activity_service.dart';
import '../common/actor.dart';
import '../common/errors.dart';
import '../common/models.dart';
import '../common/roles.dart';
import '../common/time.dart';
import '../drive/drive_service.dart';
import '../notifications/notification_service.dart';
import '../users/user_service.dart';
import 'access_service.dart';
import 'acl_events.dart';

/// Sharing (specs/06 §2, §4). Sharing changes are not undoable.
abstract final class SharingService {
  static final _random = Random.secure();
  static const _tokenAlphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String newToken() => String.fromCharCodes([
    for (var i = 0; i < 22; i++)
      _tokenAlphabet.codeUnitAt(_random.nextInt(_tokenAlphabet.length)),
  ]);

  static Future<(DriveItem, Role)> _requireSharer(
    Session session,
    Actor actor,
    UuidValue itemUuid,
  ) async {
    final (item, role) = await AccessService.require(
      session,
      actor,
      itemUuid,
      Role.viewer,
    );
    if (!AccessService.canShare(item, role)) {
      throw Errors.forbidden('You cannot share this item.');
    }
    return (item, role);
  }

  // ------------------------------------------------------------------ read

  static Future<SharingInfo> getSharing(
    Session session,
    Actor actor,
    UuidValue itemUuid,
  ) async {
    final (item, role) = await AccessService.require(
      session,
      actor,
      itemUuid,
      Role.viewer,
    );
    final canShare = AccessService.canShare(item, role);
    final now = nowUtc();
    final grants = await DriveItemPermission.db.find(
      session,
      where: (t) =>
          t.itemId.equals(item.id!) &
          (t.expiresAt.equals(null) | (t.expiresAt > now)),
    );
    final sourceIds = {for (final g in grants) ?g.inheritedFromId};
    final sources = sourceIds.isEmpty
        ? <DriveItem>[]
        : await DriveItem.db.find(
            session,
            where: (t) => t.id.inSet(sourceIds),
          );
    final sourceById = {for (final s in sources) s.id!: s};
    final users = await UserService.summaries(session, [
      item.ownerId,
      for (final g in grants) g.userId,
    ]);
    // One entry per person: the highest grant (direct grants win ties).
    final best = <String, DriveItemPermission>{};
    for (final g in grants) {
      if (g.userId == item.ownerId) continue;
      final key = g.userId != null ? 'u${g.userId}' : 'e${g.invitedEmail}';
      final prev = best[key];
      if (prev == null ||
          g.role.index > prev.role.index ||
          g.role == prev.role && g.inheritedFromId == null) {
        best[key] = g;
      }
    }
    final permissions = [
      for (final g in best.values)
        PermissionView(
          user: g.userId == null ? null : users[g.userId],
          invitedEmail: g.invitedEmail,
          role: g.role,
          inheritedFromUuid: g.inheritedFromId == null
              ? null
              : sourceById[g.inheritedFromId]?.uuid,
          inheritedFromName: g.inheritedFromId == null
              ? null
              : sourceById[g.inheritedFromId]?.name,
          grantedAt: g.grantedAt,
          expiresAt: g.expiresAt,
        ),
    ]..sort((a, b) => b.role.index.compareTo(a.role.index));
    final link = await ShareLink.db.findFirstRow(
      session,
      where: (t) => t.itemId.equals(item.id!),
    );
    final requests = canShare
        ? await AccessRequest.db.find(
            session,
            where: (t) => t.itemId.equals(item.id!) & t.handledAt.equals(null),
            orderBy: (t) => t.createdAt,
          )
        : <AccessRequest>[];
    final requesters = await UserService.summaries(session, [
      for (final r in requests) r.requesterId,
    ]);
    final transfer = await OwnershipTransfer.db.findFirstRow(
      session,
      where: (t) => t.itemId.equals(item.id!) & t.handledAt.equals(null),
    );
    return SharingInfo(
      itemUuid: item.uuid,
      itemName: item.name,
      itemKind: item.kind,
      owner: users[item.ownerId]!,
      myRole: role.access,
      canShare: canShare,
      permissions: permissions,
      link: canShare || link?.role != null
          ? (link == null
                ? null
                : ShareLinkView(token: link.token, role: link.role))
          : null,
      settings: ItemSharingSettings(
        editorsCanShare: item.editorsCanShare,
        nonEditorsCanExport: item.nonEditorsCanExport,
        viewersSeeComments: item.viewersSeeComments,
      ),
      pendingRequests: [
        for (final r in requests)
          if (requesters[r.requesterId] != null)
            AccessRequestView(
              id: r.id!,
              itemUuid: item.uuid,
              requester: requesters[r.requesterId]!,
              requestedRole: r.requestedRole,
              message: r.message,
              createdAt: r.createdAt,
            ),
      ],
      pendingTransfer: transfer == null || !canShare
          ? null
          : await _transferView(session, item, transfer),
    );
  }

  static Future<OwnershipTransferView?> _transferView(
    Session session,
    DriveItem item,
    OwnershipTransfer t,
  ) async {
    final users = await UserService.summaries(session, [
      t.fromUserId,
      t.toUserId,
    ]);
    if (users[t.fromUserId] == null || users[t.toUserId] == null) return null;
    return OwnershipTransferView(
      id: t.id!,
      itemUuid: item.uuid,
      itemName: item.name,
      from: users[t.fromUserId]!,
      to: users[t.toUserId]!,
      createdAt: t.createdAt,
    );
  }

  // ----------------------------------------------------------------- write

  /// Grants [role] to people by email. Unknown addresses become pending
  /// invites converted at sign-up.
  static Future<SharingInfo> share(
    Session session,
    Actor actor,
    UuidValue itemUuid, {
    required List<String> emails,
    required AccessRole role,
    bool notify = true,
    String? message,
    DateTime? expiresAt,
  }) async {
    final (item, myRole) = await _requireSharer(session, actor, itemUuid);
    if (role == AccessRole.owner) {
      throw Errors.invalid('Use transferOwnership to change the owner.');
    }
    if (role.role > myRole) throw Errors.forbidden();
    if (expiresAt != null && !expiresAt.isAfter(nowUtc())) {
      throw Errors.invalid('The expiration must be in the future.');
    }
    final normalized = {
      for (final e in emails) e.trim().toLowerCase(),
    }..remove('');
    if (normalized.isEmpty) throw Errors.invalid('Add at least one person.');
    if (normalized.length > 100) {
      throw Errors.invalid('Share with at most 100 people at a time.');
    }
    for (final e in normalized) {
      if (!_emailPattern.hasMatch(e)) {
        throw Errors.invalid('"$e" is not a valid email address.');
      }
    }
    final profiles = await UserProfile.db.find(
      session,
      where: (t) => t.email.inSet(normalized),
    );
    final byEmail = {for (final p in profiles) p.email: p};
    final now = nowUtc();
    final notified = <int>[];
    await session.db.transaction((tx) async {
      for (final email in normalized) {
        final profile = byEmail[email];
        if (profile?.id == item.ownerId) continue;
        final existing = await DriveItemPermission.db.findFirstRow(
          session,
          where: (t) =>
              t.itemId.equals(item.id!) &
              t.inheritedFromId.equals(null) &
              (profile == null
                  ? t.invitedEmail.equals(email)
                  : t.userId.equals(profile.id!)),
          transaction: tx,
        );
        if (existing != null) {
          await DriveItemPermission.db.updateRow(
            session,
            DriveItemPermission(
              id: existing.id,
              itemId: existing.itemId,
              userId: existing.userId,
              invitedEmail: existing.invitedEmail,
              role: role,
              grantedById: actor.userId,
              grantedAt: now,
              expiresAt: expiresAt,
            ),
            transaction: tx,
          );
        } else {
          await DriveItemPermission.db.insertRow(
            session,
            DriveItemPermission(
              itemId: item.id!,
              userId: profile?.id,
              invitedEmail: profile == null ? email : null,
              role: role,
              grantedById: actor.userId,
              grantedAt: now,
              expiresAt: expiresAt,
            ),
            transaction: tx,
          );
          if (profile != null) notified.add(profile.id!);
        }
      }
      if (item.kind == DriveItemKind.folder) {
        await AccessService.rebuildInherited(session, item, transaction: tx);
      }
    });
    await ActivityService.log(
      session,
      item.id!,
      actor,
      ActivityType.shared,
      summary: {'emails': normalized.toList(), 'role': role.name},
    );
    await AclEvents.changed(session, item);
    if (notify) {
      for (final userId in notified) {
        await NotificationService.notify(
          session,
          userId: userId,
          kind: NotificationKind.shared,
          item: item,
          actor: actor,
          payload: {
            'role': role.name,
            if (message != null && message.trim().isNotEmpty)
              'message': message.trim(),
          },
        );
      }
    }
    return getSharing(session, actor, itemUuid);
  }

  static Future<SharingInfo> updateRole(
    Session session,
    Actor actor,
    UuidValue itemUuid,
    int userId,
    AccessRole role, {
    DateTime? expiresAt,
  }) async {
    final (item, myRole) = await _requireSharer(session, actor, itemUuid);
    if (role == AccessRole.owner) {
      throw Errors.invalid('Use transferOwnership to change the owner.');
    }
    if (role.role > myRole) throw Errors.forbidden();
    if (userId == item.ownerId) {
      throw Errors.invalid("The owner's role cannot be changed.");
    }
    final grant = await DriveItemPermission.db.findFirstRow(
      session,
      where: (t) =>
          t.itemId.equals(item.id!) &
          t.userId.equals(userId) &
          t.inheritedFromId.equals(null),
    );
    if (grant == null) {
      // Inherited only: add a direct grant overriding upwards.
      await DriveItemPermission.db.insertRow(
        session,
        DriveItemPermission(
          itemId: item.id!,
          userId: userId,
          role: role,
          grantedById: actor.userId,
          grantedAt: nowUtc(),
          expiresAt: expiresAt,
        ),
      );
    } else {
      await DriveItemPermission.db.updateRow(
        session,
        DriveItemPermission(
          id: grant.id,
          itemId: grant.itemId,
          userId: grant.userId,
          role: role,
          grantedById: actor.userId,
          grantedAt: nowUtc(),
          expiresAt: expiresAt,
        ),
      );
    }
    if (item.kind == DriveItemKind.folder) {
      await AccessService.rebuildInherited(session, item);
    }
    await AclEvents.changed(session, item, affectedUsers: {userId});
    return getSharing(session, actor, itemUuid);
  }

  /// Removes a direct grant (or a pending invite by [invitedEmail]).
  static Future<SharingInfo> remove(
    Session session,
    Actor actor,
    UuidValue itemUuid, {
    int? userId,
    String? invitedEmail,
  }) async {
    final (item, _) = await AccessService.require(
      session,
      actor,
      itemUuid,
      Role.viewer,
    );
    final role = await AccessService.effectiveRole(session, actor.userId, item);
    // People may remove their own access; otherwise sharing rights are needed.
    final self = userId == actor.userId;
    if (!self && !AccessService.canShare(item, role!)) {
      throw Errors.forbidden('You cannot change who has access.');
    }
    if (userId == item.ownerId) {
      throw Errors.invalid('The owner cannot be removed.');
    }
    if (userId == null && invitedEmail == null) {
      throw Errors.invalid('Name a person to remove.');
    }
    await DriveItemPermission.db.deleteWhere(
      session,
      where: (t) =>
          t.itemId.equals(item.id!) &
          t.inheritedFromId.equals(null) &
          (userId != null
              ? t.userId.equals(userId)
              : t.invitedEmail.equals(invitedEmail!.trim().toLowerCase())),
    );
    if (userId != null) {
      await DriveItemUserState.db.deleteWhere(
        session,
        where: (t) =>
            t.itemId.equals(item.id!) &
            t.userId.equals(userId) &
            t.viaLink.equals(false) &
            t.starred.equals(false),
      );
    }
    if (item.kind == DriveItemKind.folder) {
      await AccessService.rebuildInherited(session, item);
    }
    await ActivityService.log(
      session,
      item.id!,
      actor,
      ActivityType.unshared,
      summary: {'userId': ?userId, 'email': ?invitedEmail},
    );
    await AclEvents.changed(
      session,
      item,
      affectedUsers: {?userId},
      kind: DriveChangeKind.unshared,
    );
    if (self) {
      return SharingInfo(
        itemUuid: item.uuid,
        itemName: item.name,
        itemKind: item.kind,
        owner: (await UserService.summary(session, item.ownerId))!,
        myRole: AccessRole.viewer,
        canShare: false,
        permissions: const [],
        settings: ItemSharingSettings(
          editorsCanShare: item.editorsCanShare,
          nonEditorsCanExport: item.nonEditorsCanExport,
          viewersSeeComments: item.viewersSeeComments,
        ),
        pendingRequests: const [],
      );
    }
    return getSharing(session, actor, itemUuid);
  }

  /// Offers ownership to [newOwnerUserId]; they accept with
  /// [respondToOwnershipTransfer].
  static Future<SharingInfo> transferOwnership(
    Session session,
    Actor actor,
    UuidValue itemUuid,
    int newOwnerUserId,
  ) async {
    final (item, role) = await AccessService.require(
      session,
      actor,
      itemUuid,
      Role.viewer,
    );
    if (role != Role.owner) {
      throw Errors.forbidden('Only the owner can transfer ownership.');
    }
    if (newOwnerUserId == actor.userId) {
      throw Errors.invalid('You already own this item.');
    }
    final target = await UserProfile.db.findById(session, newOwnerUserId);
    if (target == null) throw Errors.notFound('User');
    await OwnershipTransfer.db.updateWhere(
      session,
      columnValues: (t) => [t.handledAt(nowUtc()), t.accepted(false)],
      where: (t) => t.itemId.equals(item.id!) & t.handledAt.equals(null),
    );
    final transfer = await OwnershipTransfer.db.insertRow(
      session,
      OwnershipTransfer(
        itemId: item.id!,
        fromUserId: actor.userId,
        toUserId: newOwnerUserId,
        createdAt: nowUtc(),
      ),
    );
    await NotificationService.notify(
      session,
      userId: newOwnerUserId,
      kind: NotificationKind.ownershipTransfer,
      item: item,
      actor: actor,
      payload: {'transferId': transfer.id},
    );
    return getSharing(session, actor, itemUuid);
  }

  static Future<DriveItemView> respondToOwnershipTransfer(
    Session session,
    Actor actor,
    int transferId,
    bool accept,
  ) async {
    final transfer = await OwnershipTransfer.db.findById(session, transferId);
    if (transfer == null ||
        transfer.toUserId != actor.userId ||
        transfer.handledAt != null) {
      throw Errors.notFound('Transfer');
    }
    final item = await DriveItem.db.findById(session, transfer.itemId);
    if (item == null) throw Errors.notFound();
    if (item.ownerId != transfer.fromUserId) {
      await OwnershipTransfer.db.updateRow(
        session,
        transfer.copyWith(handledAt: nowUtc(), accepted: false),
      );
      throw Errors.conflict(
        'The owner changed since the transfer was offered.',
      );
    }
    await session.db.transaction((tx) async {
      await OwnershipTransfer.db.updateRow(
        session,
        transfer.copyWith(handledAt: nowUtc(), accepted: accept),
        transaction: tx,
      );
      if (!accept) return;
      await DriveItem.db.updateWhere(
        session,
        columnValues: (t) => [t.ownerId(actor.userId)],
        where: (t) => t.id.equals(item.id!),
        transaction: tx,
      );
      await DriveItemPermission.db.deleteWhere(
        session,
        where: (t) =>
            t.itemId.equals(item.id!) &
            t.userId.equals(actor.userId) &
            t.inheritedFromId.equals(null),
        transaction: tx,
      );
      // The previous owner becomes an Editor.
      await DriveItemPermission.db.insertRow(
        session,
        DriveItemPermission(
          itemId: item.id!,
          userId: transfer.fromUserId,
          role: AccessRole.editor,
          grantedById: actor.userId,
          grantedAt: nowUtc(),
        ),
        transaction: tx,
      );
    });
    final updated = (await DriveItem.db.findById(session, item.id!))!;
    if (accept) {
      await AccessService.rebuildInherited(session, updated);
      await ActivityService.log(
        session,
        item.id!,
        actor,
        ActivityType.shared,
        summary: {'ownershipFrom': transfer.fromUserId},
      );
      await AclEvents.changed(
        session,
        updated,
        affectedUsers: {transfer.fromUserId},
      );
    }
    return DriveService.get(session, actor, updated.uuid);
  }

  /// Turns link sharing on with [role], or off with null.
  static Future<SharingInfo> setLink(
    Session session,
    Actor actor,
    UuidValue itemUuid,
    AccessRole? role,
  ) async {
    final (item, myRole) = await _requireSharer(session, actor, itemUuid);
    if (role == AccessRole.owner) {
      throw Errors.invalid('Links cannot own items.');
    }
    if (role != null && role.role > myRole) throw Errors.forbidden();
    final link = await ShareLink.db.findFirstRow(
      session,
      where: (t) => t.itemId.equals(item.id!),
    );
    final linkVisitors = await DriveItemUserState.db.find(
      session,
      where: (t) => t.itemId.equals(item.id!) & t.viaLink.equals(true),
    );
    if (link == null) {
      await ShareLink.db.insertRow(
        session,
        ShareLink(
          itemId: item.id!,
          token: newToken(),
          role: role,
          createdById: actor.userId,
          createdAt: nowUtc(),
        ),
      );
    } else {
      await ShareLink.db.updateWhere(
        session,
        columnValues: (t) => [t.role(role)],
        where: (t) => t.id.equals(link.id!),
      );
    }
    await ActivityService.log(
      session,
      item.id!,
      actor,
      role == null ? ActivityType.unshared : ActivityType.shared,
      summary: {'link': role?.name},
    );
    await AclEvents.changed(
      session,
      item,
      affectedUsers: {for (final v in linkVisitors) v.userId},
      kind: role == null ? DriveChangeKind.unshared : DriveChangeKind.shared,
    );
    return getSharing(session, actor, itemUuid);
  }

  /// Replaces the link token (old links stop working).
  static Future<SharingInfo> rotateLink(
    Session session,
    Actor actor,
    UuidValue itemUuid,
  ) async {
    final (item, _) = await _requireSharer(session, actor, itemUuid);
    final link = await ShareLink.db.findFirstRow(
      session,
      where: (t) => t.itemId.equals(item.id!),
    );
    if (link == null) {
      await ShareLink.db.insertRow(
        session,
        ShareLink(
          itemId: item.id!,
          token: newToken(),
          createdById: actor.userId,
          createdAt: nowUtc(),
        ),
      );
    } else {
      await ShareLink.db.updateRow(session, link.copyWith(token: newToken()));
    }
    return getSharing(session, actor, itemUuid);
  }

  static Future<SharingInfo> updateSettings(
    Session session,
    Actor actor,
    UuidValue itemUuid,
    ItemSharingSettings settings,
  ) async {
    final (item, role) = await AccessService.require(
      session,
      actor,
      itemUuid,
      Role.viewer,
    );
    if (role != Role.owner) {
      throw Errors.forbidden('Only the owner can change these settings.');
    }
    await DriveItem.db.updateWhere(
      session,
      columnValues: (t) => [
        t.editorsCanShare(settings.editorsCanShare),
        t.nonEditorsCanExport(settings.nonEditorsCanExport),
        t.viewersSeeComments(settings.viewersSeeComments),
      ],
      where: (t) => t.id.equals(item.id!),
    );
    final updated = (await DriveItem.db.findById(session, item.id!))!;
    await AclEvents.changed(session, updated, kind: DriveChangeKind.updated);
    return getSharing(session, actor, itemUuid);
  }

  /// Asks the owner (and editors who can share) for access.
  static Future<void> requestAccess(
    Session session,
    Actor actor,
    UuidValue itemUuid,
    AccessRole role,
    String? message,
  ) async {
    final item = await AccessService.findItem(session, itemUuid);
    if (item == null) throw Errors.notFound();
    final current = await AccessService.effectiveRole(
      session,
      actor.userId,
      item,
    );
    if (current != null && current >= role.role) {
      throw Errors.invalid('You already have this access.');
    }
    if (role == AccessRole.owner) {
      throw Errors.invalid('Request editor access.');
    }
    final pending = await AccessRequest.db.findFirstRow(
      session,
      where: (t) =>
          t.itemId.equals(item.id!) &
          t.requesterId.equals(actor.userId) &
          t.handledAt.equals(null),
    );
    final request = pending != null
        ? await AccessRequest.db.updateRow(
            session,
            pending.copyWith(requestedRole: role, message: message),
          )
        : await AccessRequest.db.insertRow(
            session,
            AccessRequest(
              itemId: item.id!,
              requesterId: actor.userId,
              requestedRole: role,
              message: message?.trim(),
              createdAt: nowUtc(),
            ),
          );
    final recipients = <int>{item.ownerId};
    if (item.editorsCanShare) {
      final editors = await DriveItemPermission.db.find(
        session,
        where: (t) =>
            t.itemId.equals(item.id!) &
            t.role.equals(AccessRole.editor) &
            t.userId.notEquals(null),
      );
      recipients.addAll(editors.map((e) => e.userId!));
    }
    for (final userId in recipients) {
      await NotificationService.notify(
        session,
        userId: userId,
        kind: NotificationKind.accessRequest,
        item: item,
        actor: actor,
        payload: {
          'requestId': request.id,
          'role': role.name,
          'message': ?message,
        },
      );
    }
  }

  static Future<SharingInfo> handleAccessRequest(
    Session session,
    Actor actor,
    int requestId,
    bool approve,
    AccessRole? role,
  ) async {
    final request = await AccessRequest.db.findById(session, requestId);
    if (request == null) throw Errors.notFound('Request');
    final item = await DriveItem.db.findById(session, request.itemId);
    if (item == null) throw Errors.notFound();
    final (_, myRole) = await _requireSharer(session, actor, item.uuid);
    if (request.handledAt != null) {
      throw Errors.conflict('The request was already handled.');
    }
    await AccessRequest.db.updateRow(
      session,
      request.copyWith(
        handledAt: nowUtc(),
        handledById: actor.userId,
        outcome: approve
            ? AccessRequestOutcome.approved
            : AccessRequestOutcome.denied,
      ),
    );
    if (approve) {
      final grantRole = role ?? request.requestedRole;
      if (grantRole.role > myRole) throw Errors.forbidden();
      final requester = await UserProfile.db.findById(
        session,
        request.requesterId,
      );
      if (requester != null) {
        return share(
          session,
          actor,
          item.uuid,
          emails: [requester.email],
          role: grantRole,
        );
      }
    }
    return getSharing(session, actor, item.uuid);
  }

  /// Resolves a share link token for the signed-in caller and records the
  /// visit (the item appears in "Shared with me").
  static Future<InviteResolution> resolveInvite(
    Session session,
    Actor actor,
    String token,
  ) async {
    final link = await ShareLink.db.findFirstRow(
      session,
      where: (t) => t.token.equals(token.trim()),
    );
    if (link == null) throw Errors.notFound('Link');
    final item = await DriveItem.db.findById(session, link.itemId);
    if (item == null || item.trashedAt != null) throw Errors.notFound();
    final role = await AccessService.effectiveRole(session, actor.userId, item);
    if (role == null) {
      throw Errors.forbidden('Link sharing is turned off for this item.');
    }
    await DriveService.recordOpen(session, actor, item, role);
    return InviteResolution(
      itemUuid: item.uuid,
      kind: item.kind,
      name: item.name,
      role: role.access,
    );
  }

  /// Daily job: removes expired grants and re-mirrors affected spaces.
  static Future<int> removeExpiredGrants(
    Session session, {
    DateTime? now,
  }) async {
    final at = now ?? nowUtc();
    final expired = await DriveItemPermission.db.find(
      session,
      where: (t) => t.expiresAt < at,
      limit: 1000,
    );
    final itemIds = {for (final e in expired) e.itemId};
    final users = {for (final e in expired) ?e.userId};
    await DriveItemPermission.db.deleteWhere(
      session,
      where: (t) => t.id.inSet({for (final e in expired) e.id!}),
    );
    for (final id in itemIds) {
      final item = await DriveItem.db.findById(session, id);
      if (item == null) continue;
      if (item.kind == DriveItemKind.folder) {
        await AccessService.rebuildInherited(session, item);
      }
      await AclEvents.changed(session, item, affectedUsers: users);
    }
    return expired.length;
  }

  static String encodePayload(Map<String, Object?> payload) =>
      jsonEncode(payload);
}
