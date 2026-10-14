import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/data_tools/data_tools.dart';
import 'package:wonky_sheets/features/data_tools/data_tools_overlay.dart';
import 'package:wonky_sheets/features/filters/filter_column_popover.dart';
import 'package:wonky_sheets/features/filters/filter_controller.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() async {
    s = SheetsHarness.open();
    for (final (i, v) in ['Name', 'a', 'b', 'c'].indexed) {
      await s.type('A${i + 1}', v);
    }
    await s.select('A2');
    await s.run('sheets.filter.toggle');
  });
  tearDown(() => s.dispose());

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('Given a filter on column A, when its popover opens ($mode) '
        'then it opens to the right of the button and stays on screen', (
      tester,
    ) async {
      await pumpSheets(
        tester,
        s,
        dark: dark,
        child: SizedBox(
          width: 1000,
          height: 700,
          child: DataToolsGridOverlay(editor: s.editor),
        ),
      );
      DataTools.of(s.editor).filters.popover.value = FilterPopoverRequest(
        s.sheetId,
        s.sheet.columns.idAt(0),
        const Rect.fromLTWH(90, 0, 18, 20),
      );
      await tester.pumpAndSettle();

      final popover = tester.getRect(find.byType(FilterColumnPopover));
      expect(popover.left, greaterThanOrEqualTo(0));
      expect(popover.width, kFilterPopoverWidth);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Given a column far right, when its popover opens ($mode) '
        'then it is right-aligned to the button', (tester) async {
      await pumpSheets(
        tester,
        s,
        dark: dark,
        child: SizedBox(
          width: 1000,
          height: 700,
          child: DataToolsGridOverlay(editor: s.editor),
        ),
      );
      DataTools.of(s.editor).filters.popover.value = FilterPopoverRequest(
        s.sheetId,
        s.sheet.columns.idAt(0),
        const Rect.fromLTWH(600, 0, 18, 20),
      );
      await tester.pumpAndSettle();

      final popover = tester.getRect(find.byType(FilterColumnPopover));
      expect(popover.right, closeTo(618, 12));
    });
  }
}
