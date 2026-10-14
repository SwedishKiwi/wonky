import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/grid/grid_area.dart';
import 'package:wonky_sheets/features/in_cell/cell_features.dart';
import 'package:wonky_sheets/features/in_cell/spill_blockers_layer.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() {
    s = SheetsHarness.open();
    attachCellFeatures(s.editor);
  });
  tearDown(() => s.dispose());

  test('Given a blocked array when asking for its blockers then the cells '
      'with content in its area are listed', () async {
    await s.type('A1', '=SEQUENCE(4)');
    await s.type('A3', 'x');
    await s.type('A4', 'y');
    expect(s.text('A1'), '#SPILL!');

    final b = spillBlockers(s.editor, s.sheetId, 0, 0);

    expect(b.map((r) => r.a1), ['A3', 'A4']);
    expect(spillBlockers(s.editor, s.sheetId, 2, 0), isEmpty);
  });

  for (final dark in [false, true]) {
    testWidgets('Given a selected #SPILL! anchor (${dark ? 'dark' : 'light'}) '
        'when the grid paints then the blocker outline layer runs without '
        'errors', (tester) async {
      await s.type('B2', '=SEQUENCE(1,3)');
      await s.type('D2', 'z');
      await pumpSheets(
        tester,
        s,
        dark: dark,
        child: GridArea(controller: s.editor, services: s.services),
      );
      await s.select('B2');
      await tester.pump();

      expect(
        s.editor.layers.overlay.whereType<SpillBlockersLayer>(),
        hasLength(1),
      );
      expect(spillBlockers(s.editor, s.sheetId, 1, 1).single.a1, 'D2');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
