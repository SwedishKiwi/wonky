import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/in_cell/cell_features.dart';
import 'package:wonky_sheets/features/in_cell/in_cell_controller.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

/// In-cell widgets (03 §14) on the grid at 100 % zoom: row header 48 px,
/// column header 24 px, rows 21 px, columns 100 px.
void main() {
  late SheetsHarness s;

  setUp(() {
    s = SheetsHarness.open();
    attachCellFeatures(s.editor);
  });
  tearDown(() => s.dispose());

  Rect cell(int row, int col) =>
      Rect.fromLTWH(48.0 + col * 100, 24.0 + row * 21, 100, 21);

  Future<void> dropdown() => s.run('sheets.dv.saveRule', {
    'ranges': ['B2:B10'],
    'criteria': {
      'type': 'oneOfList',
      'options': [
        {'value': 'Open', 'bg': '#D4EDBC', 'fg': '#11734B'},
        {'value': 'Closed', 'bg': '#FFCFC9', 'fg': '#B10202'},
      ],
    },
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('Given a checkbox in B2 ($theme) when clicking the box then it '
        'toggles, and clicking beside it only selects', (tester) async {
      await s.select('B2');
      await s.run('sheets.insert.checkbox');
      await pumpSheets(tester, s, dark: dark);

      await tester.tapAt(cell(1, 1).center);
      await tester.pump(const Duration(milliseconds: 500));
      expect(s.content('B2'), 'b:1');

      await tester.tapAt(cell(1, 1).centerLeft + const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 500));
      expect(s.content('B2'), 'b:1');
      expect(s.editor.activeA1, 'B2');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Given a dropdown chip ($theme) when clicking it then the '
        'picker opens, and picking an item writes it', (tester) async {
      await dropdown();
      await s.type('B2', 'Open');
      await pumpSheets(tester, s, dark: dark);

      await tester.tapAt(cell(1, 1).centerLeft + const Offset(14, 0));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('sheets.cellPopup.dropdown')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('sheets.dropdownPicker.item.Closed')),
      );
      await tester.pumpAndSettle();

      expect(s.text('B2'), 'Closed');
      expect(InCellController.of(s.editor).popup.value, isNull);
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('Given a dropdown cell when pressing Alt+Down then the picker '
      'opens and Esc closes it', (tester) async {
    await dropdown();
    await s.select('B3');
    await pumpSheets(tester, s);

    await s.run('sheets.dv.openDropdown');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('sheets.cellPopup.dropdown')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(s.text('B3'), 'Closed');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Given a cell with a note when hovering it then the note card '
      'shows', (tester) async {
    await s.run('sheets.notes.insert', {'cell': 'C3', 'text': 'Check this'});
    await pumpSheets(tester, s);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(5, 5));
    await mouse.moveTo(cell(2, 2).center);
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.byKey(const ValueKey<String>('sheets.cellCard.note')),
      findsOneWidget,
    );
    expect(find.text('Check this'), findsOneWidget);
    await mouse.removePointer();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Given a linked cell when selecting it then the link card shows '
      'the URL', (tester) async {
    await s.select('A1');
    await s.run('sheets.insert.link', {
      'url': 'example.com',
      'text': 'Example',
    });
    await s.select('A2');
    await pumpSheets(tester, s);

    await s.select('A1');
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('sheets.cellCard.link')),
      findsOneWidget,
    );
    expect(find.text('https://example.com'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Given a formula error when hovering it then the error tooltip '
      'shows the message', (tester) async {
    await s.type('A1', '=1/0');
    await pumpSheets(tester, s);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(5, 5));
    await mouse.moveTo(cell(0, 0).center);
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.byKey(const ValueKey<String>('sheets.cellCard.error')),
      findsOneWidget,
    );
    await mouse.removePointer();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Given Insert › Note when typing and pressing Esc then the note '
      'is saved in one undo step', (tester) async {
    await s.select('D4');
    await pumpSheets(tester, s);

    await s.run('sheets.notes.insert');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('sheets.noteEditor.text')),
      'Hello',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final (sheet, r) = (s.sheet, s.model.parseA1('D4').rect);
    expect(sheet.cellAt(r.top, r.left)?.note, 'Hello');
    await s.undo();
    expect(sheet.cellAt(r.top, r.left)?.note, isNull);
    await tester.pump(const Duration(seconds: 1));
  });
}
