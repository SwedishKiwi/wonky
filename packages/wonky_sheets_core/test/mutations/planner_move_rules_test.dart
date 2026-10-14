import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';

import '../support/planner_harness.dart';

/// Conditional formatting and data validation formulas on plain moves
/// (drag, cut & paste without hidden rows; 06 §15.3, 03 §11): they are
/// written for the rule's anchor (top-left of its first range), keep their
/// references like moved cell formulas, and follow references into the moved
/// cells.
PlannerHarness _harness() {
  final b = WorkbookBuilder()..sheet('Sheet1', rows: 20, cols: 8);
  b.values('A1', [
    [1, 10],
    [2, 20],
    [3, 30],
    [4, 40],
  ]);
  return PlannerHarness(b);
}

String _ruleJson(PlannerHarness h, String formula, String anchor) {
  final a = h.range(anchor).rect;
  return jsonEncode({
    'type': 'customFormula',
    'values': [
      {
        'v': h.hooks.toStored(
          formula,
          sheetId: h.sheetId,
          row: a.top,
          col: a.left,
        ),
      },
    ],
  });
}

/// The A1 text of the first formula of a rule JSON (written for the rule's
/// anchor, the top-left of its first range) as the cell [cell] evaluates it.
String _formulaAt(
  PlannerHarness h,
  String json,
  RuleKind kind,
  String ruleId,
  String cell,
) {
  String? found;
  void walk(Object? v) {
    if (v is String && v.startsWith('=')) found ??= v;
    if (v is Map) v.values.forEach(walk);
    if (v is List) v.forEach(walk);
  }

  walk(jsonDecode(json));
  final anchor = h.model.sheets.first.ruleRects(kind, ruleId).first;
  final r = h.range(cell);
  final atCell = h.hooks.translate(
    found!,
    fromSheetId: r.sheetId,
    fromRow: anchor.top,
    fromCol: anchor.left,
    toSheetId: r.sheetId,
    toRow: r.rect.top,
    toCol: r.rect.left,
  );
  return h.hooks.toA1(
    atCell,
    sheetId: r.sheetId,
    row: r.rect.top,
    col: r.rect.left,
  );
}

String _cf(PlannerHarness h, CfRuleRecord r, String cell) =>
    _formulaAt(h, r.ruleJson, RuleKind.conditionalFormat, r.id, cell);

String _dv(PlannerHarness h, DvRuleRecord r, String cell) =>
    _formulaAt(h, r.criteriaJson, RuleKind.dataValidation, r.id, cell);

void main() {
  group('Given a conditional format rule with relative formulas', () {
    late PlannerHarness h;
    setUp(() {
      h = _harness();
      // Each cell of B1:B4 compares itself with its left neighbour.
      h.apply(
        AddCfRule(h.sheetId, [
          h.range('B1:B4').rect,
        ], _ruleJson(h, r'=B1>A1*5', 'B1')),
      );
    });

    CfRuleRecord rule() => h.model.sheets.first.cfRules.values.single;

    test('when the whole rule is moved then references into the moved cells '
        'follow and the others stay, and undo restores', () {
      final before = h.dump();
      h.apply(MoveRange(h.range('B1:B4'), h.sheetId, 0, 3));
      final s = h.model.sheets.first;
      expect(s.ruleRects(RuleKind.conditionalFormat, rule().id), [
        const GridRect(0, 3, 3, 3),
      ]);
      // The moved cell D1 compares itself (it was B1) with A1 (not moved).
      expect(_cf(h, rule(), 'D1'), '=D1>A1*5');
      expect(_cf(h, rule(), 'D3'), '=D3>A3*5');
      h.undo();
      expect(h.dump(), before);
    });

    test('when part of the rule is moved then it is split: the cells left '
        'behind keep their formula, the moved ones get a rule of their own '
        'right after it', () {
      h.apply(MoveRange(h.range('B1:B2'), h.sheetId, 9, 5));
      final s = h.model.sheets.first;
      final rules = s.cfRules.values.toList()
        ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
      expect(rules, hasLength(2));
      final kept = rules.first;
      final moved = rules.last;
      expect(s.ruleRects(RuleKind.conditionalFormat, kept.id), [
        const GridRect(2, 1, 3, 1),
      ]);
      expect(_cf(h, kept, 'B3'), '=B3>A3*5');
      expect(s.ruleRects(RuleKind.conditionalFormat, moved.id), [
        const GridRect(9, 5, 10, 5),
      ]);
      expect(_cf(h, moved, 'F10'), '=F10>A1*5');
      expect(_cf(h, moved, 'F11'), '=F11>A2*5');
    });

    test('when cells the rule reads are moved then its references follow '
        'them', () {
      h.apply(MoveRange(h.range('A1:A4'), h.sheetId, 0, 6));
      expect(_cf(h, rule(), 'B1'), '=B1>G1*5');
      expect(_cf(h, rule(), 'B4'), '=B4>G4*5');
    });
  });

  group('Given a validation rule with a relative formula', () {
    late PlannerHarness h;
    setUp(() {
      h = _harness();
      h.apply(
        SetDataValidation(h.sheetId, [
          h.range('B1:B4').rect,
        ], _ruleJson(h, r'=B1<=A1*10', 'B1')),
      );
    });

    test('when its lower half is moved then the moved validation keeps '
        'reading the same left neighbours and the rest is unchanged', () {
      h.apply(MoveRange(h.range('B3:B4'), h.sheetId, 9, 4));
      final s = h.model.sheets.first;
      final byTop = {
        for (final r in s.dvRules.values)
          s.ruleRects(RuleKind.dataValidation, r.id).first.top: r,
      };
      expect(_dv(h, byTop[0]!, 'B2'), '=B2<=A2*10');
      expect(_dv(h, byTop[9]!, 'E10'), '=E10<=A3*10');
      expect(_dv(h, byTop[9]!, 'E11'), '=E11<=A4*10');
    });

    test('when its upper half is moved then the rule left behind is '
        're-anchored at its new first cell', () {
      h.apply(MoveRange(h.range('B1:B2'), h.sheetId, 9, 4));
      final s = h.model.sheets.first;
      final byTop = {
        for (final r in s.dvRules.values)
          s.ruleRects(RuleKind.dataValidation, r.id).first.top: r,
      };
      expect(s.ruleRects(RuleKind.dataValidation, byTop[2]!.id), [
        const GridRect(2, 1, 3, 1),
      ]);
      expect(_dv(h, byTop[2]!, 'B3'), '=B3<=A3*10');
      expect(_dv(h, byTop[9]!, 'E10'), '=E10<=A1*10');
    });

    test('when copied then the formula is translated like a copied cell '
        'formula', () {
      h.apply(MoveRange(h.range('B3:B4'), h.sheetId, 9, 4, copy: true));
      final s = h.model.sheets.first;
      final copy = s.dvRules.values.firstWhere(
        (r) => s.ruleRects(RuleKind.dataValidation, r.id).first.top == 9,
      );
      expect(_dv(h, copy, 'E10'), '=E10<=D10*10');
    });
  });
}
