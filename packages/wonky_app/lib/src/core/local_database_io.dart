import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> databasePath(String fileName, String? directory) async {
  final dir =
      directory ??
      p.join((await getApplicationSupportDirectory()).path, 'local');
  await Directory(dir).create(recursive: true);
  return p.join(dir, fileName);
}

Future<void> deleteDatabase(String fileName, String? directory) async {
  final path = await databasePath(fileName, directory);
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final f = File('$path$suffix');
    if (await f.exists()) await f.delete();
  }
}
