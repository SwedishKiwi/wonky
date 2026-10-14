import 'replica_recovery.dart';

/// The web replica lives in OPFS/IndexedDB behind the SQLite worker and is
/// emptied instead of moved aside: nothing to read here.
Future<ReplicaRecovery?> readRecovery(String path) async => null;
