import 'dart:convert';

import 'package:wonky_sync_models/ids.dart';

import '../../engine_bridge/stored_formula.dart';
import '../../format/theme.dart';
import '../../model/grid_range.dart';
import '../../model/records.dart';
import '../../model/schema.dart';
import '../../model/sheet_model.dart';
import '../operations.dart';
import '../plan_builder.dart';
import '../row_change.dart';
import 'helpers.dart';

/// Validates a sheet name (non-empty, ≤ 100 chars, no `[]*?/\:` like Excel
/// for export safety is NOT required by Sheets — only uniqueness and length).
void validateSheetName(PlanBuilder b, String name, {String? exceptId}) {
  final n = name.trim();
  if (n.isEmpty) {
    throw const PlanException('invalid_argument', 'Sheet name cannot be empty');
  }
  if (n.length > 100) {
    throw const PlanException(
      'invalid_argument',
      'Sheet name is too long (max 100)',
    );
  }
  final lower = n.toLowerCase();
  for (final s in b.model.sheets) {
    if (s.id == exceptId) continue;
    final cur = b.current(SheetsTables.sheet, s.id);
    final curName = (cur?[Cols.name] as String? ?? s.name).toLowerCase();
    if (curName == lower) {
      throw PlanException(
        'duplicate_name',
        'A sheet with the name "$n" already exists. Please enter another name.',
      );
    }
  }
  for (final e in b.touchedRows(SheetsTables.sheet).entries) {
    if (e.key == exceptId || e.value == null || b.model.sheet(e.key) != null) {
      continue;
    }
    if ((e.value![Cols.name] as String? ?? '').toLowerCase() == lower) {
      throw PlanException(
        'duplicate_name',
        'A sheet with the name "$n" already exists. Please enter another name.',
      );
    }
  }
}

/// The next free default name `SheetN` / `<prefix> N`.
String nextSheetName(
  PlanBuilder b, {
  String prefix = 'Sheet',
  bool spaced = false,
}) {
  final taken = {
    for (final s in b.model.sheets) s.name.toLowerCase(),
    for (final v in b.touchedRows(SheetsTables.sheet).values)
      if (v != null) (v[Cols.name] as String? ?? '').toLowerCase(),
  };
  for (var i = 1; ; i++) {
    final name = spaced ? '$prefix $i' : '$prefix$i';
    if (!taken.contains(name.toLowerCase())) return name;
  }
}

String _sheetKeyAt(PlanBuilder b, int? index, {String? excludeId}) {
  final keys = [
    for (final s in b.model.sheets)
      if (s.id != excludeId) s.record!.sortKey,
  ];
  final i = index == null ? keys.length : index.clamp(0, keys.length);
  final prev = i > 0 ? keys[i - 1] : null;
  final next = i < keys.length ? keys[i] : null;
  if (prev != null && next != null && prev.compareTo(next) >= 0) {
    return FractionalIndex.after(prev);
  }
  return FractionalIndex.between(prev, next);
}

/// Inserts a grid sheet with [rows] × [columns] entities; returns the id.
String insertSheet(
  PlanBuilder b, {
  required String name,
  required String sortKey,
  int rows = 1000,
  int columns = 26,
  SheetKind kind = SheetKind.grid,
  String? id,
}) {
  final sheetId = id ?? b.ctx.ids.newId();
  b.insert(SheetsTables.sheet, sheetId, {
    Cols.spreadsheetId: b.model.spreadsheetId,
    Cols.name: name,
    Cols.sortKey: sortKey,
    SheetCols.kind: kind.name,
    Cols.hidden: false,
    SheetCols.tabColor: null,
    SheetCols.rightToLeft: false,
    SheetCols.showGridlines: true,
    SheetCols.frozenRows: 0,
    SheetCols.frozenColumns: 0,
    SheetCols.defaultRowHeight: 21.0,
    SheetCols.defaultColumnWidth: 100.0,
    Cols.formatJson: null,
    SheetCols.printSettingsJson: null,
  });
  if (kind == SheetKind.grid) {
    final rk = FractionalIndex.nBetween(null, null, rows);
    for (final k in rk) {
      b.insert(SheetsTables.sheetRow, b.ctx.ids.newId(), {
        Cols.sheetId: sheetId,
        Cols.sortKey: k,
        Cols.hidden: false,
      });
    }
    final ck = FractionalIndex.nBetween(null, null, columns);
    for (final k in ck) {
      b.insert(SheetsTables.sheetColumn, b.ctx.ids.newId(), {
        Cols.sheetId: sheetId,
        Cols.sortKey: k,
        Cols.hidden: false,
      });
    }
  }
  return sheetId;
}

