import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets/features/data_tools/data_tools.dart';
import 'package:wonky_sheets_core/model.dart';

import '../support/sheets_harness.dart';

/// Status/Amount table in A1:B6 (header row 1).
Future<void> seedTable(SheetsHarness s) async {
  const rows = [
    ['Status', 'Amount'],
    ['Open', '10'],
    ['Closed', '200'],
    ['Open', '30'],
    ['Closed', '5'],
    ['Open', '150'],
  ];
  for (var r = 0; r < rows.length; r++) {
    await s.type('A${r + 1}', rows[r][0]);
    await s.type('B${r + 1}', rows[r][1]);
  }
}

bool hidden(SheetsHarness s, int row) => s.sheet.rows.isHidden(row);

void main() {
  late SheetsHarness s;
  late DataTools tools;

  setUp(() async {
    s = SheetsHarness.open();
    tools = DataTools.of(s.editor);
    await seedTable(s);
  });
  tearDown(() => s.dispose());

  String colId(int c) => s.sheet.columns.idAt(c);

  Future<void> hideValues(int col, List<String> values) =>
      s.run('sheets.filter.setColumnCriteria', {
        'colId': colId(col),
        'criteria': {'hiddenValues': values},
      });

  group('Given a table and a single active cell inside it', () {
    setUp(() => s.select('A3'));

    test('when toggling the filter then the data region becomes the basic '
        'filter range in one step', () async {
      final before = s.h.undoLabels.length;

      await s.run('sheets.filter.toggle');

      expect(tools.filters.basicFilter(s.sheetId)!.range.a1, 'A1:B6');
      expect(s.h.undoLabels.length, before + 1);
    });

    test('when toggling twice then the filter is removed, and undo restores '
        'it', () async {
      await s.run('sheets.filter.toggle');
      await s.run('sheets.filter.toggle');
      expect(s.sheet.basicFilter, isNull);

      await s.undo();

      expect(s.sheet.basicFilter, isNotNull);
    });
  });

  group('Given a basic filter on the table', () {
    setUp(() async {
      await s.select('A1');
      await s.run('sheets.filter.toggle');
    });

    test('when hiding the value Closed then its rows are hidden on the '
        'filter layer and the header stays visible', () async {
      await hideValues(0, ['Closed']);

      expect(
        [for (var r = 0; r < 6; r++) hidden(s, r)],
        [false, false, true, false, true, false],
      );
      expect(s.sheet.rows.isHiddenBy(HiddenLayers.filter, 2), isTrue);
    });

    test(
      'when combining values and a condition then rows must pass both',
      () async {
        await hideValues(0, ['Closed']);
        await s.run('sheets.filter.setColumnCriteria', {
          'colId': colId(1),
          'criteria': {
            'condition': {
              'type': 'numberGreater',
              'values': [
                {'v': '100'},
              ],
            },
          },
        });

        expect(
          [for (var r = 1; r < 6; r++) hidden(s, r)],
          [true, true, true, true, false],
        );
      },
    );

    test(
      'when SUBTOTAL sums the column then filtered rows are ignored',
      () async {
        await s.type('D1', '=SUBTOTAL(9,B2:B6)');
        expect(s.text('D1'), '395');

        await hideValues(0, ['Closed']);
        s.editor.engine.settle();

        expect(s.text('D1'), '190');
      },
    );

    test('when undoing a criterion then the rows reappear', () async {
      await hideValues(0, ['Open']);
      expect(hidden(s, 1), isTrue);

      await s.undo();

      expect(hidden(s, 1), isFalse);
    });

    test('when another row is edited so it no longer matches then it hides '
        '(live re-filtering)', () async {
      await hideValues(0, ['Closed']);
      await s.select('C1');

      await s.type('A4', 'Closed');

      expect(hidden(s, 3), isTrue);
    });

    test('when clearing all filters then every row is visible again', () async {
      await hideValues(0, ['Open']);

      await s.run('sheets.filter.clearAll');

      expect([for (var r = 0; r < 6; r++) hidden(s, r)], everyElement(false));
    });

    test('when sorting from the filter menu then the data rows are sorted '
        'under the header with the indicator stored, in one step', () async {
      final before = s.h.undoLabels.length;

      await s.run('sheets.filter.sortColumn', {
        'colId': colId(1),
        'ascending': true,
      });

      expect(
        [for (var r = 2; r <= 6; r++) s.text('B$r')],
        ['5', '10', '30', '150', '200'],
      );
      expect(s.text('A1'), 'Status');
      expect(tools.filters.basicFilter(s.sheetId)!.sort, [(colId(1), true)]);
      expect(s.h.undoLabels.length, before + 1);
    });

    test('when filtering by the active cell value then only rows with that '
        'value stay visible', () async {
      await s.select('A3');

      await s.run('sheets.filter.byCellValue');

      expect(
        [for (var r = 1; r < 6; r++) hidden(s, r)],
        [true, false, true, false, true],
      );
    });

    test('when copying across filtered rows then only visible rows are '
        'copied', () async {
      await hideValues(0, ['Closed']);
      await s.select('A1:A6');

      await s.run('sheets.edit.copy');

      final text = s.clip.data?.plainText ?? '';
      expect(text, isNot(contains('Closed')));
      expect(text, contains('Open'));
    });

    test('when saving as a filter view then the view is active and replaces '
        'the basic filter in this grid', () async {
      await hideValues(0, ['Closed']);

      final r = await s.run('sheets.filter.saveAsFilterView');

      final id = (r.data! as Map)['viewId'] as String;
      expect(tools.filters.activeViewId(s.sheetId), id);
      expect(s.sheet.rows.isHiddenBy(HiddenLayers.filterView, 2), isTrue);
      // The basic filter keeps feeding formulas (SUBTOTAL) but is
      // suppressed on screen while the view is shown (07 §4.3).
      expect(s.sheet.rows.isHiddenBy(HiddenLayers.filter, 2), isTrue);
      expect(s.sheet.rows.isLayerSuppressed(HiddenLayers.filter), isTrue);

      await s.run('sheets.filterView.activate', {'viewId': null});

      expect(s.sheet.rows.isLayerSuppressed(HiddenLayers.filter), isFalse);
      expect(s.sheet.rows.isHidden(2), isTrue);
    });

    test('when a value is typed in the row below the table then the row '
        'joins the open-ended filter', () async {
      await hideValues(0, ['Closed']);
      expect(tools.filters.basicOpenEnded(s.sheetId), isTrue);

      await s.type('A7', 'Closed');
      await s.select('A1');

      expect(tools.filters.basicFilter(s.sheetId)!.range.a1, 'A1:B7');
      expect(s.sheet.rows.isHidden(6), isTrue);
    });
  });

  group('Given filter views', () {
    setUp(() => s.select('A1'));

    test('when an editor creates a view then it is saved as Filter 1 and '
        'active; closing it shows all rows', () async {
      await s.run('sheets.filterView.create');
      final id = tools.filters.activeViewId(s.sheetId)!;
      expect(s.sheet.filterViews[id]?.name, 'Filter 1');

      await s.run('sheets.filterView.setColumnCriteria', {
        'viewId': id,
        'colId': colId(0),
        'criteria': {
          'hiddenValues': ['Open'],
        },
      });
      expect(hidden(s, 1), isTrue);

      await s.run('sheets.filterView.activate', {'viewId': null});
      expect(hidden(s, 1), isFalse);
    });

    test(
      'when renaming and deleting a saved view then undo restores it',
      () async {
        await s.run('sheets.filterView.create');
        final id = tools.filters.activeViewId(s.sheetId)!;

        await s.run('sheets.filterView.rename', {'viewId': id, 'name': 'Open'});
        await s.run('sheets.filterView.delete', {'viewId': id});
        expect(s.sheet.filterViews, isEmpty);
        expect(tools.filters.activeViewId(s.sheetId), isNull);

        await s.undo();

        expect(s.sheet.filterViews[id]?.name, 'Open');
      },
    );

    test('when a temporary view filters then nothing is saved and no undo '
        'step is added', () async {
      final before = s.h.undoLabels.length;

      await s.run('sheets.filterView.create', {'temporary': true});
      final id = tools.filters.activeViewId(s.sheetId)!;
      await s.run('sheets.filterView.setColumnCriteria', {
        'viewId': id,
        'colId': colId(0),
        'criteria': {
          'hiddenValues': ['Open'],
        },
      });

      expect(id, startsWith('temp:'));
      expect(hidden(s, 1), isTrue);
      expect(s.sheet.filterViews, isEmpty);
      expect(s.h.undoLabels.length, before);
    });
  });

  group('Given a viewer', () {
    late SheetsHarness v;
    setUp(() => v = SheetsHarness.open(role: Role.viewer));
    tearDown(() => v.dispose());

    test('when creating a filter view then it is temporary', () async {
      await v.run('sheets.filterView.create');

      final id = DataTools.of(v.editor).filters.activeViewId(v.sheetId);
      expect(id, startsWith('temp:'));
    });
  });
}
