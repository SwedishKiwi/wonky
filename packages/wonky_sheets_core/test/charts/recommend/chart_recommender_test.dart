import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

import '../support/chart_test_support.dart';

List<ChartSuggestion> suggest(
  List<List<Object?>> rows, {
  Map<String, String> formats = const {},
  String? a1,
}) {
  final (_, model) = buildTable(rows, columnFormats: formats);
  final width = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
  final range = a1 ?? 'A1:${String.fromCharCode(0x40 + width)}${rows.length}';
  return ChartRecommender.recommend(
    SelectionProfile.fromRanges(
      [rangeOf(model, range)],
      model,
      ModelCellSource(model),
    ),
  );
}

void main() {
  final cases =
      <(String, List<List<Object?>>, Map<String, String>, List<String>)>[
        (
          'rule 1: few text labels and one positive column',
          [
            ['Fruit', 'Sales'],
            ['Apples', 4],
            ['Pears', 3],
            ['Plums', 2],
          ],
          {},
          ['Pie chart', 'Column chart', 'Bar chart', 'Doughnut chart'],
        ),
        (
          'rule 2: dates and numbers',
          [
            ['Day', 'Visits', 'Sales'],
            [45000, 10, 3],
            [45001, 12, 4],
            [45002, 9, 2],
          ],
          {'A': 'yyyy-mm-dd'},
          ['Line chart', 'Area chart', 'Column chart', 'Combo chart'],
        ),
        (
          'rule 3: text labels and several numeric columns',
          [
            ['Region', 'Q1', 'Q2'],
            ['North', 4, 5],
            ['South', -3, 2],
          ],
          {},
          ['Column chart', 'Bar chart', 'Stacked column chart', 'Line chart'],
        ),
        (
          'rule 4: many repeated labels',
          [
            ['Region', 'Amount'],
            for (var i = 0; i < 40; i++) [i.isEven ? 'East' : 'West', i],
          ],
          {},
          ['Column chart', 'Pie chart', 'Table chart'],
        ),
        (
          'rule 5: two numeric columns',
          [
            ['X', 'Y'],
            [1, 2],
            [2, 3],
          ],
          {},
          ['Scatter chart', 'Line chart'],
        ),
        (
          'rule 5: three numeric columns',
          [
            ['X', 'Y', 'Size'],
            [1, 2, 5],
            [2, 3, 6],
          ],
          {},
          ['Scatter chart', 'Line chart', 'Bubble chart'],
        ),
        (
          'rule 6: one numeric column',
          [
            ['Score'],
            [1],
            [5],
            [3],
          ],
          {},
          ['Histogram chart', 'Column chart', 'Scorecard chart'],
        ),
        (
          'rule 7: dates with low/open/close/high headers',
          [
            ['Date', 'High', 'Low', 'Open', 'Close'],
            [45000, 5, 1, 2, 4],
            [45001, 6, 2, 4, 3],
          ],
          {'A': 'yyyy-mm-dd'},
          ['Candlestick chart', 'Line chart'],
        ),
        (
          'rule 8: a single number',
          [
            [42],
          ],
          {},
          ['Scorecard chart'],
        ),
        (
          'rule 9: mostly text',
          [
            ['Name', 'Note'],
            ['a', 'x'],
            ['b', 'y'],
          ],
          {},
          ['Table chart', 'Column chart'],
        ),
      ];

  group('Given the recommendation rules of 08 §5.2', () {
    for (final (name, rows, formats, expected) in cases) {
      test(
        'when the selection matches $name then the suggestions are $expected',
        () {
          final s = suggest(rows, formats: formats);

          expect(s.map((x) => x.label), expected);
          expect(s.first.isDefault, isTrue);
          expect(s.skip(1).map((x) => x.isDefault), everyElement(isFalse));
        },
      );
    }

    for (final (name, rows, formats, _) in cases) {
      test(
        'when inserting the default chart for $name then it lays out with content',
        () {
          final (_, model) = buildTable(rows, columnFormats: formats);
          final width = rows.fold<int>(
            0,
            (m, r) => r.length > m ? r.length : m,
          );
          final range = rangeOf(
            model,
            'A1:${String.fromCharCode(0x40 + width)}${rows.length}',
          );
          final spec = ChartRecommender.recommend(
            SelectionProfile.fromRanges([range], model, ModelCellSource(model)),
          ).first.spec;

          final scene = sceneOf(spec, model);

          expect(textsOf(scene, SceneRole.emptyState), isEmpty);
        },
      );
    }
  });

  group('Given the candlestick suggestion', () {
    test(
      'when the headers are in another order then the series are low, open, close, high',
      () {
        final (_, model) = buildTable(
          [
            ['Date', 'High', 'Low', 'Open', 'Close'],
            [45000, 5, 1, 2, 4],
          ],
          columnFormats: {'A': 'yyyy-mm-dd'},
        );
        final profile = SelectionProfile.fromRanges(
          [rangeOf(model, 'A1:E2')],
          model,
          ModelCellSource(model),
        );

        final spec = ChartRecommender.recommend(profile).first.spec;

        expect(spec.data.seriesRefs.map((r) => r.key), [
          columnKey(model, 'C'),
          columnKey(model, 'D'),
          columnKey(model, 'E'),
          columnKey(model, 'B'),
        ]);
      },
    );
  });

  group('Given a selection profile', () {
    test(
      'when profiling then the header count is detected and written into the spec',
      () {
        final (_, model) = buildTable([
          ['Fruit', 'Sales'],
          ['Apples', 4],
          ['Pears', 4],
        ]);

        final profile = SelectionProfile.fromRanges(
          [rangeOf(model, 'A1:B3')],
          model,
          ModelCellSource(model),
        );
        final spec = ChartRecommender.recommend(profile).first.spec;

        expect(profile.headerCount, 1);
        expect(profile.rowCount, 2);
        expect(profile.columns.first.isText, isTrue);
        expect(profile.columns.first.distinctCount, 2);
        expect(profile.columns.last.allPositive, isTrue);
        expect(spec.data.headerCount, 1);
        expect(spec.data.domain!.key, columnKey(model, 'A'));
      },
    );
  });

  group('Given a sheet with a block of data', () {
    test(
      'when growing from a cell inside then the whole contiguous block is found',
      () {
        final (_, model) = buildTable([
          [null, null, null, null],
          [null, 'a', 'b', null],
          [null, 1, 2, null],
          [null, 3, null, null],
        ]);

        final r = ChartRecommender.contiguousRegion(
          model.sheets.first.id,
          2,
          2,
          ModelCellSource(model),
          rowCount: 10,
          columnCount: 10,
        );

        expect([r.top, r.left, r.bottom, r.right], [1, 1, 3, 2]);
      },
    );
  });
}
