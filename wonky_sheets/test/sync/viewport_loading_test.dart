import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets/features/model/workbook_session.dart';
import 'package:wonky_sheets/features/model/loading_gate.dart';
import 'package:wonky_sheets/features/sync/sheets_replica.dart';
import 'package:wonky_sheets/features/sync/sheets_writer.dart';
import 'package:wonky_sheets/features/sync/synced_workbook_session.dart';
import 'package:wonky_sheets_core/formula.dart' show FNumber, GridRect;
import 'package:wonky_sheets_core/model.dart';

import 'support/sync_harness.dart';

final space = UuidValue.fromString('0190a000-0000-7000-8000-0000000000d1');

/// A spreadsheet of [rows] × [cols] cells: A1 sums column A, A2:A[rows]
/// hold 1..rows-1, the other columns text (`r<row>c<col>`).
Future<void> writeFixture(
  SheetsReplica replica, {
  required int rows,
  required int cols,
}) async {
  final create = await createSpreadsheet(
    replica,
    space,
    title: 'Big',
    rows: rows,
    columns: cols,
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
        for (var r = 0; r < rows; r++)
          [
            CellInput.user(r == 0 ? '=SUM(A2:A$rows)' : '$r'),
            for (var c = 1; c < cols; c++) CellInput.user('r${r}c$c'),
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
  final watch = Stopwatch()..start();
  await SheetsWriter(replica).write(
    spaceId: space,
    changes: plan.changes,
    plan: plan,
    label: plan.label,
    actorKind: 'user',
    sessionId: 'fixture',
  );
  // ignore: avoid_print
  print('${rows * cols} cells written in ${watch.elapsedMilliseconds} ms');
}

// The local writer needs ~1.5 s per 5,000 new cells (offline-sync engine
// inserts, growing with the table), so the default suite uses 15k cells
// (streamed: more than `smallSpaceRows` rows); the 200k-cell timing runs
// with `-t slow`.
const rows = 3000;
const cols = 5;

void main() {
  late SheetsReplica replica;
  late FakeSessionHost host;

  setUp(() async {
    replica = await openTestReplica();
    host = FakeSessionHost(replica);
  });

  SyncedWorkbookSession open({ViewportHint? viewport}) {
    final s = SyncedWorkbookSession.open(
      host,
      itemUuid: space,
      spaceUuid: space,
      role: Role.editor,
      viewport: viewport,
    );
    addTearDown(s.dispose);
    return s;
  }

  double sumA1(SyncedWorkbookSession s) {
    final sheet = s.model.sheets.single;
    final v = s.engine.engine.valueAt(sheet.id, 0, 0);
    return v is FNumber ? v.v : double.nan;
  }

  Future<void> openAndCompare({required int rows, required int cols}) async {
    await writeFixture(replica, rows: rows, cols: cols);
    final watch = Stopwatch()..start();
    final s = open();
    await s.opened;
    final ready = watch.elapsedMilliseconds;

    expect(s.loadState.value, isA<WorkbookReady>());
    final sheet = s.model.sheets.single;
    final far = rows - 100;
    expect(s.rowLoading.complete, isFalse);
    expect(s.model.cellAt(sheet.id, 5, 3)?.content, 's:r5c3');
    expect(s.rowLoading.isRowLoaded(sheet.id, sheet.rows.idAt(5)), isTrue);
    expect(s.rowLoading.isRowLoaded(sheet.id, sheet.rows.idAt(far)), isFalse);
    expect(s.model.cellAt(sheet.id, far, 3), isNull);

    await s.rowLoading.whenComplete;
    final full = watch.elapsedMilliseconds;
    // ignore: avoid_print
    print('${rows * cols} cells: ready after $ready ms, all after $full ms');

    expect(s.rowLoading.progress, 1);
    expect(s.model.cellAt(sheet.id, far, 3)?.content, 's:r${far}c3');
    expect(canonical(s.model), canonical(await reloadModel(replica, space)));
    expect(sumA1(s), (rows - 1) * rows / 2);
    expect(ready, lessThan(full));
  }

  test('Given a big spreadsheet, when opened, then the first window is ready '
      'before the rest has loaded, and after streaming the model equals a '
      'full reload with formulas recalculated', () async {
    await openAndCompare(rows: rows, cols: cols);
  });

  test(
    'Given a 200k-cell spreadsheet, when opened, then it is ready long '
    'before it has loaded completely',
    () => openAndCompare(rows: 10000, cols: 20),
    tags: ['slow'],
    timeout: const Timeout(Duration(minutes: 15)),
  );

  test(
    'Given a spreadsheet streaming in, when the user edits a loaded row '
    'then it is kept, and an edit of a row still loading is refused',
    () async {
      await writeFixture(replica, rows: rows, cols: cols);
      final s = open();
      await s.opened;
      final sheet = s.model.sheets.single;
      const farRect = GridRect(2900, 0, 2900, 3);

      s.execute(
        SetCellInputs(
          sheetId: sheet.id,
          row: 3,
          col: 2,
          inputs: [
            [CellInput.user('edited')],
          ],
        ),
      );
      expect(
        () => s.execute(
          SetFormat(
            [ResolvedRange(sheet.id, farRect)],
            const {FormatAttr.bold: true},
          ),
        ),
        throwsA(
          isA<PlanException>().having((e) => e.code, 'code', LoadingGate.code),
        ),
      );
      expect(
        () => s.execute(FindReplace(find: 'r1c1', replacement: 'x')),
        throwsA(isA<PlanException>()),
      );

      await s.rowLoading.whenComplete;
      await s.flush();

      expect(s.model.cellAt(sheet.id, 3, 2)?.content, 's:edited');
      expect(s.model.cellAt(sheet.id, 2900, 3)?.content, 's:r2900c3');
      expect(canonical(s.model), canonical(await reloadModel(replica, space)));
      s.execute(
        SetFormat(
          [ResolvedRange(sheet.id, farRect)],
          const {FormatAttr.bold: true},
        ),
      );
      expect(s.model.cellAt(sheet.id, 2900, 3)?.content, 's:r2900c3');
    },
  );

  test('Given a spreadsheet streaming in, when the grid asks for far rows '
      'then they load before the rows in between', () async {
    await writeFixture(replica, rows: rows, cols: cols);
    final s = open();
    await s.opened;
    final sheet = s.model.sheets.single;
    final far = sheet.rows.idAt(2500);
    final between = sheet.rows.idAt(1500);
    bool? betweenWhenFar;
    void check() {
      if (betweenWhenFar == null && s.rowLoading.isRowLoaded(sheet.id, far)) {
        betweenWhenFar = s.rowLoading.isRowLoaded(sheet.id, between);
      }
    }

    s.rowLoading.addListener(check);
    s.rowLoading.prioritize(sheet.id, 2500, 2540);
    await s.rowLoading.whenComplete;
    s.rowLoading.removeListener(check);

    expect(betweenWhenFar, isFalse);
  });

  test('Given a restored view state, when opened, then the hinted window is '
      'loaded at ready', () async {
    await writeFixture(replica, rows: rows, cols: cols);
    final probe = await reloadModel(replica, space);
    final sheetId = probe.sheets.single.id;
    final s = open(viewport: ViewportHint(sheetId: sheetId, topRow: 2000));
    await s.opened;

    final sheet = s.model.sheets.single;
    expect(s.model.cellAt(sheet.id, 2100, 1)?.content, 's:r2100c1');
    expect(s.rowLoading.isRowLoaded(sheet.id, sheet.rows.idAt(1000)), isFalse);
    await s.rowLoading.whenComplete;
  });

  test('Given a remote change to a row still loading, when it is ingested '
      'then streaming does not overwrite it', () async {
    await writeFixture(replica, rows: rows, cols: cols);
    final s = open();
    await s.opened;
    final sheet = s.model.sheets.single;
    final m = await reloadModel(replica, space);
    final plan = const SheetsMutationPlanner().plan(
      SetCellInputs(
        sheetId: sheet.id,
        row: 2990,
        col: 1,
        inputs: [
          [CellInput.user('remote')],
        ],
      ),
      m,
      PlanContext(userId: testUser.uuid, now: DateTime.utc(2026, 10, 2)),
    );
    await SheetsWriter(replica).write(
      spaceId: space,
      changes: plan.changes,
      label: 'Remote',
      actorKind: 'user',
      sessionId: 'remote',
    );
    await s.ingestRemote();
    await s.rowLoading.whenComplete;
    await s.ingestRemote();

    expect(s.model.cellAt(sheet.id, 2990, 1)?.content, 's:remote');
    expect(canonical(s.model), canonical(await reloadModel(replica, space)));
  });
}
