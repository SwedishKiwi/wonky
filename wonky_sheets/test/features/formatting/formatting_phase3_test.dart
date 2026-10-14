import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets/features/conditional_format/cf_panel.dart';
import 'package:wonky_sheets/features/formatting/cell_fonts.dart';
import 'package:wonky_sheets/features/formatting/formatting_features.dart';
import 'package:wonky_sheets/features/formatting/formula_field.dart';
import 'package:wonky_sheets/features/formatting/sheets_settings_section.dart';
import 'package:wonky_sheets/features/formatting/sheets_user_defaults.dart';
import 'package:wonky_sheets/features/model/memory_workbook_session.dart';
import 'package:wonky_sheets/features/number_format/custom_currency_dialog.dart';
import 'package:wonky_sheets/features/print/print_fonts.dart';
import 'package:wonky_sheets_core/model.dart' show CfPresets;

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() async {
    s = SheetsHarness.open();
    FormattingFeatures.install(s.editor);
    await s.type('A1', '10');
    await s.type('A2', '20');
    await s.select('A1:A2');
  });
  tearDown(() async {
    FormattingFeatures.maybeOf(s.editor)?.dispose();
    await s.dispose();
  });

  Widget panel(Widget child) => SizedBox(width: 360, height: 760, child: child);
  Finder key(String k) => find.byKey(ValueKey<String>(k));
  // PanelSelect keys are `<name>.<value>` / `<name>.option.<value>`.
  Finder select(String name) => find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> &&
        k.value.startsWith('$name.') &&
        !k.value.startsWith('$name.option.');
  }).first;
  Future<void> pick(WidgetTester tester, String name, String value) async {
    await tester.tap(select(name));
    await tester.pumpAndSettle();
    final f = find.byKey(ValueKey<String>('$name.option.$value')).last;
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('Given a new custom-formula rule ($mode) when nothing was '
        'typed then no error shows; after clearing the field "Enter a '
        'value." shows under it', (tester) async {
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(400, 800),
        child: panel(CfPanel(services: s.services, editor: s.editor)),
      );
      await tester.tap(key('cf.add'));
      await tester.pumpAndSettle();
      await pick(tester, 'cf.condition', 'ConditionType.customFormula');
      await tester.pumpAndSettle();

      expect(key('cf.value.0'), findsOne);
      expect(key('cf.value.0.error'), findsNothing);
      expect(key('cf.editor.error'), findsNothing);

      await tester.enterText(key('cf.value.0'), '=SU');
      await tester.pumpAndSettle();
      // Function autocomplete under the field.
      expect(key('cf.value.0.completions'), findsOne);
      expect(key('cf.value.0.completion.SUM'), findsOne);

      await tester.enterText(key('cf.value.0'), '');
      await tester.pumpAndSettle();
      expect(key('cf.value.0.error'), findsOne);
      expect(find.text('Enter a value.'), findsOne);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Given a date rule with an exact date ($mode) when picking '
        'a day in the calendar then the field gets an ISO date', (
      tester,
    ) async {
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(400, 800),
        child: panel(CfPanel(services: s.services, editor: s.editor)),
      );
      await tester.tap(key('cf.add'));
      await tester.pumpAndSettle();
      await pick(tester, 'cf.condition', 'ConditionType.dateEq');
      await pick(tester, 'cf.date', 'exact');
      await tester.pumpAndSettle();

      await tester.tap(key('cf.date.pick'));
      await tester.pumpAndSettle();
      expect(key('cf.date.calendar'), findsOne);
      await tester.tap(find.text('15').first);
      await tester.pumpAndSettle();

      final field = tester.widget<ShadInput>(
        find.descendant(
          of: key('cf.value.0'),
          matching: find.byType(ShadInput),
        ),
      );
      expect(field.controller!.text, matches(RegExp(r'^\d{4}-\d{2}-15$')));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Given a formula field with the caret after "=" when a range '
      'is selected on the grid then its reference is inserted, and a new '
      'selection replaces it (point mode)', (tester) async {
    var value = '';
    await pumpSheets(
      tester,
      s,
      size: const Size(400, 400),
      child: panel(
        StatefulBuilder(
          builder: (context, setState) => FormulaField(
            keyName: 'ff',
            editor: s.editor,
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    );
    await tester.tap(key('ff'));
    await tester.enterText(key('ff'), '=SUM(');
    await tester.pumpAndSettle();
    expect(key('ff.pointHint'), findsOne);
    expect(key('ff.signature'), findsOne);

    await s.select('B2:B5');
    await tester.pumpAndSettle();
    expect(value, '=SUM(B2:B5');

    await s.select('C1');
    await tester.pumpAndSettle();
    expect(value, '=SUM(C1');

    // A parse error shows under the field.
    await tester.enterText(key('ff'), '=SUM(1,,');
    await tester.pumpAndSettle();
    expect(key('ff.error'), findsOne);
  });

  testWidgets('Given the formula field completions when pressing Enter then '
      'the highlighted function is inserted', (tester) async {
    var value = '';
    await pumpSheets(
      tester,
      s,
      size: const Size(400, 400),
      child: panel(
        StatefulBuilder(
          builder: (context, setState) => FormulaField(
            keyName: 'ff',
            editor: s.editor,
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    );
    await tester.tap(key('ff'));
    await tester.enterText(key('ff'), '=AVERA');
    await tester.pumpAndSettle();
    expect(key('ff.completions'), findsOne);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(value, startsWith('=AVERAGE'));
  });

  for (final dark in [false, true]) {
    testWidgets(
      'Given Settings › Sheets at 360 px (${dark ? 'dark' : 'light'}) '
      'when choosing a locale, font and fill lists then the defaults are '
      'stored',
      (tester) async {
        await pumpSheets(
          tester,
          s,
          dark: dark,
          size: const Size(400, 900),
          child: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: SheetsSettingsSection(services: s.services),
            ),
          ),
        );
        expect(key('settings.sheets.locale'), findsOne);
        expect(key('settings.sheets.timeZone'), findsOne);
        expect(key('settings.sheets.font'), findsOne);
        expect(key('settings.sheets.fillLists'), findsOne);

        final d = SheetsUserDefaults.of(s.services);
        await d.set(SheetsUserDefaults.keyLocale, 'de_DE');
        await d.set(SheetsUserDefaults.keyFontFamily, CellFonts.lato);
        await tester.enterText(
          key('settings.sheets.fillLists'),
          'Low, Mid, High',
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(d.locale, 'de_DE');
        expect(d.fontFamily, CellFonts.lato);
        expect(d.customFillLists, [
          ['Low', 'Mid', 'High'],
        ]);
        // Fill series of the open spreadsheet use the custom lists.
        final session = s.editor.session as WorkbookSessionBase;
        expect(session.customLists, [
          ['Low', 'Mid', 'High'],
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('Given a custom fill list when filling down from Low then the list '
      'continues', () async {
    await SheetsUserDefaults.of(s.services).set(
      SheetsUserDefaults.keyCustomFillLists,
      [
        ['Low', 'Mid', 'High'],
      ],
    );
    await s.type('C1', 'Low');
    await s.run('sheets.fill.series', {'source': 'C1', 'target': 'C1:C4'});
    expect([s.text('C2'), s.text('C3'), s.text('C4')], ['Mid', 'High', 'Low']);
  });

  testWidgets('Given the custom currency dialog when expanding a currency '
      'then the [Red] negative example is red and names are localized', (
    tester,
  ) async {
    await pumpSheets(
      tester,
      s,
      size: const Size(600, 700),
      child: const CustomCurrencyDialog(locale: 'en_US'),
    );
    expect(find.text('US Dollar'), findsOne);
    await tester.tap(key('dialog.customCurrency.USD'));
    await tester.pumpAndSettle();
    final red = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.style?.color == const Color(0xFFFF0000));
    expect(red, isNotEmpty);
  });

  test('Given a color scale over more cells than the big-stats limit when '
      'it is evaluated then the scale appears once the background stats are '
      'ready (06 §15.10)', () async {
    final cf = FormattingFeatures.of(s.editor).cf;
    cf.evaluator.asyncStatsCells = 1;
    await s.type('A3', '30');
    await s.run('sheets.cf.addRule', {
      'ranges': ['A1:A3'],
      'rule': CfPresets.colorScales().first.rule.toJson(),
    });
    final sid = s.sheetId;
    expect(cf.evaluator.evaluate(sid, 2, 0).scaleColor, isNull);
    expect(cf.computingStats, isTrue);

    await cf.statsIdle();

    expect(cf.evaluator.evaluate(sid, 0, 0).scaleColor, '#FFFFFF');
    expect(cf.evaluator.evaluate(sid, 2, 0).scaleColor, '#57BB8A');
    // An edit keeps the old scale while the new stats compute (no flicker).
    await s.type('A2', '5');
    expect(cf.evaluator.evaluate(sid, 2, 0).scaleColor, isNotNull);
    await cf.statsIdle();
  });

  test('Given the bundled fonts then theme preset families render with '
      'bundled faces and the PDF uses the static ones', () {
    expect(CellFonts.displayFamily('Roboto'), CellFonts.roboto);
    expect(CellFonts.displayFamily('Lato'), CellFonts.lato);
    expect(CellFonts.displayFamily('Roboto Mono'), CellFonts.robotoMono);
    expect(CellFonts.displayFamily('Montserrat'), CellFonts.montserrat);
    expect(CellFonts.displayFamily('Merriweather'), CellFonts.merriweather);
    expect(CellFonts.displayFamily('Poppins'), CellFonts.lato);
    expect(CellFonts.displayFamily('Lora'), CellFonts.ebGaramond);
    expect(SheetsPdfFonts.pdfFamily('Roboto'), CellFonts.roboto);
    expect(SheetsPdfFonts.pdfFamily('Inter'), SheetsPdfFonts.sans);
  });
}
