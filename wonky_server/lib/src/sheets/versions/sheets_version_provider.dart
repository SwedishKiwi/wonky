import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    hide Protocol;

import '../../generated/protocol.dart' as gen;
import 'package:wonky_sheets_core/model.dart'
    show ChangeKinds, RowChange, SheetsTables;

import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../platform/common/time.dart';
import '../../platform/files/file_service.dart';
import '../../platform/versions/version_service.dart';
import '../sync/server_sheets_writer.dart';
import '../sync/sync_db.dart';
import '../sync/synced_tables.dart';

/// Sheets versions (Sheets 10 §5.1): a gzip NDJSON snapshot of all synced
/// rows of the space in cloud storage; restore applies the row diff as
/// normal forward writes recorded as a [ServerChangeRecord].
class SheetsVersionProvider implements VersionProvider {
  const SheetsVersionProvider();

  static const format = 'wonky-sheets-snapshot';
  static const excluded = {
    SheetsTables.changeLog,
    SheetsTables.scriptBuild,
    SheetsTables.scriptTrigger,
  };
  static const _chunk = 5000;

  @override
  DriveItemKind get kind => DriveItemKind.spreadsheet;

  /// All visible rows of [space] by table name (admin read), in dependency
  /// order, as JSON maps without `spaceId`.
  static Future<Map<String, Map<String, Map<String, dynamic>>>> readSpace(
    Session session,
    UuidValue space,
  ) async {
    final spaceRow = await OfflineSyncSpace.db.findFirstRow(
      session,
      where: (t) => t.uuidSpaceId.equals(space),
    );
    final result = <String, Map<String, Map<String, dynamic>>>{};
    if (spaceRow == null) return result;
    final ids = await session.db.unsafeQuery(
      r'''
      SELECT t.name, r."uuidRowId" FROM crdt_data_rows r
      JOIN crdt_schema_tables t ON t.id = r."tblId"
      WHERE r."spaceId" = @space AND r.visibility <= 2
      ''',
      parameters: QueryParameters.named({'space': spaceRow.id}),
    );
    final byTable = <String, Set<UuidValue>>{};
    for (final row in ids) {
      byTable.putIfAbsent(row[0] as String, () => {}).add(row[1] as UuidValue);
    }
    final db = syncSessionOf(session);
    for (final name in SheetsTables.dependencyOrder) {
      if (excluded.contains(name)) continue;
      final table = syncedTablesByName[name];
      final tableIds = byTable[name];
      if (table == null || tableIds == null) continue;
      final list = tableIds.toList();
      final rows = <String, Map<String, dynamic>>{};
      for (var i = 0; i < list.length; i += _chunk) {
        final chunk = list.sublist(
          i,
          i + _chunk > list.length ? list.length : i + _chunk,
        );
        for (final r in await table.findByIds(db, chunk.toSet())) {
          final json = (r.toJson() as Map).cast<String, dynamic>()
            ..remove('spaceId');
          rows[json['id'] as String] = json;
        }
      }
      result[name] = rows;
    }
    return result;
  }

  static Uint8List encode(
    UuidValue space,
    Map<String, Map<String, Map<String, dynamic>>> rows,
  ) {
    final out = StringBuffer();
    out.writeln(
      jsonEncode({
        'format': format,
        'v': 1,
        'spreadsheetId': space.uuid,
        'capturedAt': nowUtc().toIso8601String(),
        'syncTablesHash': syncTablesHashOf(),
        'counts': {for (final e in rows.entries) e.key: e.value.length},
      }),
    );
    for (final table in rows.entries) {
      for (final row in table.value.values) {
        out.writeln(jsonEncode({'tb': table.key, 'row': row}));
      }
    }
    return Uint8List.fromList(gzip.encode(utf8.encode(out.toString())));
  }

  static Map<String, Map<String, Map<String, dynamic>>> decode(Uint8List data) {
    final lines = const LineSplitter().convert(utf8.decode(gzip.decode(data)));
    if (lines.isEmpty) throw const FormatException('Empty snapshot');
    final header = jsonDecode(lines.first) as Map;
    if (header['format'] != format) {
      throw const FormatException('Not a Wonky Sheets snapshot');
    }
    final result = <String, Map<String, Map<String, dynamic>>>{};
    for (final line in lines.skip(1)) {
      if (line.isEmpty) continue;
      final m = jsonDecode(line) as Map;
      final row = (m['row'] as Map).cast<String, dynamic>();
      result.putIfAbsent(m['tb'] as String, () => {})[row['id'] as String] = row;
    }
    return result;
  }

