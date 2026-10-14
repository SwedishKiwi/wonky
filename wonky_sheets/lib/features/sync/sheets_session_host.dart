import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart';

import 'sheets_replica.dart';
import 'sheets_writer.dart';

/// Thrown by [SheetsSessionHost] calls that need the server while offline.
class SheetsOfflineException implements Exception {
  const SheetsOfflineException([this.message = 'offline']);

  final String message;

  @override
  String toString() => 'SheetsOfflineException: $message';
}

/// What a `SyncedWorkbookSession` needs from the per-user sync controller
/// (implemented by `SheetsSyncController`; tests use a fake on a temporary
/// replica).
abstract interface class SheetsSessionHost {
  /// The user's local replica.
  SheetsReplica get replica;

  /// The serialized writer on [replica].
  SheetsWriter get writer;

  /// `ChangeLog.sessionId` of this app session.
  String get sessionId;

  /// Whether the server is reachable (connectivity, incl. *Simulate
  /// offline*); notifies on changes.
  ValueListenable<bool> get online;

  /// Spaces merged by a sync cycle (`onMergeSuccess`), on the main isolate.
  Stream<UuidValue> get merges;

  /// `sheets.subscribe(itemUuid)`; throws [SheetsOfflineException] offline.
  Future<SubscribeResult> subscribe(UuidValue itemUuid);

  /// `sheets.spaceStats(itemUuid)`; throws [SheetsOfflineException] offline.
  Future<SpaceStats> spaceStats(UuidValue itemUuid);

  /// Asks for a sync cycle soon (new membership, local writes).
  void kick();

  /// The smallest journal cursor of the open sessions changed.
  void journalCursorsChanged();
}
