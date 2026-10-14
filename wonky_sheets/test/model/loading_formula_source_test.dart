import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets/features/model/loading_formula_source.dart';
import 'package:wonky_sheets/features/sync/sheets_writer.dart';
import 'package:wonky_sheets/features/sync/synced_workbook_session.dart';
import 'package:wonky_sheets_core/formula.dart' show FError, FNumber;
import 'package:wonky_sheets_core/model.dart';

import '../sync/support/sync_harness.dart';

final space = UuidValue.fromString('0190a000-0000-7000-8000-0000000000c7');

/// Formulas reading rows that are still streaming in show `#LOADING`
/// (02 §6, 05 §13.6) instead of partial values.
void main() {
  test('Given a spreadsheet streaming in, when a formula reads rows that '
      'are not loaded yet, then it is loading until they arrive, while '
      'formulas over loaded rows show their value at once', () async {
    const rows = 3000;
    final replica = await openTestReplica();
    final create = await createSpreadsheet(
      replica,
      space,
      rows: rows,
      columns: 4,
    );
    final model = WorkbookModel(spreadsheetId: space.uuid)..applyPlan(create);
    final sheet = model.sheets.single;
    final binding = ModelEngineBinding.create(model);
    final plan = const SheetsMutationPlanner().plan(
      SetCellInputs(
        sheetId: sheet.id,
        row: 0,
        col: 0,
        inputs: [
          [
            CellInput.user('=SUM(A2:A$rows)'),
            CellInput.user('=D2*2'),
            CellInput.user('=A1+1'),
          ],
          for (var r = 1; r < rows; r++)
            [
              CellInput.user('1'),
              CellInput.user('x'),
              CellInput.user('y'),
              CellInput.user('$r'),
            ],
        ],
      ),
      model,
      PlanContext(
        userId: testUser.uuid,
        now: DateTime.utc(2026, 10, 1),
        formulas: EngineFormulaHooks(model, engine: binding.engine),
      ),
    );
    binding.dispose();
    await SheetsWriter(replica).write(
      spaceId: space,
      changes: plan.changes,
      plan: plan,
      label: plan.label,
      actorKind: 'user',
      sessionId: 'fixture',
    );

    final s = SyncedWorkbookSession.open(
      FakeSessionHost(replica),
      itemUuid: space,
      spaceUuid: space,
      role: Role.editor,
    );
    addTearDown(s.dispose);
    await s.opened;
    expect(s.rowLoading.complete, isFalse);
    final id = s.model.sheets.single.id;
    final source = LoadingFormulaSource(
      s.engine.engine,
      s.engine.engine,
      s.model,
      s.rowLoading,
    );
    addTearDown(source.dispose);

    bool loading(int col) {
      final v = source.valueAt(id, 0, col);
      return v is FError && v.pending;
    }

    expect(loading(0), isTrue, reason: 'SUM over rows still streaming');
    expect(loading(1), isFalse, reason: 'reads a loaded row only');
    expect(source.valueAt(id, 0, 1), const FNumber(2));
    expect(loading(2), isTrue, reason: 'reads the loading formula');

    await s.rowLoading.whenComplete;
    expect(loading(0), isFalse);
    expect(loading(2), isFalse);
    expect(source.valueAt(id, 0, 0), FNumber((rows - 1).toDouble()));
    expect(source.valueAt(id, 0, 2), FNumber(rows.toDouble()));
  });
}
