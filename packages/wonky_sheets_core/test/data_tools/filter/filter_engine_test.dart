import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/data_tools/data_tools.dart';

import '../../rules/support/core.dart';
import '../../rules/support/rule_fixtures.dart';

const display = FunctionDisplayText(_fmt);
String _fmt(CellValue v, String? f) => f == '0.00' && v is NumberValue
    ? v.number.toStringAsFixed(2)
    : ValueText.automatic(v);

void main() {
  group('Given filter criteria JSON', () {
    test(
      'when parsing per-column criteria then all parts decode and round-trip',
      () {
        const json =
            '{"c1":{"hiddenValues":["Closed",""],"condition":{"type":"numberGreater","values":[{"v":"100"}]},"visibleBackgroundColor":"#F4CCCC"}}';
        final c = FilterCriteria.parse(json);
        final col = c.columns['c1']!;
        expect(col.hiddenValues, {'Closed', ''});
        expect(col.condition!.type, ConditionType.numberGreater);
        expect(col.visibleBackgroundColor, '#F4CCCC');
        expect(jsonDecode(c.encode()), jsonDecode(json));
      },
    );

    test(
      'when setting and clearing a column then empty criteria are dropped',
      () {
        final c = FilterCriteria().withColumn(
          'a',
          ColumnCriteria(hiddenValues: ['x']),
        );
        expect(c.columns.keys, ['a']);
        expect(c.withColumn('a', null).isEmpty, isTrue);
        expect(c.withColumn('a', ColumnCriteria()).isEmpty, isTrue);
        expect(c.retain({'b'}).isEmpty, isTrue);
      },
    );
  });

  group('Given a table A1:C7 with a header row', () {
    late WorkbookBuilder b;
    late String sid;
    setUp(() {
      b = WorkbookBuilder();
      sid = b.sheet('Sheet1', rows: 10, cols: 4);
      b.values('A1', [
        ['Status', 'Amount', 'Region'],
        ['Open', 50, 'East'],
        ['Closed', 150, 'West'],
        ['Open', 200, 'east'],
        [null, 120, 'North'],
        ['Blocked', 99.5, 'East'],
        ['Open', 'n/a', 'West'],
      ]);
      b.set(
        'B2',
        'n:50',
        format: {
          FormatAttr.fillColor: '#F4CCCC',
          FormatAttr.numberFormat: '0.00',
        },
      );
    });

    FilterInput input(WorkbookModel m, Map<int, ColumnCriteria> criteria) =>
        FilterInput(
          sheetId: sid,
          range: const GridRect(0, 0, 6, 2),
          criteria: criteria,
          source: SheetFilterSource(
            sid,
            CellTextReader(ModelCellSource(m), display),
            formats: EffectiveFormatResolver(m),
          ),
          conditions: ConditionEvaluator(),
        );

    final cases = <(String, Map<int, ColumnCriteria>, List<int>)>[
      ('no criteria', {}, []),
      (
        'hidden value Closed',
        {
          0: ColumnCriteria(hiddenValues: ['Closed']),
        },
        [2],
      ),
      (
        'hidden blanks',
        {
          0: ColumnCriteria(hiddenValues: ['']),
        },
        [4],
      ),
      (
        'hidden values are case-sensitive',
        {
          2: ColumnCriteria(hiddenValues: ['East']),
        },
        [1, 5],
      ),
      (
        'hidden value uses display text',
        {
          1: ColumnCriteria(hiddenValues: ['50']),
        },
        [],
      ),
      (
        'hidden formatted display text',
        {
          1: ColumnCriteria(hiddenValues: ['50.00']),
        },
        [1],
      ),
      (
        'condition greater than 100',
        {
          1: ColumnCriteria(
            condition: Condition.tryParse(
              '{"type":"numberGreater","values":[{"v":"100"}]}',
            ),
          ),
        },
        [1, 5, 6],
      ),
      (
        'condition text contains east (case-insensitive)',
        {
          2: ColumnCriteria(
            condition: Condition.tryParse(
              '{"type":"textContains","values":[{"v":"EAST"}]}',
            ),
          ),
        },
        [2, 4, 6],
      ),
      (
        'values AND condition across columns',
        {
          0: ColumnCriteria(hiddenValues: ['Closed']),
          1: ColumnCriteria(
            condition: Condition.tryParse(
              '{"type":"numberGreater","values":[{"v":"100"}]}',
            ),
          ),
        },
        [1, 2, 5, 6],
      ),
      (
        'values AND condition in one column',
        {
          1: ColumnCriteria(
            hiddenValues: ['200'],
            condition: Condition.tryParse(
              '{"type":"numberGreater","values":[{"v":"100"}]}',
            ),
          ),
        },
        [1, 3, 5, 6],
      ),
      (
        'fill color',
        {1: ColumnCriteria(visibleBackgroundColor: '#f4cccc')},
        [2, 3, 4, 5, 6],
      ),
      (
        'text color default black',
        {1: ColumnCriteria(visibleForegroundColor: '#000000')},
        [],
      ),
      (
        'blank condition',
        {0: ColumnCriteria(condition: Condition.tryParse('{"type":"blank"}'))},
        [1, 2, 3, 5, 6],
      ),
    ];
    for (final (name, criteria, hidden) in cases) {
      test('when filtering by $name then rows $hidden are hidden', () {
        final v = FilterEngine.compute(input(b.build(), criteria));
        expect(v.hiddenRows.toList(), hidden);
        expect(v.isHidden(0), isFalse, reason: 'header row is always visible');
      });
    }

    test(
      'when using a value index then hidden values give the same result',
      () {
        final m = b.build();
        final inp = input(m, {
          0: ColumnCriteria(hiddenValues: ['Open']),
        });
        final idx = ValueIndex.build(inp.source, 0, 1, 6);
        expect(idx.rowsOf('Open'), [1, 3, 6]);
        expect(idx.count(''), 1);
        expect(
          FilterEngine.compute(inp, indexes: {0: idx}).hiddenRows.toList(),
          [1, 3, 6],
        );
      },
    );

    test(
      'when building the checklist then blanks come first and other columns\' hidden values are flagged',
      () {
        final m = b.build();
        final inp = input(m, {
          1: ColumnCriteria(
            condition: Condition.tryParse(
              '{"type":"numberLess","values":[{"v":"100"}]}',
            ),
          ),
        });
        final list = FilterEngine.checklist(inp, 0);
        expect(list, [
          const ChecklistEntry('Blocked', 1),
          const ChecklistEntry('Open', 1),
          const ChecklistEntry('', 1, hiddenByOthers: true),
          const ChecklistEntry('Closed', 1, hiddenByOthers: true),
        ]);
        final all = FilterEngine.checklist(input(m, {}), 0);
        expect(all.first, const ChecklistEntry('', 1));
        expect(all.map((e) => e.text), ['', 'Blocked', 'Closed', 'Open']);
      },
    );

    test('when a cell changes then updating only that row re-evaluates it', () {
      final m = b.build();
      final crit = {
        0: ColumnCriteria(hiddenValues: ['Closed']),
      };
      final v1 = FilterEngine.compute(input(m, crit));
      m.upsertRow(
        SheetsTables.cell,
        SheetsIds.cellId(sid, b.rowId(1), b.colId(0)),
        {
          Cols.sheetId: sid,
          CellCols.rowId: b.rowId(1),
          CellCols.columnId: b.colId(0),
          CellCols.content: 's:Closed',
        },
      );
      final v2 = FilterEngine.update(v1, input(m, crit), [1]);
      expect(v2.hiddenRows.toList(), [1, 2]);
      expect(v2.hiddenRowIds(m.sheets.single.rows), {b.rowId(1), b.rowId(2)});
    });

    test(
      'when computing a basic filter record then column ids resolve and unknown ids are ignored',
      () {
        b.row(SheetsTables.basicFilter, SheetsIds.basicFilterId(sid), {
          Cols.sheetId: sid,
          Cols.rangeJson: gridRange(b, sid, 0, 0, 6, 2).encode(),
          'criteriaJson': jsonEncode({
            b.colId(0): {
              'hiddenValues': ['Open'],
            },
            'gone': {
              'hiddenValues': ['x'],
            },
          }),
        });
        final m = b.build();
        final s = m.sheets.single;
        final v = FilterEngine.computeForRecord(
          s,
          s.basicFilter!,
          SheetFilterSource(sid, CellTextReader(ModelCellSource(m), display)),
          ConditionEvaluator(),
        )!;
        expect(v.hiddenRows.toList(), [1, 3, 6]);
        expect(v.visibleCount, 3);
      },
    );

    test(
      'when a custom formula condition is used then it is anchored at the first data cell',
      () {
        final m = b.build();
        final values = ModelCellSource(m);
        final hooksEv = ConditionEvaluator(hooks: _RowHooks(values));
        final inp = FilterInput(
          sheetId: sid,
          range: const GridRect(0, 0, 6, 2),
          criteria: {
            1: ColumnCriteria(condition: CustomFormulaCondition('=anchor')),
          },
          source: SheetFilterSource(sid, CellTextReader(values, display)),
          conditions: hooksEv,
        );
        FilterEngine.compute(inp);
        expect(_RowHooks.anchors, {(1, 1)});
      },
    );
  });

  group('Given a filter view sorted for display', () {
    test(
      'when computing the view order then display and model rows map both ways',
      () {
        final vals = [NumberValue(3), NumberValue(1), NumberValue(2)];
        final order = ViewRowOrder.compute(
          SortTable(3, {'c': SortKeyColumn.fromValues(vals)}),
          [const ValueSortSpec('c')],
          top: 5,
        );
        expect([for (var r = 5; r < 8; r++) order.modelRow(r)], [6, 7, 5]);
        expect(order.displayRow(5), 7);
        expect(
          order.modelRow(2),
          2,
          reason: 'rows outside the range map to themselves',
        );
        expect(ViewRowOrder.identity(0, 3).isIdentity, isTrue);
      },
    );
  });
}

final class _RowHooks extends _NoHooks {
  _RowHooks(this.values);
  final CellSource values;
  static final Set<(int, int)> anchors = {};

  @override
  FValue evaluateRelative(
    String stored, {
    required String sheetId,
    required int anchorRow,
    required int anchorCol,
    required int row,
    required int col,
  }) {
    anchors.add((anchorRow, anchorCol));
    return FBool.t;
  }
}

abstract class _NoHooks implements FormulaHooks {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
