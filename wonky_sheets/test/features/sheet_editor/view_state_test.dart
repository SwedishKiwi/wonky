import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart' show MemoryStore;
import 'package:wonky_sheets/features/data_tools/data_tools.dart';
import 'package:wonky_sheets/features/grid/selection/grid_selection.dart';
import 'package:wonky_sheets/features/model/local_view_state.dart';
import 'package:wonky_sheets/features/sheet_editor/sheet_editor_controller.dart';
import 'package:wonky_sheets/features/sheet_editor/view_state_binding.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../../support/sheets_harness.dart';

void main() {
  group('LocalViewState', () {
    test('Given a view state, when it is stored and read back, then every '
        'field survives', () async {
      final store = LocalViewStateStore(MemoryStore());
      final state = LocalViewState(
        savedAt: DateTime.utc(2026, 10, 14, 9),
        activeSheetId: 's2',
        selections: const {
          's2': {'sheet': 's2'},
        },
        scrollX: 120,
        scrollY: 3400,
        topRow: 160,
        zoom: 1.25,
        panelId: 'sheets.panel.cf',
        temporaryViews: const [
          SavedTemporaryView(
            sheetId: 's2',
            name: 'Mine',
            rangeJson: {'s': 's2'},
            criteriaJson: {},
            active: true,
          ),
        ],
      );

      await store.write('book', state);
      final fresh = LocalViewStateStore(MemoryStore());
      expect(await fresh.read('book'), isNull);
      final back = LocalViewState.fromJson(state.toJson())!;

      expect(back.activeSheetId, 's2');
      expect(back.scrollY, 3400);
      expect(back.topRow, 160);
      expect(back.zoom, 1.25);
      expect(back.panelId, 'sheets.panel.cf');
      expect(back.temporaryViews.single.active, isTrue);
      expect((await store.read('book'))?.topRow, 160);
      expect((await store.lastOpened()).keys, ['book']);
    });

    test('Given more than the kept number of spreadsheets, when writing, '
        'then the oldest are dropped', () async {
      final mem = MemoryStore();
      final store = LocalViewStateStore(mem);
      for (var i = 0; i < LocalViewStateStore.maxEntries + 5; i++) {
        await mem.write(
          '${LocalViewStateStore.prefix}old$i',
          LocalViewState(savedAt: DateTime.utc(2020, 1, 1, 0, i)).toJson(),
        );
      }

      await store.write('new', LocalViewState(savedAt: DateTime.utc(2026)));
      await Future<void>.delayed(Duration.zero);
      await pumpEventQueue();

      final keys = await mem.keys(LocalViewStateStore.prefix);
      expect(keys, hasLength(LocalViewStateStore.maxEntries));
      expect(keys, contains('${LocalViewStateStore.prefix}new'));
      expect(keys, isNot(contains('${LocalViewStateStore.prefix}old0')));
    });
  });

  group('ViewStateBinding', () {
    testWidgets('Given a spreadsheet left on a second sheet with a selection, '
        'zoom, scroll and a temporary filter view, when it is opened again '
        'then all of it is restored', (tester) async {
      final s = SheetsHarness.open();
      final store = LocalViewStateStore(MemoryStore());
      s.session.execute(const AddSheet(name: 'Data'));
      final data = s.model.sheets.firstWhere((x) => x.name == 'Data');

      final first = ViewStateBinding.attach(s.editor, store);
      s.editor.activateSheet(data.id);
      s.editor.selection.setRanges([
        (SelectionKind.cells, const GridRect(4, 2, 6, 3)),
      ]);
      s.editor.setZoom(1.5);
      s.editor.scroll.jumpTo(80, 400);
      DataTools.of(s.editor).filters.createTemporary(
        data.id,
        GridRange(
          sheetId: data.id,
          r1: data.rows.idAt(0),
          r2: data.rows.idAt(9),
          c1: data.columns.idAt(0),
          c2: data.columns.idAt(2),
        ),
        name: 'Just mine',
      );
      await first.save();
      await tester.pump();

      final again = SheetEditorController(
        services: s.services,
        session: s.session,
      );
      ViewStateBinding.attach(again, store);
      tester.binding.scheduleFrame();
      await tester.pump();

      expect(again.activeSheetId, data.id);
      final sel = again.selection.resolved;
      expect(sel.ranges.single.rect, const GridRect(4, 2, 6, 3));
      expect(again.scroll.zoom, 1.5);
      expect(again.scroll.y, 400);
      final filters = DataTools.of(again).filters;
      expect(filters.temporaryViews.single.name, 'Just mine');
      expect(filters.activeViewId(data.id), filters.temporaryViews.single.id);
      again.dispose();
      await s.dispose();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Given a route that names a sheet, when the view state is '
        'restored then the route sheet stays active', (tester) async {
      final s = SheetsHarness.open();
      final store = LocalViewStateStore(MemoryStore());
      s.session.execute(const AddSheet(name: 'Data'));
      final data = s.model.sheets.firstWhere((x) => x.name == 'Data');
      final first = ViewStateBinding.attach(s.editor, store);
      s.editor.activateSheet(data.id);
      await first.save();

      final again = SheetEditorController(
        services: s.services,
        session: s.session,
      );
      ViewStateBinding.attach(again, store, restoreSheet: false);
      await tester.pump();

      expect(again.activeSheetId, isNot(data.id));
      again.dispose();
      await s.dispose();
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
