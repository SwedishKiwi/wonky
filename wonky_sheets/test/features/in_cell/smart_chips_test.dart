import 'dart:ui' show PictureRecorder;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide RichText;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wonky_client/wonky_client.dart' show DriveItemKind;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets/features/formatting/rich_text_paint.dart';
import 'package:wonky_sheets/features/grid/paint/text_layout_cache.dart';
import 'package:wonky_sheets/features/grid/grid_area.dart';
import 'package:wonky_sheets/features/in_cell/cell_features.dart';
import 'package:wonky_sheets/features/in_cell/in_cell_controller.dart';
import 'package:wonky_sheets/features/in_cell/smart_chips.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() {
    s = SheetsHarness.open();
    attachCellFeatures(s.editor);
  });
  tearDown(() => s.dispose());

  test('Given a cell when inserting a person chip then it holds rich text '
      'with the chip, in one undo step', () async {
    final r = await s.h.invoke('sheets.insert.smartChip', {
      'kind': 'person',
      'email': 'ann@x.com',
      'name': 'Ann Lee',
      'cell': 'B2',
    }, InvocationSource.mcp);

    expect(r.status, CommandStatus.ok, reason: r.message);
    expect(s.text('B2'), 'Ann Lee');
    final chip = PersonChip.of(s.sheet.cellAt(1, 1)?.decoded);
    expect(chip, const PersonChip(email: 'ann@x.com', name: 'Ann Lee'));
    expect(
      InCellController.of(
        s.editor,
      ).infoAt(s.sheetId, 1, 1, hover: true)?.person,
      chip,
    );
    await s.undo();
    expect(s.content('B2'), isNull);
  });

  test(
    'Given a cell when inserting a date chip then a date is written',
    () async {
      final r = await s.h.invoke('sheets.insert.smartChip', {
        'kind': 'date',
        'date': '2026-03-04',
        'cell': 'C3',
      }, InvocationSource.mcp);

      expect(r.status, CommandStatus.ok, reason: r.message);
      expect(s.sheet.cellAt(2, 2)?.decoded, isA<NumberContent>());
    },
  );

  for (final dark in [false, true]) {
    testWidgets('Given the grid (${dark ? 'dark' : 'light'}) when typing @ '
        'into a cell then the chip menu opens, and its text entry keeps '
        '"@home" as plain text', (tester) async {
      await pumpSheets(tester, s, dark: dark);
      await s.select('B2');
      s.editor.gridFocus.requestFocus();
      await tester.pump();

      await typeChars(tester, s.editor.editor, '@');
      await tester.pumpAndSettle();

      expect(s.editor.editor.isEditing, isFalse);
      expect(
        InCellController.of(s.editor).popup.value?.kind,
        CellPopupKind.smartChip,
      );
      expect(
        find.byKey(const ValueKey<String>('sheets.smartChip.search')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('sheets.smartChip.search')),
        'home',
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(s.text('B2'), '@home');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Given person and file chips, also inside other text '
        '(${dark ? 'dark' : 'light'}), when the grid paints then they are '
        'laid out as rich runs by the cell layer', (tester) async {
      await s.h.invoke('sheets.insert.smartChip', {
        'kind': 'person',
        'email': 'bo@x.com',
        'name': 'Bo',
        'cell': 'A1',
      }, InvocationSource.mcp);
      await s.h.invoke('sheets.insert.smartChip', {
        'kind': 'file',
        'uuid': '01923456-789a-7bcd-8ef0-000000000001',
        'name': 'Roadmap',
        'itemKind': 'document',
        'cell': 'A2',
      }, InvocationSource.mcp);
      // "Owner: " + a person chip in one cell.
      s.session.execute(
        SetCellInputs(
          sheetId: s.sheetId,
          row: 2,
          col: 0,
          inputs: [
            [
              CellInput.content(
                RichTextContent(
                  RichText('Owner: Ann', [
                    RichRun(7, 10, {
                      RichRunKeys.chip: {'kind': 'person', 'email': 'a@x.com'},
                    }),
                  ]),
                ),
              ),
            ],
          ],
        ),
      );
      await pumpSheets(
        tester,
        s,
        dark: dark,
        child: GridArea(controller: s.editor, services: s.services),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final p = richTextLayouts.layout(
        RichText('Owner: Ann', [
          RichRun(7, 10, {
            RichRunKeys.chip: {'kind': 'person', 'email': 'a@x.com'},
          }),
        ]),
        const GridTextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: Color(0xFF000000),
        ),
        pxPerPoint: 4 / 3,
        linkColor: const Color(0xFF0000FF),
        resolveColor: (c) => c,
      );
      final spans = RichChipSpan.of(p);
      expect(spans.single.kind, 'person');
      expect(spans.single.label, 'Ann');
      expect(spans.single.start, 7);
      expect(spans.single.end, 7 + 1 + 3 + 1);
      expect(p.getBoxesForPlaceholders(), hasLength(2));
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      paintRichChipsBehind(canvas, p, Offset.zero, const Color(0xFFE8EAED));
      canvas.drawParagraph(p, Offset.zero);
      paintRichChipsFront(canvas, p, Offset.zero);
      recorder.endRecording().dispose();
      expect(PersonChip.of(s.sheet.cellAt(2, 0)?.decoded)?.name, 'Ann');
      await tester.pump(const Duration(seconds: 1));
    });
  }

  test('Given a file chip when its card opens the file then the drive item '
      'opens in this window', () async {
    final uuid = s.h.drive
        .seed(name: 'Roadmap', kind: DriveItemKind.spreadsheet)
        .uuid;
    final r = await s.h.invoke('sheets.insert.smartChip', {
      'kind': 'file',
      'uuid': uuid.uuid,
      'cell': 'B3',
    }, InvocationSource.mcp);
    expect(r.status, CommandStatus.ok, reason: r.message);
    expect(s.text('B3'), 'Roadmap');
    final info = InCellController.of(
      s.editor,
    ).infoAt(s.sheetId, 2, 1, hover: true);
    expect(
      info?.file,
      FileChip(uuid: uuid.uuid, name: 'Roadmap', itemKind: 'spreadsheet'),
    );

    final visited = <String>[];
    s.services.router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/s/:id',
          builder: (_, st) {
            visited.add(st.uri.path);
            return const SizedBox();
          },
        ),
      ],
    );
    final open = await s.h.invoke('sheets.chip.openFile', {
      'uuid': uuid.uuid,
    }, InvocationSource.mcp);
    expect(open.status, CommandStatus.ok, reason: open.message);
    expect((open.data! as Map)['kind'], 'spreadsheet');
    expect(
      s.services.router.routeInformationProvider.value.uri.path,
      '/s/${uuid.uuid}',
    );
  });
}
