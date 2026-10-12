import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:wonky_sync_models/ids.dart';

import '../../platform/common/models.dart';
import '../sync/sync_db.dart';

/// Copies a spreadsheet space into a new space (Sheets 10 §5.4 "Make a
/// copy"). Row ids are global and cannot move between spaces, so every
/// entity gets a new UUIDv7; cell ids are recomputed with
/// [SheetsIds.cellId]; ids inside strings (stored formula tokens in base-62
/// form, GridRange JSON, anchors) are remapped. Script triggers, builds and
/// the change log are not copied.
abstract final class SpaceCopier {
  static const _chunk = 2000;

  static final _uuidPattern = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );
  static final _base62Pattern = RegExp(r'[0-9A-Za-z]{22}');

  /// Copies [fromSpace] into the existing, empty [toSpace] as [authorUuid]
  /// (a readWrite member of [toSpace]). Returns the id map (old → new,
  /// dashed lower-case) for remapping comment anchors.
  static Future<Map<String, String>> copy(
    Session session, {
    required UuidValue fromSpace,
    required UuidValue toSpace,
    required UuidValue authorUuid,
    String? title,
    IdGenerator ids = const UuidV7IdGenerator(),
  }) async {
    final db = syncSessionOf(session);
    final spreadsheet = await Spreadsheet.db.findById(db, fromSpace);
    if (spreadsheet == null) {
      throw StateError('Spreadsheet $fromSpace has no rows to copy.');
    }
    final sheets = await Sheet.db.find(
      db,
      where: (t) => t.spreadsheetId.equals(fromSpace),
    );
    final sheetIds = {for (final s in sheets) s.id};
    Future<List<T>> bySheet<T extends TableRow>(
      Future<List<T>> Function() load,
    ) => sheetIds.isEmpty ? Future.value(<T>[]) : load();

    final rows = await bySheet(
      () => SheetRow.db.find(db, where: (t) => t.sheetId.inSet(sheetIds)),
    );
    final columns = await bySheet(
      () => SheetColumn.db.find(db, where: (t) => t.sheetId.inSet(sheetIds)),
    );
    final cells = await bySheet(
      () => Cell.db.find(db, where: (t) => t.sheetId.inSet(sheetIds)),
    );
    final merges = await bySheet(
      () => MergedRange.db.find(db, where: (t) => t.sheetId.inSet(sheetIds)),
    );
    final groups = await bySheet(
      () => DimensionGroup.db.find(db, where: (t) => t.sheetId.inSet(sheetIds)),
    );
    final protections = await bySheet(
      () => ProtectedRange.db.find(db, where: (t) => t.sheetId.inSet(sheetIds)),
    );
    final cfRules = await bySheet(
      () => ConditionalFormatRule.db.find(
        db,
        where: (t) => t.sheetId.inSet(sheetIds),
      ),
    );
    final dvRules = await bySheet(
      () => DataValidationRule.db.find(
        db,
        where: (t) => t.sheetId.inSet(sheetIds),
      ),
    );
    final filters = await bySheet(
      () => BasicFilter.db.find(db, where: (t) => t.sheetId.inSet(sheetIds)),
    );
    final views = await bySheet(
      () => FilterView.db.find(db, where: (t) => t.sheetId.inSet(sheetIds)),
    );
    final bandings = await bySheet(
      () => Banding.db.find(db, where: (t) => t.sheetId.inSet(sheetIds)),
    );
    final objects = await bySheet(
      () => EmbeddedObject.db.find(db, where: (t) => t.sheetId.inSet(sheetIds)),
    );
    final pivots = await bySheet(
      () => PivotTable.db.find(db, where: (t) => t.sheetId.inSet(sheetIds)),
    );
    final names = await NamedRange.db.find(
      db,
      where: (t) => t.spreadsheetId.equals(fromSpace),
    );
    final projects = await ScriptProject.db.find(
      db,
      where: (t) => t.spreadsheetId.equals(fromSpace),
    );
    final projectIds = {for (final p in projects) p.id};
    final files = projectIds.isEmpty
        ? <ScriptFile>[]
        : await ScriptFile.db.find(
            db,
            where: (t) => t.projectId.inSet(projectIds),
          );
    final macros = projectIds.isEmpty
        ? <Macro>[]
        : await Macro.db.find(db, where: (t) => t.projectId.inSet(projectIds));
    final properties = projectIds.isEmpty
        ? <ScriptProperty>[]
        : await ScriptProperty.db.find(
            db,
            where: (t) => t.projectId.inSet(projectIds),
          );

    // ---- id map
    final idMap = <String, String>{fromSpace.uuid: toSpace.uuid};
    void map(UuidValue id) => idMap[id.uuid] = ids.newId();
    for (final list in <List<TableRow>>[
      sheets,
      rows,
      columns,
      merges,
      groups,
      protections,
      cfRules,
      dvRules,
      views,
      bandings,
      objects,
      pivots,
      names,
      projects,
      files,
      macros,
      properties,
    ]) {
      for (final row in list) {
        map(row.id as UuidValue);
      }
    }
    for (final f in filters) {
      idMap[f.id.uuid] = SheetsIds.basicFilterId(idMap[f.sheetId.uuid]!);
    }
    for (final c in cells) {
      idMap[c.id.uuid] = SheetsIds.cellId(
        idMap[c.sheetId.uuid]!,
        idMap[c.rowId.uuid]!,
        idMap[c.columnId.uuid]!,
      );
    }
    final base62Map = {
      for (final e in idMap.entries)
        Base62Uuid.encode(e.key): Base62Uuid.encode(e.value),
    };

    String remap(String s) {
      var out = s.replaceAllMapped(
        _uuidPattern,
        (m) => idMap[m[0]!.toLowerCase()] ?? m[0]!,
      );
      if (out.contains('⟦')) {
        out = out.replaceAllMapped(
          _base62Pattern,
          (m) => base62Map[m[0]!] ?? m[0]!,
        );
      }
      return out;
    }

    Object? remapJson(Object? value) {
      if (value is String) return remap(value);
      if (value is List) return [for (final v in value) remapJson(v)];
      if (value is Map) {
        return {
          for (final e in value.entries)
            if (e.key != 'spaceId') e.key: remapJson(e.value),
        };
      }
      return value;
    }

    T clone<T>(SerializableModel row, T Function(Map<String, dynamic>) from) {
      final json = jsonDecode(jsonEncode(row.toJson())) as Map<String, dynamic>;
      return from((remapJson(json) as Map).cast<String, dynamic>());
    }

    final copySpreadsheet = clone(spreadsheet, Spreadsheet.fromJson);
    final newSpreadsheet = Spreadsheet(
      id: toSpace,
      title: title ?? copySpreadsheet.title,
      locale: copySpreadsheet.locale,
      timeZone: copySpreadsheet.timeZone,
      recalcMode: copySpreadsheet.recalcMode,
      iterativeCalc: copySpreadsheet.iterativeCalc,
      maxIterations: copySpreadsheet.maxIterations,
      convergenceThreshold: copySpreadsheet.convergenceThreshold,
      defaultFontFamily: copySpreadsheet.defaultFontFamily,
      defaultFontSize: copySpreadsheet.defaultFontSize,
      themeJson: copySpreadsheet.themeJson,
      displayLanguage: copySpreadsheet.displayLanguage,
      createdBy: authorUuid,
      createdAt: DateTime.now().toUtc(),
    );

    Future<void> write<T extends TableRow>(
      List<T> list,
      Future<void> Function(List<T> chunk, Transaction tx) insert,
    ) async {
      for (var i = 0; i < list.length; i += _chunk) {
        final chunk = list.sublist(
          i,
          i + _chunk > list.length ? list.length : i + _chunk,
        );
        await db.offlineSyncDb.transactionForUser(
          authorUuid,
          (tx) => insert(chunk, tx),
          spaceId: toSpace,
        );
      }
    }

    await db.offlineSyncDb.transactionForUser(
      authorUuid,
      (tx) async {
        await Spreadsheet.db.insertRow(db, newSpreadsheet, transaction: tx);
        await Sheet.db.insert(
          db,
          [for (final s in sheets) clone(s, Sheet.fromJson)],
          transaction: tx,
        );
      },
      spaceId: toSpace,
    );
    await write(
      [for (final r in rows) clone(r, SheetRow.fromJson)],
      (c, tx) => SheetRow.db.insert(db, c, transaction: tx),
    );
    await write(
      [for (final r in columns) clone(r, SheetColumn.fromJson)],
      (c, tx) => SheetColumn.db.insert(db, c, transaction: tx),
    );
    await write(
      [for (final r in cells) clone(r, Cell.fromJson)],
      (c, tx) => Cell.db.insert(db, c, transaction: tx),
    );
    await db.offlineSyncDb.transactionForUser(
      authorUuid,
      (tx) async {
        if (merges.isNotEmpty) {
          await MergedRange.db.insert(
            db,
            [for (final r in merges) clone(r, MergedRange.fromJson)],
            transaction: tx,
          );
        }
        if (groups.isNotEmpty) {
          await DimensionGroup.db.insert(
            db,
            [for (final r in groups) clone(r, DimensionGroup.fromJson)],
            transaction: tx,
          );
        }
        if (protections.isNotEmpty) {
          await ProtectedRange.db.insert(
            db,
            [for (final r in protections) clone(r, ProtectedRange.fromJson)],
            transaction: tx,
          );
        }
        if (cfRules.isNotEmpty) {
          await ConditionalFormatRule.db.insert(
            db,
            [for (final r in cfRules) clone(r, ConditionalFormatRule.fromJson)],
            transaction: tx,
          );
        }
        if (dvRules.isNotEmpty) {
          await DataValidationRule.db.insert(
            db,
            [for (final r in dvRules) clone(r, DataValidationRule.fromJson)],
            transaction: tx,
          );
        }
        if (filters.isNotEmpty) {
          await BasicFilter.db.insert(
            db,
            [for (final r in filters) clone(r, BasicFilter.fromJson)],
            transaction: tx,
          );
        }
        if (views.isNotEmpty) {
          await FilterView.db.insert(
            db,
            [for (final r in views) clone(r, FilterView.fromJson)],
            transaction: tx,
          );
        }
        if (bandings.isNotEmpty) {
          await Banding.db.insert(
            db,
            [for (final r in bandings) clone(r, Banding.fromJson)],
            transaction: tx,
          );
        }
        if (objects.isNotEmpty) {
          await EmbeddedObject.db.insert(
            db,
            [for (final r in objects) clone(r, EmbeddedObject.fromJson)],
            transaction: tx,
          );
        }
        if (pivots.isNotEmpty) {
          await PivotTable.db.insert(
            db,
            [for (final r in pivots) clone(r, PivotTable.fromJson)],
            transaction: tx,
          );
        }
        if (names.isNotEmpty) {
          await NamedRange.db.insert(
            db,
            [for (final r in names) clone(r, NamedRange.fromJson)],
            transaction: tx,
          );
        }
        if (projects.isNotEmpty) {
          await ScriptProject.db.insert(
            db,
            [for (final r in projects) clone(r, ScriptProject.fromJson)],
            transaction: tx,
          );
        }
        if (files.isNotEmpty) {
          await ScriptFile.db.insert(
            db,
            [for (final r in files) clone(r, ScriptFile.fromJson)],
            transaction: tx,
          );
        }
        if (macros.isNotEmpty) {
          await Macro.db.insert(
            db,
            [for (final r in macros) clone(r, Macro.fromJson)],
            transaction: tx,
          );
        }
        if (properties.isNotEmpty) {
          await ScriptProperty.db.insert(
            db,
            [for (final r in properties) clone(r, ScriptProperty.fromJson)],
            transaction: tx,
          );
        }
      },
      spaceId: toSpace,
    );
    return idMap;
  }
}
