import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/data_validation/dv_controller.dart';
import 'package:wonky_sheets/features/data_validation/dv_panel.dart';
import 'package:wonky_sheets/features/in_cell/cell_features.dart';
import 'package:wonky_sheets/features/protection/protection_panel.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() {
    s = SheetsHarness.open();
    attachCellFeatures(s.editor);
  });
  tearDown(() => s.dispose());

  Widget panel(Widget child) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 520, height: 760, child: child),
  );

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('Given the data validation panel ($theme) when adding a '
        'dropdown with two items then Done saves one rule', (tester) async {
      await s.select('A2:A9');
      await s.run('sheets.dv.openPanel');
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(800, 800),
        child: panel(DvPanel(services: s.services, editor: s.editor)),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('dv.option.0')),
        'Open',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('dv.option.1')),
        'Closed',
      );
      await tester.tap(find.byKey(const ValueKey<String>('dv.done')));
      await tester.pumpAndSettle();

      final rule = s.sheet.dvRules.values.single;
      final c = DvCriteria.tryParse(rule.criteriaJson)! as DvListCriteria;
      expect(c.options.map((o) => o.value), ['Open', 'Closed']);
      expect(
        s.sheet.ruleRects(RuleKind.dataValidation, rule.id).single.a1,
        'A2:A9',
      );
      // Back to the list, which shows the rule.
      expect(
        find.byKey(ValueKey<String>('dv.rule.${rule.id}')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Given the data validation panel ($theme, 360 px) when '
        'typing items then the grid previews the dropdown before Done and '
        'the items reorder by drag and Alt+arrows', (tester) async {
      await s.select('B2:B6');
      await s.run('sheets.dv.openPanel');
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(800, 800),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 360,
            height: 760,
            child: DvPanel(services: s.services, editor: s.editor),
          ),
        ),
      );
      CellWidgetKind kindAt(int r, int c) =>
          s.editor.cells.displayAt(s.sheetId, r, c)?.widget.kind ??
          CellWidgetKind.none;

      await tester.enterText(
        find.byKey(const ValueKey<String>('dv.option.0')),
        'Open',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('dv.option.1')),
        'Closed',
      );
      await tester.pump();
      expect(s.sheet.dvRules, isEmpty, reason: 'nothing is written yet');
      expect(kindAt(2, 1), CellWidgetKind.dropdownChip);
      expect(kindAt(2, 2), CellWidgetKind.none);

      // Alt+↓ in the first item moves it down.
      await tester.tap(find.byKey(const ValueKey<String>('dv.option.0')));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      String item(int i) => tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(ValueKey<String>('dv.option.$i')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text;
      expect([item(0), item(1)], ['Closed', 'Open']);

      // Drag the second item above the first.
      final handle = find.byKey(const ValueKey<String>('dv.option.1.drag'));
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, -10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect([item(0), item(1)], ['Open', 'Closed']);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey<String>('dv.done')));
      await tester.pumpAndSettle();
      final rule = s.sheet.dvRules.values.single;
      final c = DvCriteria.tryParse(rule.criteriaJson)! as DvListCriteria;
      expect(c.options.map((o) => o.value), ['Open', 'Closed']);
      // The preview ended with the editor; the saved rule shows instead.
      expect(DataValidationController.of(s.editor).draft, isNull);
      expect(kindAt(2, 1), CellWidgetKind.dropdownChip);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Given the protection panel ($theme) when protecting a range '
        'with the permissions dialog then one protection is added', (
      tester,
    ) async {
      await s.select('F2:F40');
      await s.run('sheets.protect.openPanel');
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(800, 800),
        child: panel(ProtectionPanel(services: s.services, editor: s.editor)),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('protection.description')),
        'Totals',
      );
      await tester.tap(find.byKey(const ValueKey<String>('protection.done')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('dialog.protectionPermissions.ok')),
      );
      await tester.pumpAndSettle();

      final p = s.sheet.protections.values.single;
      expect(p.description, 'Totals');
      expect(find.text('Totals'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
