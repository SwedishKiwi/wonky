import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/commands/named_commands.dart';
import 'package:wonky_sheets/features/data_tools/data_tools.dart';

import '../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() => s = SheetsHarness.open());
  tearDown(() => s.dispose());

  group('Given a range with duplicate rows', () {
    setUp(() async {
      for (final (i, v) in ['Name', 'a', 'b', 'a', 'c', 'b'].indexed) {
        await s.type('A${i + 1}', v);
      }
    });

    test('when removing duplicates with a header then the first '
        'occurrences remain compacted upward in one step', () async {
      final before = s.h.undoLabels.length;

      final r = await s.run('sheets.cleanup.removeDuplicates', {
        'range': 'A1:A6',
        'hasHeader': true,
      });

      expect(
        [for (var i = 1; i <= 6; i++) s.text('A$i')],
        ['Name', 'a', 'b', 'c', '', ''],
      );
      expect((r.data! as Map)['duplicatesRemoved'], 2);
      expect(s.h.undoLabels.length, before + 1);
    });

    test('when sorting the range with specs and a header then it sorts '
        'descending under the header', () async {
      await s.run('sheets.data.sortRange', {
        'range': 'A1:A6',
        'hasHeader': true,
        'specs': [
          {'colId': s.sheet.columns.idAt(0), 'ascending': false},
        ],
      });

      expect(
        [for (var i = 1; i <= 6; i++) s.text('A$i')],
        ['Name', 'c', 'b', 'b', 'a', 'a'],
      );
    });

    test('when sorting the selected range then the selection stays on the '
        'same cells instead of following the moved rows', () async {
      await s.select('A2:A6');

      await s.run('sheets.data.sortRange', {
        'colId': s.sheet.columns.idAt(0),
        'ascending': false,
      });

      expect(s.text('A2'), 'c');
      expect(s.editor.selection.describe(), 'A2:A6');
    });

    test('when randomizing the selected range then the selection stays on '
        'the same cells', () async {
      await s.select('A2:A6');

      await s.run('sheets.data.randomizeRange');

      expect(s.editor.selection.describe(), 'A2:A6');
    });
  });

  group('Given delimited text in a column', () {
    setUp(() async {
      await s.type('A1', '"Doe, John",42');
      await s.type('A2', 'Roe,7');
    });

    test('when splitting with detection then parts go to the right and the '
        'separator chip appears', () async {
      await s.select('A1:A2');

      await s.run('sheets.data.splitTextToColumns');

      expect(s.text('A1'), 'Doe, John');
      expect(s.text('B1'), '42');
      expect(s.text('B2'), '7');
      expect(DataTools.of(s.editor).splitChip.value?.detected, ',');
    });

    test(
      'when data to the right exists then a forced split replaces it',
      () async {
        await s.type('B1', 'x');

        await s.run('sheets.data.splitTextToColumns', {
          'range': 'A1:A2',
          'force': true,
        });

        expect(s.text('B1'), '42');
      },
    );
  });

  group('Given named ranges', () {
    test('when adding Sales then =SUM(Sales) works, and renaming rewrites '
        'the formula in one step', () async {
      await s.type('B2', '1');
      await s.type('B3', '2');
      await s.run('sheets.namedRanges.add', {
        'name': 'Sales',
        'range': 'B2:B3',
      });
      await s.type('C1', '=SUM(Sales)');
      expect(s.text('C1'), '3');

      final id = namedRangesOf(s.model).single.id;
      await s.run('sheets.namedRanges.update', {'id': id, 'name': 'Revenue'});

      expect(s.editor.editableText(0, 2), '=SUM(Revenue)');
      expect(s.text('C1'), '3');
    });

    test('when a name looks like a cell then it is refused', () async {
      final r = await s.run('sheets.namedRanges.add', {
        'name': 'TAX2024',
        'range': 'A1',
      });

      expect(r.isOk, isFalse);
      expect(namedRangesOf(s.model), isEmpty);
    });

    test('when deleting a named range then undo restores it', () async {
      await s.run('sheets.namedRanges.add', {'name': 'X', 'range': 'A1'});
      final id = namedRangesOf(s.model).single.id;

      await s.run('sheets.namedRanges.delete', {'id': id});
      expect(namedRangesOf(s.model), isEmpty);

      await s.undo();
      expect(namedRangesOf(s.model).single.name, 'X');
    });
  });

  group('Given named functions', () {
    test('when creating GROSS(price, rate) then =GROSS(100, 0.19) returns '
        '119', () async {
      await s.run('sheets.namedFunctions.create', {
        'name': 'gross',
        'description': 'Gross price',
        'params': ['price', 'rate'],
        'definition': '=price*(1+rate)',
      });

      await s.type('A1', '=GROSS(100, 0.19)');

      expect(s.text('A1'), '119');
      final f = namedFunctionsOf(s.model).single;
      expect(f.name, 'GROSS');
      expect(NamedFunctionMeta.parse(f.metaJson).params, ['price', 'rate']);
    });

    test(
      'when the definition contains a cell reference then it is refused',
      () async {
        final r = await s.run('sheets.namedFunctions.create', {
          'name': 'BAD',
          'params': ['x'],
          'definition': '=x+A1',
        });

        expect(r.isOk, isFalse);
        expect(namedFunctionsOf(s.model), isEmpty);
      },
    );
  });
}
