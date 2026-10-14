import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/data_tools/data_tools.dart';

import '../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;
  late DataTools tools;

  setUp(() async {
    s = SheetsHarness.open();
    tools = DataTools.of(s.editor);
    await s.type('A1', 'East');
    await s.type('A2', 'Northeast');
    await s.type('A3', 'West');
    await s.type('B1', '=LEN(A1)');
  });
  tearDown(() => s.dispose());

  group('Given the find bar', () {
    test('when searching "east" then East and Northeast match and next '
        'selects them in order', () async {
      await s.run('sheets.find.open', {'query': 'east'});

      expect(tools.find.matches, hasLength(2));
      expect(s.editor.activeA1, 'A1');

      await s.run('sheets.find.next');
      expect(s.editor.activeA1, 'A2');

      await s.run('sheets.find.next');
      expect(s.editor.activeA1, 'A1');
    });

    test('when matching the entire cell then only East matches', () async {
      await s.run('sheets.find.open');
      tools.find.setQuery(
        'east',
        options: tools.find.options.copyWith(entireCell: true),
      );

      expect(tools.find.matches.single.row, 0);
    });

    test('when an invalid regex is used then an error is shown and nothing '
        'matches', () async {
      await s.run('sheets.find.open');
      tools.find.setQuery(
        '(',
        options: tools.find.options.copyWith(regex: true),
      );

      expect(tools.find.error, isNotNull);
      expect(tools.find.matches, isEmpty);
    });
  });

  group('Given Find and replace', () {
    test('when replacing all with a regex then every cell changes in one '
        'undo step', () async {
      final before = s.h.undoLabels.length;

      await s.run('sheets.find.replaceAll', {
        'find': r'(\w*)east',
        'replace': r'$1-EAST',
        'useRegex': true,
        'scope': 'sheet',
      });

      expect(s.text('A1'), '-EAST');
      expect(s.text('A2'), 'North-EAST');
      expect(s.text('A3'), 'West');
      expect(s.h.undoLabels.length, before + 1);

      await s.undo();
      expect(s.text('A2'), 'Northeast');
    });

    test(
      'when replacing within formulas then the formula text changes',
      () async {
        await s.run('sheets.find.replaceAll', {
          'find': 'LEN',
          'replace': 'UPPER',
          'searchFormulas': true,
        });

        expect(s.text('B1'), 'EAST');
      },
    );

    test(
      'when replacing the current match then only that cell changes',
      () async {
        await s.run('sheets.find.open', {'query': 'east'});

        await s.run('sheets.find.replace', {'find': 'east', 'replace': 'x'});

        expect(s.text('A1'), 'x');
        expect(s.text('A2'), 'Northeast');
      },
    );
  });
}
