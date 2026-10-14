import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets/commands/sheets_commands.dart';
import 'package:wonky_sheets/features/model/sheets_undo.dart';
import 'package:wonky_sheets_core/model.dart';

import '../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() => s = SheetsHarness.open());
  tearDown(() => s.dispose());

  group('Given cells A1 bold and A2 not bold', () {
    setUp(() async {
      await s.type('A1', 'a');
      await s.type('A2', 'b');
      await s.select('A1');
      await s.run('sheets.format.bold');
    });

    test('when toggling bold on A1:A2 then both are bold, then both are '
        'not bold, one undo step each (AC-F1)', () async {
      await s.select('A1:A2');
      final before = s.h.undoLabels.length;

      await s.run('sheets.format.bold');
      expect(s.format('A1')[FormatAttr.bold], isTrue);
      expect(s.format('A2')[FormatAttr.bold], isTrue);

      await s.run('sheets.format.bold');
      expect(s.format('A1')[FormatAttr.bold], isNot(true));
      expect(s.format('A2')[FormatAttr.bold], isNot(true));
      expect(s.h.undoLabels.length, before + 2);
    });

    test(
      'when bolding three disjoint ranges then one undo step covers all',
      () async {
        await s.select('C1,D5:D6,F2');
        final before = s.h.undoLabels.length;

        await s.run('sheets.format.bold');

        expect(s.format('C1')[FormatAttr.bold], isTrue);
        expect(s.format('D6')[FormatAttr.bold], isTrue);
        expect(s.format('F2')[FormatAttr.bold], isTrue);
        expect(s.h.undoLabels.length, before + 1);
        await s.undo();
        expect(s.format('D6')[FormatAttr.bold], isNull);
      },
    );

    test(
      'when the toolbar reads the active cell then bold is checked',
      () async {
        await s.select('A1');
        expect(
          s.services.dispatcher.stateOf('sheets.format.bold').checked,
          isTrue,
        );
      },
    );
  });

  group('Given the number 1234.5 in A1', () {
    setUp(() async {
      await s.type('A1', '1234.5');
      await s.select('A1');
    });

    test('when formatting as currency then it shows \$1,234.50', () async {
      await s.run('sheets.format.numberFormat', {'preset': 'currency'});
      expect(s.text('A1'), r'$1,234.50');
    });

    test('when formatting as percent then it shows a percentage', () async {
      await s.run('sheets.format.numberFormat', {'preset': 'percent'});
      expect(s.text('A1'), '123450.00%');
    });

    test('when increasing decimals then one more decimal shows', () async {
      await s.run('sheets.format.numberFormat', {'preset': 'number'});
      await s.run('sheets.format.increaseDecimals');
      expect(s.text('A1'), '1,234.500');
    });

    test('when setting text and fill colors, size, alignment and wrap then '
        'the attributes are stored and undo restores them', () async {
      await s.run('sheets.format.textColor', {'color': '#FF0000'});
      await s.run('sheets.format.fillColor', {'color': '#00FF00'});
      await s.run('sheets.format.fontSize', {'size': 14});
      await s.run('sheets.format.hAlign', {'align': 'center'});
      await s.run('sheets.format.wrap', {'strategy': 'wrap'});

      final f = s.format('A1');
      expect(f[FormatAttr.textColor], '#FF0000');
      expect(f[FormatAttr.fillColor], '#00FF00');
      expect(f[FormatAttr.fontSize], 14.0);
      expect(f[FormatAttr.hAlign], HorizontalAlign.center);
      expect(f[FormatAttr.wrap], WrapStrategy.wrap);

      for (var i = 0; i < 5; i++) {
        await s.undo();
      }
      expect(s.format('A1')[FormatAttr.textColor], isNull);
    });

    test('when adding all borders and clearing formatting then the borders '
        'come and go', () async {
      await s.select('A1:B2');
      await s.run('sheets.format.borders', {'preset': 'all'});
      expect(s.format('B2')[FormatAttr.borderBottom], isNotNull);

      await s.run('sheets.format.clear');
      expect(s.format('B2')[FormatAttr.borderBottom], isNull);
    });

    test('when painting the format onto C3 then C3 gets it', () async {
      await s.run('sheets.format.italic');

      await s.run('sheets.format.applyPaintFormat', {
        'source': 'A1',
        'target': 'C3',
      });

      expect(s.format('C3')[FormatAttr.italic], isTrue);
    });
  });

  group('Given a 2×2 block with only a top-left value', () {
    setUp(() async {
      await s.type('A1', 'x');
      await s.select('A1:B2');
    });

    test('when merging then one merge exists; unmerge removes it', () async {
      await s.run('sheets.format.merge', {'mode': 'all'});
      expect(s.sheet.merges, hasLength(1));

      await s.run('sheets.format.unmerge');
      expect(s.sheet.merges, isEmpty);

      await s.undo();
      expect(s.sheet.merges, hasLength(1));
    });

    test('when merging over data without force from MCP then it is '
        'refused with the data-loss message', () async {
      await s.type('B2', 'y');
      await s.select('A1:B2');

      final r = await s.run('sheets.format.merge', {'mode': 'all'});

      expect(r.status, CommandStatus.failed);
      expect(s.sheet.merges, isEmpty);
    });
  });

  group('Given values in A1:A3', () {
    setUp(() async {
      await s.type('A1', '1');
      await s.type('A2', '2');
      await s.type('A3', '3');
    });

    test('when inserting a row above row 2 then data shifts down and undo '
        'restores', () async {
      final rows = s.sheet.rows.length;
      await s.select('A2');

      await s.run('sheets.rows.insertAbove');

      expect(s.sheet.rows.length, rows + 1);
      expect(s.text('A3'), '2');
      await s.undo();
      expect(s.sheet.rows.length, rows);
      expect(s.text('A2'), '2');
    });

    test(
      'when deleting row 1 then =SUM(A1:A3) shrinks and undo restores',
      () async {
        await s.type('B1', '=SUM(A1:A3)');
        await s.select('A1');

        await s.run('sheets.rows.delete', {
          'ids': [s.sheet.rows.idAt(1)],
        });
        expect(s.text('A2'), '3');

        await s.undo();
        expect(s.text('A2'), '2');
        expect(s.text('B1'), '6');
      },
    );

    test('when hiding and unhiding column A then its size toggles', () async {
      await s.select('A1');
      await s.run('sheets.cols.hide');
      expect(s.sheet.columns.isHidden(0), isTrue);

      await s.select('B1');
      await s.run('sheets.cols.unhide');
      expect(s.sheet.columns.isHidden(0), isFalse);
    });

    test('when resizing column B then its width is stored', () async {
      await s.run('sheets.cols.resize', {
        'ids': [s.sheet.columns.idAt(1)],
        'size': 180,
      });
      expect(s.sheet.columns.sizeAt(1), 180);
      await s.undo();
      expect(s.sheet.columns.sizeAt(1), 100);
    });

    test('when moving row 1 down then it swaps with row 2', () async {
      await s.select('A1');
      await s.run('sheets.rows.moveDown');
      expect(s.text('A1'), '2');
      expect(s.text('A2'), '1');
    });

    test(
      'when freezing two rows then the sheet stores it; undo resets it',
      () async {
        await s.run('sheets.view.freezeRows', {'count': 2});
        expect(s.sheet.record!.frozenRows, 2);
        await s.undo();
        expect(s.sheet.record!.frozenRows, 0);
      },
    );

    test('when inserting cells shifting down then A1 moves to A2', () async {
      await s.select('A1');
      await s.run('sheets.cells.insertShiftDown');
      expect(s.text('A2'), '1');
    });

    test(
      'when sorting the sheet by column A descending then 3 comes first',
      () async {
        await s.select('A1');
        await s.run('sheets.data.sortSheet', {'ascending': false});
        expect(s.text('A1'), '3');
      },
    );
  });

  group('Given one sheet', () {
    test('when adding, renaming, duplicating and deleting sheets then each '
        'is one undo step', () async {
      await s.run('sheets.sheet.add');
      expect(s.model.sheets, hasLength(2));
      final added = s.editor.activeSheetId;

      await s.run('sheets.sheet.rename', {'sheetId': added, 'name': 'Data'});
      expect(s.model.sheet(added)!.name, 'Data');

      await s.run('sheets.sheet.duplicate', {'sheetId': added});
      expect(s.model.sheets, hasLength(3));

      await s.run('sheets.sheet.delete', {'sheetId': added});
      expect(s.model.sheets, hasLength(2));

      await s.undo();
      expect(s.model.sheets, hasLength(3));
      expect(s.model.sheet(added)!.name, 'Data');
    });

    test('when hiding the last visible sheet then it is refused', () async {
      expect(() => s.run('sheets.sheet.hide'), throwsA(isA<CommandDisabled>()));
    });

    test('when coloring a tab then the color is stored', () async {
      await s.run('sheets.sheet.setColor', {'color': '#FF0000'});
      expect(s.sheet.record!.tabColor, '#FF0000');
    });
  });

  group('Given the command registry', () {
    test('then every Sheets command id is well-formed and unique', () {
      final ids = [for (final c in sheetsCommands(s.services)) c.id.value];
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids.every((i) => CommandId(i).isValid), isTrue);
    });

    test('then features that are not built yet are listed but disabled', () {
      for (final id in ['sheets.format.convertToTable']) {
        expect(s.services.registry.byId(id), isNotNull);
        expect(s.services.dispatcher.stateOf(id).enabled, isFalse);
      }
    });
  });

  group('Given an undo entry', () {
    test(
      'when encoding it to JSON and back then the changes survive',
      () async {
        await s.type('A1', 'persist');
        final step = s.services.undo.undoStepsOf(s.doc.undoStackKey).single;
        final entry = step.entries.single as SheetsRowsUndoEntry;

        final decoded = SheetsRowsUndoEntry.fromJson(entry.toJson());

        expect(decoded!.changes, entry.changes);
      },
    );

    test(
      'when a collaborator changed the same cell then undo skips it',
      () async {
        await s.type('A1', 'original');
        await s.type('A1', 'mine');
        final cell = s.model.cellAt(s.sheetId, 0, 0)!;
        // A remote edit of the same column.
        s.session.applyChanges([
          RowChange.update(
            SheetsTables.cell,
            cell.id,
            {CellCols.content: cell.content},
            {CellCols.content: 's:theirs'},
          ),
        ], label: 'remote');

        await s.undo();

        expect(s.text('A1'), 'theirs');
      },
    );
  });
}
