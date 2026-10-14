import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  testWidgets('Given the grid when typing 7 2 Enter then B2 holds 72 and '
      'the active cell moves down', (tester) async {
    final s = SheetsHarness.open();
    addTearDown(s.dispose);
    await pumpSheets(tester, s);
    await s.select('B2');
    s.editor.gridFocus.requestFocus();
    await tester.pump();

    await typeChars(tester, s.editor.editor, '7');
    expect(s.editor.editor.isEditing, isTrue);
    await typeChars(tester, s.editor.editor, '2');
    expect(s.editor.editor.text.text, '72');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(s.text('B2'), '72');
    expect(s.editor.activeA1, 'B3');
    await tester.pump(const Duration(seconds: 1));
  });
}