/// [CreateSpreadsheet].
MutationPlan planCreateSpreadsheet(PlanBuilder b, CreateSpreadsheet op) {
  final font = op.fontFamily?.trim();
  final theme = font == null || font.isEmpty
      ? SpreadsheetTheme.standard
      : SpreadsheetTheme.standard.copyWith(textFont: font);
  b.insert(SheetsTables.spreadsheet, op.spreadsheetId, {
    SpreadsheetCols.title: op.title,
    SpreadsheetCols.locale: op.locale,
    SpreadsheetCols.timeZone: op.timeZone,
    SpreadsheetCols.recalcMode: 'onChange',
    SpreadsheetCols.iterativeCalc: false,
    SpreadsheetCols.maxIterations: 50,
    SpreadsheetCols.convergenceThreshold: 0.05,
    SpreadsheetCols.defaultFontFamily: theme.textFont,
    SpreadsheetCols.defaultFontSize: op.fontSize ?? 10.0,
    SpreadsheetCols.themeJson: theme.toJson(),
    Cols.createdBy: b.ctx.userId,
  });
  final id = insertSheet(
    b,
    name: op.firstSheetName,
    sortKey: FractionalIndex.first(),
    rows: op.rows,
    columns: op.columns,
  );
  b.result['sheetId'] = id;
  b.summary.sheets.add(id);
  return b.build('Create spreadsheet', kinds: [ChangeKinds.sheets]);
}

/// [AddSheet].
MutationPlan planAddSheet(PlanBuilder b, AddSheet op) {
  final name = op.name ?? nextSheetName(b);
  validateSheetName(b, name);
  if (op.kind == SheetKind.grid) {
    b.checkCellLimit(b.model.gridCellCount + op.rows * op.columns);
  }
  final id = insertSheet(
    b,
    name: name.trim(),
    sortKey: _sheetKeyAt(b, op.index),
    rows: op.rows,
    columns: op.columns,
    kind: op.kind,
    id: op.sheetId,
  );
  b.result['sheetId'] = id;
  b.summary.sheets.add(id);
  return b.build('Add sheet', kinds: [ChangeKinds.sheets]);
}

/// All child records of a sheet (cells, rows, columns, rules, objects, pivots)
/// as `(table, id)`, children first.
Iterable<(String, String)> sheetChildren(SheetModel s) sync* {
  for (final c in s.cells.all) {
    yield (SheetsTables.cell, c.id);
  }
  for (final m in [
    s.merges,
    s.groups,
    s.protections,
    s.cfRules,
    s.dvRules,
    s.filterViews,
    s.bandings,
    s.objects,
    s.pivots,
  ]) {
    for (final r in m.values) {
      yield (r.table, r.id);
    }
  }
  if (s.basicFilter != null) {
    yield (SheetsTables.basicFilter, s.basicFilter!.id);
  }
  for (final id in s.rowRecords.keys) {
    yield (SheetsTables.sheetRow, id);
  }
  for (final id in s.columnRecords.keys) {
    yield (SheetsTables.sheetColumn, id);
  }
}

/// [DeleteSheet]: deletes the sheet and every child explicitly (so undo
/// revives all of them with the same ids).
MutationPlan planDeleteSheet(PlanBuilder b, DeleteSheet op) {
  final s = b.sheetOf(op.sheetId);
  final remainingVisible = b.model.sheets
      .where((x) => x.id != s.id && !x.record!.hidden)
      .length;
  if (remainingVisible == 0) {
    throw const PlanException(
      'invalid_argument',
      "You can't remove all the visible sheets in a document",
    );
  }
  for (final (t, id) in sheetChildren(s)) {
    b.delete(t, id);
  }
  b.delete(SheetsTables.sheet, s.id);
  b.summary.addDeleted('sheets', s.id);
  b.summary.sheets.add(s.id);
  return b.build('Delete sheet', kinds: [ChangeKinds.sheets]);
}

/// [RenameSheet].
MutationPlan planRenameSheet(PlanBuilder b, RenameSheet op) {
  final s = b.sheetOf(op.sheetId);
  validateSheetName(b, op.name, exceptId: s.id);
  b.update(SheetsTables.sheet, s.id, {Cols.name: op.name.trim()});
  b.summary.sheets.add(s.id);
  return b.build('Rename sheet', kinds: [ChangeKinds.sheets]);
}

