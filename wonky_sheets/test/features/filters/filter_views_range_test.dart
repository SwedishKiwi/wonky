import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/data_tools/data_tools.dart';
import 'package:wonky_sheets/features/filters/filter_views_panel.dart';
import 'package:wonky_sheets/features/grid/selection/grid_selection.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('Given an active saved filter view in the panel at 360 px '
        '($mode), when its range field picks a range on the grid, then the '
        'view range is set in one step when picking ends', (tester) async {
      final s = SheetsHarness.open();
      for (var r = 1; r <= 6; r++) {
        await s.type('A$r', r == 1 ? 'Name' : 'n$r');
        await s.type('B$r', '$r');
      }
      await s.select('A1');
      await s.run('sheets.filterView.create');
      final filters = DataTools.of(s.editor).filters;
      final id = filters.activeViewId(s.sheetId)!;
      final other = FocusNode();
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(400, 800),
        child: Column(
          children: [
            SizedBox(
              width: 360,
              height: 600,
              child: FilterViewsPanel(editor: s.editor),
            ),
            Focus(focusNode: other, child: const SizedBox(height: 10)),
          ],
        ),
      );
      expect(find.byKey(ValueKey('filterViews.rangeField.$id')), findsOne);
      expect(tester.takeException(), isNull);
      final steps = s.h.undoLabels.length;

      await tester.tap(find.byKey(const ValueKey('filterViews.range.input')));
      await tester.pump();
      s.editor.selection.setRanges([
        (SelectionKind.cells, const GridRect(0, 0, 3, 1)),
      ]);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('filterViews.range.input')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        'A1:B4',
      );
      other.requestFocus();
      await tester.pumpAndSettle();

      expect(filters.view(s.sheetId, id)!.range, const GridRect(0, 0, 3, 1));
      expect(s.h.undoLabels.length, steps + 1);
      await tester.pumpWidget(const SizedBox());
      other.dispose();
      await s.dispose();
    });
  }
}
