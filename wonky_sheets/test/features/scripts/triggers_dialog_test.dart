import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets/features/scripts/script_project.dart';
import 'package:wonky_sheets/features/scripts/triggers_dialog.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

import '../../support/grid_pump.dart';
import 'script_test_support.dart';

const _main = r'''
import 'package:wonky/wonky.dart';

void dailySummary() {}

void archive() {}
''';

Future<ScriptHarness> _open(WidgetTester tester) async {
  final h = (await tester.runAsync(() async {
    final h = await ScriptHarness.open({'main.dart': _main});
    h.backend.granted = {ScriptScopes.triggers};
    await h.svc.refreshGrant();
    return h;
  }))!;
  addTearDown(() => tester.runAsync(h.dispose));
  return h;
}

Future<void> _pumpDialog(
  WidgetTester tester,
  ScriptHarness h, {
  bool dark = false,
  Size size = const Size(1000, 700),
}) async {
  await pumpSheets(
    tester,
    h.s,
    dark: dark,
    size: size,
    child: Builder(
      builder: (context) => Center(
        child: ShadButton(
          key: const ValueKey('open'),
          onPressed: () => showTriggersDialog(context, h.s.editor),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('Given no triggers in ${dark ? 'dark' : 'light'} mode then the '
        'dialog says so', (tester) async {
      final h = await _open(tester);
      await _pumpDialog(tester, h, dark: dark);

      expect(find.byKey(const ValueKey('dialog.triggers')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dialog.triggers.empty')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Given a time-driven trigger then the dialog lists it with its '
      'schedule, and the switch and delete button change the row', (
    tester,
  ) async {
    final h = await _open(tester);
    await tester.runAsync(
      () => h.s.run('sheets.script.addTrigger', {
        'functionName': 'dailySummary',
        'event': 'timeDriven',
        'schedule': {'type': 'days', 'interval': 1, 'atHour': 9},
      }),
    );
    final id = ScriptProjectRows.triggers(h.s.model).single.id;
    await _pumpDialog(tester, h, size: const Size(360, 700));

    expect(find.byKey(ValueKey('dialog.triggers.row.$id')), findsOneWidget);
    expect(find.textContaining('Every 1 day(s) at 9:00'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(ValueKey('dialog.triggers.enabled.$id')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(
      ScriptProjectRows.triggers(h.s.model).single.columns[ScriptCols.enabled],
      isFalse,
    );

    await tester.tap(find.byKey(ValueKey('dialog.triggers.delete.$id')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(ScriptProjectRows.triggers(h.s.model), isEmpty);
    expect(find.byKey(const ValueKey('dialog.triggers.empty')), findsOneWidget);
    // Let tooltip timers elapse.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Given the Add trigger form then saving returns an onEdit '
      'trigger with its options, which the command stores', (tester) async {
    final h = await _open(tester);
    TriggerDraft? draft;
    await pumpSheets(
      tester,
      h.s,
      size: const Size(360, 800),
      child: Builder(
        builder: (context) => Center(
          child: ShadButton(
            key: const ValueKey('add'),
            onPressed: () async =>
                draft = await showAddTriggerDialog(context, h.s.editor),
            child: const Text('add'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('add')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final form = h.s.services.openDialogs.last;
    expect(form.describe()['title'], 'Add trigger');
    expect(form.setField('function', 'archive'), isTrue);
    expect(form.setField('event', 'onEdit'), isTrue);
    expect(form.setField('fireForMcp', true), isTrue);
    expect(form.press('save'), isTrue);
    await tester.pumpAndSettle();

    expect(draft?.functionName, 'archive');
    expect(draft?.event, 'onEdit');
    expect(draft?.schedule, isNull);
    expect(draft?.options?['fireForMcp'], isTrue);

    await tester.runAsync(
      () => h.s.run('sheets.script.addTrigger', {
        'functionName': draft!.functionName,
        'event': draft!.event,
        'options': draft!.options,
      }),
    );
    final row = ScriptProjectRows.triggers(h.s.model).single;
    expect(row.columns[ScriptCols.kind], 'onEdit');
    expect('${row.columns[ScriptCols.optionsJson]}', contains('fireForMcp'));
    await tester.pump(const Duration(seconds: 2));
  });
}
