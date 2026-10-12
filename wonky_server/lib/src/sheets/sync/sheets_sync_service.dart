import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

import '../../platform/common/actor.dart';
import '../../platform/common/models.dart';
import '../changelog/change_log_consumer.dart';

/// The custom sync endpoint's server side (suite 12 §2.5): wraps
/// `session.offlineSync.sync` with `onMergeSuccess`, which fans out
/// `sheets:merged:<space>` and runs the change-log consumer.
abstract final class SheetsSyncService {
  static String mergedChannel(UuidValue space) => 'sheets:merged:${space.uuid}';

  static final Map<String, Hlc> _lastHlc = {};

  /// When true (tests), merge processing is awaited inside the sync loop.
  static bool processInline = false;

  static Stream<OfflineSyncStreamEvent> sync(
    Session session,
    Actor actor, {
    required Stream<OfflineSyncStreamEvent> changes,
    bool once = false,
  }) => session.offlineSync.sync(
    userId: actor.authUserId,
    inbound: changes,
    once: once,
    mode: OfflineSyncPeerMode.authoritative,
    onMergeSuccess: (space, hlc) => onMerged(session, space, hlc),
  );

  /// Called for every space after each sync round; only reacts when the
  /// space's high-water mark moved.
  static Future<void> onMerged(Session session, UuidValue space, Hlc hlc) async {
    final key = space.uuid;
    final last = _lastHlc[key];
    if (last != null && hlc.compareTo(last) <= 0) return;
    _lastHlc[key] = hlc;
    await session.messages.postMessage(
      mergedChannel(space),
      SheetsMergedSignal(spaceUuid: space, hlc: hlc.toString()),
    );
    if (processInline) {
      await ChangeLogConsumer.processSpace(session, space);
      return;
    }
    final serverpod = session.serverpod;
    unawaited(() async {
      final internal = await serverpod.createSession(enableLogging: false);
      try {
        await ChangeLogConsumer.processSpace(internal, space);
      } on Exception catch (e, st) {
        internal.log(
          'Change log processing of $space failed: $e',
          level: LogLevel.error,
          stackTrace: st,
        );
      } finally {
        await internal.close();
      }
    }());
  }
}
