import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:wonky_sheets/features/scripts/editor/script_editor_screen.dart';
import 'package:wonky_sheets/features/scripts/script_project.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';
import 'script_test_support.dart';

const _main = r'''
import 'package:wonky/wonky.dart';

/// @customfunction
Object? TWICE(Object? x) => x is num ? x * 2 : null;

void hello() {
  SpreadsheetApp.active.toast('Hi');
}
''';

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('Given the script editor in $mode mode then it shows the '
        'files, functions, code and problems', (tester) async {
      final h = (await tester.runAsync(
        () => ScriptHarness.open({'main.dart': _main}),
      ))!;
      addTearDown(() => tester.runAsync(h.dispose));
      await pumpSheets(
        tester,
        h.s,
        dark: dark,
        size: const Size(1280, 800),
        child: ScriptEditorScreen(
          services: h.s.services,
          itemUuid: testItemUuid,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const ValueKey('sheets.scriptEditor')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('script.file.main.dart')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('script.function.hello')),
        findsOneWidget,
      );
      expect(find.byType(CodeEditor), findsOneWidget);
      expect(find.byKey(const ValueKey('script.run')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('script.problems.empty')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Given a narrow window then the file rail becomes a dropdown', (
    tester,
  ) async {
    final h = (await tester.runAsync(
      () => ScriptHarness.open({'main.dart': _main}),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await pumpSheets(
      tester,
      h.s,
      size: const Size(700, 700),
      child: ScriptEditorScreen(services: h.s.services, itemUuid: testItemUuid),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('script.rail')), findsNothing);
    expect(find.byKey(const ValueKey('script.fileSelect')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Given an edited file then the dirty dot shows and saving '
      'clears it', (tester) async {
    final h = (await tester.runAsync(
      () => ScriptHarness.open({'main.dart': _main}),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await pumpSheets(
      tester,
      h.s,
      size: const Size(1280, 800),
      child: ScriptEditorScreen(services: h.s.services, itemUuid: testItemUuid),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final main = ScriptProjectRows.fileNamed(h.s.model, 'main.dart')!;

    h.svc.setDraft(main.id, '$_main\nvoid more() {}\n');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('script.file.main.dart.dirty')),
      findsOneWidget,
    );

    await tester.runAsync(() => h.svc.save(main.id));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('script.file.main.dart.dirty')),
      findsNothing,
    );
  });
}
