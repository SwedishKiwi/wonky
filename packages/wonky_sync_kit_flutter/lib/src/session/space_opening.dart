import 'dart:async';

import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    show OfflineSyncSpaceRole;
import 'package:wonky_client/wonky_client.dart'
    show AccessRole, SpaceStats, UuidValue;
import 'package:wonky_core/wonky_core.dart' show Role;

import '../controller/sync_session_host.dart';
import '../replica/sync_replica.dart';
import '../writer/sync_writer.dart';

/// Steps shared by the open flows of synced file sessions (suite 12 §2.3,
/// Sheets 02 §6, Slides 02 §9.1).
abstract final class SpaceOpening {
  /// Waits until the local row count of [space] reaches the server's
  /// ([stats]), reporting the downloaded share to [onProgress]; gives up
  /// waiting for the last rows once the root row ([rootTable]) is there and
  /// nothing arrived for [settleTimeout] (the rest is patched in as it
  /// arrives), and returns at once when offline with nothing on the device.
  static Future<void> waitForSpace(
    SyncSessionHost<SyncReplica, SyncWriter> host,
    UuidValue space,
    SpaceStats stats, {
    required String rootTable,
    required Duration settleTimeout,
    required bool Function() isDisposed,
    required void Function(double progress) onProgress,
  }) async {
    final total = stats.totalRows <= 0 ? 1 : stats.totalRows;
    var last = -1;
    var lastChange = DateTime.now();
    while (!isDisposed()) {
      final counts = await host.replica.rowCounts(space);
      final have = counts.values.fold(0, (a, b) => a + b);
      final present = (counts[rootTable] ?? 0) > 0;
      if (present && have >= stats.totalRows) return;
      if (have != last) {
        last = have;
        lastChange = DateTime.now();
        onProgress((have / total).clamp(0.0, 1.0));
      } else if (present &&
          DateTime.now().difference(lastChange) > settleTimeout) {
        return;
      } else if (!host.online.value && !present) {
        return;
      }
      await Future.any<void>([
        host.merges.firstWhere((s) => s == space).then((_) {}),
        Future<void>.delayed(const Duration(milliseconds: 500)),
      ]);
    }
  }

  /// The suite role of a drive [AccessRole].
  static Role roleOf(AccessRole r) => switch (r) {
    AccessRole.viewer => Role.viewer,
    AccessRole.commenter => Role.commenter,
    AccessRole.editor => Role.editor,
    AccessRole.owner => Role.owner,
  };

  /// The role after the membership cache reported [membership] for a
  /// session at [current]: write membership raises viewers and commenters
  /// to editor, read-only membership lowers editors and owners to viewer;
  /// null = unchanged. (No membership — unshared, trashed, evicted — is
  /// the caller's case.)
  static Role? roleFromMembership(
    OfflineSyncSpaceRole membership,
    Role current,
  ) => switch (membership) {
    OfflineSyncSpaceRole.readWrite =>
      current < Role.editor ? Role.editor : null,
    OfflineSyncSpaceRole.readOnly =>
      current >= Role.editor ? Role.viewer : null,
  };
}
