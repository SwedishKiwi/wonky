import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sync_kit/tables.dart';

import 'replica_recovery.dart';

/// Reads the spaces with local writes (`sheets_dirty_space`) from the
/// replica file at [path] with plain SQLite, read-only. Visible rows only
/// (the engine's `crdt_data_rows.visibility`, as `SyncReplica.rowCounts`).
Future<List<RecoveredSpace>?> readRecovery(
  String path,
  SyncTableSet tables,
) async {
  if (!File(path).existsSync()) return null;
  Database? db;
  try {
    db = sqlite3.open(path, mode: OpenMode.readOnly);
    final dirty = db.select(
      'SELECT s."id", s."uuidSpaceId" FROM "sheets_dirty_space" d '
      'JOIN "offline_sync_spaces" s ON s."uuidSpaceId" = d."spaceUuid"',
    );
    final tableIds = {
      for (final r in db.select(
        'SELECT "id", "name" FROM "crdt_schema_tables"',
      ))
        r['name'] as String: r['id'] as int,
    };
    final out = <RecoveredSpace>[];
    for (final d in dirty) {
      final key = d['id'] as int;
      final uuid = UuidValue.fromByteList(
        Uint8List.fromList(d['uuidSpaceId'] as List<int>),
      ).uuid;
      final rows = <(String, Map<String, Object?>)>[];
      for (final spec in tables.modelTables) {
        final table = spec.name;
        final tblId = tableIds[table];
        if (tblId == null) continue;
        final ResultSet result;
        try {
          result = db.select(
            'SELECT t.* FROM "$table" t JOIN "crdt_data_rows" r '
            'ON r."uuidRowId" = t."id" AND r."tblId" = ? '
            'WHERE t."spaceId" = ? AND r."visibility" <= 2',
            [tblId, key],
          );
        } on SqliteException catch (e) {
          debugPrint('Recovery: reading $table failed: $e');
          continue;
        }
        for (final r in result) {
          final columns = ReplicaRecoveryReader.columnsFromRaw(tables, table, {
            for (final name in result.columnNames) name: r[name],
          });
          if (columns != null) rows.add((table, columns));
        }
      }
      if (rows.isEmpty) continue;
      out.add(RecoveredSpace(spaceUuid: uuid, rows: rows));
    }
    return out;
  } catch (e) {
    debugPrint('Reading the broken replica failed: $e');
    return null;
  } finally {
    db?.close();
  }
}