  static String syncTablesHashOf() => OfflineSyncEngine.computeSyncTablesHash(
    syncTables,
    tableDefinitions: gen.Protocol().getTargetTableDefinitions(),
  );

  @override
  Future<CapturedVersion> capture(Session session, DriveItem item) async {
    final space = item.contentRef!;
    final rows = await readSpace(session, space);
    final bytes = encode(space, rows);
    final file = await FileService.storeServerFile(
      session,
      ownerId: item.ownerId,
      itemId: item.id,
      kind: StoredFileKind.snapshot,
      fileName: 'snapshot.wsv.gz',
      mimeType: 'application/gzip',
      bytes: bytes,
    );
    return CapturedVersion(
      storageKind: VersionStorage.snapshotFile,
      snapshotFileId: file.fileUuid,
      sizeBytes: bytes.length,
    );
  }

  @override
  Future<void> afterCapture(
    Session session,
    DriveItem item,
    ItemVersion version,
  ) async {
    final file = await FileService.byUuid(session, version.snapshotFileId!);
    if (file == null) return;
    final bytes = await FileService.readBytes(session, file);
    final rows = decode(bytes.buffer.asUint8List(0, bytes.lengthInBytes));
    final sheets = rows[SheetsTables.sheet]?.values ?? const [];
    int countFor(String table, String sheetId) =>
        rows[table]?.values.where((r) => r['sheetId'] == sheetId).length ?? 0;
    await SheetsSnapshotIndex.db.insertRow(
      session,
      SheetsSnapshotIndex(
        itemVersionId: version.id!,
        sheetsJson: jsonEncode([
          for (final s in sheets)
            {
              'id': s['id'],
              'name': s['name'],
              'kind': s['kind'],
              'rows': countFor(SheetsTables.sheetRow, s['id'] as String),
              'cols': countFor(SheetsTables.sheetColumn, s['id'] as String),
              'cells': countFor(SheetsTables.cell, s['id'] as String),
            },
        ]),
        changedRangesJson: '[]',
        authorIds: version.authors,
      ),
    );
  }

  @override
  Future<RestoredVersion> restore(
    Session session,
    Actor actor,
    DriveItem item,
    ItemVersion version,
  ) async {
    final fileId = version.snapshotFileId;
    if (fileId == null) throw Errors.invalid('The version has no snapshot.');
    final file = await FileService.byUuid(session, fileId);
    if (file == null) throw Errors.expired('The snapshot is no longer stored.');
    final bytes = await FileService.readBytes(session, file);
    final target = decode(bytes.buffer.asUint8List(0, bytes.lengthInBytes));
    final current = await readSpace(session, item.contentRef!);
    final changes = diff(current, target);
    final label = 'Restore version "${version.name ?? version.createdAt.toIso8601String()}"';
    final (changeId, _) = await ServerSheetsWriter.applyRecorded(
      session,
      actor: actor,
      item: item,
      changes: changes,
      label: label,
      kinds: {ChangeKinds.restore},
      lifetime: const Duration(days: 7),
    );
    return RestoredVersion(changeId: changeId);
  }

  /// Row changes turning [current] into [target]: inserts parents first,
  /// deletes children first, updates naming only differing columns.
  static List<RowChange> diff(
    Map<String, Map<String, Map<String, dynamic>>> current,
    Map<String, Map<String, Map<String, dynamic>>> target,
  ) {
    final upserts = <RowChange>[];
    final deletes = <RowChange>[];
    for (final table in SheetsTables.dependencyOrder) {
      if (excluded.contains(table)) continue;
      final cur = current[table] ?? const {};
      final tgt = target[table] ?? const {};
      for (final entry in tgt.entries) {
        final now = cur[entry.key];
        if (now == null) {
          upserts.add(RowChange.insert(table, entry.key, entry.value));
          continue;
        }
        final before = <String, Object?>{};
        final after = <String, Object?>{};
        for (final col in entry.value.entries) {
          if (col.key == 'id') continue;
          if (jsonEncode(now[col.key]) != jsonEncode(col.value)) {
            before[col.key] = now[col.key];
            after[col.key] = col.value;
          }
        }
        if (after.isNotEmpty) {
          upserts.add(RowChange.update(table, entry.key, before, after));
        }
      }
      for (final entry in cur.entries) {
        if (!tgt.containsKey(entry.key)) {
          deletes.add(RowChange.delete(table, entry.key, entry.value));
        }
      }
    }
    return [...deletes.reversed, ...upserts];
  }

  @override
  Future<void> discard(Session session, ItemVersion version) async {
    if (version.snapshotFileId != null) {
      await FileService.deleteFile(session, version.snapshotFileId!);
    }
  }
}
