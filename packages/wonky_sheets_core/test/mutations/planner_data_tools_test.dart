import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';

import '../support/planner_harness.dart';

const _other = '00000000-0000-4000-8000-0000000000aa';

/// Applies [op], checks that undo restores the exact state, and re-applies it
/// so the test can assert the result. Returns the plan.
MutationPlan _roundTrip(PlannerHarness h, SheetsOperation op) {
  final before = h.dump();
  final p = h.apply(op);
  h.undo();
  expect(h.dump(), before, reason: 'undo restores the model');
  h.model.applyPlan(p);
  h.history.add(p);
  return p;
}

List<String?> _column(PlannerHarness h, String col, int from, int to) => [
  for (var r = from; r <= to; r++) h.content('$col$r'),
];

PlanContext _ctx(
  PlannerHarness h, {
  String? userId,
  Iterable<GridRect> Function(String sheetId)? overlays,
}) => PlanContext(
  userId: userId ?? h.ctx.userId,
  now: PlannerHarness.now,
  ids: h.ids,
  formulas: h.hooks,
  values: ModelCellSource(h.model),
  random: h.random,
  maxCells: 10000000,
  overlays: overlays,
);

void _input(PlannerHarness h, String a1, String text) {
  final r = h.range(a1);
  h.apply(
    SetCellInputs(
      sheetId: r.sheetId,
      row: r.rect.top,
      col: r.rect.left,
      inputs: [
        [CellInput.user(text)],
      ],
    ),
  );
}

