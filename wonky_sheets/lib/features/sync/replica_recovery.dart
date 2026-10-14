import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:serverpod_database/serverpod_database.dart'
    show ColumnBool, ColumnDateTime, ColumnDouble, ColumnUuid;
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sync_models/tables.dart';

import 'replica_recovery_io.dart'
    if (dart.library.js_interop) 'replica_recovery_web.dart'
    as platform;
import 'sheets_replica.dart';

/// One spreadsheet with unsynced local writes read from a replica that can't
/// be opened (suite 12 §2.5 recovery export).
class RecoveredSpreadsheet {
  const RecoveredSpreadsheet({
    required this.spaceUuid,
    required this.title,
    required this.rows,
  });

  final String spaceUuid;
  final String title;

  /// Every visible model row of the space (table, column map).
  final List<(String, Map<String, Object?>)> rows;
}

/// The unsynced spreadsheets of a broken replica, offered as "Download
/// unsynced changes" before the replica is moved aside.
///
/// The engine metadata can't tell which rows the server hasn't
/// acknowledged, so the export holds the whole spreadsheets that had local
/// writes since their last complete sync (`SheetsDirtySpace`): one XLSX per
/// spreadsheet plus `rows.json` with the raw rows (lossless; support can
/// re-import them).
class ReplicaRecovery {
  const ReplicaRecovery(this.spreadsheets);

  final List<RecoveredSpreadsheet> spreadsheets;

  bool get isEmpty => spreadsheets.isEmpty;

  /// Reads the replica file [path] read-only (desktop; null on the web or
  /// when the file can't be read at all).
  static Future<ReplicaRecovery?> read(String path) =>
      platform.readRecovery(path);

  /// `Wonky Sheets unsynced changes <date>.zip`.
  static String fileName(DateTime now) =>
      'Wonky Sheets unsynced changes '
      '${now.year}-${_two(now.month)}-${_two(now.day)}.zip';

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// The ZIP to download.
  Uint8List toZip() {
    final archive = Archive();
    final names = <String>{};
    final json = <Map<String, Object?>>[];
    for (final s in spreadsheets) {
      final model = WorkbookModel.fromRows(s.spaceUuid, s.rows);
      var base = SheetsWorkbookExporter.sanitizeFileName(s.title);
      var n = 2;
      while (!names.add(base.toLowerCase())) {
        base = '${SheetsWorkbookExporter.sanitizeFileName(s.title)} ($n)';
        n++;
      }
      try {
        final binding = ModelEngineBinding.create(model);
        final doc = SheetsWorkbookExporter.toDocument(
          model,
          values: EngineIrValueSource(binding.engine),
        );
        final (bytes, _) = SheetsWorkbookExporter.writeDocument(
          doc,
          SheetsExportFormat.xlsx,
        );
        binding.dispose();
        archive.addFile(ArchiveFile('$base.xlsx', bytes.length, bytes));
      } catch (_) {
        // The raw rows below still hold everything.
      }
      json.add({
        'spreadsheetId': s.spaceUuid,
        'title': s.title,
        'rows': [
          for (final (table, columns) in s.rows)
            {'table': table, 'columns': _jsonColumns(columns)},
        ],
      });
    }
    final rows = utf8.encode(
      const JsonEncoder.withIndent('  ').convert({'spreadsheets': json}),
    );
    archive.addFile(ArchiveFile('rows.json', rows.length, rows));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static Map<String, Object?> _jsonColumns(Map<String, Object?> c) => {
    for (final e in c.entries)
      e.key: switch (e.value) {
        final DateTime d => d.toUtc().toIso8601String(),
        final Enum v => v.name,
        final v => v,
      },
  };

  /// A column map from raw SQLite values of [table] (UUIDs as 16-byte
  /// blobs, times as epoch milliseconds, booleans as 0/1), as
  /// `SyncedTableSpec.toColumns` returns them.
  static Map<String, Object?>? columnsFromRaw(
    String table,
    Map<String, Object?> raw,
  ) {
    final spec = SyncedTables.byName[table];
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

  /// The model tables read for a recovery (as `SheetsReplica.loadSpace`).
  static List<String> get tables => [
    for (final s in SheetsReplica.modelTables) s.name,
  ];
}
