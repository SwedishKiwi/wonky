import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/pivot/pivot.dart';

import 'support/pivot_fixtures.dart';

void main() {
  const regions = ['East', 'West', 'North', 'South'];
  const products = ['Apple', 'Banana', 'Cherry'];

  SourceTable table(Random rnd, int n) => SourceTable.fromRows(
    colIds: const ['r', 'p', 'u', 'v'],
    headers: const ['Region', 'Product', 'Units', 'Price'],
    rows: [
      for (var i = 0; i < n; i++)
        [
          TextValue(regions[rnd.nextInt(regions.length)]),
          TextValue(products[rnd.nextInt(products.length)]),
          NumberValue(rnd.nextInt(50).toDouble()),
          i % 7 == 0 ? CellValue.empty : NumberValue(rnd.nextInt(1000) / 10),
        ],
    ],
    display: plainDisplay,
  );

  final spec = PivotSpec(
    rows: [PivotGroupSpec('r', sortByValueIndex: 0, ascending: false)],
    columns: const [PivotGroupSpec('p')],
    values: const [
      PivotValueSpec(source: 'u'),
      PivotValueSpec(source: 'v', summarizeBy: PivotSummarize.average),
      PivotValueSpec(source: 'v', summarizeBy: PivotSummarize.count),
      PivotValueSpec(source: 'v', summarizeBy: PivotSummarize.counta),
      PivotValueSpec(source: 'u', summarizeBy: PivotSummarize.max),
      PivotValueSpec(source: 'u', showAs: PivotShowAs.percentOfGrandTotal),
    ],
  );

  /// Every displayed value, in output order.
  List<Object> snapshot(PivotResult r) {
    final out = <Object>[];
    void rows(PivotAxisNode n) {
      out.add(n.path.map((k) => k.labelText).join('/'));
      void cols(PivotAxisNode c) {
        for (var j = 0; j < r.valueFields.length; j++) {
          final v = r.value(n, c, j);
          out.add(v is NumberValue ? v.number.toStringAsFixed(9) : '$v');
        }
        c.children.forEach(cols);
      }

      cols(r.columnRoot);
      n.children.forEach(rows);
    }

    rows(r.rowRoot);
    return out;
  }

  test('Given random value edits, when they are applied as deltas, then the '
      'result equals a fresh computation (values, show as, value sorting)', () {
    final rnd = Random(7);
    final source = table(rnd, 400);
    const engine = PivotEngine();
    final ctx = PivotContext();
    final result = engine.compute(spec, source, ctx);
    expect(PivotEngine.supportsDelta(spec), isTrue);
    var applied = 0;
    for (var round = 0; round < 40; round++) {
      final rows = <int, List<(CellValue, String?)>>{};
      for (var k = 0; k < 1 + rnd.nextInt(6); k++) {
        final i = rnd.nextInt(source.rowCount);
        rows[i] = [
          (source.columns[0].values[i], null),
          (source.columns[1].values[i], null),
          // Units never drop: a MIN/MAX extreme can't be taken out.
          (
            NumberValue(
              (source.columns[2].values[i] as NumberValue).number +
                  rnd.nextInt(5),
            ),
            null,
          ),
          (
            rnd.nextBool() ? CellValue.empty : NumberValue(rnd.nextInt(99) / 3),
            null,
          ),
        ];
      }
      final out = engine.applyDelta(result, rows, ctx);
      if (out == null) continue;
      applied++;
      expect(identical(out, result), isTrue);
      final fresh = engine.compute(spec, source, ctx);
      expect(snapshot(out), snapshot(fresh), reason: 'round $round');
    }
    expect(applied, greaterThan(20));
  });

  test('Given a pivot, when a delta changes a group key, removes the MAX, '
      'brings an error, or the spec filters or calculates, then it is '
      'refused without changes', () {
    final source = table(Random(3), 50);
    const engine = PivotEngine();
    final ctx = PivotContext();
    final result = engine.compute(spec, source, ctx);
    final before = snapshot(result);
    List<(CellValue, String?)> row(int i, {CellValue? r, CellValue? u}) => [
      (r ?? source.columns[0].values[i], null),
      (source.columns[1].values[i], null),
      (u ?? source.columns[2].values[i], null),
      (source.columns[3].values[i], null),
    ];
    final other = regions.firstWhere(
      (x) => x != (source.columns[0].values[0] as TextValue).text,
    );

    expect(
      engine.applyDelta(result, {0: row(0, r: TextValue(other))}, ctx),
      isNull,
    );
    expect(
      engine.applyDelta(result, {
        1: row(1, u: const ErrorValue(CellErrorKind.div0)),
      }, ctx),
      isNotNull,
      reason: 'a new error is added (no removal of one)',
    );
    final fresh = engine.compute(spec, source, ctx);
    expect(snapshot(result), snapshot(fresh));
    expect(
      engine.applyDelta(result, {1: row(1, u: const NumberValue(3))}, ctx),
      isNull,
      reason: 'SUM is in error now',
    );

    final again = engine.compute(spec, table(Random(3), 50), ctx);
    final maxRow = List.generate(50, (i) => i).reduce(
      (a, b) =>
          (again.source.columns[2].values[a] as NumberValue).number >=
              (again.source.columns[2].values[b] as NumberValue).number
          ? a
          : b,
    );
    expect(
      engine.applyDelta(again, {
        maxRow: [
          for (final c in again.source.columns)
            c.colId == 'u'
                ? (const NumberValue(-1) as CellValue, null)
                : (c.values[maxRow], null),
        ],
      }, ctx),
      isNull,
    );
    expect(snapshot(again), before);

    expect(
      PivotEngine.supportsDelta(
        PivotSpec(
          rows: const [PivotGroupSpec('r')],
          values: const [
            PivotValueSpec(source: 'u', summarizeBy: PivotSummarize.median),
          ],
        ),
      ),
      isFalse,
    );
    expect(
      PivotEngine.supportsDelta(
        PivotSpec(
          rows: const [PivotGroupSpec('r')],
          values: const [PivotValueSpec(formula: '=1')],
        ),
      ),
      isFalse,
    );
  });
}
