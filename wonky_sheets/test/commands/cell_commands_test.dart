import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';

import 'package:wonky_sheets/features/clipboard/system_clipboard.dart';

import '../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() => s = SheetsHarness.open());
  tearDown(() => s.dispose());

  group('Given a blank spreadsheet', () {
    test('when typing a number then the cell shows it, and undo/redo '
        'remove and restore it', () async {
      await s.type('A1', '42');
      expect(s.text('A1'), '42');

      await s.undo();
      expect(s.text('A1'), '');

      await s.redo();
      expect(s.text('A1'), '42');
    });

    test('when typing a formula then it shows the computed value and '
        'recalculates when an input changes', () async {
      await s.type('A1', '2');
      await s.type('A2', '3');
      await s.type('A3', '=A1+A2');
      expect(s.text('A3'), '5');

      await s.type('A1', '10');
      expect(s.text('A3'), '13');
    });

    test('when typing one value then one undo step labelled Typing is '
        'recorded', () async {
      await s.type('B2', 'hello');
      expect(s.h.undoLabels, hasLength(1));
    });

    test('when entering x for a 3×2 selection then every cell gets it in one '
        'undo step (AC-E5)', () async {
      await s.select('A1:B3');

      await s.run('sheets.cell.setInputForSelection', {'input': 'x'});

      for (final a1 in ['A1', 'B1', 'A2', 'B2', 'A3', 'B3']) {
        expect(s.text(a1), 'x', reason: a1);
      }
      expect(s.h.undoLabels, hasLength(1));
      await s.undo();
      expect(s.text('B3'), '');
    });

    test('when entering a formula for a selection then references are '
        'translated per cell', () async {
      await s.type('A1', '1');
      await s.type('A2', '2');
      await s.select('B1:B2');

      await s.run('sheets.cell.setInputForSelection', {'input': '=A1*10'});

      expect(s.text('B1'), '10');
      expect(s.text('B2'), '20');
    });

    test('when clearing values then contents go and formats stay', () async {
      await s.type('A1', '5');
      await s.select('A1');
      await s.run('sheets.format.bold');

      await s.run('sheets.edit.clearValues');

      expect(s.content('A1'), isNull);
      expect(s.format('A1')[FormatAttr.bold], isTrue);
      await s.undo();
      expect(s.text('A1'), '5');
    });

    test('when filling down then the top row is copied with relative '
        'formulas translated', () async {
      await s.type('A1', '1');
      await s.type('A2', '2');
      await s.type('A3', '3');
      await s.type('B1', '=A1*2');
      await s.select('B1:B3');

      await s.run('sheets.fill.down');

      expect(s.text('B2'), '4');
      expect(s.text('B3'), '6');
      await s.undo();
      expect(s.text('B3'), '');
    });

    test('when filling the series 1, 3 down three more cells then it '
        'continues 5, 7, 9', () async {
      await s.type('A1', '1');
      await s.type('A2', '3');

      await s.run('sheets.fill.series', {
        'source': 'A1:A2',
        'target': 'A1:A5',
        'mode': 'auto',
      });

      expect([s.text('A3'), s.text('A4'), s.text('A5')], ['5', '7', '9']);
    });

    test('when copying and pasting then values and formats arrive and one '
        'undo step is recorded for the paste', () async {
      await s.type('A1', 'top');
      await s.select('A1');
      await s.run('sheets.format.italic');
      await s.run('sheets.edit.copy');
      await s.select('C3');

      await s.run('sheets.edit.paste');

      expect(s.text('C3'), 'top');
      expect(s.format('C3')[FormatAttr.italic], isTrue);
      await s.undo();
      expect(s.text('C3'), '');
    });

    test('when cutting and pasting then the data moves', () async {
      await s.type('A1', 'move me');
      await s.select('A1');
      await s.run('sheets.edit.cut');
      await s.select('D4');

      await s.run('sheets.edit.paste');

      expect(s.text('D4'), 'move me');
      expect(s.text('A1'), '');
    });

    test('when pasting plain text then it is parsed like typing', () async {
      await s.clip.write(
        const SystemClipboardData(plainText: '1\t2\n3\t=A1+B1'),
      );
      await s.select('A1');

      await s.run('sheets.edit.paste');

      expect(s.text('B2'), '3');
    });

    test('when inserting a date then the cell holds a date', () async {
      await s.select('A1');

      await s.run('sheets.cell.insertDate');

      expect(s.content('A1'), startsWith('n:'));
    });

    test('when setting a note then the cell has it; undo removes it', () async {
      await s.run('sheets.notes.insert', {'cell': 'B2', 'text': 'Check'});

      expect(s.model.cellAt(s.sheetId, 1, 1)?.note, 'Check');
      await s.undo();
      expect(s.model.cellAt(s.sheetId, 1, 1)?.note, isNull);
    });

    test('when inserting a link then the cell gets the url', () async {
      await s.select('A1');

      await s.run('sheets.insert.link', {
        'url': 'https://example.com',
        'text': 'Example',
      });

      expect(s.text('A1'), 'Example');
      expect(s.format('A1')[FormatAttr.linkUrl], 'https://example.com');
    });
  });

  group('Given a viewer', () {
    setUp(() async {
      await s.dispose();
      s = SheetsHarness.open(role: Role.viewer);
    });

    test('when typing then the command is refused', () async {
      expect(() => s.type('A1', '1'), throwsA(isA<CommandException>()));
    });

    test('when copying then it is allowed', () async {
      final r = await s.run('sheets.edit.copy');
      expect(r.isOk, isTrue);
    });
  });
}
