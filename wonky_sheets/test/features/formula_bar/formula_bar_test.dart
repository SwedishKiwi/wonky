import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/formula_bar/formula_bar.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() => s = SheetsHarness.open());
  tearDown(() => s.dispose());

  Future<void> pumpBar(WidgetTester tester) =>
      pumpSheets(tester, s, child: FormulaBar(controller: s.editor));

  testWidgets('Given a formula in B2 when it is the active cell then the '
      'formula bar shows its A1 text', (tester) async {
    await s.type('A1', '4');
    await s.type('B2', '=A1*2');
    await s.select('B2');
    await pumpBar(tester);

    expect(find.text('=A1*2'), findsOneWidget);
    expect(find.text('B2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Given the name box when typing D10 and Enter then D10 is '
      'selected', (tester) async {
    await pumpBar(tester);

    await tester.enterText(find.byKey(const ValueKey('sheets.nameBox')), 'D10');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(s.editor.activeA1, 'D10');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Given a range selected when typing a new name in the name box '
      'then a named range is created', (tester) async {
    await s.select('B2:B5');
    await pumpBar(tester);

    await tester.enterText(
      find.byKey(const ValueKey('sheets.nameBox')),
      'Sales',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(s.model.namedRange('Sales'), isNotNull);
    await s.select('A1');
    expect(s.editor.goTo('Sales'), isTrue);
    expect(s.editor.selection.describe(), 'B2:B5');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Given the formula bar when clicking it then the active cell '
      'is edited in the bar', (tester) async {
    await s.type('A1', 'hello');
    await s.select('A1');
    await pumpBar(tester);

    await tester.tap(find.byKey(const ValueKey('sheets.formulaBar.display')));
    await tester.pump();
    await tester.pump();

    expect(s.editor.editor.isEditing, isTrue);
    expect(s.editor.editor.text.text, 'hello');
    expect(
      find.byKey(const ValueKey('sheets.formulaBar.editor')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
  });
}
