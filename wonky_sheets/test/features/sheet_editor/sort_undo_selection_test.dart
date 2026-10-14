import 'package:flutter_test/flutter_test.dart';

import '../../support/sheets_harness.dart';

void main() {
  for (final (command, select) in [
    ('sheets.data.sortSheet', 'B2'),
    ('sheets.data.sortRange', 'A2:A5'),
  ]) {
    test('Given rows sorted by $command, when the sort is undone and redone '
        'then the selection stays on $select', () async {
      final s = SheetsHarness.open();
      addTearDown(s.dispose);
      for (final (i, v) in ['5', '3', '1', '4', '2'].indexed) {
        await s.type('A${i + 1}', v);
        await s.type('B${i + 1}', 'row $v');
      }
      await s.select(select);

      await s.run(command);
      expect(s.editor.selection.describe(), select);
      await s.undo();
      expect(s.content('A2'), 'n:3');
      expect(s.editor.selection.describe(), select);
      await s.redo();
      expect(s.editor.selection.describe(), select);
    });
  }
}
