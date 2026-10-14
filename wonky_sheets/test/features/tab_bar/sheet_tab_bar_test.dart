import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/tab_bar/sheet_tab_bar.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() => s = SheetsHarness.open());
  tearDown(() => s.dispose());

  Future<void> pumpBar(WidgetTester tester) => pumpSheets(
    tester,
    s,
    child: Column(
      children: [
        const Spacer(),
        SheetTabBar(controller: s.editor),
      ],
    ),
  );

  testWidgets('Given the tab bar when pressing + then a sheet is added and '
      'activated', (tester) async {
    await pumpBar(tester);

    await tester.tap(find.byKey(const ValueKey('sheets.tab.add')));
    await tester.pump();

    expect(s.model.sheets, hasLength(2));
    expect(find.text('Sheet2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Given a tab when double-clicking it then an inline field '
      'renames the sheet on Enter', (tester) async {
    await pumpBar(tester);
    final tab = find.byKey(ValueKey('sheets.tab.${s.sheetId}'));

    await tester.tap(tab);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(tab);
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('sheets.tab.renameField')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('sheets.tab.renameField')),
      'Budget',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(s.sheet.name, 'Budget');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Given two sheets when clicking the other tab then it becomes '
      'active', (tester) async {
    await s.run('sheets.sheet.add');
    final second = s.editor.activeSheetId;
    final first = s.model.sheets.first.id;
    await pumpBar(tester);

    await tester.tap(find.byKey(ValueKey('sheets.tab.$first')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(s.editor.activeSheetId, first);
    expect(second, isNot(first));
    await tester.pump(const Duration(seconds: 1));
  });
}
