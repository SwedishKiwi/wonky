import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart' show MemoryStore;
import 'package:wonky_sheets/features/model/local_view_state.dart';
import 'package:wonky_sheets/features/sheet_editor/sheet_editor_controller.dart';
import 'package:wonky_sheets/features/sheet_editor/view_state_binding.dart';

import '../../support/sheets_harness.dart';

void main() {
  group('Side panel restore precedence', () {
    Future<(SheetsHarness, LocalViewStateStore)> saved(String panel) async {
      final s = SheetsHarness.open();
      final store = LocalViewStateStore(MemoryStore());
      final first = ViewStateBinding.attach(s.editor, store);
      s.services.panels.open(panel);
      await first.save();
      s.services.panels.close();
      return (s, store);
    }

    testWidgets('Given a spreadsheet saved with the CF panel open, when it '
        'is opened while a panel of the previous document is still open, '
        'then the saved panel replaces it', (tester) async {
      final (s, store) = await saved('sheets.panel.cf');
      s.services.panels.open('shell.comments');

      final again = SheetEditorController(
        services: s.services,
        session: s.session,
      );
      ViewStateBinding.attach(again, store);
      tester.binding.scheduleFrame();
      await tester.pump();

      expect(s.services.panels.activePanelId, 'sheets.panel.cf');
      again.dispose();
      await s.dispose();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Given a saved panel, when the spreadsheet opens another '
        'panel while it starts (a deep link), then that panel wins', (
      tester,
    ) async {
      final (s, store) = await saved('sheets.panel.cf');

      final again = SheetEditorController(
        services: s.services,
        session: s.session,
      );
      ViewStateBinding.attach(again, store);
      // e.g. `?comment=` opening the comments panel before the first frame.
      s.services.panels.open('shell.comments');
      tester.binding.scheduleFrame();
      await tester.pump();

      expect(s.services.panels.activePanelId, 'shell.comments');
      again.dispose();
      await s.dispose();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Given a spreadsheet saved without a panel, when it opens '
        'while another panel is open, then that panel stays', (tester) async {
      final s = SheetsHarness.open();
      final store = LocalViewStateStore(MemoryStore());
      await ViewStateBinding.attach(s.editor, store).save();
      s.services.panels.open('shell.comments');

      final again = SheetEditorController(
        services: s.services,
        session: s.session,
      );
      ViewStateBinding.attach(again, store);
      tester.binding.scheduleFrame();
      await tester.pump();

      expect(s.services.panels.activePanelId, 'shell.comments');
      again.dispose();
      await s.dispose();
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
