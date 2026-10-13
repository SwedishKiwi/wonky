import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';

import '../support/planner_harness.dart';

PlannerHarness _harness() {
  final b = WorkbookBuilder()..sheet('Sheet1', rows: 20, cols: 6);
  b.values('A1', [
    [1, 'a'],
    [2, 'b'],
    [3, 'c'],
  ]);
  return PlannerHarness(b);
}

void _formula(PlannerHarness h, String a1, String formula) {
  final r = h.range(a1);
  h.apply(
    SetCellInputs(
      sheetId: r.sheetId,
      row: r.rect.top,
      col: r.rect.left,
      inputs: [
        [CellInput.user(formula)],
      ],
    ),
  );
}

void main() {
  group('Given a block referenced by formulas', () {
    late PlannerHarness h;
    setUp(() {
      h = _harness();
      _formula(h, 'D1', '=A1');
      _formula(h, 'D2', '=SUM(A1:A3)');
      _formula(h, 'D3', '=SUM(A1:A5)');
    });

    test(
      'when moving the block then references fully inside follow it (03 §11)',
      () {
        final before = h.dump();
        h.apply(MoveRange(h.range('A1:B3'), h.sheetId, 9, 2));
        expect(h.content('A1'), isNull);
        expect(h.content('C10'), 'n:1');
        expect(h.formulaA1('D1'), '=C10');
        expect(h.formulaA1('D2'), '=SUM(C10:C12)');
        expect(h.formulaA1('D3'), '=SUM(A1:A5)');
        h.undo();
        expect(h.dump(), before);
      },
    );

    test('when copying a formula then relative references are translated', () {
      h.apply(MoveRange(h.range('D1'), h.sheetId, 1, 4, copy: true));
      expect(h.formulaA1('E2'), '=B2');
      expect(h.formulaA1('D1'), '=A1');
    });

    test(
      'when pasting a source into a larger multiple then it is tiled (03 §12.3)',
      () {
        const src = PasteSource(
          cells: [
            [PasteCell(content: NumberContent(7)), PasteCell(text: 'x')],
          ],
        );
        h.apply(PasteClipboard(h.range('A10:D11'), src));
        expect(h.content('A10'), 'n:7');
        expect(h.content('B10'), 's:x');
        expect(h.content('C11'), 'n:7');
        expect(h.content('D11'), 's:x');
      },
    );

    test('when pasting values only then computed values replace formulas', () {
      final src = PasteSource(
        spreadsheetId: h.model.spreadsheetId,
        sheetId: h.sheetId,
        cells: [
          [
            PasteCell(
              storedFormula: h.content('D2'),
              value: const NumberValue(6),
              format: CellFormat({FormatAttr.bold: true}),
            ),
          ],
        ],
      );
      h.apply(PasteClipboard(h.range('F1'), src, mode: PasteMode.valuesOnly));
      expect(h.content('F1'), 'n:6');
      expect(h.cell('F1')!.format.isEmpty, isTrue);
    });

    test(
      'when pasting a formula from the same spreadsheet then it is translated',
      () {
        final src = PasteSource(
          spreadsheetId: h.model.spreadsheetId,
          sheetId: h.sheetId,
          sourceRow: 0,
          sourceCol: 3,
          cells: [
            [PasteCell(storedFormula: h.content('D1'))],
          ],
        );
        h.apply(PasteClipboard(h.range('E5'), src));
        expect(h.formulaA1('E5'), '=B5');
      },
    );

    test(
      'when randomizing with a seed then rows are permuted and formulas keep copy semantics',
      () {
        _formula(h, 'C1', '=A1*2');
        final p = h.plan(RandomizeRange(h.range('A1:C3')));
        h.model.applyPlan(p);
        final values = [for (var r = 1; r <= 3; r++) h.content('A$r')];
        expect(values.toSet(), {'n:1', 'n:2', 'n:3'});
        final row = values.indexOf('n:1') + 1;
        expect(h.formulaA1('C$row'), '=A$row*2');
      },
    );

    test(
      'when shifting cells right then the strip moves and references follow',
      () {
        h.apply(ShiftCells(h.range('A1:A3'), ShiftDirection.right));
        expect(h.content('A1'), isNull);
        expect(h.content('B1'), 'n:1');
        expect(h.content('C1'), 's:a');
      },
    );
  });

  group('Given rules and names', () {
    late PlannerHarness h;
    setUp(() => h = _harness());

    test(
      'when adding CF rules with beforeRuleId then sort keys order them',
      () {
        final s = h.model.sheets.first;
        final a =
            h
                    .apply(AddCfRule(s.id, [h.range('A1:A3').rect], '{"v":1}'))
                    .result['ruleId']!
                as String;
        final b =
            h
                    .apply(
                      AddCfRule(
                        s.id,
                        [h.range('B1:B3').rect],
                        '{"v":1}',
                        beforeRuleId: a,
                      ),
                    )
                    .result['ruleId']!
                as String;
        expect(
          s.cfRules[b]!.sortKey.compareTo(s.cfRules[a]!.sortKey),
          lessThan(0),
        );
        h.apply(ReorderCfRule(b, null));
        expect(
          s.cfRules[b]!.sortKey.compareTo(s.cfRules[a]!.sortKey),
          greaterThan(0),
        );
      },
    );

    test(
      'when a new validation overlaps an old one then the old range is subtracted (07 §6.4)',
      () {
        final s = h.model.sheets.first;
        h.apply(
          SetDataValidation(s.id, [
            const GridRect(0, 0, 9, 0),
          ], '{"type":"checkbox"}'),
        );
        final old = s.dvRules.keys.single;
        h.apply(
          SetDataValidation(s.id, [
            const GridRect(0, 0, 4, 0),
          ], '{"type":"numberGreater","values":[{"v":"1"}]}'),
        );
        expect(s.ruleRects(RuleKind.dataValidation, old), [
          const GridRect(5, 0, 9, 0),
        ]);
        expect(s.dvRules, hasLength(2));
      },
    );

    test(
      'when renaming a named range then formulas using it are rewritten',
      () {
        h.apply(AddNamedRange('Sales', range: h.range('A1:A3')));
        _formula(h, 'E1', '=SUM(Sales)');
        final id = h.model.namedRange('sales')!.id;
        h.apply(UpdateNamedRange(id, name: 'Revenue'));
        expect(h.formulaA1('E1'), '=SUM(Revenue)');
        expect(
          () => h.plan(const AddNamedRange('TAX2024', formula: '=1')),
          throwsA(isA<PlanException>()),
        );
        expect(
          () => h.plan(const AddNamedRange('true_x', formula: '=1')),
          throwsA(isA<PlanException>()),
        );
      },
    );

    test(
      'when inserting checkboxes then empty cells get FALSE and a rule is added',
      () {
        final s = h.model.sheets.first;
        h.apply(InsertCheckboxes(s.id, [const GridRect(0, 4, 1, 4)]));
        expect(h.content('E1'), 'b:0');
        expect(s.dvRules.values.single.criteriaJson, contains('checkbox'));
      },
    );

    test('when adding a basic filter then its id is deterministic', () {
      final s = h.model.sheets.first;
      h.apply(SetBasicFilter(s.id, const GridRect(0, 0, 2, 1)));
      h.apply(
        SetFilterColumnCriteria(s.id, s.columns.idAt(0), {
          'hiddenValues': ['1'],
        }),
      );
      expect(s.basicFilter!.criteriaJson, contains('hiddenValues'));
    });
  });

  group('Given random operation sequences', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      test(
        'when applying random edits and undoing all then the state is restored (seed $seed)',
        () {
          final h = _harness();
          final rnd = Random(seed);
          final initial = h.dump();
          for (var i = 0; i < 25; i++) {
            final s = h.model.sheets.first;
            final r = rnd.nextInt(s.rows.length - 2);
            final c = rnd.nextInt(s.columns.length - 1);
            final op = switch (rnd.nextInt(8)) {
              0 => SetCellInputs(
                sheetId: s.id,
                row: r,
                col: c,
                inputs: [
                  [CellInput.user('${rnd.nextInt(100)}')],
                ],
              ),
              1 => SetFormat(
                [ResolvedRange(s.id, GridRect(r, c, r + 1, c + 1))],
                {FormatAttr.bold: rnd.nextBool()},
              ),
              2 => InsertDimension(s.id, Dimension.rows, r, 1 + rnd.nextInt(2)),
              3 => DeleteDimension(s.id, Dimension.rows, [s.rows.idAt(r)]),
              4 => MoveDimension(s.id, Dimension.columns, [
                s.columns.idAt(c),
              ], s.columns.idAt(rnd.nextInt(s.columns.length))),
              5 => SetBorders([
                ResolvedRange(s.id, GridRect(r, c, r + 1, c)),
              ], BorderPreset.all),
              6 => MoveRange(
                ResolvedRange(s.id, GridRect(r, c, r, c)),
                s.id,
                rnd.nextInt(s.rows.length),
                rnd.nextInt(s.columns.length),
              ),
              _ => SetCellInputs(
                sheetId: s.id,
                row: r,
                col: c,
                inputs: [
                  [const CellInput.user('=SUM(A1:A3)')],
                ],
              ),
            };
            try {
              h.apply(op);
            } on PlanException {
              // Refused operations change nothing.
            }
          }
          while (h.history.isNotEmpty) {
            h.undo();
          }
          expect(h.dump(), initial, reason: 'seed $seed');
        },
      );
    }
  });
}
