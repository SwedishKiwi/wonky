import 'package:flutter/widgets.dart' hide RichText;
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/formatting/rich_text_editing.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../support/sheets_harness.dart';

void main() {
  group('Given runs on "Total revenue"', () {
    const rich = RichText('Total revenue', [
      RichRun(0, 5, {'bold': true}),
    ]);

    test('when typing after the run then it grows', () {
      final r = RichTextEditing.remapRuns(rich, 'Totals revenue');
      expect(r.runs.single.end, 6);
    });

    test('when typing before the run then it shifts', () {
      final r = RichTextEditing.remapRuns(rich, 'A Total revenue');
      expect((r.runs.single.start, r.runs.single.end), (2, 7));
    });

    test('when deleting inside the run then it shrinks', () {
      final r = RichTextEditing.remapRuns(rich, 'Tal revenue');
      expect((r.runs.single.start, r.runs.single.end), (0, 3));
    });

    test('when replacing the whole text then the run disappears', () {
      expect(RichTextEditing.remapRuns(rich, 'x').runs, isEmpty);
    });
  });

  group('Given a cell being edited', () {
    late SheetsHarness s;
    setUp(() => s = SheetsHarness.open());
    tearDown(() => s.dispose());

    test('when bolding a selected word and committing then the cell stores '
        'a bold run (06 §11)', () async {
      await s.type('A1', 'Total revenue');
      await s.select('A1');
      final ed = s.editor.editor;
      ed.begin();
      ed.text.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      expect(ed.isEditing, isTrue, reason: 'editing');
      expect(ed.text.selection.isCollapsed, isFalse, reason: 'selection');
      final r = await s.run('sheets.format.bold');
      expect(r.isOk, isTrue, reason: '${r.message}');
      expect(
        ed.isEditing,
        isTrue,
        reason: 'still editing; cell bold=${s.format('A1')[FormatAttr.bold]}',
      );
      expect(ed.text.richRuns!.runs.single.format, {'bold': true});
      // The cell itself isn't bold.
      expect(s.format('A1')[FormatAttr.bold], isNull);

      await ed.commit();
      final content = s.model.cellAt(s.sheetId, 0, 0)!.decoded;
      expect(content, isA<RichTextContent>());
      final runs = (content! as RichTextContent).rich.runs;
      expect((runs.single.start, runs.single.end), (0, 5));

      // Editing it again loads the runs.
      await s.select('A1');
      ed.begin();
      expect(ed.text.richRuns!.runs, hasLength(1));
      ed.cancel();
    });

    test('when a number is committed with runs then it is stored as a '
        'number', () async {
      await s.run('sheets.cell.setRichText', {
        'a1': 'B1',
        'text': '42',
        'runs': [
          {
            's': 0,
            'e': 2,
            'f': {'bold': true},
          },
        ],
      });
      expect(s.content('B1'), startsWith('n:'));
    });
  });
}
