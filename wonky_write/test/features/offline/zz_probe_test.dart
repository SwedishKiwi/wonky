import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite_async/sqlite_async.dart';

void main() {
  test('probe', () async {
    final dir = Directory.systemTemp.createTempSync('wonky_probe');
    final db = SqliteDatabase(path: '${dir.path}/x.db');
    await db.execute('CREATE TABLE t (a TEXT)');
    await db.execute('INSERT INTO t VALUES (?)', ['hi']);
    final r = await db.getAll('SELECT * FROM t');
    expect(r.first['a'], 'hi');
    await db.close();
  });
}
