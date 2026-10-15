import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Desktop: `<application support>/local/<fileName>` (as the shell's
/// `LocalDatabases`).
Future<String> replicaPath(String fileName, String? directory) async {
  final dir =
      directory ??
      p.join((await getApplicationSupportDirectory()).path, 'local');
  await Directory(dir).create(recursive: true);
  return p.join(dir, fileName);
}

/// Deletes the replica files (and the SQLite side files).
Future<bool> deleteReplica(String fileName, String? directory) async {
  final path = await replicaPath(fileName, directory);
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final f = File('$path$suffix');
    if (await f.exists()) await f.delete();
  }
  return true;
}

/// Moves a replica that cannot be opened aside (kept for recovery).
Future<void> moveReplicaAside(String fileName, String? directory) async {
  final path = await replicaPath(fileName, directory);
  final stamp = DateTime.now().millisecondsSinceEpoch;
  for (final suffix in const ['', '-wal', '-shm']) {
    final f = File('$path$suffix');
    if (await f.exists()) await f.rename('$path.broken-$stamp$suffix');
  }
}
