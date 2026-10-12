import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

import '../../generated/sync_tables.dart';

/// A CRDT-aware database session for synced reads and writes.
///
/// Request sessions are already wrapped by the generated `Serverpod`'s
/// database interceptor; sessions that bypass it (tests, internal sessions)
/// are wrapped here. Reads outside [OfflineSyncDatabase.transactionForUser]
/// are admin reads: they see every space but hide deleted rows.
DatabaseSession syncSessionOf(Session session) {
  if (session.db is OfflineSyncDatabase) return session;
  return _wrapped[session] ??= OfflineSyncDatabaseSession.wraps(
    session,
    syncTables: syncTables,
  );
}

final _wrapped = Expando<DatabaseSession>('wonkySyncSession');

/// The offline-sync space role mirrored from a drive role (specs/06 §3).
OfflineSyncSpaceRole spaceRoleFor({required bool canWrite}) =>
    canWrite ? OfflineSyncSpaceRole.readWrite : OfflineSyncSpaceRole.readOnly;