void main() {
  // ---------------------------------------------------------------------------
  group('Given a table with a header row (sort, 07 §2)', () {
    late PlannerHarness h;
    late String colA;
    late String colB;
    setUp(() {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 12, cols: 4);
      b.values('A1', [
        ['Name', 'Score'],
        ['banana', 3],
        ['Apple', 1],
        ['cherry', 2],
        ['apple', 2],
        [null, 5],
      ]);
      h = PlannerHarness(b);
      colA = h.model.sheets.first.columns.idAt(0);
      colB = h.model.sheets.first.columns.idAt(1);
    });

    test(
      'when sorting A→Z with a header then text is case-insensitive, blanks last and undo restores',
      () {
        final p = _roundTrip(
          h,
          SortRange(h.range('A1:B6'), [SortKeySpec(colA)], hasHeader: true),
        );
        expect(_column(h, 'A', 1, 6), [
          's:Name',
          's:Apple',
          's:apple',
          's:banana',
          's:cherry',
          null,
        ]);
        expect(_column(h, 'B', 2, 6), ['n:1', 'n:2', 'n:3', 'n:2', 'n:5']);
        expect(p.label, 'Sort range');
        expect(p.result['movedRows'], 4);
      },
    );

    test('when sorting Z→A then blanks still sort last', () {
      _roundTrip(
        h,
        SortRange(h.range('A2:B6'), [SortKeySpec(colA, ascending: false)]),
      );
      expect(_column(h, 'A', 2, 6), [
        's:cherry',
        's:banana',
        's:apple',
        's:Apple',
        null,
      ]);
    });

    test('when sorting by two keys then the second breaks ties', () {
      _roundTrip(
        h,
        SortRange(h.range('A2:B6'), [
          SortKeySpec(colB),
          SortKeySpec(colA, ascending: false),
        ]),
      );
      expect(_column(h, 'B', 2, 6), ['n:1', 'n:2', 'n:2', 'n:3', 'n:5']);
      expect(_column(h, 'A', 2, 6), [
        's:Apple',
        's:cherry',
        's:apple',
        's:banana',
        null,
      ]);
    });

    test('when a label is given then the plan uses it', () {
      final p = h.plan(
        SortRange(h.range('A2:B6'), [SortKeySpec(colA)], label: 'Sort sheet'),
      );
      expect(p.label, 'Sort sheet');
    });

    test('when the key column is outside the range then it is refused', () {
      final colD = h.model.sheets.first.columns.idAt(3);
      expect(
        () => h.plan(SortRange(h.range('A2:B6'), [SortKeySpec(colD)])),
        throwsA(
          isA<PlanException>().having(
            (e) => e.code,
            'code',
            'invalid_argument',
          ),
        ),
      );
    });

    test('when there are no sort keys then it is refused', () {
      expect(
        () => h.plan(SortRange(h.range('A2:B6'), const [])),
        throwsA(isA<PlanException>()),
      );
    });

    test('when the range has a single data row then nothing changes', () {
      final p = h.plan(
        SortRange(h.range('A1:B2'), [SortKeySpec(colA)], hasHeader: true),
      );
      expect(p.changes, isEmpty);
    });

    test(
      'when the rows have no cells outside the range then rows are reordered by sort key only',
      () {
        final p = _roundTrip(
          h,
          SortRange(h.range('A2:D6'), [SortKeySpec(colA)]),
        );
        expect(p.result['strategy'], 'rowReorder');
        expect(
          p.changes.every((c) => c.table == SheetsTables.sheetRow),
          isTrue,
        );
        expect(_column(h, 'A', 2, 3), ['s:Apple', 's:apple']);
      },
    );

    test(
      'when cells exist outside the range then contents move and the outside column is untouched',
      () {
        _input(h, 'D2', 'keep');
        final p = _roundTrip(
          h,
          SortRange(h.range('A2:B6'), [SortKeySpec(colA)]),
        );
        expect(p.result['strategy'], 'contentMove');
        expect(h.content('D2'), 's:keep');
        expect(_column(h, 'A', 2, 3), ['s:Apple', 's:apple']);
      },
    );

    test(
      'when a sorted row has a formula then it gets copy semantics and outside references keep positions',
      () {
        _input(h, 'C2', '=B2*2');
        _input(h, 'C3', r'=$B$2');
        _input(h, 'D1', '=SUM(B2:B6)');
        _roundTrip(h, SortRange(h.range('A2:C6'), [SortKeySpec(colA)]));
        // banana (row 2) moves to row 4.
        expect(h.content('A4'), 's:banana');
        expect(h.formulaA1('C4'), '=B4*2');
        // Apple (row 3) moves to row 2; its absolute reference stays.
        expect(h.formulaA1('C2'), r'=$B$2');
        expect(h.formulaA1('D1'), '=SUM(B2:B6)');
      },
    );

    test('when sorting by fill color then rows with the color come first', () {
      h.apply(SetFormat([h.range('A4')], {FormatAttr.fillColor: '#FF0000'}));
      _roundTrip(
        h,
        SortRange(h.range('A2:B6'), [SortKeySpec(colA, fillColor: '#ff0000')]),
      );
      expect(h.content('A2'), 's:cherry');
    });

    test('when the range has a vertical merge then it is refused', () {
      h.apply(MergeCells([h.range('B2:B3')], force: true));
      expect(
        () => h.plan(SortRange(h.range('A2:B6'), [SortKeySpec(colA)])),
        throwsA(
          isA<PlanException>()
              .having((e) => e.code, 'code', 'merge_conflict')
              .having(
                (e) => e.message,
                'message',
                "Can't sort a range with vertically merged cells",
              ),
        ),
      );
    });

    test(
      'when a horizontal merge is inside a content move then it moves with its row',
      () {
        _input(h, 'D6', 'outside');
        h.apply(MergeCells([h.range('B2:C2')]));
        _roundTrip(h, SortRange(h.range('A2:C6'), [SortKeySpec(colB)]));
        // banana (score 3) lands on row 5.
        final s = h.model.sheets.first;
        expect(h.content('A5'), 's:banana');
        expect(s.mergeAt(4, 1), const GridRect(4, 1, 4, 2));
        expect(s.mergeAt(1, 1), isNull);
      },
    );

    test(
      'when rows are reordered then a single-row merge travels with its row',
      () {
        h.apply(MergeCells([h.range('C2:D2')]));
        final p = _roundTrip(
          h,
          SortRange(h.range('A2:D6'), [SortKeySpec(colA)]),
        );
        expect(p.result['strategy'], 'rowReorder');
        final s = h.model.sheets.first;
        expect(h.content('A4'), 's:banana');
        expect(s.mergeAt(3, 2), const GridRect(3, 2, 3, 3));
      },
    );

    test('when the range contains spill output then it is refused', () {
      final ctx = _ctx(h, overlays: (_) => [const GridRect(3, 1, 4, 1)]);
      expect(
        () => const SheetsMutationPlanner().plan(
          SortRange(h.range('A2:B6'), [SortKeySpec(colA)]),
          h.model,
          ctx,
        ),
        throwsA(
          isA<PlanException>().having(
            (e) => e.code,
            'code',
            'overlay_conflict',
          ),
        ),
      );
    });

    test(
      'when another user protected the range then sorting is refused for this user',
      () {
        final s = h.model.sheets.first;
        h.model.applyPlan(
          const SheetsMutationPlanner().plan(
            AddProtection(s.id, range: const GridRect(1, 0, 6, 1)),
            h.model,
            _ctx(h, userId: _other),
          ),
        );
        expect(
          () => h.plan(SortRange(h.range('A2:B6'), [SortKeySpec(colA)])),
          throwsA(
            isA<PlanException>().having(
              (e) => e.code,
              'code',
              'protected_range',
            ),
          ),
        );
      },
    );

    test(
      'when a CF rule covers the sorted rows then it keeps covering the same positions',
      () {
        final s = h.model.sheets.first;
        h.apply(AddCfRule(s.id, [const GridRect(1, 0, 3, 0)], '{"v":1}'));
        final rule = s.cfRules.keys.single;
        _roundTrip(h, SortRange(h.range('A2:D6'), [SortKeySpec(colA)]));
        expect(s.ruleRects(RuleKind.conditionalFormat, rule), [
          const GridRect(1, 0, 3, 0),
        ]);
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('Given mixed value types (sort ordering, 07 §2.3)', () {
    test(
      'when sorting ascending then numbers, text, booleans, errors, blanks',
      () {
        final b = WorkbookBuilder()..sheet('Sheet1', rows: 8, cols: 2);
        b.values('A1', [
          [true],
          ['x'],
          [CellErrorKind.na],
          [null],
          [10],
          [-1],
        ]);
        final h = PlannerHarness(b);
        final col = h.model.sheets.first.columns.idAt(0);
        _roundTrip(h, SortRange(h.range('A1:A6'), [SortKeySpec(col)]));
        expect(_column(h, 'A', 1, 6), [
          'n:-1',
          'n:10',
          's:x',
          'b:1',
          'e:#N/A',
          null,
        ]);
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('Given a range to randomize (07 §14)', () {
    test(
      'when randomizing with a seeded random then the rows are a permutation and undo restores',
      () {
        final b = WorkbookBuilder()..sheet('Sheet1', rows: 10, cols: 2);
        b.values('A1', [
          for (var i = 1; i <= 8; i++) [i, 'r$i'],
        ]);
        final h = PlannerHarness(b, seed: 7);
        final p = _roundTrip(h, RandomizeRange(h.range('A1:B8')));
        expect(p.label, 'Randomize range');
        final values = _column(h, 'A', 1, 8);
        expect(values.toSet(), {for (var i = 1; i <= 8; i++) 'n:$i'});
        for (var r = 1; r <= 8; r++) {
          final n = h.content('A$r')!.substring(2);
          expect(h.content('B$r'), 's:r$n');
        }
      },
    );

    test('when the range has one row then nothing changes', () {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 3, cols: 2);
      b.values('A1', [
        [1, 2],
      ]);
      final h = PlannerHarness(b);
      expect(h.plan(RandomizeRange(h.range('A1:B1'))).changes, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('Given rows with duplicates (remove duplicates, 07 §12.1)', () {
    late PlannerHarness h;
    setUp(() {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 10, cols: 4);
      b.values('A1', [
        ['Region', 'Amount'],
        ['East', 1],
        ['east', 1],
        ['East', 1],
        ['West', 2],
        ['East', 3],
      ]);
      b.value('D2', 'outside');
      h = PlannerHarness(b);
    });

    test(
      'when comparing all columns then later duplicates are removed, kept rows compact upward and undo restores',
      () {
        final p = _roundTrip(
          h,
          RemoveDuplicates(h.range('A1:B6'), hasHeader: true),
        );
        expect(p.label, 'Remove duplicates');
        expect(p.result['duplicatesRemoved'], 1);
        expect(p.result['uniqueRemaining'], 4);
        expect(
          p.result['message'],
          '1 duplicate row found and removed. 4 unique rows remain.',
        );
        expect(_column(h, 'A', 1, 6), [
          's:Region',
          's:East',
          's:east',
          's:West',
          's:East',
          null,
        ]);
        expect(_column(h, 'B', 2, 6), ['n:1', 'n:1', 'n:2', 'n:3', null]);
        expect(h.content('D2'), 's:outside');
      },
    );

    test('when comparing one column then only that column counts', () {
      final colA = h.model.sheets.first.columns.idAt(0);
      final p = _roundTrip(
        h,
        RemoveDuplicates(h.range('A1:B6'), hasHeader: true, colIds: [colA]),
      );
      expect(p.result['duplicatesRemoved'], 2);
      expect(_column(h, 'A', 2, 6), ['s:East', 's:east', 's:West', null, null]);
    });

    test('when there are no duplicates then nothing is written', () {
      final p = h.plan(RemoveDuplicates(h.range('A5:B6')));
      expect(p.changes, isEmpty);
      expect(p.result['message'], 'No duplicate rows found.');
    });

    test('when a compared column is outside the range then it is refused', () {
      final colD = h.model.sheets.first.columns.idAt(3);
      expect(
        () => h.plan(RemoveDuplicates(h.range('A1:B6'), colIds: [colD])),
        throwsA(isA<PlanException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('Given text with stray whitespace (trim, 07 §12.2)', () {
    test(
      'when trimming then text and rich text are trimmed, other values untouched, and undo restores',
      () {
        final b = WorkbookBuilder()..sheet('Sheet1', rows: 5, cols: 2);
        b.values('A1', [
          ['  a  b '],
          [3],
          ['ok'],
          ['x  y\n'],
        ]);
        b.set('B1', '=A1');
        final h = PlannerHarness(b);
        final p = _roundTrip(h, TrimWhitespace([h.range('A1:B4')]));
        expect(_column(h, 'A', 1, 4), ['s:a b', 'n:3', 's:ok', 's:x y']);
        expect(h.content('B1'), '=A1');
        expect(p.result['trimmed'], 2);
        expect(p.result['message'], 'Trimmed whitespace from 2 cells.');
      },
    );

    test('when nothing needs trimming then the message says so', () {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 2, cols: 1);
      b.value('A1', 'clean');
      final h = PlannerHarness(b);
      final p = h.plan(TrimWhitespace([h.range('A1:A2')]));
      expect(p.changes, isEmpty);
      expect(p.result['message'], 'No whitespace to trim.');
    });
  });

  // ---------------------------------------------------------------------------
  group('Given a column of delimited text (split, 07 §13)', () {
    late PlannerHarness h;
    setUp(() {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 6, cols: 2);
      b.values('A1', [
        ['"Doe, John",42,2026-10-12'],
        ['Roe,7'],
        ['single'],
      ]);
      b.set('A4', '=1');
      h = PlannerHarness(b);
    });

    test(
      'when splitting with auto-detection then parts are parsed into new columns and undo restores',
      () {
        final p = _roundTrip(h, SplitTextToColumns(h.range('A1:A4')));
        expect(p.label, 'Split text to columns');
        expect(p.result['separator'], ',');
        expect(p.result['columns'], 3);
        expect(h.model.sheets.first.columns.length, 3);
        expect(h.content('A1'), 's:Doe, John');
        expect(h.content('B1'), 'n:42');
        expect(h.content('C1'), startsWith('n:'));
        expect(h.cell('C1')!.format[FormatAttr.numberFormat], isNotNull);
        expect(h.content('A2'), 's:Roe');
        expect(h.content('B2'), 'n:7');
        expect(h.content('A3'), 's:single');
        expect(h.content('A4'), '=1');
      },
    );

    test('when a separator is given then it is used', () {
      final p = _roundTrip(
        h,
        SplitTextToColumns(h.range('A2:A2'), separator: 'o'),
      );
      expect(p.result['separator'], 'o');
      expect(h.content('A2'), 's:R');
      expect(h.content('B2'), 's:e,7');
    });

    test('when cells to the right are not empty then it asks first', () {
      _input(h, 'B2', 'busy');
      expect(
        () => h.plan(SplitTextToColumns(h.range('A1:A3'))),
        throwsA(
          isA<PlanException>().having(
            (e) => e.code,
            'code',
            'confirm_overwrite',
          ),
        ),
      );
      _roundTrip(h, SplitTextToColumns(h.range('A1:A3'), force: true));
      expect(h.content('B2'), 'n:7');
    });

    test('when more than one column is selected then it is refused', () {
      expect(
        () => h.plan(SplitTextToColumns(h.range('A1:B3'))),
        throwsA(
          isA<PlanException>().having(
            (e) => e.message,
            'message',
            'Please select a single column of data to split.',
          ),
        ),
      );
    });

    test('when no separator can be detected then it is refused', () {
      expect(
        () => h.plan(SplitTextToColumns(h.range('A3:A3'))),
        throwsA(
          isA<PlanException>().having((e) => e.code, 'code', 'no_separator'),
        ),
      );
    });

    test('when a part looks like a formula then it stays text', () {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 2, cols: 2);
      b.value('A1', 'a;=1+1');
      final h2 = PlannerHarness(b);
      h2.apply(SplitTextToColumns(h2.range('A1:A1')));
      expect(h2.content('B1'), 's:=1+1');
    });
  });

  // ---------------------------------------------------------------------------
  group('Given cells to search (find and replace, 07 §11)', () {
    late PlannerHarness h;
    setUp(() {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 6, cols: 3);
      b.values('A1', [
        ['East', 100, 'Northeast'],
        ['east side', 1234.5, '12-34'],
      ]);
      b.set('A3', '=SUM(B1:B2)');
      b.sheet('Other', rows: 3, cols: 2);
      b.value('A1', 'East');
      h = PlannerHarness(b);
    });

    test(
      'when replacing in all sheets then every instance is replaced in one step and undo restores',
      () {
        final p = _roundTrip(
          h,
          const FindReplace(find: 'east', replacement: 'West'),
        );
        expect(p.label, 'Replace all');
        expect(h.content('A1'), 's:West');
        expect(h.content('C1'), 's:NorthWest');
        expect(h.content('A2'), 's:West side');
        expect(h.content('Other!A1'), 's:West');
        expect(p.result['replaced'], 4);
        expect(
          p.result['message'],
          "Replaced 4 instances of 'east' with 'West'.",
        );
      },
    );

    test(
      'when matching case and the entire cell then only exact cells change',
      () {
        final p = _roundTrip(
          h,
          FindReplace(
            find: 'East',
            replacement: 'W',
            sheetIds: [h.sheetId],
            matchCase: true,
            matchEntireCell: true,
          ),
        );
        expect(p.result['replaced'], 1);
        expect(h.content('A1'), 's:W');
        expect(h.content('C1'), 's:Northeast');
        expect(h.content('Other!A1'), 's:East');
      },
    );

    test('when replacing in a number then the edit text is parsed again', () {
      _roundTrip(
        h,
        FindReplace(find: '1', replacement: '2', range: h.range('B1')),
      );
      expect(h.content('B1'), 'n:200');
      expect(h.content('B2'), 'n:1234.5');
    });

    test('when using a regex with groups then they are expanded', () {
      _roundTrip(
        h,
        const FindReplace(
          find: r'(\d+)-(\d+)',
          replacement: r'$2-$1',
          useRegex: true,
        ),
      );
      expect(h.content('C2'), 's:34-12');
    });

    test('when the regex is invalid then it is refused', () {
      expect(
        () => h.plan(
          const FindReplace(find: '(', replacement: 'x', useRegex: true),
        ),
        throwsA(
          isA<PlanException>().having(
            (e) => e.code,
            'code',
            'invalid_argument',
          ),
        ),
      );
    });

    test('when searching within formulas then the formula is rewritten', () {
      _roundTrip(
        h,
        const FindReplace(
          find: 'SUM',
          replacement: 'AVERAGE',
          searchFormulas: true,
        ),
      );
      expect(h.formulaA1('A3'), '=AVERAGE(B1:B2)');
    });

    test('when not searching within formulas then formulas are kept', () {
      final p = h.plan(const FindReplace(find: 'SUM', replacement: 'X'));
      expect(p.changes, isEmpty);
      expect(p.result['message'], "No instances of 'SUM' were replaced.");
    });

    test('when replacing a single cell then only that cell changes', () {
      final p = _roundTrip(
        h,
        FindReplace(
          find: 'east',
          replacement: 'west',
          onlyCell: (h.sheetId, 0, 2),
        ),
      );
      expect(p.label, 'Replace');
      expect(h.content('C1'), 's:Northwest');
      expect(h.content('A1'), 's:East');
    });

    test(
      'when a matching cell is protected by another user then it is skipped with a warning',
      () {
        final s = h.model.sheets.first;
        h.model.applyPlan(
          const SheetsMutationPlanner().plan(
            AddProtection(s.id, range: const GridRect(0, 0, 0, 0)),
            h.model,
            _ctx(h, userId: _other),
          ),
        );
        final p = _roundTrip(
          h,
          FindReplace(find: 'east', replacement: 'W', sheetIds: [s.id]),
        );
        expect(h.content('A1'), 's:East');
        expect(h.content('C1'), 's:NorthW');
        expect(p.result['skippedProtected'], 1);
        expect(p.warnings, ['1 cell was skipped because it is protected.']);
        expect(
          () => h.plan(
            FindReplace(find: 'East', replacement: 'W', onlyCell: (s.id, 0, 0)),
          ),
          throwsA(
            isA<PlanException>().having(
              (e) => e.code,
              'code',
              'protected_range',
            ),
          ),
        );
      },
    );
  });
}
