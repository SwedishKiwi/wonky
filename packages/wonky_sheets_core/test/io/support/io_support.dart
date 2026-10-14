import 'dart:convert';
import 'dart:typed_data';

import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sync_models/ids.dart';

export 'package:wonky_sheets_core/src/testing/workbook_builder.dart'
    show WorkbookBuilder, cellAtA1, contentAt;

/// The acting user of planner tests.
const String kTestUser = '00000000-0000-4000-8000-0000000000ff';

/// A deterministic plan context.
PlanContext ioContext(IdGenerator ids, {int maxCells = 1000000}) => PlanContext(
  userId: kTestUser,
  now: DateTime.utc(2026, 1, 2, 3, 4, 5),
  ids: ids,
  maxCells: maxCells,
);

/// An IR cell from a test literal: `num` → number, `bool` → boolean,
/// `'=…'` → formula, other strings → text, [IrCell] as is.
IrCell irCell(Object v) => switch (v) {
  final IrCell c => c,
  final num n => IrCell(value: IrNumber(n.toDouble())),
  final bool b => IrCell(value: IrBool(b)),
  final String s when s.startsWith('=') => IrCell(formulaA1: s.substring(1)),
  final String s => IrCell(value: IrText(s)),
  _ => throw ArgumentError.value(v),
};

/// A sheet filled with [rows] from A1 (null = empty).
IrSheet irSheet(String name, [List<List<Object?>> rows = const []]) {
  final s = IrSheet(name);
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      final v = rows[r][c];
      if (v != null) s.cells.set(r, c, irCell(v));
    }
  }
  return s;
}

/// A document with [sheets].
WorkbookDocument irDoc(List<IrSheet> sheets, {String? title}) =>
    WorkbookDocument(title: title ?? 'Imported', locale: 'en_US')
      ..sheets.addAll(sheets);

/// Imports [doc] into a new spreadsheet model.
({WorkbookModel model, IrImportResult result}) importNew(
  WorkbookDocument doc, {
  IdGenerator? ids,
  int maxCells = 1000000,
}) {
  final g = ids ?? SequentialIdGenerator();
  final model = WorkbookModel(spreadsheetId: g.newId());
  final result = IrToRowsPlanner.plan(
    doc,
    model,
    ioContext(g, maxCells: maxCells),
  );
  model.applyPlan(result.plan);
  return (model: model, result: result);
}

/// A canonical text of every row of [model] (for undo comparisons).
String rowsSnapshot(WorkbookModel model) {
  final rows = [
    for (final (t, c) in model.allRows())
      jsonEncode({
        't': t,
        for (final e
            in (c.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
          e.key: e.value is DateTime
              ? (e.value! as DateTime).toIso8601String()
              : e.value,
      }),
  ]..sort();
  return rows.join('\n');
}

/// The A1 text of the formula in the cell at [a1] (`=…`), or its content.
String? formulaAt(WorkbookModel model, String a1) {
  final r = model.parseA1(a1, contextSheetId: model.sheets.first.id);
  final content = model.cellAt(r.sheetId, r.rect.top, r.rect.left)?.content;
  if (content == null || !content.startsWith('=')) return content;
  return EngineFormulaHooks(
    model,
  ).toA1(content, sheetId: r.sheetId, row: r.rect.top, col: r.rect.left);
}

/// The computed value at [a1] (engine recalculation).
CellValue valueAt(WorkbookModel model, String a1) {
  final binding = ModelEngineBinding.create(model);
  final r = model.parseA1(a1, contextSheetId: model.sheets.first.id);
  return binding.engine
      .computedAt(r.sheetId, r.rect.top, r.rect.left)
      .value
      .toCellValue();
}

/// The IR of [model] with computed values (no format hints).
WorkbookDocument irOf(
  WorkbookModel model, {
  Map<String, List<int>> images = const {},
}) {
  final binding = ModelEngineBinding.create(model);
  return ModelToIr.convert(
    model,
    values: EngineIrValueSource(binding.engine),
    formatHints: false,
    imageBytes: (uuid) {
      final b = images[uuid];
      return b == null ? null : Uint8List.fromList(b);
    },
  );
}
