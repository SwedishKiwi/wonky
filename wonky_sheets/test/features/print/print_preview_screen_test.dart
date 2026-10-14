import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/print/print_controller.dart';
import 'package:wonky_sheets/features/print/print_page_painter.dart';
import 'package:wonky_sheets/features/print/print_preview_screen.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() async {
    s = SheetsHarness.open();
    for (var r = 1; r <= 80; r++) {
      await s.type('A$r', 'Row $r');
      await s.type('B$r', '${r * 10}');
    }
    await s.run('sheets.format.bold', {
      'ranges': ['A1:B1'],
    });
  });
  tearDown(() => s.dispose());

  Future<void> pumpPreview(
    WidgetTester tester, {
    bool dark = false,
    Size? size,
  }) async {
    await pumpSheets(
      tester,
      s,
      dark: dark,
      size: size ?? const Size(1280, 900),
      child: SheetsPrintPreviewScreen(
        services: s.services,
        itemUuid: testItemUuid,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final dark in [false, true]) {
    testWidgets('Given the print route in ${dark ? 'dark' : 'light'} mode '
        'when it opens then pages, thumbnails and settings are shown', (
      tester,
    ) async {
      await pumpPreview(tester, dark: dark);

      expect(find.byKey(const ValueKey('print.page.1')), findsOneWidget);
      expect(find.byKey(const ValueKey('print.thumb.1')), findsOneWidget);
      expect(find.byKey(const ValueKey('print.settings')), findsOneWidget);
      expect(find.text('Page 1 of 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Given the print route when switching to landscape then the '
      'setting is stored and the pages re-paginate', (tester) async {
    await pumpPreview(tester);
    final c = PrintController.current!;

    await c.update({'orientation': 'landscape'});
    await tester.pump(const Duration(milliseconds: 300));

    expect(c.pages.first.pageWidth, greaterThan(c.pages.first.pageHeight));
    expect(s.sheet.record?.printSettingsJson, contains('landscape'));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Given a narrow window when the print route opens then it '
      'does not overflow', (tester) async {
    await pumpPreview(tester, size: const Size(380, 800));

    expect(find.byKey(const ValueKey('print.page.1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('print.toggleSettings')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('print.settings')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Given a page with gridlines and headings when painting it '
      'then it paints without errors', (tester) async {
    await s.run('sheets.print.updateSettings', {
      'patch': {'gridlines': true, 'headings': true, 'notes': true},
    });
    final c = PrintController(s.editor);
    addTearDown(c.dispose);
    c.repaginate(immediate: true);
    await pumpPreview(tester);

    expect(find.byType(CustomPaint), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PrintPagePainter,
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}
