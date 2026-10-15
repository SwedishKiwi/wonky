import 'dart:async';

import 'package:serverpod/serverpod.dart';

import '../common/actor.dart';
import '../common/models.dart';
import '../sharing/access_service.dart';
import '../storage/storage_service.dart';
import 'drive_file_filters.dart';
import 'drive_views.dart';
import '../cluster/cluster_bus.dart';

/// Live drive updates (`drive.watch`, specs/05 §2). Changes are posted per
/// user on `drive:user:<userId>`; each watcher resolves the item with its
/// own role, so lists show the right permissions.
abstract final class DriveEvents {
  static String channel(int userId) => 'drive:user:$userId';

  /// Notifies everyone who may see [item] (plus [alsoNotify], e.g. users who
  /// just lost access) about a change.
  static Future<void> notify(
    Session session,
    DriveItem item,
    DriveChangeKind kind, {
    Set<int> alsoNotify = const {},
  }) async {
    final users = {
      ...await AccessService.interestedUsers(session, item),
      ...alsoNotify,
    };
    final signal = DriveChangeSignal(kind: kind, itemUuid: item.uuid);
    for (final userId in users) {
      await ClusterBus.post(session, channel(userId), signal);
    }
  }

  /// Notifies about several items at once.
  static Future<void> notifyAll(
    Session session,
    Iterable<DriveItem> items,
    DriveChangeKind kind, {
    Set<int> alsoNotify = const {},
  }) async {
    for (final item in items) {
      await notify(session, item, kind, alsoNotify: alsoNotify);
    }
  }

  /// The live stream of changes visible to [actor].
  static Stream<DriveChange> watch(Session session, Actor actor) async* {
    final signals = session.messages.createStream<DriveChangeSignal>(
      channel(actor.userId),
    );
    await for (final signal in signals) {
      // (v2) The watcher's storage changed (Drive 03 §3).
      if (signal.kind == DriveChangeKind.storageChanged) {
        yield DriveChange(
          kind: DriveChangeKind.storageChanged,
          itemUuid: signal.itemUuid,
          storage: await StorageService.instance.usage(session, actor.userId),
        );
        continue;
      }
      final item = await AccessService.findItem(session, signal.itemUuid);
      final role = item == null
          ? null
          : await AccessService.effectiveRole(session, actor.userId, item);
      if (item == null || role == null) {
        yield DriveChange(
          kind: DriveChangeKind.removed,
          itemUuid: signal.itemUuid,
        );
        continue;
      }
      // (v2) Uploads in progress are only visible to their uploader.
      if (!DriveFileFilters.listable(item, actor.userId)) continue;
      final view = await DriveViews.one(
        session,
        actor.userId,
        item,
        role: role,
      );
      yield DriveChange(kind: signal.kind, itemUuid: item.uuid, item: view);
    }
  }
}