/// [MoveSheet].
MutationPlan planMoveSheet(PlanBuilder b, MoveSheet op) {
  final s = b.sheetOf(op.sheetId);
  final key = _sheetKeyAt(b, op.index, excludeId: s.id);
  b.update(SheetsTables.sheet, s.id, {Cols.sortKey: key});
  b.summary.sheets.add(s.id);
  return b.build('Move sheet', kinds: [ChangeKinds.sheets]);
}

/// [SetSheetProperties].
MutationPlan planSetSheetProperties(PlanBuilder b, SetSheetProperties op) {
  final s = b.sheetOf(op.sheetId);
  if (op.hidden == true) {
    final visible = b.model.sheets
        .where((x) => x.id != s.id && !x.record!.hidden)
        .length;
    if (visible == 0) {
      throw const PlanException(
        'invalid_argument',
        "You can't hide all sheets",
      );
    }
  }
  b.update(SheetsTables.sheet, s.id, {
    if (op.tabColor != null) SheetCols.tabColor: op.tabColor,
    if (op.clearTabColor) SheetCols.tabColor: null,
    if (op.hidden != null) Cols.hidden: op.hidden,
    if (op.showGridlines != null) SheetCols.showGridlines: op.showGridlines,
    if (op.rightToLeft != null) SheetCols.rightToLeft: op.rightToLeft,
    if (op.defaultRowHeight != null)
      SheetCols.defaultRowHeight: op.defaultRowHeight,
    if (op.defaultColumnWidth != null)
      SheetCols.defaultColumnWidth: op.defaultColumnWidth,
  });
  b.summary.sheets.add(s.id);
  final label = op.hidden == true
      ? 'Hide sheet'
      : op.hidden == false
      ? 'Unhide sheet'
      : (op.tabColor != null || op.clearTabColor)
      ? 'Change tab color'
      : 'Sheet settings';
  return b.build(label, kinds: [ChangeKinds.sheets]);
}

/// [SetSpreadsheetProperties].
MutationPlan planSetSpreadsheetProperties(
  PlanBuilder b,
  SetSpreadsheetProperties op,
) {
  final id = b.model.spreadsheetId;
  final writes = <String, Object?>{
    if (op.title != null) SpreadsheetCols.title: op.title,
    if (op.locale != null) SpreadsheetCols.locale: op.locale,
    if (op.timeZone != null) SpreadsheetCols.timeZone: op.timeZone,
    if (op.recalcMode != null) SpreadsheetCols.recalcMode: op.recalcMode,
    if (op.iterativeCalc != null)
      SpreadsheetCols.iterativeCalc: op.iterativeCalc,
    if (op.maxIterations != null)
      SpreadsheetCols.maxIterations: op.maxIterations,
    if (op.convergenceThreshold != null)
      SpreadsheetCols.convergenceThreshold: op.convergenceThreshold,
    if (op.displayLanguage != null)
      SpreadsheetCols.displayLanguage: op.displayLanguage,
  };
  if (op.themeJson != null) {
    final theme = SpreadsheetTheme.parse(op.themeJson);
    writes[SpreadsheetCols.themeJson] = theme.toJson();
    writes[SpreadsheetCols.defaultFontFamily] = theme.textFont;
  }
  if (b.current(SheetsTables.spreadsheet, id) == null) {
    throw const PlanException('not_found', 'Spreadsheet row not loaded');
  }
  b.update(SheetsTables.spreadsheet, id, writes);
  final label = op.themeJson != null
      ? 'Change theme'
      : op.title != null
      ? 'Rename'
      : 'Spreadsheet settings';
  return b.build(label, kinds: [ChangeKinds.settings]);
}

/// [SetPrintSettings] (merge patch per sheet).
MutationPlan planSetPrintSettings(PlanBuilder b, SetPrintSettings op) {
  for (final sheetId in op.sheetIds) {
    final s = b.sheetOf(sheetId);
    String? next;
    if (op.patch == null) {
      next = null;
    } else {
      final cur = op.replace
          ? <String, Object?>{}
          : PlanBuilderHelpers.decodeMap(s.record?.printSettingsJson);
      next = jsonEncode(jsonMergePatch(cur, op.patch!));
    }
    b.update(SheetsTables.sheet, s.id, {SheetCols.printSettingsJson: next});
    b.summary.sheets.add(s.id);
  }
  return b.build('Change print settings', kinds: [ChangeKinds.settings]);
}

