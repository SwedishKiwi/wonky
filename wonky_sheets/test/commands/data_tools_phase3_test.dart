import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/data_tools/cleanup_suggestions.dart';
import 'package:wonky_sheets/features/data_tools/cleanup_suggestions_panel.dart';
import 'package:wonky_sheets/features/data_tools/data_tools.dart';
import 'package:wonky_sheets/features/named_ranges/import_named_functions_dialog.dart';
import 'package:wonky_sheets/features/slicers/slicer_controller.dart';
import 'package:wonky_sheets/features/slicers/slicer_spec.dart';
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

  group('Given a basic filter', () {
    setUp(() async {
      await s.select('A1');
      await s.run('sheets.filter.toggle');
    });

    test('when sorting by fill color then rows with that fill come first, '
        'in one step', () async {
      await s.select('A5');
      await s.run('sheets.format.fillColor', {'color': '#FFFF00'});
      final before = s.h.undoLabels.length;

      await s.run('sheets.filter.sortColumn', {
        'colId': colId(0),
        'fillColor': '#FFFF00',
      });

      expect(s.text('A2'), 'Closed');
      expect(s.text('B2'), '5');
      expect(s.text('A1'), 'Status');
      expect(s.h.undoLabels.length, before + 1);
    });

    test('when an edited row no longer matches then it stays visible, '
        'marked as the sticky row, until the selection leaves it', () async {
      await s.run('sheets.filter.setColumnCriteria', {
        'colId': colId(0),
        'criteria': {
          'hiddenValues': ['Closed'],
        },
      });
      await s.select('A2');
      await s.run('sheets.cell.setInput', {'input': 'Closed'});

      expect(s.sheet.rows.isHidden(1), isFalse);
      expect(tools.filters.stickyHiddenRow(s.sheetId), 1);

      await s.select('A6');
      await Future<void>.delayed(Duration.zero);
      expect(tools.filters.stickyHiddenRow(s.sheetId), isNull);
      expect(s.sheet.rows.isHidden(1), isTrue);
    });
  });

  test('Given row 1 looks like a header and no frozen rows when sorting the '
      'sheet then a header is suggested, and freezeHeader keeps it on top '
      'in one step', () async {
    await s.select('B3');
    final r = await s.run('sheets.data.sortSheet', {'ascending': true});
    expect((r.data! as Map)['headerSuggested'], isTrue);
    await s.undo();
    final before = s.h.undoLabels.length;

    await s.run('sheets.data.sortSheet', {
      'colId': colId(1),
      'ascending': true,
      'freezeHeader': true,
    });

    expect(s.sheet.record?.frozenRows, 1);
    expect(s.text('A1'), 'Status');
    expect(s.text('B2'), '5');
    expect(s.h.undoLabels.length, before + 1);
  });

  group('Given messy data', () {
    setUp(() async {
      await s.type('C1', 'Code');
      await s.type('C2', "'42");
      await s.type('C3', "'7");
      await s.type('A4', 'open');
      await s.type('A7', 'Open  ');
      await s.type('B7', '1');
      await s.type('A9', 'Closed');
      await s.type('B9', '2');
    });

    List<CleanupSuggestion> suggestions() => cleanupSuggestionsOf(s.editor);

    test('when detecting then numbers as text, spaces, capitalization and '
        'empty rows are suggested', () {
      final kinds = {for (final x in suggestions()) x.kind};
      expect(
        kinds,
        containsAll([
          CleanupKind.numbersAsText,
          CleanupKind.whitespace,
          CleanupKind.capitalization,
          CleanupKind.emptyRows,
        ]),
      );
    });

    test('when applying "numbers as text" then the cells become numbers in '
        'one step, and undo restores the text', () async {
      final sug = suggestions().firstWhere(
        (x) => x.kind == CleanupKind.numbersAsText,
      );
      final before = s.h.undoLabels.length;

      await s.run('sheets.cleanup.applySuggestion', {'id': sug.id});

      expect(s.sheet.cellAt(1, 2)?.decoded, isA<NumberContent>());
      expect(s.h.undoLabels.length, before + 1);
      await s.undo();
      expect(s.sheet.cellAt(1, 2)?.decoded, isA<TextContent>());
    });

    test('when applying "empty rows" then the blank row inside the data is '
        'deleted', () async {
      final sug = suggestions().firstWhere(
        (x) => x.kind == CleanupKind.emptyRows,
      );
      final rows = s.sheet.rows.length;

      await s.run('sheets.cleanup.applySuggestion', {'id': sug.id});

      expect(s.sheet.rows.length, rows - sug.count);
      expect(
        suggestions().where((x) => x.kind == CleanupKind.emptyRows),
        isEmpty,
      );
    });

    test(
      'when dismissing a suggestion then it is hidden on this device',
      () async {
        final sug = suggestions().first;
        tools.dismissedCleanup.add('${s.sheetId}/${sug.id}');
        expect(suggestions().map((x) => x.id), isNot(contains(sug.id)));
      },
    );
  });

  group('Given a slicer on the Status column', () {
    late String id;

    setUp(() async {
      await s.select('A2');
      final r = await s.run('sheets.slicer.add');
      id = (r.data! as Map)['objectId'] as String;
    });

    test('when hiding Closed then those rows hide for everyone, SUBTOTAL '
        'ignores them, in one undo step; undo shows them again', () async {
      await s.type('D1', '=SUBTOTAL(9,B2:B6)');
      final before = s.h.undoLabels.length;

      await s.run('sheets.slicer.setCriteria', {
        'objectId': id,
        'criteria': {
          'hiddenValues': ['Closed'],
        },
      });

      expect(s.sheet.rows.isHiddenBy(HiddenLayers.slicer, 2), isTrue);
      expect(s.sheet.rows.isHidden(2), isTrue);
      expect(s.text('D1'), '190');
      expect(s.h.undoLabels.length, before + 1);
      final spec = SlicerSpec.tryParse(s.sheet.objects[id]!.specJson)!;
      expect(spec.criteria?.hiddenValues, {'Closed'});

      await s.undo();
      expect(s.sheet.rows.isHidden(2), isFalse);
    });

    test('when a viewer changes the slicer then only their screen changes '
        '(formulas and the stored criteria stay)', () async {
      final slicers = SlicerController.of(s.editor);
      slicers.setOverride(id, ColumnCriteria(hiddenValues: ['Open']));

      expect(s.sheet.rows.isHidden(1), isTrue);
      expect(s.sheet.rows.isHiddenBy(HiddenLayers.slicer, 1), isFalse);
      expect(
        SlicerSpec.tryParse(s.sheet.objects[id]!.specJson)!.criteria,
        isNull,
      );

      await s.run('sheets.slicer.reset', {'objectId': id});
      expect(s.sheet.rows.isHidden(1), isFalse);
    });

    test('when the slicer is deleted then its rows reappear', () async {
      await s.run('sheets.slicer.setCriteria', {
        'objectId': id,
        'criteria': {
          'hiddenValues': ['Closed'],
        },
      });
      s.model.applyPlan(
        const SheetsMutationPlanner().plan(
          DeleteObject(id),
          s.model,
          s.session.planContext(),
        ),
      );
      expect(s.sheet.rows.isHidden(2), isFalse);
    });
  });

  group('Given named functions of another spreadsheet', () {
    const fns = [
      ImportableFunction(name: 'TAX', formula: '=LAMBDA(x, x*0.19)'),
      ImportableFunction(name: 'GROSS', formula: '=LAMBDA(x, x+TAX(x))'),
      ImportableFunction(name: 'OTHER', formula: '=LAMBDA(x, x)'),
    ];

    test('when importing GROSS then TAX comes along as a dependency', () {
      expect(ImportableFunction.withDependencies(['GROSS'], fns), {
        'GROSS',
        'TAX',
      });
    });

    test('when parsing the server list then entries without a formula are '
        'skipped', () {
      final list = ImportableFunction.parseList(
        '[{"name":"A","formula":"=LAMBDA(x,x)"},{"name":"B"}]',
      );
      expect(list.map((f) => f.name), ['A']);
    });

    test(
      'when offline (no client) then the import fails with a message',
      () async {
        final r = await s.run('sheets.namedFunctions.import', {
          'sourceItemUuid': '01923456-789a-7bcd-8ef0-123456789abd',
          'names': ['GROSS'],
        });
        expect(r.isOk, isFalse);
      },
    );
  });
}
