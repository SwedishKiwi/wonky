import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/grid/selection/data_edge_finder.dart';
import 'package:wonky_sheets/features/grid/selection/grid_selection.dart';
import 'package:wonky_sheets/features/sheet_editor/sheet_editor_controller.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;
  SheetEditorController ed() => s.editor;

  setUp(() => s = SheetsHarness.open());
  tearDown(() => s.dispose());

  group('Given a selection of B2:C3', () {
    setUp(() => s.select('B2:C3'));

    test('when rows are inserted above remotely then the selection keeps '
        'covering the same data (id-based)', () {
      s.session.execute(InsertDimension(s.sheetId, Dimension.rows, 0, 3));
      ed().selection.modelChanged();

      expect(ed().selection.describe(), 'B5:C6');
    });

    test(
      'when extending with Shift+↓ then the range grows from the anchor',
      () {
        ed().moveActive(NavDirection.down, extend: true);
        expect(ed().selection.describe(), 'B2:C4');
      },
    );

    test('when snapshotting and restoring then the selection is equal', () {
      final snap = ed().captureSelection();
      s.select('E5');

      ed().restoreSelection(snap);

      expect(ed().selection.describe(), 'B2:C3');
    });
  });

  group('Given a merge B2:C3', () {
    setUp(() async {
      await s.select('B2:C3');
      await s.run('sheets.format.merge', {'mode': 'all'});
    });

    test('when clicking inside the merge then the whole merge is selected', () {
      ed().selection.selectCell(2, 2);
      expect(
        ed().selection.resolved.activeRange.rect,
        const GridRect(1, 1, 2, 2),
      );
      expect(ed().activeA1, 'B2');
    });

    test(
      'when moving down from the merge then the active cell steps over it',
      () {
        ed().selection.selectCell(1, 1);
        ed().moveActive(NavDirection.down);
        expect(ed().activeA1, 'B4');
      },
    );
  });

  group('Given data in A1:B3', () {
    setUp(() async {
      for (final a1 in ['A1', 'A2', 'A3', 'B1', 'B2', 'B3']) {
        await s.type(a1, '1');
      }
      await s.select('A2');
    });

    test(
      'when pressing Mod+A then the data region is selected, then all',
      () async {
        await s.run('sheets.select.all');
        expect(ed().selection.describe(), 'A1:B3');

        await s.run('sheets.select.all');
        expect(ed().selection.resolved.activeRange.kind, SelectionKind.all);
      },
    );

    test('when going to Sheet1!B2 by name then it is selected', () async {
      final r = await s.run('sheets.nav.goTo', {'target': 'B2'});
      expect(r.isOk, isTrue);
      expect(ed().activeA1, 'B2');
    });

    test('when going to an invalid range then it fails', () async {
      final r = await s.run('sheets.nav.goTo', {'target': 'not a range!'});
      expect(r.isOk, isFalse);
    });
  });

  group('Given several sheets', () {
    test('when switching sheets then each keeps its selection', () async {
      await s.select('C3');
      final first = s.sheetId;
      await s.run('sheets.sheet.add');
      await s.select('D4');

      ed().activateSheet(first);

      expect(ed().activeA1, 'C3');
    });
  });
}
