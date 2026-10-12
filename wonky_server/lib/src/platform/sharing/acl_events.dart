import 'package:serverpod/serverpod.dart';

import '../../sheets/spaces/space_service.dart';
import '../../write/ot/document_bus.dart';
import '../common/models.dart';
import '../drive/drive_events.dart';
import 'access_service.dart';

/// Propagates permission changes (specs/06 §3): drive lists of affected users,
/// spreadsheet space membership (mirroring) and open document streams
/// (`DocRoleChanged`).
abstract final class AclEvents {
  /// Call after grants, links, ownership, trash state or the position of
  /// [item] changed. [affectedUsers] are users who may have lost access and
  /// must be notified as well. Folders propagate to their descendants.
  static Future<void> changed(
    Session session,
    DriveItem item, {
    Set<int> affectedUsers = const {},
    DriveChangeKind kind = DriveChangeKind.shared,
  }) async {
    final nodes = item.kind == DriveItemKind.folder
        ? await AccessService.subtree(session, item)
        : [item];
    for (final node in nodes) {
      await DriveEvents.notify(
        session,
        node,
        kind,
        alsoNotify: affectedUsers,
      );
      switch (node.kind) {
        case DriveItemKind.spreadsheet:
          await SpaceService.mirrorMembership(session, node);
        case DriveItemKind.document:
          if (node.contentRef != null) {
            await DocumentBus.rolesChanged(session, node.contentRef!);
          }
        case DriveItemKind.folder:
          break;
      }
    }
  }
}
