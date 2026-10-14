import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

/// Keyboard map of 03 §7: each chord dispatches the expected command.
void main() {
  late SheetsHarness s;
  late List<(String, Map<String, Object?>)> dispatched;
  late StreamSubscription<Object?> sub;

  setUp(() {
    s = SheetsHarness.open();
    dispatched = [];
    sub = s.services.dispatcher.events.listen(
      (e) => dispatched.add((e.id.value, e.args)),
    );
  });

  tearDown(() async {
    await sub.cancel();
    await s.dispose();
  });

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool ctrl = false,
    bool shift = false,
    bool alt = false,
  }) async {
    if (ctrl) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(key);
    if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (ctrl) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  Future<void> ready(WidgetTester tester) async {
    await pumpSheets(tester, s);
    s.editor.gridFocus.requestFocus();
    await tester.pump();
  }

  final cases =
      <
        (
          String,
          LogicalKeyboardKey,
          bool,
          bool,
          bool,
          String,
          Map<String, Object?>,
        )
      >[
        (
          '↓',
          LogicalKeyboardKey.arrowDown,
          false,
          false,
          false,
          'sheets.nav.move',
          {'dir': 'down'},
        ),
        (
          'Shift+→',
          LogicalKeyboardKey.arrowRight,
          false,
          true,
          false,
          'sheets.nav.move',
          {'dir': 'right', 'extend': true},
        ),
        (
          'Ctrl+↓',
          LogicalKeyboardKey.arrowDown,
          true,
          false,
          false,
          'sheets.nav.move',
          {'dir': 'down', 'toEdge': true},
        ),
        (
          'Tab',
          LogicalKeyboardKey.tab,
          false,
          false,
          false,
          'sheets.nav.tab',
          {},
        ),
        (
          'Enter',
          LogicalKeyboardKey.enter,
          false,
          false,
          false,
          'sheets.nav.enter',
          {},
        ),
        (
          'Home',
          LogicalKeyboardKey.home,
          false,
          false,
          false,
          'sheets.nav.rowStart',
          {},
        ),
        (
          'Ctrl+End',
          LogicalKeyboardKey.end,
          true,
          false,
          false,
          'sheets.nav.sheetEnd',
          {},
        ),
        (
          'PageDown',
          LogicalKeyboardKey.pageDown,
          false,
          false,
          false,
          'sheets.nav.page',
          {'dir': 'down'},
        ),
        (
          'Ctrl+A',
          LogicalKeyboardKey.keyA,
          true,
          false,
          false,
          'sheets.select.all',
          {},
        ),
        (
          'Shift+Space',
          LogicalKeyboardKey.space,
          false,
          true,
          false,
          'sheets.select.rows',
          {},
        ),
        (
          'F2',
          LogicalKeyboardKey.f2,
          false,
          false,
          false,
          'sheets.cell.edit',
          {},
        ),
        (
          'Delete',
          LogicalKeyboardKey.delete,
          false,
          false,
          false,
          'sheets.edit.clearValues',
          {},
        ),
        (
          'Ctrl+D',
          LogicalKeyboardKey.keyD,
          true,
          false,
          false,
          'sheets.fill.down',
          {},
        ),
        (
          'Ctrl+B',
          LogicalKeyboardKey.keyB,
          true,
          false,
          false,
          'sheets.format.bold',
          {},
        ),
        (
          'Ctrl+Shift+4',
          LogicalKeyboardKey.digit4,
          true,
          true,
          false,
          'sheets.format.numberFormat',
          {'preset': 'currency'},
        ),
        (
          'Ctrl+\\',
          LogicalKeyboardKey.backslash,
          true,
          false,
          false,
          'sheets.format.clear',
          {},
        ),
        (
          'Shift+F11',
          LogicalKeyboardKey.f11,
          false,
          true,
          false,
          'sheets.sheet.add',
          {},
        ),
      ];

  for (final (name, key, ctrl, shift, alt, id, args) in cases) {
    testWidgets('Given the grid focused when pressing $name then $id runs', (
      tester,
    ) async {
      await ready(tester);

      await press(tester, key, ctrl: ctrl, shift: shift, alt: alt);

      expect(dispatched.map((d) => d.$1), contains(id));
      final match = dispatched.firstWhere((d) => d.$1 == id);
      expect(match.$2, args);
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('Given a value in A1 when pressing Ctrl+↓ on A1 with data in '
      'A1:A3 and A6 then the active cell visits A3, A6, then the last row', (
    tester,
  ) async {
    await s.type('A1', '1');
    await s.type('A2', '2');
    await s.type('A3', '3');
    await s.type('A6', '6');
    await s.select('A1');
    await ready(tester);

    await press(tester, LogicalKeyboardKey.arrowDown, ctrl: true);
    expect(s.editor.activeA1, 'A3');
    await press(tester, LogicalKeyboardKey.arrowDown, ctrl: true);
    expect(s.editor.activeA1, 'A6');
    await press(tester, LogicalKeyboardKey.arrowDown, ctrl: true);
    expect(s.editor.activeA1, 'A${s.sheet.rows.length}');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Given a 3×2 selection when pressing Enter then the active cell '
      'cycles through the selection without changing it (AC-E6)', (
    tester,
  ) async {
    await s.select('A1:B3');
    await ready(tester);

    final visited = <String>[];
    for (var i = 0; i < 6; i++) {
      await press(tester, LogicalKeyboardKey.enter);
      visited.add(s.editor.activeA1);
    }

    expect(visited, ['A2', 'A3', 'B1', 'B2', 'B3', 'A1']);
    expect(s.editor.selection.describe(), 'A1:B3');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Given editing a formula when pressing arrows in Enter mode then '
      'a reference is pointed, and F4 cycles it absolute', (tester) async {
    await s.select('B2');
    await ready(tester);

    await typeChars(tester, s.editor.editor, '=');
    expect(s.editor.editor.text.text, '=');
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(s.editor.editor.text.text, '=B1');
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(s.editor.editor.text.text, '=A1');
    await press(tester, LogicalKeyboardKey.f4);
    expect(s.editor.editor.text.text, r'=$A$1');
    await press(tester, LogicalKeyboardKey.escape);
    expect(s.editor.editor.isEditing, isFalse);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Given typing =su when pressing Tab then SUM( is inserted and '
      'Enter commits with the closing parenthesis (AC-E1)', (tester) async {
    await s.type('A1', '2');
    await s.type('A2', '5');
    await s.select('A3');
    await ready(tester);

    await typeChars(tester, s.editor.editor, '=');
    await typeChars(tester, s.editor.editor, 'su');
    expect(s.editor.editor.showCompletions, isTrue);
    expect(s.editor.editor.completions.items.first.name, 'SUM');
    await press(tester, LogicalKeyboardKey.tab);
    expect(s.editor.editor.text.text, '=SUM(');
    s.editor.editor.pointAt(const GridRect(0, 0, 1, 0));
    await press(tester, LogicalKeyboardKey.enter);
    await tester.pump();

    expect(s.text('A3'), '7');
    expect(s.editor.editableText(2, 0), '=SUM(A1:A2)');
    await tester.pump(const Duration(seconds: 1));
  });
}
