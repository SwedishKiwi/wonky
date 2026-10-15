import 'dart:async';

import 'package:serverpod/serverpod.dart';

import '../cluster/cluster_bus.dart';
import '../common/models.dart';
import '../drive/drive_events.dart';

/// `storageChanged` drive events (Drive 03 §3): posted to the user's drive
/// channel whenever their counters change, debounced per user by
/// [debounce] so a batch of changes gives one event (and the event
/// arrives after the changing transaction committed). `drive.watch`
/// resolves the signal to the watcher's [StorageUsage].
abstract final class StorageEvents {
  /// The nil UUID: a storage change is not about an item.
  static final nilUuid = UuidValue.fromString(
    '00000000-0000-0000-0000-000000000000',
  );

  /// Debounce per user; [Duration.zero] posts at once (tests).
  static Duration debounce = const Duration(seconds: 1);

  static final Map<int, Timer> _timers = {};

  /// The signal posted on the user's drive channel.
  static DriveChangeSignal get signal => DriveChangeSignal(
    kind: DriveChangeKind.storageChanged,
    itemUuid: nilUuid,
  );

  /// Posts a storage change for each of [userIds] (debounced).
  static Future<void> changed(Session session, Iterable<int> userIds) async {
    final pod = session.serverpod;
    for (final userId in userIds.toSet()) {
      if (debounce == Duration.zero) {
        await _post(pod, userId);
        continue;
      }
      _timers[userId]?.cancel();
      _timers[userId] = Timer(debounce, () {
        _timers.remove(userId);
        unawaited(_post(pod, userId));
      });
    }
  }

  static Future<void> _post(Serverpod pod, int userId) async {
    try {
      await ClusterBus.postOn(
        pod,
        DriveEvents.channel(userId),
        signal,
        coalesceKey: 'storage:$userId',
      );
    } on Object {
      // Best effort: the meter refreshes on its own too.
    }
  }
}
