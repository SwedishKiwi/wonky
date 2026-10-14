import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;

import 'replica_recovery.dart';

/// Reads the spreadsheets with local writes (`sheets_dirty_space`) from the
/// replica file at [path] with plain SQLite, read-only, bypassing the sync
/// engine that failed to open it. Visible rows only (the engine's
/// `crdt_data_rows.visibility`, as `SheetsReplica.rowCounts`).
Future<ReplicaRecovery?> readRecovery(String path) async {
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
    final out = <RecoveredSpreadsheet>[];
    for (final d in dirty) {
      final key = d['id'] as int;
      final uuid = UuidValue.fromByteList(
        Uint8List.fromList(d['uuidSpaceId'] as List<int>),
      ).uuid;
      final rows = <(String, Map<String, Object?>)>[];
      for (final table in ReplicaRecovery.tables) {
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
          final columns = ReplicaRecovery.columnsFromRaw(table, {
            for (final name in result.columnNames) name: r[name],
          });
          if (columns != null) rows.add((table, columns));
        }
      }
      final title = rows
          .where((r) => r.$1 == 'spreadsheet')
          .map((r) => r.$2['title'])
          .firstOrNull;
      if (rows.isEmpty) continue;
      out.add(
        RecoveredSpreadsheet(
          spaceUuid: uuid,
          title: title is String ? title : 'Untitled spreadsheet',
          rows: rows,
        ),
      );
    }
    return ReplicaRecovery(out);
  } catch (e) {
    debugPrint('Reading the broken Sheets replica failed: $e');
    return null;
  } finally {
    db?.close();
  }
}
