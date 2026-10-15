import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

import '../common/actor.dart';
import '../common/models.dart';
import 'space_kinds.dart';

/// The authoritative side of an app's sync stream (suite 12 §2.5–2.6): the
/// offline-sync engine run for one [SpaceKind], so `sheetsSync.sync` only
/// syncs spreadsheet spaces and (v2) `slidesSync.sync` only deck spaces,
/// each with the personal space (patch OS-8, [SpaceKindFilter]).
///
/// `session.offlineSync.sync` (the hosted `serverpod_offline_sync_server`
/// facade) has no filter parameter, so this runs the vendored engine
/// directly — exactly what the facade does (`OfflineSyncEngine.sync` with
/// the request [Session], authoritative mode) with an engine configured
/// like the one `initializeOfflineSync` installs (same synced tables,
/// serialization manager and defaults). The engine keeps no state of its
/// own between streams: the CRDT schema context lives in the session's
/// intercepted database.
abstract final class SpaceSync {
  static final _engines = Expando<OfflineSyncEngine>('wonkySpaceSyncEngine');

  static OfflineSyncEngine _engineOf(Session session) {
    final pod = session.server.serverpod;
    return _engines[pod] ??= OfflineSyncEngine(
      syncTables: syncTables,
      serializationManager: pod.serializationManager,
    );
  }

  /// Runs [actor]'s sync stream over the spaces of [kind] (+ the personal
  /// space).
  static Stream<OfflineSyncStreamEvent> sync(
    Session session,
    Actor actor, {
    required SpaceKind kind,
    required Stream<OfflineSyncStreamEvent> changes,
    bool once = false,
    OfflineSyncOnMergeSuccess? onMergeSuccess,
  }) => _engineOf(session).sync(
    session,
    userId: actor.authUserId,
    inbound: changes,
    once: once,
    mode: OfflineSyncPeerMode.authoritative,
    onMergeSuccess: onMergeSuccess,
    spaceFilter: SpaceKindFilter(session, kind).call,
  );
}