/// RFC 7386 JSON merge patch.
Map<String, Object?> jsonMergePatch(
  Map<String, Object?> target,
  Map<String, Object?> patch,
) {
  final out = Map<String, Object?>.of(target);
  patch.forEach((k, v) {
    if (v == null) {
      out.remove(k);
    } else if (v is Map) {
      final t = out[k];
      out[k] = jsonMergePatch(
        t is Map ? t.cast<String, Object?>() : {},
        v.cast<String, Object?>(),
      );
    } else {
      out[k] = v;
    }
  });
  return out;
}

/// [DuplicateSheet]: copies rows/columns (new ids, same keys), cells, rules,
/// objects and pivots; same-sheet formula references are remapped to the copy.
MutationPlan planDuplicateSheet(PlanBuilder b, DuplicateSheet op) {
  final s = b.sheetOf(op.sheetId);
  final baseName = 'Copy of ${s.name}';
  var name = op.name ?? baseName;
  if (op.name == null) {
    final taken = {for (final x in b.model.sheets) x.name.toLowerCase()};
    var i = 2;
    while (taken.contains(name.toLowerCase())) {
      name = '$baseName $i';
      i++;
    }
  }
  validateSheetName(b, name);
  b.checkCellLimit(b.model.gridCellCount + s.rows.length * s.columns.length);
  final order = b.model.sheets.indexWhere((x) => x.id == s.id);
  final newId = b.ctx.ids.newId();
  final rec = s.record!.toColumns()
    ..remove(Cols.id)
    ..[Cols.name] = name
    ..[Cols.sortKey] = _sheetKeyAt(b, op.index ?? order + 1)
    ..[Cols.hidden] = false;
  b.insert(SheetsTables.sheet, newId, rec);
  final idMap = <String, String>{s.id: newId};
  for (final r in s.rowRecords.values) {
    idMap[r.id] = b.ctx.ids.newId();
  }
  for (final c in s.columnRecords.values) {
    idMap[c.id] = b.ctx.ids.newId();
  }
  for (final r in s.rowRecords.values) {
    b.insert(
      SheetsTables.sheetRow,
      idMap[r.id]!,
      {...r.toColumns(), Cols.sheetId: newId}..remove(Cols.id),
    );
  }
  for (final c in s.columnRecords.values) {
    b.insert(
      SheetsTables.sheetColumn,
      idMap[c.id]!,
      {...c.toColumns(), Cols.sheetId: newId}..remove(Cols.id),
    );
  }
  String remapText(String text) {
    final same = StoredFormula.mapTokens(text, (t) {
      if (t.sheetId != null && t.sheetId != s.id) return t;
      return t.copyWith(
        sheetId: null,
        rowId: t.rowId == null ? null : (idMap[t.rowId!] ?? t.rowId),
        colId: t.colId == null ? null : (idMap[t.colId!] ?? t.colId),
      );
    });
    return same;
  }

  for (final cell in s.cells.all) {
    final rowId = idMap[cell.rowId];
    final colId = idMap[cell.columnId];
    if (rowId == null || colId == null) continue;
    final cols = cell.toColumns()
      ..remove(Cols.id)
      ..[Cols.sheetId] = newId
      ..[CellCols.rowId] = rowId
      ..[CellCols.columnId] = colId;
    final content = cell.content;
    if (content != null && content.startsWith('=')) {
      cols[CellCols.content] = remapText(content);
    }
    b.insert(SheetsTables.cell, SheetsIds.cellId(newId, rowId, colId), cols);
  }
  String? remapRange(String? json) {
    final g = GridRange.tryParse(json);
    if (g == null) return json;
    if (g.sheetId != s.id) return json;
    return GridRange(
      sheetId: newId,
      r1: g.r1 == null ? null : idMap[g.r1!],
      r2: g.r2 == null ? null : idMap[g.r2!],
      c1: g.c1 == null ? null : idMap[g.c1!],
      c2: g.c2 == null ? null : idMap[g.c2!],
      r1k: g.r1k,
      r2k: g.r2k,
      c1k: g.c1k,
      c2k: g.c2k,
    ).encode();
  }

  String remapRanges(String json) => GridRange.encodeList(
    GridRange.parseList(
      json,
    ).map((g) => GridRange.tryParse(remapRange(g.encode()))!),
  );

  String remapJson(String json) {
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return json;
    }
    final (out, _) = StoredFormula.mapJsonFormulas(decoded, remapText);
    Object? walk(Object? v) {
      if (v is Map) {
        if (v['s'] is String && (v.containsKey('r1') || v.containsKey('c1'))) {
          return jsonDecode(remapRange(jsonEncode(v))!);
        }
        return {for (final e in v.entries) e.key: walk(e.value)};
      }
      if (v is List) return [for (final e in v) walk(e)];
      return v;
    }

    return jsonEncode(walk(out));
  }

  void copy(
    SyncRecord r,
    Map<String, Object?> Function(Map<String, Object?>) f,
  ) {
    final cols = r.toColumns()
      ..remove(Cols.id)
      ..[Cols.sheetId] = newId;
    b.insert(r.table, b.ctx.ids.newId(), f(cols));
  }

  for (final m in s.merges.values) {
    copy(m, (c) => c..[Cols.rangeJson] = remapRange(m.rangeJson));
  }
  for (final g in s.groups.values) {
    copy(
      g,
      (c) => c
        ..['startId'] = idMap[g.startId] ?? g.startId
        ..['endId'] = idMap[g.endId] ?? g.endId,
    );
  }
  for (final r in s.cfRules.values) {
    copy(
      r,
      (c) => c
        ..[Cols.rangesJson] = remapRanges(r.rangesJson)
        ..['ruleJson'] = remapJson(r.ruleJson),
    );
  }
  for (final r in s.dvRules.values) {
    copy(
      r,
      (c) => c
        ..[Cols.rangesJson] = remapRanges(r.rangesJson)
        ..['criteriaJson'] = remapJson(r.criteriaJson),
    );
  }
  for (final r in s.bandings.values) {
    copy(r, (c) => c..[Cols.rangeJson] = remapRange(r.rangeJson));
  }
  for (final r in s.protections.values) {
    copy(r, (c) {
      c[Cols.rangeJson] = remapRange(r.rangeJson);
      if (r.exceptRangesJson != null) {
        c['exceptRangesJson'] = remapRanges(r.exceptRangesJson!);
      }
      return c;
    });
  }
  for (final r in s.filterViews.values) {
    copy(
      r,
      (c) => c
        ..[Cols.rangeJson] = remapRange(r.rangeJson)
        ..['criteriaJson'] = remapJson(r.criteriaJson),
    );
  }
  if (s.basicFilter != null) {
    final f = s.basicFilter!;
    final cols = f.toColumns()
      ..remove(Cols.id)
      ..[Cols.sheetId] = newId
      ..[Cols.rangeJson] = remapRange(f.rangeJson)
      ..['criteriaJson'] = _remapCriteriaKeys(remapJson(f.criteriaJson), idMap);
    b.insert(SheetsTables.basicFilter, SheetsIds.basicFilterId(newId), cols);
  }
  for (final o in s.objects.values) {
    copy(o, (c) {
      final anchor = PlanBuilderHelpers.decodeMap(o.anchorJson);
      for (final k in ['rowId', 'colId']) {
        final v = anchor[k];
        if (v is String) {
          final canonical = v.contains('-')
              ? v
              : (Base62Uuid.isValid(v) ? Base62Uuid.decode(v) : v);
          final mapped = idMap[canonical];
          if (mapped != null) anchor[k] = Base62Uuid.encode(mapped);
        }
      }
      c['anchorJson'] = jsonEncode(anchor);
      c['specJson'] = remapJson(o.specJson);
      return c;
    });
  }
  for (final p in s.pivots.values) {
    copy(p, (c) {
      c['anchorRowId'] = idMap[p.anchorRowId] ?? p.anchorRowId;
      c['anchorColId'] = idMap[p.anchorColId] ?? p.anchorColId;
      c['sourceRangeJson'] = remapRange(p.sourceRangeJson);
      return c;
    });
  }
  b.result['sheetId'] = newId;
  b.summary.sheets.add(newId);
  return b.build('Duplicate sheet', kinds: [ChangeKinds.sheets]);
}

String _remapCriteriaKeys(String json, Map<String, String> idMap) {
  final m = PlanBuilderHelpers.decodeMap(json);
  return jsonEncode({
    for (final e in m.entries) idMap[e.key] ?? e.key: e.value,
  });
}
