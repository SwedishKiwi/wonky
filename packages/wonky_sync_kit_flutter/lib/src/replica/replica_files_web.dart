/// Web: the name is the OPFS / IndexedDB key of the sqlite web worker.
Future<String> replicaPath(String fileName, String? directory) async =>
    fileName;

/// Database deletion is unsupported on the web (callers empty the tables).
Future<bool> deleteReplica(String fileName, String? directory) async => false;

/// Not possible on the web; the caller empties the tables instead.
Future<void> moveReplicaAside(String fileName, String? directory) async {}
