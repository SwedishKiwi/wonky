import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets/features/pivot/pivot_controller.dart';
import 'package:wonky_sheets_core/model.dart';

import '../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;
  late String dataSheet;

  String col(int i) => s.model.sheet(dataSheet)!.columns.idAt(i);

  Future<String> insertPivot() async {
    final r = await s.run('sheets.insert.pivotTable', {
      'range': 'Sheet1!A1:C6',
    });
    expect(r.status, CommandStatus.ok, reason: r.message);
    return (r.data! as Map)['pivotId'] as String;
  }

  Future<CommandResult> update(String id, Map<String, Object?> spec) =>
      s.run('sheets.pivot.update', {'pivotId': id, 'spec': spec});

  Map<String, Object?> revenueByRegion() => {
    'rows': [
      {'source': col(0)},
    ],
    'values': [
      {'source': col(2), 'summarizeBy': 'sum'},
    ],
  };

  PivotController pivots() => PivotController.of(s.editor);

  setUp(() async {
    s = SheetsHarness.open();
    dataSheet = s.sheetId;
    final rows = [
      ['Region', 'Product', 'Revenue'],
      ['East', 'Apples', '10'],
      ['West', 'Apples', '20'],
      ['East', 'Pears', '5'],
      ['West', 'Pears', '7'],
      ['East', 'Plums', '1'],
    ];
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        await s.type('${'ABC'[c]}${r + 1}', rows[r][c]);
      }
    }
  });
  tearDown(() => s.dispose());

  group('Given sales data on Sheet1', () {
    test('when inserting a pivot table then a new sheet "Pivot table 1" is '
        'active with the empty-pivot message, in one undo step', () async {
      final before = s.h.undoLabels.length;

      final id = await insertPivot();

      expect(s.editor.activeSheet!.name, 'Pivot table 1');
      expect(pivots().service.byId(id)?.message, isNotNull);
      expect(pivots().editing.value, id);
      expect(s.h.undoLabels.length, before + 1);
      await s.undo();
      expect(s.model.sheetByName('Pivot table 1'), isNull);
    });

    test('when rows and values are set then the output shows the grouped '
        'sums with a grand total', () async {
      final id = await insertPivot();

      await update(id, revenueByRegion());

      expect(s.text('A1'), 'Region');
      expect(s.text('B1'), 'SUM of Revenue');
      expect(s.text('A2'), 'East');
      expect(s.text('B2'), '16');
      expect(s.text('A3'), 'West');
      expect(s.text('B3'), '27');
      expect(s.text('A4'), 'Grand Total');
      expect(s.text('B4'), '43');
    });

    test(
      'when an editor change is undone then the previous layout returns',
      () async {
        final id = await insertPivot();
        await update(id, revenueByRegion());

        await s.undo();

        expect(s.text('A1'), '');
        expect(pivots().service.byId(id)?.message, isNotNull);
        await s.redo();
        expect(s.text('B4'), '43');
      },
    );

    test('when typing into the output then the write is refused', () async {
      final id = await insertPivot();
      await update(id, revenueByRegion());

      final r = await s.run('sheets.cell.setInput', {
        'a1': 'B2',
        'input': '99',
      });

      expect(r.status, CommandStatus.failed);
      expect(s.text('B2'), '16');
      expect(s.editor.editRefusalAt(1, 1), isNotNull);
    });

    test('when a source value changes then the pivot refreshes', () async {
      final id = await insertPivot();
      await update(id, revenueByRegion());
      final pivotSheet = s.sheetId;
      s.editor.activateSheet(dataSheet);

      await s.type('C2', '100');
      pivots().service.flush();

      s.editor.activateSheet(pivotSheet);
      expect(s.text('B2'), '106');
    });

    test('when a formula uses GETPIVOTDATA then it returns the East total '
        'and follows refreshes', () async {
      final id = await insertPivot();
      await update(id, revenueByRegion());
      s.editor.activateSheet(dataSheet);

      await s.type(
        'E1',
        "=GETPIVOTDATA(\"SUM of Revenue\", 'Pivot table 1'!A1, \"Region\", "
            '"East")',
      );
      await s.type('E2', "=SUM('Pivot table 1'!B2:B3)");
      expect(s.text('E1'), '16');
      expect(s.text('E2'), '43');

      await s.type('C4', '50');
      pivots().service.flush();

      expect(s.text('E1'), '61');
      expect(s.text('E2'), '88');
    });

    test('when data blocks the output then the anchor shows #REF! until the '
        'data is removed', () async {
      final id = await insertPivot();
      await s.type('A3', 'x');

      await update(id, revenueByRegion());

      expect(s.text('A1'), '#REF!');
      expect(pivots().service.byId(id)?.problem, isNotNull);
      await s.select('A3');
      await s.run('sheets.edit.clearValues');
      expect(s.text('A1'), 'Region');
    });

    test('when the whole output is cleared then the pivot is deleted in one '
        'step', () async {
      final id = await insertPivot();
      await update(id, revenueByRegion());
      await s.select('A1:B4');

      await s.run('sheets.edit.clearValues');

      expect(pivots().service.byId(id), isNull);
      expect(s.text('A1'), '');
      await s.undo();
      expect(s.text('B4'), '43');
    });

    test(
      'when deleting the pivot by command then the output disappears',
      () async {
        final id = await insertPivot();
        await update(id, revenueByRegion());

        await s.run('sheets.pivot.delete', {'pivotId': id});

        expect(s.text('A2'), '');
      },
    );

    test('when drilling down on a value then a Details sheet lists the '
        'contributing source rows', () async {
      final id = await insertPivot();
      await update(id, revenueByRegion());

      final r = await s.run('sheets.pivot.drillDown', {
        'pivotId': id,
        'cell': 'B2',
      });

      expect(r.status, CommandStatus.ok, reason: r.message);
      expect(s.editor.activeSheet!.name, 'Details 1');
      expect(s.services.panels.isOpen(PivotController.panelId), isFalse);
      expect(pivots().editing.value, isNull);
      expect(s.text('A1'), 'Region');
      expect(s.text('A4'), 'East');
      expect(s.text('C4'), '1');
      expect(s.text('A5'), '');
    });

    test(
      'when copying pivot output then the clipboard holds its values',
      () async {
        final id = await insertPivot();
        await update(id, revenueByRegion());
        await s.select('A2:B3');

        await s.run('sheets.edit.copy');

        expect(s.clip.data?.plainText, 'East\t16\nWest\t27');
      },
    );

    test('when creating a manual group on a Rows field then the output '
        'groups its items', () async {
      final id = await insertPivot();
      await update(id, revenueByRegion());

      final r = await s.run('sheets.pivot.createGroup', {
        'pivotId': id,
        'field': 'Region',
        'group': {
          'kind': 'manual',
          'groups': [
            {
              'name': 'All',
              'items': ['East', 'West'],
            },
          ],
        },
      });

      expect(r.status, CommandStatus.ok, reason: r.message);
      expect(s.text('A2'), 'All');
      expect(s.text('B2'), '43');
    });
  });

  group('Given a pivot with Region rows', () {
    test('when its output is copied and pasted elsewhere then values are '
        'pasted', () async {
      final id = await insertPivot();
      await update(id, revenueByRegion());
      await s.select('A2:B3');
      await s.run('sheets.edit.copy');
      s.editor.activateSheet(dataSheet);
      await s.select('E1');

      await s.run('sheets.edit.paste');

      expect(s.content('E1'), 's:East');
      expect(s.content('F1'), 'n:16');
    });

    test('when a filter hides West then only East remains', () async {
      final id = await insertPivot();
      final spec = revenueByRegion()
        ..['filters'] = [
          {
            'source': col(0),
            'criteria': {
              'hiddenValues': ['West'],
            },
          },
        ];

      await update(id, spec);

      expect(s.text('A2'), 'East');
      expect(s.text('A3'), 'Grand Total');
      expect(s.text('B3'), '16');
    });

    test(
      'when a calculated field doubles Revenue then its sums show',
      () async {
        final id = await insertPivot();
        final spec = revenueByRegion()
          ..['values'] = [
            {
              'formula': '=${PivotFormula.tokenOf(col(2))}*2',
              'summarizeBy': 'sum',
              'name': 'Double',
            },
          ];

        await update(id, spec);

        expect(s.text('B1'), 'Double');
        expect(s.text('B2'), '32');
      },
    );

    test(
      'when values show as % of grand total then they are percentages',
      () async {
        final id = await insertPivot();
        final spec = revenueByRegion();
        (spec['values']! as List)[0] = {
          'source': col(2),
          'summarizeBy': 'sum',
          'showAs': 'percentOfGrandTotal',
        };

        await update(id, spec);

        expect(s.text('B4'), '100.00%');
      },
    );
  });

  group('Given a pivot output on its own sheet', () {
    test('when the whole output is cut and pasted on another sheet then the '
        'pivot moves there in one step, and undo brings it back', () async {
      final id = await insertPivot();
      await update(id, revenueByRegion());
      final pivotSheet = s.sheetId;
      await s.select('A1:B4');
      await s.run('sheets.edit.cut');
      s.editor.activateSheet(dataSheet);
      await s.select('E2');
      final before = s.h.undoLabels.length;

      final r = await s.run('sheets.edit.paste');

      expect(r.status, CommandStatus.ok, reason: r.message);
      expect(s.h.undoLabels.length, before + 1);
      expect(pivots().service.byId(id), isNull);
      final moved = pivots().service.outputsOf(dataSheet).single;
      expect(moved.anchorRow, 1);
      expect(moved.anchorCol, 4);
      expect(s.text('E3'), 'East');
      expect(s.text('F5'), '43');
      expect(pivots().service.outputsOf(pivotSheet), isEmpty);

      await s.undo();
      expect(pivots().service.byId(id)?.sheetId, pivotSheet);
      expect(pivots().service.outputsOf(dataSheet), isEmpty);
    });

    test('when the whole output is cut and pasted on the same sheet then the '
        'anchor moves', () async {
      final id = await insertPivot();
      await update(id, revenueByRegion());
      await s.select('A1:B4');
      await s.run('sheets.edit.cut');
      await s.select('D3');

      await s.run('sheets.edit.paste');

      final o = pivots().service.byId(id)!;
      expect((o.anchorRow, o.anchorCol), (2, 3));
      expect(s.text('D4'), 'East');
    });

    test('when row labels are selected then they become a named manual '
        'group in one step', () async {
      final id = await insertPivot();
      await update(id, revenueByRegion());
      await s.select('A2:A3');
      expect(
        s.services.dispatcher.stateOf('sheets.pivot.groupSelection').enabled,
        isTrue,
      );

      final r = await s.run('sheets.pivot.groupSelection', {'name': 'Coast'});

      expect(r.status, CommandStatus.ok, reason: r.message);
      expect(s.text('A2'), 'Coast');
      expect(s.text('B2'), '43');
      final g = PivotSpec.parse(
        pivots().service.byId(id)!.record.specJson,
      ).rows.single.group;
      expect(g, isA<PivotManualGrouping>());
      await s.undo();
      expect(s.text('A2'), 'East');
    });

    test(
      'when a value cell is selected then grouping is not offered',
      () async {
        final id = await insertPivot();
        await update(id, revenueByRegion());
        await s.select('B2');

        expect(
          s.services.dispatcher.stateOf('sheets.pivot.groupSelection').enabled,
          isFalse,
        );
        expect(pivots().service.byId(id), isNotNull);
      },
    );
  });

  group('Given a viewer', () {
    test(
      'when the spreadsheet is view-only then inserting is disabled',
      () async {
        final v = SheetsHarness.open(role: Role.viewer);
        addTearDown(v.dispose);
        final st = v.services.dispatcher.stateOf('sheets.insert.pivotTable');
        expect(st.enabled, isFalse);
      },
    );
  });
}
