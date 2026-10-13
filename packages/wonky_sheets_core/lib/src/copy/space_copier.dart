import 'dart:convert';

import 'package:wonky_sync_models/ids.dart';

import '../engine_bridge/stored_formula.dart';
import '../model/schema.dart';

/// Result of [SpaceCopier.copy].
final class SpaceCopy {
  /// Creates a result.
  const SpaceCopy(this.rows, this.idMap);

  /// Rows of the copy `(table, columns)` in dependency order.
  final List<(String table, Map<String, Object?> columns)> rows;

  /// Old id → new id (incl. the spreadsheet/space id).
  final Map<String, String> idMap;

  /// Maps a comment anchor or any old id to the copy.
  String? map(String oldId) => idMap[oldId];
}

/// Copies a spreadsheet (space) or a subset of sheets into a new space with
/// fresh ids (10 §5.4 `SpaceCopier`): new UUIDs for every entity, cell ids
/// recomputed with `SheetsIds.cellId`, stored formula tokens, GridRange JSON,
/// object anchors, filter criteria keys and pivot field references remapped.
/// Script files are copied; triggers, builds and the change log are not.
abstract final class SpaceCopier {
  static const _skipTables = {
    SheetsTables.changeLog,
    SheetsTables.scriptBuild,
    SheetsTables.scriptTrigger,
  };

  /// Copies [rows] of space [sourceSpaceId] into [targetSpaceId].
  ///
  /// [sheetIds] limits the copy to those sheets (Copy sheet to another
  /// spreadsheet): the spreadsheet row, named ranges of other sheets and
  /// scripts are then skipped. [title] overrides the copied title.
  static SpaceCopy copy(
    Iterable<(String table, Map<String, Object?> columns)> rows, {
    required String sourceSpaceId,
    required String targetSpaceId,
    required IdGenerator ids,
    required String userId,
    required DateTime now,
    Set<String>? sheetIds,
    String? title,
  }) {
    final input = [
      for (final (t, c) in rows)
        if (!_skipTables.contains(t)) (t, Map<String, Object?>.of(c)),
    ];
    // Subset filter.
    if (sheetIds != null) {
      final keep = <(String, Map<String, Object?>)>[];
      for (final (t, c) in input) {
        switch (t) {
          case SheetsTables.spreadsheet:
          case SheetsTables.scriptProject:
          case SheetsTables.scriptFile:
          case SheetsTables.macro:
          case SheetsTables.scriptProperty:
            continue;
          case SheetsTables.sheet:
            if (sheetIds.contains(c[Cols.id])) keep.add((t, c));
          case SheetsTables.namedRange:
            final r = c[Cols.rangeJson];
            if (r is String && sheetIds.any(r.contains)) keep.add((t, c));
          default:
            if (sheetIds.contains(c[Cols.sheetId])) keep.add((t, c));
        }
      }
      input
        ..clear()
        ..addAll(keep);
    }
    // Id map.
    final idMap = <String, String>{sourceSpaceId: targetSpaceId};
    for (final (t, c) in input) {
      final id = c[Cols.id]?.toString();
      if (id == null ||
          t == SheetsTables.spreadsheet ||
          t == SheetsTables.cell ||
          t == SheetsTables.basicFilter) {
        continue;
      }
      if (t == SheetsTables.scriptBuild) continue;
      idMap[id] = ids.newId();
    }
    final b62 = {
      for (final e in idMap.entries)
        Base62Uuid.encode(e.key): Base62Uuid.encode(e.value),
    };
    String mapId(String s) => idMap[s] ?? b62[s] ?? s;
    final fieldToken = RegExp('⟦F:([0-9A-Za-z-]+)⟧');
    String mapText(String s) {
      var out = s;
      if (out.contains('⟦')) {
        out = StoredFormula.remapIds(out, idMap);
        out = out.replaceAllMapped(
          fieldToken,
          (m) => '⟦F:${mapId(m.group(1)!)}⟧',
        );
      }
      return out;
    }

    Object? mapJson(Object? v) {
      if (v is String) return mapText(mapId(v));
      if (v is List) return [for (final e in v) mapJson(e)];
      if (v is Map) {
        return {
          for (final e in v.entries) mapId(e.key.toString()): mapJson(e.value),
        };
      }
      return v;
    }

    String? mapJsonString(String? s) {
      if (s == null || s.isEmpty) return s;
      try {
        return jsonEncode(mapJson(jsonDecode(s)));
      } on FormatException {
        return mapText(s);
      }
    }

    final out = <(String, Map<String, Object?>)>[];
    for (final (t, c) in input) {
      final m = <String, Object?>{};
      c.forEach((k, v) {
        if (v is String) {
          if (k.endsWith('Json')) {
            m[k] = mapJsonString(v);
          } else if (k == Cols.id ||
              k.endsWith('Id') ||
              k == 'startId' ||
              k == 'endId') {
            m[k] = mapId(v);
          } else if (k == CellCols.content || k == 'formula') {
            m[k] = v.startsWith('=') ? mapText(v) : v;
          } else {
            m[k] = v;
          }
        } else {
          m[k] = v;
        }
      });
      switch (t) {
        case SheetsTables.spreadsheet:
          m[Cols.id] = targetSpaceId;
          m[Cols.createdBy] = userId;
          m[Cols.createdAt] = now;
          if (title != null) m[SpreadsheetCols.title] = title;
        case SheetsTables.sheet:
          m[Cols.spreadsheetId] = targetSpaceId;
        case SheetsTables.namedRange:
          m[Cols.spreadsheetId] = targetSpaceId;
        case SheetsTables.cell:
          m[Cols.id] = SheetsIds.cellId(
            m[Cols.sheetId]! as String,
            m[CellCols.rowId]! as String,
            m[CellCols.columnId]! as String,
          );
        case SheetsTables.basicFilter:
          m[Cols.id] = SheetsIds.basicFilterId(m[Cols.sheetId]! as String);
        case SheetsTables.scriptProject:
          m[Cols.spreadsheetId] = targetSpaceId;
      }
      out.add((t, m));
    }
    out.sort(
      (x, y) => SheetsTables.rank(x.$1).compareTo(SheetsTables.rank(y.$1)),
    );
    return SpaceCopy(out, idMap);
  }
}
