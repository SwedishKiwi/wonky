import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/data_tools/data_tools.dart';
import 'package:wonky_sheets_core/model.dart';

import '../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;
  late DataTools tools;

  setUp(() {
    s = SheetsHarness.open();
    tools = DataTools.of(s.editor);
  });
  tearDown(() => s.dispose());

  List<GroupSpan> rowGroups() => tools.groups.spans(s.sheetId, Dimension.rows);

  group('Given rows 3–8 selected', () {
    setUp(() => s.run('sheets.select.range', {'a1': 'A3:A8'}));

    test('when grouping rows then a depth-1 group 3–8 exists and the gutter '
        'appears', () async {
      await s.run('sheets.group.groupRows');

      expect(rowGroups().single.start, 2);
      expect(rowGroups().single.end, 7);
      expect(rowGroups().single.depth, 1);
      expect(tools.groups.gutters(s.sheet).rows, greaterThan(0));
    });

    test('when grouping rows 4–5 inside it then that group has depth 2, and '
        'level 1 collapses everything', () async {
      await s.run('sheets.group.groupRows');
      await s.select('A4:A5');
      await s.run('sheets.group.groupRows');

      expect(rowGroups().map((g) => g.depth), [1, 2]);

      await s.run('sheets.group.collapseToLevel', {
        'dimension': 'rows',
        'level': 1,
      });

      expect([
        for (var r = 2; r <= 7; r++) s.sheet.rows.isHidden(r),
      ], everyElement(true));
      expect(s.sheet.rows.isHidden(8), isFalse);
    });

    test('when toggling the group then its rows hide and show, each an undo '
        'step', () async {
      await s.run('sheets.group.groupRows');
      final id = rowGroups().single.id;

      await s.run('sheets.group.toggle', {'groupId': id});
      expect(s.sheet.rows.isHidden(4), isTrue);
      expect(s.sheet.rows.isHiddenBy(HiddenLayers.groups, 4), isTrue);

      await s.undo();
      expect(s.sheet.rows.isHidden(4), isFalse);
    });

    test(
      'when ungrouping row 5 from a group 4–5 then it shrinks to row 4',
      () async {
        await s.select('A4:A5');
        await s.run('sheets.group.groupRows');
        await s.select('A5');

        await s.run('sheets.group.ungroupRows');

        expect(rowGroups().single.start, 3);
        expect(rowGroups().single.end, 3);
      },
    );

    test('when collapsing and expanding all row groups then every group '
        'follows', () async {
      await s.run('sheets.group.groupRows');

      await s.run('sheets.group.collapseAll', {'dimension': 'rows'});
      expect(rowGroups().single.collapsed, isTrue);

      await s.run('sheets.group.expandAll', {'dimension': 'rows'});
      expect(rowGroups().single.collapsed, isFalse);
    });
  });

  test('Given columns B–D selected when grouping columns then a column group '
      'exists', () async {
    await s.run('sheets.select.range', {'a1': 'B:D'});

    await s.run('sheets.group.groupColumns');

    final g = tools.groups.spans(s.sheetId, Dimension.columns).single;
    expect((g.start, g.end), (1, 3));
  });
}
