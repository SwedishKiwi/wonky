import 'package:wonky_sync_kit/tables.dart';

import 'replica_recovery.dart';

/// The web replica lives in OPFS/IndexedDB behind the SQLite worker and is
/// emptied instead of moved aside: nothing to read here.
Future<List<RecoveredSpace>?> readRecovery(
  String path,
  SyncTableSet tables,
) async => null;
