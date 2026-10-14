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

String? _format(PlannerHarness h, String a1) =>
    h.cell(a1)?.format[FormatAttr.numberFormat] as String?;

void main() {
  group('Given numbers with different formats (decimals, 06 §5.10)', () {
    late PlannerHarness h;
    setUp(() {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 6, cols: 3);
      b.value('A1', 1234.5);
      b.value('A2', 2, format: {FormatAttr.numberFormat: '0.00'});
      b.value('A3', 0.5, format: {FormatAttr.numberFormat: '0%'});
      h = PlannerHarness(b);
    });

    test(
      'when increasing then every distinct pattern gets one more decimal and undo restores',
      () {
        final p = _roundTrip(h, AdjustDecimals([h.range('A1:A3')], 1));
        expect(p.label, 'Increase decimals');
        expect(
          _format(h, 'A1'),
          DecimalsAdjuster.adjust(
            null,
            1,
            activeValue: const NumberValue(1234.5),
          ),
        );
        expect(_format(h, 'A2'), '0.000');
        expect(_format(h, 'A3'), '0.0%');
      },
    );

    test('when decreasing then the last decimal is removed', () {
      final p = _roundTrip(h, AdjustDecimals([h.range('A2:A3')], -1));
      expect(p.label, 'Decrease decimals');
      expect(_format(h, 'A2'), '0.0');
      expect(_format(h, 'A3'), '0%');
    });

    test(
      'when an active cell is given then Automatic cells follow its value',
      () {
        h.apply(
          SetCellInputs(
            sheetId: h.sheetId,
            row: 4,
            col: 0,
            inputs: [
              [const CellInput.raw(1.25)],
            ],
          ),
        );
        _roundTrip(
          h,
          AdjustDecimals([h.range('A1:A5')], 1, active: (h.sheetId, 4, 0)),
        );
        final expected = DecimalsAdjuster.adjust(
          null,
          1,
          activeValue: const NumberValue(1.25),
        );
        expect(_format(h, 'A1'), expected);
        expect(_format(h, 'A5'), expected);
      },
    );

    test(
      'when adjusting whole columns then the column default and explicit cells change',
      () {
        final s = h.model.sheets.first;
        final col = ResolvedRange(
          s.id,
          GridRect(0, 0, s.rows.length - 1, 0),
          wholeColumns: true,
        );
        _roundTrip(h, AdjustDecimals([col], 1));
        expect(
          s.columnRecords[s.columns.idAt(0)]!.format[FormatAttr.numberFormat],
          isNotNull,
        );
        expect(_format(h, 'A2'), '0.000');
      },
    );

    test('when the delta is zero then nothing changes', () {
      expect(h.plan(AdjustDecimals([h.range('A1:A3')], 0)).changes, isEmpty);
    });
  });

  group('Given rows to group (outline, 07 §16)', () {
    late PlannerHarness h;
    late SheetModel s;
    setUp(() {
      h = PlannerHarness(WorkbookBuilder()..sheet('Sheet1', rows: 20, cols: 4));
      s = h.model.sheets.first;
    });

    GroupOperation op(
      GroupAction a, {
      int? start,
      int? end,
      String? id,
      int? level,
      Dimension d = Dimension.rows,
    }) => GroupOperation(
      s.id,
      d,
      a,
      start: start,
      end: end,
      groupId: id,
      level: level,
    );

    List<(int, int, int, bool)> spans() => [
      for (final g in s.groups.values)
        (
          s.rows.indexOf(g.startId),
          s.rows.indexOf(g.endId),
          g.depth,
          g.collapsed,
        ),
    ]..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : b.$2 - a.$2);

    test(
      'when grouping rows 3–8 and then 4–5 then they nest and undo restores',
      () {
        final p = _roundTrip(h, op(GroupAction.group, start: 2, end: 7));
        expect(p.label, 'Group rows');
        expect(s.groups.keys, [p.result['groupId']]);
        _roundTrip(h, op(GroupAction.group, start: 3, end: 4));
        expect(spans(), [(2, 7, 1, false), (3, 4, 2, false)]);
      },
    );

    test('when ungrouping one row of a group then it shrinks', () {
      h.apply(op(GroupAction.group, start: 3, end: 4));
      final p = _roundTrip(h, op(GroupAction.ungroup, start: 4, end: 4));
      expect(p.label, 'Ungroup rows');
      expect(spans(), [(3, 3, 1, false)]);
    });

    test('when ungrouping the middle of a group then it splits', () {
      h.apply(op(GroupAction.group, start: 2, end: 8));
      _roundTrip(h, op(GroupAction.ungroup, start: 5, end: 5));
      expect(spans(), [(2, 4, 1, false), (6, 8, 1, false)]);
    });

    test(
      'when toggling, collapsing and expanding then the state is shared',
      () {
        final id =
            h.apply(op(GroupAction.group, start: 2, end: 4)).result['groupId']!
                as String;
        expect(
          _roundTrip(h, op(GroupAction.toggle, id: id)).label,
          'Collapse group',
        );
        expect(s.groups[id]!.collapsed, isTrue);
        _roundTrip(h, op(GroupAction.expand, id: id));
        expect(s.groups[id]!.collapsed, isFalse);
        _roundTrip(h, op(GroupAction.collapse, id: id));
        expect(s.groups[id]!.collapsed, isTrue);
        expect(h.plan(op(GroupAction.collapse, id: id)).changes, isEmpty);
      },
    );

    test('when collapsing to level 2 then only deeper groups collapse', () {
      h.apply(op(GroupAction.group, start: 2, end: 8));
      h.apply(op(GroupAction.group, start: 3, end: 4));
      _roundTrip(h, op(GroupAction.collapseToLevel, level: 2));
      expect(spans(), [(2, 8, 1, false), (3, 4, 2, true)]);
      _roundTrip(h, op(GroupAction.collapseAll));
      expect(spans().every((g) => g.$4), isTrue);
      _roundTrip(h, op(GroupAction.expandAll));
      expect(spans().any((g) => g.$4), isFalse);
      final p = _roundTrip(h, op(GroupAction.removeAll));
      expect(p.label, 'Remove all groups');
      expect(s.groups, isEmpty);
    });

    test('when grouping a ninth level then it is refused', () {
      for (var i = 0; i < 8; i++) {
        h.apply(op(GroupAction.group, start: 2, end: 10));
      }
      expect(
        () => h.plan(op(GroupAction.group, start: 2, end: 10)),
        throwsA(
          isA<PlanException>()
              .having((e) => e.code, 'code', 'group_too_deep')
              .having(
                (e) => e.message,
                'message',
                "You can't group more than 8 levels.",
              ),
        ),
      );
    });

    test('when grouping columns then the label names columns', () {
      final p = _roundTrip(
        h,
        op(GroupAction.group, start: 1, end: 2, d: Dimension.columns),
      );
      expect(p.label, 'Group columns');
      expect(s.groups.values.single.dimension, Dimension.columns);
    });

    test('when arguments are missing or unknown then it is refused', () {
      expect(
        () => h.plan(op(GroupAction.group)),
        throwsA(
          isA<PlanException>().having(
            (e) => e.code,
            'code',
            'invalid_argument',
          ),
        ),
      );
      expect(
        () => h.plan(op(GroupAction.toggle, id: 'nope')),
        throwsA(
          isA<PlanException>().having((e) => e.code, 'code', 'not_found'),
        ),
      );
      expect(
        () => h.plan(op(GroupAction.group, start: 0, end: 99)),
        throwsA(
          isA<PlanException>().having((e) => e.code, 'code', 'invalid_range'),
        ),
      );
      expect(
        () => h.plan(op(GroupAction.collapseToLevel, level: 0)),
        throwsA(isA<PlanException>()),
      );
    });
  });
}
