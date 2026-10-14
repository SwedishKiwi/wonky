import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_client/wonky_client.dart'
    show
        ItemVersionView,
        UuidValue,
        VersionKind,
        VersionRestoreResult,
        VersionStorage;
import 'package:wonky_sheets/features/history/server_change_undo.dart';
import 'package:wonky_sheets/features/history/sheets_version_view.dart';
import 'package:wonky_sheets/features/history/version_snapshots.dart';
import 'package:wonky_sheets/features/model/memory_workbook_session.dart';
import 'package:wonky_sheets_core/model.dart' hide ActorKind;

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

ItemVersionView version(int id) => ItemVersionView(
  id: id,
  itemUuid: UuidValue.fromString(testItemUuid),
  kind: VersionKind.auto,
  createdAt: DateTime.utc(2026, 10, id),
  authors: [TestUsers.anna],
  storageKind: VersionStorage.snapshotFile,
  sizeBytes: 100,
);

void main() {
  group('Given two versions of a spreadsheet', () {
    late SheetsHarness s;
    late List<int> v1;
    late List<int> v2;

    setUp(() {
      s = SheetsHarness.open();
      final session = MemoryWorkbookSession.blank(
        itemUuid: UuidValue.fromString(testItemUuid),
      );
      final sheetId = session.model.sheets.first.id;
      SheetsOperation set(int row, int col, String text) => SetCellInputs(
        sheetId: sheetId,
        row: row,
        col: col,
        inputs: [
          [CellInput.user(text)],
        ],
      );
      session.execute(set(0, 0, 'Region'));
      session.execute(set(1, 1, '10'));
      v1 = SnapshotCodec.encodeModel(
        session.model,
        capturedAt: DateTime.utc(2026, 10, 1),
      );
      session.execute(set(1, 1, '20'));
      session.execute(set(3, 2, 'New'));
      v2 = SnapshotCodec.encodeModel(
        session.model,
        capturedAt: DateTime.utc(2026, 10, 2),
      );
      VersionSnapshots.clear();
      VersionSnapshots.fetch = (item, id) async => id == 1 ? v1 : v2;
      addTearDown(() {
        VersionSnapshots.fetch = null;
        VersionSnapshots.clear();
      });
    });
    tearDown(() => s.dispose());

    test('when decoded then the snapshot rows build the model', () {
      final rows = VersionSnapshots.decode(v2);
      final model = WorkbookModel.fromRows(
        rows.firstWhere((r) => r.$1 == SheetsTables.spreadsheet).$2['id']
            as String,
        rows,
      );
      final sheet = model.sheets.first;
      expect(sheet.cellAt(3, 2)?.content, 's:New');
    });

    testWidgets('when the newer version is shown then the grid is read-only, '
        'changed cells are listed and next change selects them', (
      tester,
    ) async {
      await pumpSheets(
        tester,
        s,
        child: SheetsVersionView(
          services: s.services,
          itemUuid: UuidValue.fromString(testItemUuid),
          version: version(2),
          previous: version(1),
          showChanges: true,
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      await tester.pump();

      final state = tester.state<SheetsVersionViewState>(
        find.byType(SheetsVersionView),
      );
      expect(state.editor, isNotNull);
      expect(state.editor!.canEdit, isFalse);
      expect(state.changes, hasLength(2));
      expect(find.text('2 cells changed'), findsOneWidget);

      state.step(forward: true);
      await tester.pump();
      expect(state.editor!.activeA1, 'B2');
      state.step(forward: true);
      expect(state.editor!.activeA1, 'C4');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    test('when a restore result carries a change id then the undo entry is a '
        'server change', () {
      final e = SheetsVersionRenderer().restoreUndoEntry(
        UuidValue.fromString(testItemUuid),
        1,
        VersionRestoreResult(
          restorePoint: version(3),
          changeId: UuidValue.fromString(
            '00000000-0000-7000-8000-000000000009',
          ),
        ),
      );
      expect(e, isA<SheetsServerChangeEntry>());
    });
  });
}
