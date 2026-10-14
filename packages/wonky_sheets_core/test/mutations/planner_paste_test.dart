import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';

import '../support/planner_harness.dart';

MutationPlan _roundTrip(PlannerHarness h, SheetsOperation op) {
  final before = h.dump();
  final p = h.apply(op);
  h.undo();
  expect(h.dump(), before, reason: 'undo restores the model');
  h.model.applyPlan(p);
  h.history.add(p);
  return p;
}

PlannerHarness _harness() {
  final b = WorkbookBuilder()..sheet('Sheet1', rows: 30, cols: 8);
  b.values('A1', [
    [1, 'a'],
    [2, 'b'],
    [3, 'c'],
    [4, 'd'],
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

void _hideRow(PlannerHarness h, int row) {
  final s = h.model.sheets.first;
  h.apply(
    SetDimensionHidden(s.id, Dimension.rows, [s.rows.idAt(row)], hidden: true),
  );
}

PasteSource _clip(
  PlannerHarness h,
  String from,
  String to, {
  bool cut = false,
}) {
  final copy = ClipboardEncoder.copy(
    h.model,
    h.range(from),
    ModelCellSource(h.model),
    clipId: 'clip-$from',
    hooks: h.hooks,
    isCut: cut,
  );
  final t = h.range(to);
  return ClipboardDecoder.decode(
    html: copy.html,
    last: copy.payload,
    targetSpreadsheetId: h.model.spreadsheetId,
    targetSheetId: t.sheetId,
    targetRow: t.rect.top,
    targetCol: t.rect.left,
    hooks: h.hooks,
  )!.source;
}

/// The A1 text of the first formula in a rule JSON, at [anchor].
String _ruleFormulaA1(PlannerHarness h, String json, String anchor) {
  String? found;
  void walk(Object? v) {
    if (v is String && v.startsWith('=')) found ??= v;
    if (v is Map) v.values.forEach(walk);
    if (v is List) v.forEach(walk);
  }

  walk(jsonDecode(json));
  final r = h.range(anchor);
  return h.hooks.toA1(
    found!,
    sheetId: r.sheetId,
    row: r.rect.top,
    col: r.rect.left,
  );
}

String _ruleJson(PlannerHarness h, String formula, String anchor) {
  final a = h.range(anchor).rect;
  final stored = h.hooks.toStored(
    formula,
    sheetId: h.sheetId,
    row: a.top,
    col: a.left,
  );
  return jsonEncode({
    'type': 'customFormula',
    'values': [
      {'v': stored},
    ],
  });
}

void main() {
  group('Given a cut whose copy skipped a hidden row (03 §12.6)', () {
    test(
      'when pasting then only the visible rows move, the hidden row stays, and undo restores',
      () {
        final h = _harness();
        _formula(h, 'D20', '=A3');
        _formula(h, 'D21', '=A2');
        _formula(h, 'D22', '=SUM(A3:B3)');
        _hideRow(h, 1);
        final src = _clip(h, 'A1:B3', 'E10', cut: true);
        expect(src.sourceRowIndices, [0, 2]);
        final p = _roundTrip(h, PasteClipboard(h.range('E10'), src));
        expect(p.label, 'Paste');
        expect(
          [h.content('E10'), h.content('F10'), h.content('E11')],
          ['n:1', 's:a', 'n:3'],
        );
        expect(h.content('E12'), isNull);
        expect(
          [h.content('A1'), h.content('A3'), h.content('B3')],
          [null, null, null],
        );
        expect([h.content('A2'), h.content('B2')], ['n:2', 's:b']);
        expect(h.formulaA1('D20'), '=E11');
        expect(h.formulaA1('D21'), '=A2');
        expect(h.formulaA1('D22'), '=SUM(E11:F11)');
      },
    );

    test(
      'when the destination overlaps the source then every reference moves once',
      () {
        final h = _harness();
        _formula(h, 'G1', '=A1+A3');
        _hideRow(h, 1);
        final src = _clip(h, 'A1:A4', 'A3', cut: true);
        _roundTrip(h, PasteClipboard(h.range('A3'), src));
        expect(
          [for (var r = 1; r <= 5; r++) h.content('A$r')],
          [null, 'n:2', 'n:1', 'n:3', 'n:4'],
        );
        expect(h.formulaA1('G1'), '=A3+A4');
      },
    );

    test('when nothing was hidden then the cut moves the whole block', () {
      final h = _harness();
      final src = _clip(h, 'A1:B2', 'E1', cut: true);
      _roundTrip(h, PasteClipboard(h.range('E1'), src));
      expect([h.content('E2'), h.content('A2')], ['n:2', null]);
    });

    test('when the cut lands on another sheet then references follow', () {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 10, cols: 4);
      b.values('A1', [
        [1],
        [2],
        [3],
      ]);
      b.sheet('Other', rows: 10, cols: 4);
      final h = PlannerHarness(b);
      _formula(h, 'B1', '=A3*2');
      _hideRow(h, 1);
      final src = _clip(h, 'A1:B3', 'Other!C1', cut: true);
      _roundTrip(h, PasteClipboard(h.range('Other!C1'), src));
      expect(h.content('Other!C2'), 'n:3');
      expect(h.content('A2'), 'n:2');
      final moved = h.content('Other!D1')!;
      expect(
        h.hooks.toA1(moved, sheetId: h.model.sheets.last.id, row: 0, col: 3),
        '=C2*2',
      );
    });
  });

  group('Given rules with relative formulas (06 §15.3)', () {
    test(
      'when pasting validation whose rule starts above the copy then the formula is re-anchored',
      () {
        final h = _harness();
        h.apply(
          SetDataValidation(h.sheetId, [
            h.range('B1:B4').rect,
          ], _ruleJson(h, r'=AND(A1>1,$A$1>0)', 'B1')),
        );
        final src = _clip(h, 'B2:B3', 'E5');
        _roundTrip(
          h,
          PasteClipboard(h.range('E5'), src, mode: PasteMode.dataValidation),
        );
        final s = h.model.sheets.first;
        final pasted = s.dvRules.values.firstWhere(
          (r) => s.ruleRects(RuleKind.dataValidation, r.id).first.top == 4,
        );
        expect(s.ruleRects(RuleKind.dataValidation, pasted.id), [
          const GridRect(4, 4, 5, 4),
        ]);
        expect(
          _ruleFormulaA1(h, pasted.criteriaJson, 'E5'),
          r'=AND(D5>1,$A$1>0)',
        );
      },
    );

    test(
      'when pasting all into a tiled selection on another sheet then one rule anchored at the first tile covers every tile',
      () {
        final b = WorkbookBuilder()..sheet('Sheet1', rows: 10, cols: 4);
        b.sheet('Other', rows: 20, cols: 4);
        final h = PlannerHarness(b);
        h.apply(
          AddCfRule(h.sheetId, [
            h.range('C1:C2').rect,
          ], _ruleJson(h, r'=$A1=2', 'C1')),
        );
        final src = _clip(h, 'C1:C2', 'Other!C10');
        _roundTrip(h, PasteClipboard(h.range('Other!C10:C13'), src));
        final other = h.model.sheets.last;
        final pasted = other.cfRules.values.single;
        expect(_ruleFormulaA1(h, pasted.ruleJson, 'Other!C10'), r'=$A10=2');
        expect(other.ruleRects(RuleKind.conditionalFormat, pasted.id), [
          const GridRect(9, 2, 10, 2),
          const GridRect(11, 2, 12, 2),
        ]);
      },
    );

    test(
      'when pasting all on the same sheet then an equivalent rule absorbs the pasted tiles',
      () {
        final h = _harness();
        h.apply(
          AddCfRule(h.sheetId, [
            h.range('C1:C2').rect,
          ], _ruleJson(h, r'=$A1=2', 'C1')),
        );
        final src = _clip(h, 'C1:C2', 'C10');
        _roundTrip(h, PasteClipboard(h.range('C10:C13'), src));
        final s = h.model.sheets.first;
        final rule = s.cfRules.values.single;
        expect(
          s
              .ruleRects(RuleKind.conditionalFormat, rule.id)
              .fold<int>(0, (n, r) => n + r.cellCount),
          6,
        );
      },
    );

    test(
      'when the pasted rule equals an existing one at its anchor then the ranges merge',
      () {
        final h = _harness();
        h.apply(
          AddCfRule(h.sheetId, [
            h.range('C1:C3').rect,
          ], _ruleJson(h, r'=$A1=2', 'C1')),
        );
        final src = _clip(h, 'C2', 'C6');
        _roundTrip(
          h,
          PasteClipboard(
            h.range('C6'),
            src,
            mode: PasteMode.conditionalFormatting,
          ),
        );
        final s = h.model.sheets.first;
        final rule = s.cfRules.values.single;
        expect(
          s.ruleRects(RuleKind.conditionalFormat, rule.id),
          containsAll([const GridRect(0, 2, 2, 2), const GridRect(5, 2, 5, 2)]),
        );
        expect(_ruleFormulaA1(h, rule.ruleJson, 'C1'), r'=$A1=2');
      },
    );

    test('when the rule has no formula then its JSON is kept verbatim', () {
      final h = _harness();
      const json = '{"type":"numberGreater","values":[{"v":"1"}]}';
      h.apply(SetDataValidation(h.sheetId, [h.range('B1:B2').rect], json));
      final src = _clip(h, 'B1:B2', 'G1');
      _roundTrip(
        h,
        PasteClipboard(h.range('G1'), src, mode: PasteMode.dataValidation),
      );
      final s = h.model.sheets.first;
      expect(s.dvRules.values.map((r) => r.criteriaJson).toSet(), {json});
    });
  });
}
