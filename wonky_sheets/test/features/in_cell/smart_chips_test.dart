import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets/features/grid/grid_area.dart';
import 'package:wonky_sheets/features/in_cell/cell_features.dart';
import 'package:wonky_sheets/features/in_cell/in_cell_controller.dart';
import 'package:wonky_sheets/features/in_cell/smart_chips.dart';
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

  test('Given a cell when inserting a person chip then it holds rich text '
      'with the chip, in one undo step', () async {
    final r = await s.h.invoke('sheets.insert.smartChip', {
      'kind': 'person',
      'email': 'ann@x.com',
      'name': 'Ann Lee',
      'cell': 'B2',
    }, InvocationSource.mcp);

    expect(r.status, CommandStatus.ok, reason: r.message);
    expect(s.text('B2'), 'Ann Lee');
    final chip = PersonChip.of(s.sheet.cellAt(1, 1)?.decoded);
    expect(chip, const PersonChip(email: 'ann@x.com', name: 'Ann Lee'));
    expect(
      InCellController.of(
        s.editor,
      ).infoAt(s.sheetId, 1, 1, hover: true)?.person,
      chip,
    );
    await s.undo();
    expect(s.content('B2'), isNull);
  });

  test(
    'Given a cell when inserting a date chip then a date is written',
    () async {
      final r = await s.h.invoke('sheets.insert.smartChip', {
        'kind': 'date',
        'date': '2026-03-04',
        'cell': 'C3',
      }, InvocationSource.mcp);

      expect(r.status, CommandStatus.ok, reason: r.message);
      expect(s.sheet.cellAt(2, 2)?.decoded, isA<NumberContent>());
    },
  );

  for (final dark in [false, true]) {
    testWidgets('Given the grid (${dark ? 'dark' : 'light'}) when typing @ '
        'into a cell then the chip menu opens, and its text entry keeps '
        '"@home" as plain text', (tester) async {
      await pumpSheets(tester, s, dark: dark);
      await s.select('B2');
      s.editor.gridFocus.requestFocus();
      await tester.pump();

      await typeChars(tester, s.editor.editor, '@');
      await tester.pumpAndSettle();

      expect(s.editor.editor.isEditing, isFalse);
      expect(
        InCellController.of(s.editor).popup.value?.kind,
        CellPopupKind.smartChip,
      );
      expect(
        find.byKey(const ValueKey<String>('sheets.smartChip.search')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('sheets.smartChip.search')),
        'home',
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(s.text('B2'), '@home');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Given a person chip (${dark ? 'dark' : 'light'}) when the '
        'grid paints then the chip layer draws it', (tester) async {
      await s.h.invoke('sheets.insert.smartChip', {
        'kind': 'person',
        'email': 'bo@x.com',
        'name': 'Bo',
        'cell': 'A1',
      }, InvocationSource.mcp);
      await pumpSheets(
        tester,
        s,
        dark: dark,
        child: GridArea(controller: s.editor, services: s.services),
      );
      await tester.pump();

      expect(
        s.editor.layers.content.whereType<PersonChipLayer>(),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
