import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets/features/grid/grid_area.dart';
import 'package:wonky_sheets/features/macros/macro_recording_bar.dart';
import 'package:wonky_sheets/features/macros/macro_service.dart';
import 'package:wonky_sheets/features/scripts/runtime/script_ui.dart';
import 'package:wonky_sheets/l10n/sheets_l10n.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';
import '../scripts/script_test_support.dart';

const _main = r'''
import 'package:wonky/wonky.dart';

void stamp() {
  SpreadsheetApp.activeSheet.getRange('C1').value = 'stamped';
}
''';

/// The shell app with the services' navigator key (dialogs of the script
/// UI delegate use `services.navigatorContext`).
Future<void> _pumpApp(
  WidgetTester tester,
  SheetsHarness s,
  Widget child, {
  bool dark = false,
}) async {
  await tester.pumpWidget(
    Provider<ShellServices>.value(
      value: s.services,
      child: ShadApp(
        navigatorKey: s.services.navigatorKey,
        theme: dark ? WonkyTheme.dark() : WonkyTheme.light(),
        localizationsDelegates: const [
          WonkyAppLocalizations.delegate,
          WonkyUiLocalizations.delegate,
          SheetsLocalizations.delegate,
        ],
        home: Material(type: MaterialType.transparency, child: child),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('Given a recording in ${dark ? 'dark' : 'light'} mode at 360 '
        'px then the bar shows the count, modes, Save and Cancel', (
      tester,
    ) async {
      final h = (await tester.runAsync(
        () => ScriptHarness.open({'main.dart': _main}),
      ))!;
      addTearDown(() => tester.runAsync(h.dispose));
      final svc = MacroService.of(h.s.editor)..startRecording();
      await pumpSheets(
        tester,
        h.s,
        dark: dark,
        size: const Size(360, 640),
        child: MacroRecordingOverlay(editor: h.s.editor),
      );

      expect(find.byKey(const ValueKey('macro.recordingBar')), findsOneWidget);
      expect(find.text('Recording new macro…'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const ValueKey('macro.recording.mode.relative')),
      );
      await tester.pump();
      expect(svc.mode, MacroReferenceMode.relative);

      await tester.tap(find.byKey(const ValueKey('macro.recording.cancel')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(svc.recording, isFalse);
      expect(find.byKey(const ValueKey('macro.recordingBar')), findsNothing);
    });
  }

  testWidgets('Given a macro on slot 3 when Mod+Alt+Shift+3 is pressed in '
      'the grid then the macro runs', (tester) async {
    final h = (await tester.runAsync(() async {
      final h = await ScriptHarness.open({'main.dart': _main});
      await h.s.run('sheets.macro.import', {
        'functionName': 'stamp',
        'name': 'Stamp',
        'shortcutSlot': 3,
      });
      return h;
    }))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await pumpSheets(tester, h.s);
    h.s.editor.gridFocus.requestFocus();
    await tester.pump();
    expect(find.byType(GridArea), findsOneWidget);

    await tester.runAsync(() async {
      await simulateKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await simulateKeyDownEvent(LogicalKeyboardKey.altLeft);
      await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await simulateKeyDownEvent(LogicalKeyboardKey.digit3);
      await simulateKeyUpEvent(LogicalKeyboardKey.digit3);
      await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await simulateKeyUpEvent(LogicalKeyboardKey.altLeft);
      await simulateKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await pumpScripts(20);
    });
    await tester.pump();

    expect(h.s.text('C1'), 'stamped');
  });

  testWidgets('Given a script alert with Yes/No then a dialog asks and the '
      'answer goes back to the script', (tester) async {
    final h = (await tester.runAsync(
      () => ScriptHarness.open({'main.dart': _main}),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await _pumpApp(tester, h.s, const SizedBox());
    final ui = AppScriptUi(h.s.editor, onMenu: (_) {});

    final answer = ui.showDialog(
      const ScriptDialogRequest(
        title: 'Archive',
        message: 'Archive 3 rows?',
        buttons: ScriptButtonSet.yesNo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Archive 3 rows?'), findsOneWidget);
    final dialog = h.s.services.openDialogs.last;
    expect(dialog.describe()['title'], 'Archive');
    dialog.press('yes');
    await tester.pumpAndSettle();

    expect((await answer).button, ScriptButton.yes);
  });

  testWidgets('Given a script prompt then the typed text comes back', (
    tester,
  ) async {
    final h = (await tester.runAsync(
      () => ScriptHarness.open({'main.dart': _main}),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await _pumpApp(tester, h.s, const SizedBox(), dark: true);
    final ui = AppScriptUi(h.s.editor, onMenu: (_) {});

    final answer = ui.showDialog(
      const ScriptDialogRequest(
        message: 'Your name?',
        buttons: ScriptButtonSet.okCancel,
        prompt: true,
      ),
    );
    await tester.pumpAndSettle();
    final dialog = h.s.services.openDialogs.last;
    dialog.setField('text', 'Bo');
    dialog.press('ok');
    await tester.pumpAndSettle();

    final r = await answer;
    expect(r.button, ScriptButton.ok);
    expect(r.text, 'Bo');
  });
}
