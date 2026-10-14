import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/formatting/spreadsheet_settings_dialog.dart';
import 'package:wonky_sheets_core/formula.dart'
    show CompletionContext, completionsAt;

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  test('Given display language de, when formulas are typed, shown and '
      'computed, then names and booleans are German and the stored form is '
      'English', () async {
    final s = SheetsHarness.open();
    await s.run('sheets.settings.update', {'displayLanguage': 'de'});
    expect(s.model.spreadsheet.displayLanguage, 'de');
    // One undo step.
    await s.undo();
    expect(s.model.spreadsheet.displayLanguage, isNot('de'));
    await s.redo();
    expect(s.model.spreadsheet.displayLanguage, 'de');

    await s.type('A1', '=SUMME(1, 2)');
    await s.type('A2', '=wenn(A1>2, wahr, falsch)');
    await s.type('A3', '=SUM(A1, 1)');

    expect(s.content('A1'), contains('SUM('));
    expect(s.content('A2'), contains('IF('));
    expect(s.text('A1'), '3');
    expect(s.text('A2'), 'WAHR');
    expect(s.text('A3'), '4');
    expect(s.editor.editableText(0, 0), '=SUMME(1, 2)');
    expect(s.editor.editableText(1, 0), '=WENN(A1>2, WAHR, FALSCH)');
    expect(s.editor.editableText(2, 0), '=SUMME(A1, 1)');
    final list = completionsAt(
      '=ZÄHL',
      5,
      CompletionContext(locale: s.editor.formulaLocale),
    );
    expect(list.items.first.name, 'ZÄHLENWENN');

    // Back to English: the same formulas read in English.
    await s.run('sheets.settings.update', {'displayLanguage': ''});
    expect(s.editor.editableText(1, 0), '=IF(A1>2, TRUE, FALSE)');
    expect(s.text('A2'), 'TRUE');
    await s.dispose();
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('Given the settings dialog at 360 px ($mode), when Function '
        'language is set to Svenska, then the preview and the result follow', (
      tester,
    ) async {
      final s = SheetsHarness.open();
      SpreadsheetSettings? result;
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(360, 800),
        child: const SizedBox(key: ValueKey('host'), width: 40, height: 40),
      );
      unawaited(
        showSpreadsheetSettingsDialog(
          tester.element(find.byKey(const ValueKey('host'))),
          SpreadsheetSettings.of(s.model.spreadsheet),
        ).then((r) => result = r),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dialog.settings.displayLanguage')),
        findsOne,
      );
      final state = tester.state<State<SpreadsheetSettingsDialog>>(
        find.byType(SpreadsheetSettingsDialog),
      );
      // MCP-operable field (WonkyDialogSpec).
      expect((state as dynamic).setField('displayLanguage', 'sv'), isTrue);
      expect((state as dynamic).setField('displayLanguage', 'xx'), isFalse);
      await tester.pumpAndSettle();
      final preview = tester.widget<Text>(
        find.byKey(const ValueKey('dialog.settings.preview')),
      );
      expect(preview.data, contains('=SUMMA(1, 2)'));
      expect(tester.takeException(), isNull);
      expect((state as dynamic).press('save'), isTrue);
      await tester.pumpAndSettle();
      expect(result?.changesFrom(SpreadsheetSettings.of(s.model.spreadsheet)), {
        'displayLanguage': 'sv',
      });
      await s.dispose();
    });
  }
}
