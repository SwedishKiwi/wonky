import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sheets/features/grid/grid_area.dart';
import 'package:wonky_sheets/features/grid/paint/layers/loading_layer.dart';
import 'package:wonky_sheets/features/model/memory_workbook_session.dart';
import 'package:wonky_sheets/features/model/row_loading.dart';
import 'package:wonky_sheets/features/sheet_editor/sheet_editor_controller.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

/// A memory session whose rows 100+ are still "streaming in".
class _LoadingSession extends MemoryWorkbookSession {
  _LoadingSession(MemoryWorkbookSession blank)
    : super(
        itemUuid: blank.itemUuid,
        userId: blank.userId,
        model: blank.model,
      ) {
    final sheet = model.sheets.single;
    tracker.track(sheet.id, [
      for (var r = 100; r < sheet.rows.length; r++) sheet.rows.idAt(r),
    ]);
  }

  final RowLoadTracker tracker = RowLoadTracker();

  @override
  WorkbookRowLoading get rowLoading => tracker;
}

void main() {
  late SheetsHarness h;
  late _LoadingSession session;
  late SheetEditorController editor;

  setUp(() {
    h = SheetsHarness.open();
    session = _LoadingSession(
      MemoryWorkbookSession.blank(itemUuid: UuidValue.fromString(testItemUuid)),
    );
    editor = SheetEditorController(services: h.services, session: session);
  });

  tearDown(() async {
    editor.dispose();
    await h.dispose();
  });

  bool hasLayer() => editor.layers.overlay.any((l) => l is LoadingLayer);

  test('Given rows still loading, then the skeleton layer is installed, '
      'typing there is refused and the rest is editable; when loading '
      'completes the layer goes away', () {
    expect(hasLayer(), isTrue);
    expect(
      editor.editRefusalAt(150, 0),
      'Still loading this part of the sheet…',
    );
    expect(editor.editRefusalAt(5, 0), isNull);

    session.tracker.finish();

    expect(hasLayer(), isFalse);
    expect(editor.editRefusalAt(150, 0), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'Given the grid scrolled to loading rows (${dark ? 'dark' : 'light'}) '
      'then it paints the skeleton and asks for those rows first',
      (tester) async {
        final requests = <(String, int, int)>[];
        session.tracker.onRequest = () {
          final r = session.tracker.takeRequest();
          if (r != null) requests.add(r);
        };
        await pumpSheets(
          tester,
          h,
          dark: dark,
          child: GridArea(controller: editor, services: h.services),
        );
        editor.scroll.jumpTo(0, 21.0 * 120);
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(requests, isNotEmpty);
        expect(requests.last.$2, greaterThanOrEqualTo(100));
        session.tracker.finish();
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }
}
