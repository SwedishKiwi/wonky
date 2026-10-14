import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/print/page_break_canvas.dart';
import 'package:wonky_sheets/features/print/print_controller.dart';
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
  });
  tearDown(() => s.dispose());

  Future<PrintController> pumpBreaks(
    WidgetTester tester, {
    bool dark = false,
    Size size = const Size(1280, 900),
  }) async {
    await pumpSheets(
      tester,
      s,
      dark: dark,
      size: size,
      child: SheetsPrintPreviewScreen(
        services: s.services,
        itemUuid: testItemUuid,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    final c = PrintController.current!;
    c.breakMode = true;
    await tester.pump(const Duration(milliseconds: 100));
    return c;
  }

  Offset origin(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(const ValueKey('print.breakCanvas.paint')));

  Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
    final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await tester.pump();
    for (var i = 1; i <= 5; i++) {
      await g.moveTo(Offset.lerp(from, to, i / 5)!);
      await tester.pump();
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final dark in [false, true]) {
    for (final width in [1280.0, 380.0]) {
      testWidgets('Given break mode (${dark ? 'dark' : 'light'}, '
          '${width.toInt()} px) when it opens then the grid with the '
          'automatic break renders without errors', (tester) async {
        await pumpBreaks(tester, dark: dark, size: Size(width, 900));

        expect(find.byKey(const ValueKey('print.breakCanvas')), findsOne);
        final g = PageBreakCanvas.lastGeometry!;
        expect(g.autoRows, isNotEmpty);
        expect(g.customRows, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Given the automatic break when it is dragged up then it '
      'becomes a custom break there, and confirming stores it as one undo '
      'step', (tester) async {
    final c = await pumpBreaks(tester, size: const Size(1280, 1900));
    final g = PageBreakCanvas.lastGeometry!;
    final auto = g.autoRows.first;
    final o = origin(tester);
    final x = BreakGeometry.headerW + 30;

    await drag(
      tester,
      o + Offset(x, g.rowTops[auto]),
      o + Offset(x, g.rowTops[20] + 1),
    );

    final rowId = s.sheet.rows.idAt(g.rows[20]);
    expect(c.draftRowBreaks, [rowId]);
    expect(PageBreakCanvas.lastGeometry!.customRows, {20});

    await c.confirmBreaks();
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.breakMode, isFalse);
    expect(c.settings.rowBreaks, [rowId]);
    expect(c.pages.first.rows.last, g.rows[19]);

    await s.undo();
    expect(c.settings.rowBreaks, isEmpty);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Given a custom break when it is dragged off the grid then it '
      'is removed; clicking a row number adds one', (tester) async {
    final c = await pumpBreaks(tester);
    var g = PageBreakCanvas.lastGeometry!;
    final o = origin(tester);

    // Click on the number of row 11 → a break before it.
    await tester.tapAt(
      o + Offset(BreakGeometry.headerW / 2, g.rowTops[10] + 4),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.draftRowBreaks, [s.sheet.rows.idAt(g.rows[10])]);

    g = PageBreakCanvas.lastGeometry!;
    final x = BreakGeometry.headerW + 30;
    await drag(
      tester,
      o + Offset(x, g.rowTops[10]),
      o + Offset(x, BreakGeometry.headerH / 2),
    );

    expect(c.draftRowBreaks, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Given the settings panel when "Use dark theme" is checked then '
      'the dark PDF differs from the light one', (tester) async {
    await pumpSheets(
      tester,
      s,
      size: const Size(1280, 900),
      child: SheetsPrintPreviewScreen(
        services: s.services,
        itemUuid: testItemUuid,
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    final c = PrintController.current!;

    await tester.ensureVisible(find.byKey(const ValueKey('print.darkTheme')));
    await tester.tap(find.byKey(const ValueKey('print.darkTheme')));
    await tester.pump();
    expect(c.darkTheme, isTrue);

    final (light, dark) = (await tester.runAsync(
      () async => (await c.buildPdf(), await c.buildPdf(darkTheme: true)),
    ))!;
    expect(dark, isNot(equals(light)));
    expect(dark.length, greaterThan(light.length));
  });

  testWidgets('when printing without a native print plugin then the '
      'command reports it and offers Export PDF', (tester) async {
    await pumpSheets(
      tester,
      s,
      size: const Size(1280, 900),
      child: SheetsPrintPreviewScreen(
        services: s.services,
        itemUuid: testItemUuid,
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    final r = (await tester.runAsync(() => s.run('sheets.print.print')))!;

    expect(r.isOk, isTrue, reason: r.message);
    expect((r.data as Map?)?['printed'], isFalse);
  });
}
