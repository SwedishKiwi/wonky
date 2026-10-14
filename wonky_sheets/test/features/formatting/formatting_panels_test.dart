import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/banding/banding_panel.dart';
import 'package:wonky_sheets/features/conditional_format/cf_panel.dart';
import 'package:wonky_sheets/features/formatting/formatting_features.dart';
import 'package:wonky_sheets/features/theme/theme_panel.dart';

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

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('Given a rule, when the CF panel opens at 360 px ($mode) '
        'then the list and every editor tab render without overflow', (
      tester,
    ) async {
      await s.run('sheets.cf.addRule', {
        'ranges': ['A1:A2'],
        'rule': {
          'v': 1,
          'type': 'boolean',
          'condition': {'type': 'notBlank'},
          'format': {'fillColor': '#B7E1CD'},
        },
      });
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(400, 800),
        child: panel(CfPanel(services: s.services, editor: s.editor)),
      );
      expect(find.byKey(const ValueKey<String>('cf.panel.list')), findsOne);
      await tester.tap(find.byKey(const ValueKey<String>('cf.add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('cf.panel.editor')), findsOne);
      // The four rule kinds share one row (no lone segment on a 2nd line).
      final tops = {
        for (final k in ['single', 'colorScale', 'dataBar', 'iconSet'])
          tester.getTopLeft(find.byKey(ValueKey<String>('cf.kind.$k'))).dy,
      };
      expect(tops, hasLength(1));
      for (final k in ['colorScale', 'dataBar', 'iconSet', 'single']) {
        await tester.tap(find.byKey(ValueKey<String>('cf.kind.$k')));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      // The draft previews on the grid.
      expect(FormattingFeatures.of(s.editor).cf.draft, isNotNull);
    });

    testWidgets('when the banding and theme panels open ($mode) then they '
        'render and preview', (tester) async {
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(400, 800),
        child: panel(BandingPanel(services: s.services, editor: s.editor)),
      );
      await tester.pumpAndSettle();
      expect(FormattingFeatures.of(s.editor).banding.draft, isNotNull);
      await tester.tap(find.byKey(const ValueKey<String>('banding.preset.3')));
      await tester.pumpAndSettle();

      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(400, 800),
        child: panel(ThemePanel(services: s.services, editor: s.editor)),
      );
      await tester.pumpAndSettle();
      final ocean = find.byKey(const ValueKey<String>('theme.preset.Ocean'));
      await tester.ensureVisible(ocean);
      await tester.pumpAndSettle();
      await tester.tap(ocean);
      await tester.pumpAndSettle();
      expect(s.model.previewTheme?.name, 'Ocean');
      expect(tester.takeException(), isNull);
    });
  }
}
