import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets/config/sheets_menus.dart';
import 'package:wonky_sheets/features/scripts/runtime/script_runners.dart';
import 'package:wonky_sheets/features/scripts/script_menus.dart';
import 'package:wonky_sheets/features/scripts/script_project.dart';
import 'package:wonky_sheets/features/scripts/script_service.dart';
import 'package:wonky_sheets/l10n/sheets_l10n.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';
import 'script_test_support.dart';

const _main = r'''
import 'package:wonky/wonky.dart';

/// Adds one.
///
/// @customfunction
Object? PLUSONE(Object? x) => x is num ? x + 1 : null;

void onOpen(OpenEvent e) {
  SpreadsheetApp.ui
      .createMenu('Reports')
      .addItem('Build report', 'report')
      .addSeparator()
      .addSubMenu(SpreadsheetApp.ui.createMenu('More').addItem('Clean', 'clean'))
      .addToUi();
}

void report() {}

void clean() {}
''';

void main() {
  testWidgets('Given a script with an onOpen menu then the menubar has the '
      'menu after Extensions and under Extensions, with runMenuItem items', (
    tester,
  ) async {
    final h = (await tester.runAsync(
      () => ScriptHarness.open({'main.dart': _main}),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    late MenuRoot root;
    await pumpSheets(
      tester,
      h.s,
      child: Builder(
        builder: (context) {
          root = withScriptMenus(
            sheetsMenus(
              ShellMenus(WonkyAppLocalizations.of(context)),
              l: sheetsL10n(context),
            ),
            context,
          );
          return const SizedBox();
        },
      ),
    );

    final top = root.find(ScriptMenuIds.scriptMenu(0));
    expect(top, isA<MenuSubmenu>());
    expect((top! as MenuSubmenu).label, 'Reports');
    final ids = [for (final m in root.children) m.effectiveId];
    expect(ids.indexOf('script.menu.0'), ids.indexOf('extensions') + 1);
    final item = root.find('script.menu.0.0');
    expect(item, isA<MenuCommand>());
    expect((item! as MenuCommand).commandId, 'sheets.script.runMenuItem');
    expect((item as MenuCommand).args['functionName'], 'report');
    expect(root.find('script.menu.0.2.0'), isA<MenuCommand>());
    expect(root.find('extensions.script.0'), isA<MenuSubmenu>());
  });

  test('Given the script setting "show menus" off then menus stay under '
      'Extensions only', () async {
    final h = await ScriptHarness.open({'main.dart': _main});
    addTearDown(h.dispose);

    await h.s.run('sheets.script.updateSettings', {
      'patch': {'showMenusInMenubar': false},
    });

    expect(h.svc.showMenusInMenubar, isFalse);
    await h.s.undo();
    expect(h.svc.showMenusInMenubar, isTrue);
  });

  test('Given a built custom function then formula autocomplete and '
      'signature help offer it', () async {
    final h = await ScriptHarness.open({'main.dart': _main});
    addTearDown(h.dispose);
    final ed = h.s.editor;

    ed.editor.begin(initialText: '=PLUS');

    expect(ed.editor.completions.items.map((i) => i.name), contains('PLUSONE'));
  });

  test('Given a spreadsheet without a script when the editor is opened then '
      'the project is created with main.dart and the route changes', () async {
    createScriptRunner = InlineScriptRunner.new;
    final s = SheetsHarness.open();
    addTearDown(s.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/s/:uuid',
          builder: (_, _) => const SizedBox(),
          routes: [
            GoRoute(path: 'script', builder: (_, _) => const SizedBox()),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    s.services.router = router;

    final r = await s.run('sheets.script.openEditor');

    expect(r.isOk, isTrue);
    expect(scriptProjectOf(s.model), isNotNull);
    final main = ScriptProjectRows.fileNamed(s.model, 'main.dart')!;
    expect(ScriptProjectRows.sourceOf(main), scriptTemplate);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/s/$testItemUuid/script',
    );
    expect(ScriptService.maybeOf(s.editor), isNotNull);
  });

  test(
    'Given a viewer without a script then the editor cannot be opened',
    () async {
      final s = SheetsHarness.open(role: Role.viewer);
      addTearDown(s.dispose);

      final state = s.services.dispatcher.stateOf(
        'sheets.script.openEditor',
        {},
      );

      expect(state.enabled, isFalse);
    },
  );
}
