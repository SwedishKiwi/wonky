import 'dart:math';

import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sync_models/ids.dart';

/// Applies planner operations to a model and checks undo round-trips.
final class PlannerHarness {
  PlannerHarness(this.builder, {int seed = 1})
    : model = builder.build(),
      ids = SeededIdGenerator(seed),
      random = Random(seed);

  final WorkbookBuilder builder;
  final WorkbookModel model;
  final IdGenerator ids;
  final Random random;
  final List<MutationPlan> history = [];
  late final EngineFormulaHooks hooks = EngineFormulaHooks(model);

  static final DateTime now = DateTime.utc(2026, 10, 12, 14, 5, 9);

  PlanContext get ctx => PlanContext(
    userId: '00000000-0000-4000-8000-0000000000ff',
    now: now,
    ids: ids,
    formulas: hooks,
    values: ModelCellSource(model),
    random: random,
    maxCells: 10000000,
  );

  String get sheetId => model.sheets.first.id;

  MutationPlan plan(SheetsOperation op) => const SheetsMutationPlanner().plan(op, model, ctx);

  MutationPlan apply(SheetsOperation op) {
    final p = plan(op);
    model.applyPlan(p);
    history.add(p);
    return p;
  }

  /// Undoes the last applied plan.
  void undo() {
    final p = history.removeLast();
    model.applyChanges(UndoInverter.invert(p, model));
  }

  ResolvedRange range(String a1) => model.parseA1(a1, contextSheetId: sheetId);

  String? content(String a1) => contentAt(model, a1);

  /// The A1 rendering of a cell's formula.
  String? formulaA1(String a1) {
    final r = range(a1);
    final c = content(a1);
    if (c == null || !c.startsWith('=')) return c;
    return hooks.toA1(c, sheetId: r.sheetId, row: r.rect.top, col: r.rect.left);
  }

  CellRecord? cell(String a1) => cellAtA1(model, a1);

  /// Canonical state dump for equality checks.
  Map<String, String> dump() {
    final out = <String, String>{};
    for (final (t, cols) in model.allRows()) {
      final keys = cols.keys.toList()..sort();
      out['$t:${cols[Cols.id]}'] = keys
          .where((k) => cols[k] != null)
          .map((k) => '$k=${cols[k]}')
          .join('|');
    }
    return out;
  }
}
