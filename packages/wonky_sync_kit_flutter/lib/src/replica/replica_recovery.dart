import 'dart:typed_data';

import 'package:serverpod_database/serverpod_database.dart'
    show ColumnBool, ColumnDateTime, ColumnDouble, ColumnUuid;
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sync_kit/tables.dart';
import 'package:wonky_sync_models/tables.dart';

import 'replica_recovery_io.dart'
    if (dart.library.js_interop) 'replica_recovery_web.dart'
    as platform;

/// One space with unsynced local writes read from a replica that can't be
/// opened (suite 12 §2.5 recovery export).
class RecoveredSpace {
  const RecoveredSpace({required this.spaceUuid, required this.rows});

  /// The space (= file) id.
  final String spaceUuid;

  /// Every visible model row of the space (table, column map), tables in
  /// dependency order.
  final List<(String, Map<String, Object?>)> rows;

  /// The first value of [column] in a row of [table] (e.g. the title of the
  /// root row).
  Object? valueOf(String table, String column) =>
      rows.where((r) => r.$1 == table).map((r) => r.$2[column]).firstOrNull;
}

/// Reads the unsynced spaces of a broken replica before it is moved aside,
/// so the app can offer them as "Download unsynced changes" (suite 12
/// §2.5).
///
/// The engine metadata can't tell which rows the server hasn't
/// acknowledged, so recovery returns the whole spaces that had local writes
/// since their last complete sync (the `sheets_dirty_space` marks); the app
/// turns them into its export (Sheets: one XLSX per spreadsheet plus the raw
/// rows).
abstract final class ReplicaRecoveryReader {
  /// Reads the replica file [path] with plain SQLite, read-only, bypassing
  /// the sync engine that failed to open it: the visible model rows of
  /// [tables] in every dirty space. Null on the web (the replica lives
  /// behind the SQLite worker and is emptied instead) or when the file
  /// can't be read at all.
  static Future<List<RecoveredSpace>?> read(String path, SyncTableSet tables) =>
      platform.readRecovery(path, tables);

  /// A column map from raw SQLite values of [table] (UUIDs as 16-byte
  /// blobs, times as epoch milliseconds, booleans as 0/1), as
  /// `SyncedTableSpec.toColumns` returns them. Null for unknown tables.
  static Map<String, Object?>? columnsFromRaw(
    SyncTableSet tables,
    String table,
    Map<String, Object?> raw,
  ) {
    final spec = tables.byName[table];
    if (spec == null) return null;
    final out = <String, Object?>{};
    for (final c in spec.table.columns) {
      final name = c.columnName;
      if (name == SyncedTableSpec.spaceIdColumn) continue;
      final v = raw[name];
      out[name] = v == null
          ? null
          : switch (c) {
              ColumnUuid() =>
                v is List<int>
                    ? UuidValue.fromByteList(Uint8List.fromList(v)).uuid
                    : '$v',
              ColumnDateTime() =>
                v is int
                    ? DateTime.fromMillisecondsSinceEpoch(v, isUtc: true)
                    : DateTime.parse('$v').toUtc(),
              ColumnBool() => v is int ? v != 0 : v == true,
              ColumnDouble() => (v as num).toDouble(),
              _ => v,
            };
    }
    return out;
  }
}
