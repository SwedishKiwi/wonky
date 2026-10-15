import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart'
    show SpaceStats, SubscribeResult, UuidValue;

import '../replica/sync_replica.dart';
import '../writer/sync_writer.dart';

/// What a synced file session (Sheets' `SyncedWorkbookSession`, Slides'
/// `SyncedDeckSession`) needs from the per-user sync controller
/// (implemented by `AppSyncController`; tests use a fake on a temporary
/// replica).
abstract interface class SyncSessionHost<
  R extends SyncReplica,
  W extends SyncWriter
> {
  /// The user's local replica.
  R get replica;

  /// The serialized writer on [replica].
  W get writer;

  /// The change-log `sessionId` of this app session.
  String get sessionId;

  /// Whether the server is reachable (connectivity, incl. *Simulate
  /// offline*); notifies on changes.
  ValueListenable<bool> get online;

  /// Spaces merged by a sync cycle (`onMergeSuccess`), on the main isolate.
  Stream<UuidValue> get merges;

  /// The app's `subscribe(itemUuid)`; throws `SyncOfflineException`
  /// offline.
  Future<SubscribeResult> subscribe(UuidValue itemUuid);

  /// The app's `spaceStats(itemUuid)`; throws `SyncOfflineException`
  /// offline.
  Future<SpaceStats> spaceStats(UuidValue itemUuid);

  /// Asks for a sync cycle soon (new membership, local writes).
  void kick();

  /// The smallest journal cursor of the open sessions changed.
  void journalCursorsChanged();
}

/// What the sync controller needs of an open file session: which space it
/// shows and its change-journal cursor.
abstract interface class HostedSpaceSession {
  /// The space (= file) id.
  UuidValue get spaceUuid;

  /// Whether the session was disposed.
  bool get isDisposed;

  /// The journal position of the last ingested change (null while loading
  /// and after disposal).
  int? get cursor;

  /// Closes the session (flushing its writes); the controller closes its
  /// open sessions before the replica.
  Future<void> dispose();
}
