import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/common/range_input.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets/features/grid/selection/grid_selection.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('Given a focused range input (${dark ? 'dark' : 'light'}), '
        'when the grid selection changes then the range is written, picking '
        'goes on in the grid and ends with a commit elsewhere', (tester) async {
      final s = SheetsHarness.open();
      final other = FocusNode();
      final changes = <String>[];
      final commits = <String>[];
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(360, 400),
        child: Column(
          children: [
            RangeInput(
              editor: s.editor,
              value: 'A1',
              multiple: false,
              keyName: 'test.range',
              onChanged: (t, _) => changes.add(t),
              onCommitted: (t, _) => commits.add(t),
            ),
            Focus(focusNode: other, child: const SizedBox(height: 10)),
            Focus(
              focusNode: s.editor.gridFocus,
              child: const SizedBox(height: 10),
            ),
          ],
        ),
      );

      await tester.tap(find.byKey(const ValueKey('test.range.input')));
      await tester.pump();
      s.editor.selection.setRanges([
        (SelectionKind.cells, const GridRect(1, 1, 3, 2)),
      ]);
      await tester.pump();
      expect(changes.last, 'B2:C4');

      // Into the grid: still picking.
      s.editor.gridFocus.requestFocus();
      await tester.pump();
      s.editor.selection.setRanges([
        (SelectionKind.cells, const GridRect(4, 0, 5, 0)),
      ]);
      await tester.pump();
      expect(changes.last, 'A5:A6');
      expect(commits, isEmpty);

      // Anywhere else: picking ends with a commit.
      other.requestFocus();
      await tester.pump();
      expect(commits, ['A5:A6']);
      s.editor.selection.setRanges([
        (SelectionKind.cells, const GridRect(0, 0, 0, 0)),
      ]);
      await tester.pump();
      expect(changes.last, 'A5:A6');

      await tester.pumpWidget(const SizedBox());
      other.dispose();
      await s.dispose();
    });
  }
}
