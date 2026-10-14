import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/scripts/executions_panel.dart';

import '../../support/grid_pump.dart';
import 'script_test_support.dart';

const _main = r'''
import 'package:wonky/wonky.dart';

void ok() {
  Logger.log('all good');
}

void boom() {
  throw StateError('kaput');
}
''';

void main() {
  for (final dark in [false, true]) {
    testWidgets('Given runs in ${dark ? 'dark' : 'light'} mode at 360 px then '
        'the executions panel lists them and a row expands to logs and the '
        'error', (tester) async {
      final h = (await tester.runAsync(() async {
        final h = await ScriptHarness.open({'main.dart': _main});
        await h.s.run('sheets.script.run', {'functionName': 'ok'});
        await h.s.run('sheets.script.run', {'functionName': 'boom'});
        return h;
      }))!;
      addTearDown(() => tester.runAsync(h.dispose));
      await pumpSheets(
        tester,
        h.s,
        dark: dark,
        size: const Size(360, 640),
        child: ScriptExecutionsView(editor: h.s.editor, showTitle: true),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      final rows = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('executions.row.'),
      );
      expect(rows, findsNWidgets(2));
      expect(find.text('Failed'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('boom'));
      await tester.pumpAndSettle();
      expect(find.textContaining('kaput'), findsWidgets);

      await tester.tap(find.text('ok'));
      await tester.pumpAndSettle();
      expect(find.textContaining('all good'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
