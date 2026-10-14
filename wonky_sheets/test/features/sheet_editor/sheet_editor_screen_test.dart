import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets/features/sheet_editor/sheet_editor_screen.dart';
import 'package:wonky_sheets/features/sheet_editor/sheets_document_controller.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() => s = SheetsHarness.open());

  Future<void> pumpScreen(WidgetTester tester, {bool dark = false}) async {
    s.services.deactivate(s.doc);
    await pumpSheets(
      tester,
      s,
      dark: dark,
      size: const Size(1440, 900),
      child: ActiveDocumentHostScope(
        host: s.services,
        child: SheetEditorScreen(
          services: s.services,
          itemUuid: testItemUuid,
          sessionFactory: (services, item) async => s.session,
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  SheetsDocumentController doc() =>
      s.services.activeDocument.value! as SheetsDocumentController;

  for (final dark in [false, true]) {
    testWidgets('Given an open spreadsheet (${dark ? 'dark' : 'light'}) when '
        'the screen loads then menubar, toolbar, formula bar, grid, tabs and '
        'status bar render', (tester) async {
      await pumpScreen(tester, dark: dark);

      for (final m in ['File', 'Edit', 'View', 'Insert', 'Format', 'Data']) {
        expect(find.text(m), findsWidgets, reason: m);
      }
      expect(
        find.byKey(const ValueKey('sheets.toolbar.format.bold')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('sheets.formulaBar')), findsOneWidget);
      expect(find.byKey(const ValueKey('sheets.grid')), findsOneWidget);
      expect(find.byKey(const ValueKey('sheets.tabBar')), findsOneWidget);
      expect(find.byKey(const ValueKey('sheets.status.mode')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }

  testWidgets('Given the screen when typing into a cell then the editor '
      'and the formula bar show the text and Enter commits', (tester) async {
    await pumpScreen(tester);
    final ed = doc().editor!;
    ed.gridFocus.requestFocus();
    await tester.pump();

    await typeChars(tester, ed.editor, '4');
    await typeChars(tester, ed.editor, '2');
    expect(find.byKey(const ValueKey('sheets.cellEditor')), findsOneWidget);
    expect(ed.editor.text.text, '42');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();

    expect(ed.cells.displayAt(ed.activeSheetId, 0, 0)?.text, '42');
    expect(ed.activeA1, 'A2');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
