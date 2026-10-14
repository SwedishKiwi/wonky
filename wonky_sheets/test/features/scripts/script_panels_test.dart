import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/scripts/runtime/script_panels.dart';

import '../../support/grid_pump.dart';
import 'script_test_support.dart';

const _main = r'''
import 'package:wonky/wonky.dart';

UiPanel _form(String note) => UiPanel(title: 'Import', children: [
  UiText('Choose a **source**'),
  UiSelect(id: 'source', label: 'Source', options: ['CRM', 'Shop'], value: 'CRM'),
  UiSelect(id: 'target', label: 'Target', options: ['Sheet1', 'New sheet']),
  UiTextField(id: 'from', label: 'From date', type: 'date'),
  UiCheckbox(id: 'clear', label: 'Clear sheet first'),
  UiRadioGroup(id: 'mode', options: ['Append', 'Replace'], value: 'Append'),
  UiTable(headers: ['Name', 'Rows'], rows: [['Leads', 120], ['Deals', 7]]),
  UiProgress(value: 0.4, label: 'Progress'),
  UiDivider(),
  UiRow(children: [
    UiButton('Import', onClick: 'runImport', primary: true),
    UiButton('Close', onClick: '_close'),
  ]),
  UiText(note),
]);

void openSidebar() {
  SpreadsheetApp.ui.showSidebar(_form(''));
}

void openDialog() {
  SpreadsheetApp.ui.showModalDialog(_form(''), 'Import data');
}

void runImport(UiEvent e) {
  SpreadsheetApp.activeSheet.getRange('A1').value = '${e.values['source']} ${e.values['from']}';
  e.panel.update(_form('Imported'));
}
''';

void main() {
  for (final (size, dark) in [
    (const Size(1200, 800), false),
    (const Size(360, 760), true),
  ]) {
    testWidgets('Given a script sidebar at ${size.width.toInt()} px '
        '(${dark ? 'dark' : 'light'}) when its button is pressed then the '
        'function runs with the values and updates the panel', (tester) async {
      final h = (await tester.runAsync(
        () => ScriptHarness.open({'main.dart': _main}),
      ))!;
      addTearDown(() => tester.runAsync(h.dispose));
      await tester.runAsync(() => h.svc.run('openSidebar'));
      final panels = ScriptPanels.of(h.s.editor);
      expect(panels.sidebar?.title, 'Import');
      expect(h.s.services.panels.activePanelId, scriptSidebarPanelId);

      await pumpSheets(
        tester,
        h.s,
        size: size,
        dark: dark,
        child: Builder(
          builder: (context) =>
              scriptSidebarPanelSpec(context, h.s.editor).builder(context),
        ),
      );
      expect(find.byKey(const ValueKey('script.sidebar')), findsOneWidget);
      expect(find.text('Leads'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final d = h.s.services.openDialogs.last;
      expect(d.describe()['title'], 'Import');
      expect(d.setField('source', 'Shop'), isTrue);
      expect(d.setField('from', '2026-01-01'), isTrue);
      await tester.runAsync(() async {
        expect(d.press('Import'), isTrue);
        await pumpScripts(20);
      });
      await tester.pump();
      expect(h.s.text('A1'), 'Shop 2026-01-01');
      expect(find.text('Imported'), findsOneWidget);

      expect(d.press('Close'), isTrue);
      await tester.pump();
      expect(panels.sidebar, isNull);
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('Given a script dialog then it shows the panel and closes', (
    tester,
  ) async {
    final h = (await tester.runAsync(
      () => ScriptHarness.open({'main.dart': _main}),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await pumpSheets(tester, h.s, child: const SizedBox());
    // The harness app has no shell navigator: open the dialog from here.
    ScriptPanels.contextOverride = tester.element(find.byType(SizedBox));
    addTearDown(() => ScriptPanels.contextOverride = null);
    await tester.runAsync(() => h.svc.run('openDialog'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dialog.scriptPanel')), findsOneWidget);
    expect(find.text('Import data'), findsOneWidget);
    final d = h.s.services.openDialogs.last;
    expect(d.press('close'), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dialog.scriptPanel')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });
}
