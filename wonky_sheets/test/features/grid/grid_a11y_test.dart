import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/grid/a11y/grid_semantics.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

/// Accessibility of the grid (03 §18) and the drag-copy cursor (03 §11).
void main() {
  late SheetsHarness s;

  setUp(() => s = SheetsHarness.open());
  tearDown(() => s.dispose());

  Offset cell(int row, int col) =>
      Offset(48 + col * 100 + 50, 24 + row * 21 + 10);

  group('Descriptions', () {
    test('Given cells with values, formulas, links and notes, then they are '
        'described like 03 §18', () async {
      await s.type('B4', '42');
      await s.type('B5', '=B4*2');
      await s.type('B6', '=1/0');
      final l = s.editor.l10n;

      expect(describeCell(s.editor, l, 3, 1), 'B4, 42');
      expect(describeCell(s.editor, l, 4, 1), 'B5, 84, formula =B4*2');
      expect(describeCell(s.editor, l, 6, 1), 'B7, empty');
      expect(describeCell(s.editor, l, 5, 1), startsWith('B6, error, '));

      await s.select('A1:C5');
      expect(describeSelection(s.editor, l), 'A1 to C5 selected, 15 cells');
    });

    test('Given the announcer is on, when the selection settles then the '
        'active cell is announced, and editing announces "Editing"', () async {
      await s.type('A2', 'Hello');
      final a = SelectionAnnouncer(
        s.editor,
        view: () => null,
        debounce: const Duration(milliseconds: 10),
      )..enabled = () => true;
      addTearDown(a.dispose);

      await s.select('A2');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(a.last, 'A2, Hello');

      s.editor.editor.begin();
      expect(a.last, 'Editing A2');
      s.editor.editor.cancel();
    });
  });

  for (final dark in [false, true]) {
    testWidgets('Given semantics are on (${dark ? 'dark' : 'light'}), then '
        'visible cells and column headers are table nodes', (tester) async {
      final handle = tester.ensureSemantics();
      await s.type('B2', '42');
      await pumpSheets(tester, s, dark: dark);
      await tester.pump();

      final table = tester.getSemantics(find.byType(GridSemantics));
      final labels = <String>[];
      void collect(SemanticsNode n) {
        labels.add(n.label);
        n.visitChildren((c) {
          collect(c);
          return true;
        });
      }

      collect(table);
      expect(table.label, 'Sheet1 grid');
      expect(labels, containsAll(['B2, 42', 'Column B', 'Row 2', 'A1, empty']));
      handle.dispose();
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('Given a selected cell, when its border is dragged with Alt '
      'held then the copy cursor shows and the cell is copied', (tester) async {
    await s.type('B2', 'x');
    await s.select('B2');
    await pumpSheets(tester, s);

    // The left border of B2.
    final from = Offset(48 + 100 + 1, cell(1, 1).dy);
    final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await g.moveTo(cell(3, 3));
    await tester.pump();
    final cursors = tester
        .widgetList<MouseRegion>(find.byType(MouseRegion))
        .map((m) => m.cursor);
    expect(cursors, contains(SystemMouseCursors.copy));
    await g.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    await tester.pump();

    expect(s.text('B2'), 'x');
    expect(s.text('D4'), 'x');
    await tester.pump(const Duration(seconds: 1));
  });
}
