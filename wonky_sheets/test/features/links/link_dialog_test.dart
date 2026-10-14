import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets/features/in_cell/cell_features.dart';
import 'package:wonky_sheets/features/links/link_dialog.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';
import '../protection/protection_test.dart' show protectAs;

void main() {
  late SheetsHarness s;

  setUp(() async {
    s = SheetsHarness.open();
    attachCellFeatures(s.editor);
    await s.run('sheets.namedRanges.add', {'name': 'Budget', 'range': 'B2:C9'});
  });
  tearDown(() => s.dispose());

  group('Given a spreadsheet with a named range Budget', () {
    test('when searching link targets then sheets and named ranges match', () {
      final all = linkTargets(s.model, '', activeSheetId: s.sheetId);
      expect(all.map((t) => t.label), [s.sheet.name, 'Budget']);
      expect(all.last.url, '#range=Budget');
      expect(all.last.detail, '${s.sheet.name}!B2:C9');

      final bud = linkTargets(s.model, 'bud', activeSheetId: s.sheetId);
      expect(bud.single.label, 'Budget');
    });

    test('when the query is a range then that range is offered first', () {
      final r = linkTargets(s.model, 'D4:E5', activeSheetId: s.sheetId);
      expect(r.first.url, '#sheet=${s.sheetId}&range=D4:E5');
      expect(r.first.label, '${s.sheet.name}!D4:E5');
    });

    test('when labelling internal links then sheet names are shown', () {
      expect(linkTargetLabel(s.model, '#sheet=${s.sheetId}'), s.sheet.name);
      expect(linkTargetLabel(s.model, 'https://a.b'), isNull);
    });
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('Given the insert link dialog ($theme, 360 px) when '
        'searching and picking a named range then the cell links to it', (
      tester,
    ) async {
      await s.select('A1');
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(360, 700),
        child: const SizedBox.expand(),
      );
      final context = tester.element(find.byType(SizedBox).first);
      final done = s.services.dispatcher.invoke(
        'sheets.insert.link',
        source: InvocationSource.ui,
        context: context,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('dialog.link.url')),
        'bud',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('dialog.link.suggestion.0')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('dialog.link.ok')));
      await tester.pumpAndSettle();
      expect((await done).isOk, isTrue);
      expect(tester.takeException(), isNull);

      final d = s.editor.cells.displayAt(s.sheetId, 0, 0)!;
      expect(d.linkUrl, '#range=Budget');
      expect(d.text, 'Budget');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Given a warning-only protection ($theme) when inserting a '
        'link there and confirming "Heads up!" then the link dialog is not '
        'asked again', (tester) async {
      protectAs(s, 'A1:A5', warningOnly: true);
      await s.select('A2');
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(800, 700),
        child: const SizedBox.expand(),
      );
      final context = tester.element(find.byType(SizedBox).first);
      final done = s.services.dispatcher.invoke(
        'sheets.insert.link',
        source: InvocationSource.ui,
        context: context,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('dialog.link.url')),
        'example.com',
      );
      await tester.tap(find.byKey(const ValueKey<String>('dialog.link.ok')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('dialog.protectedWarning')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('dialog.protectedWarning.ok')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('dialog.link')), findsNothing);
      expect((await done).isOk, isTrue);
      expect(
        s.editor.cells.displayAt(s.sheetId, 1, 0)!.linkUrl,
        'https://example.com',
      );
      // One undo step.
      await s.undo();
      expect(s.editor.cells.displayAt(s.sheetId, 1, 0)?.linkUrl, isNull);
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
