import 'replica_files_io.dart'
    if (dart.library.js_interop) 'replica_files_web.dart'
    as platform;

/// Where replicas, uploads and caches of an app live and how they are
/// removed (suite 12 §2.5).
abstract final class ReplicaFiles {
  /// The path (desktop: `<application support>/local/<fileName>`, or under
  /// [directory]) or the OPFS/IndexedDB name (web) of [fileName].
  static Future<String> path(String fileName, [String? directory]) =>
      platform.replicaPath(fileName, directory);

  /// Deletes the database file and its SQLite side files (desktop). False on
  /// the web, where callers empty the tables instead.
  static Future<bool> delete(String fileName, [String? directory]) =>
      platform.deleteReplica(fileName, directory);

  /// Moves a database that cannot be opened aside, kept for recovery
  /// (desktop: `<file>.broken-<ms>`; no-op on the web).
  static Future<void> moveAside(String fileName, [String? directory]) =>
      platform.moveReplicaAside(fileName, directory);
}
