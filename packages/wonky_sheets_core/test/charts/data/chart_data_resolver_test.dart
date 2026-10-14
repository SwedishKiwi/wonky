import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart' hide fail;
import 'package:wonky_sheets_core/model.dart';

import '../support/chart_test_support.dart';

void main() {
  group('Given the monthly revenue table A1:D13', () {
    late WorkbookModel model;
    late ChartSpec spec;
    setUp(() {
      model = monthlyRevenue();
      spec = specFor(model, 'A1:D13');
    });

    test('when resolving with auto headers then row 1 names three series', () {
      final data = resolveChart(spec, model);

      expect([for (final s in data.series) s.name], ['North', 'South', 'East']);
      expect(data.domain.labels.first, 'Jan');
      expect(data.domain.labels.last, 'Dec');
      expect(data.domain.kind, DomainKind.categorical);
      expect(data.domain.name, 'Month');
      expect(data.pointCount, 12);
      expect(data.warnings, isEmpty);
    });

    test('when resolving then the series keys are the source column ids', () {
      final data = resolveChart(spec, model);

      expect(
        [for (final s in data.series) s.key],
        [columnKey(model, 'B'), columnKey(model, 'C'), columnKey(model, 'D')],
      );
      expect(data.domain.key, columnKey(model, 'A'));
    });

    test('when resolving then values are read per point', () {
      final data = resolveChart(spec, model);

      expect(data.series.first.values.take(3), [10, 13, 16]);
      expect(data.sourceCellCount, 13 * 4);
    });

    test('when headerCount is 0 then the header row is a point', () {
      final data = resolveChart(
        specFor(model, 'A1:D13', headerCount: 0),
        model,
      );

      expect(data.pointCount, 13);
      expect(data.domain.labels.first, 'Month');
      expect(data.series.first.name, 'Column B');
      expect(data.series.first.values.first, isNaN);
    });

    test('when switching rows and columns then each month is a series', () {
      final data = resolveChart(
        specFor(model, 'A1:D13', switched: true),
        model,
      );

      expect(data.series, hasLength(12));
      expect(data.series.first.name, 'Jan');
      expect(data.domain.labels, ['North', 'South', 'East']);
      expect(data.series.first.key, model.sheets.first.rows.idAt(1));
    });

    test('when a row is hidden by the user then it is skipped', () {
      final data = resolveChart(
        spec,
        model,
        source: FakeCellSource(model, hiddenRows: {2}),
      );

      expect(data.pointCount, 11);
      expect(data.domain.labels, isNot(contains('Feb')));
    });

    test('when a row is hidden by the basic filter then it is skipped', () {
      final data = resolveChart(
        spec,
        model,
        source: FakeCellSource(model, filteredRows: {3}),
      );

      expect(data.domain.labels, isNot(contains('Mar')));
    });

    test('when hidden data is included then hidden rows are kept', () {
      final withHidden = spec.copyWith(
        data: spec.data.copyWith(includeHidden: true),
      );

      final data = resolveChart(
        withHidden,
        model,
        source: FakeCellSource(model, hiddenRows: {2}),
      );

      expect(data.pointCount, 12);
      expect(data.domain.labels, contains('Feb'));
    });

    test('when a column is hidden then its series is left out', () {
      final data = resolveChart(
        spec,
        model,
        source: FakeCellSource(model, hiddenColumns: {2}),
      );

      expect([for (final s in data.series) s.name], ['North', 'East']);
    });

    test('when a series has a label override then it is used as name', () {
      final styled = spec.withSeriesStyle(
        columnKey(model, 'C'),
        const SeriesStyle(labelOverride: 'Southern region'),
      );

      final data = resolveChart(styled, model);

      expect(data.series[1].name, 'Southern region');
    });

    test('when the domain is reversed then the points are reversed', () {
      final reversed = spec.copyWith(
        data: spec.data.copyWith(domain: const DomainRef(reverse: true)),
      );

      final data = resolveChart(reversed, model);

      expect(data.domain.labels.first, 'Dec');
      expect(data.series.first.values.first, 43);
    });

    test('when nothing changes then the data version is stable', () {
      final a = resolveChart(spec, model);
      final b = resolveChart(spec, model);

      expect(a.dataVersion, b.dataVersion);
    });

    test('when a source value changes then the data version changes', () {
      final before = resolveChart(spec, model);

      final after = resolveChart(
        spec,
        model,
        source: FakeCellSource(model, computed: {(1, 1): const FNumber(99)}),
      );

      expect(after.series.first.values.first, 99);
      expect(after.dataVersion, isNot(before.dataVersion));
    });
  });

  group('Given explicit series refs', () {
    late WorkbookModel model;
    setUp(() => model = monthlyRevenue());

    test(
      'when the refs list two columns in reverse order then that order is kept',
      () {
        final spec = specFor(model, 'A1:D13');
        final ordered = spec.copyWith(
          data: spec.data.copyWith(
            seriesRefs: [
              SeriesRef(key: columnKey(model, 'C')),
              SeriesRef(key: columnKey(model, 'B')),
              SeriesRef(key: columnKey(model, 'D'), hidden: true),
            ],
          ),
        );

        final data = resolveChart(ordered, model);

        expect([for (final s in data.series) s.name], ['South', 'North']);
      },
    );

    test(
      'when a referenced column was deleted then it is reported missing',
      () {
        const gone = '00000000-0000-4000-8000-00000000dead';
        final spec = specFor(model, 'A1:D13');
        final withGone = spec.copyWith(
          data: spec.data.copyWith(
            seriesRefs: [
              SeriesRef(key: columnKey(model, 'B')),
              const SeriesRef(key: gone),
            ],
          ),
        );

        final data = resolveChart(withGone, model);

        expect(data.missingSeriesKeys, [gone]);
        expect(
          data.warnings.map((w) => w.code),
          contains(ChartWarningCode.missingSeries),
        );
        expect(data.series.map((s) => s.name), ['North', 'South', 'East']);
      },
    );
  });

  group('Given a domain of numbers or dates', () {
    test('when the first column holds numbers then the domain is numeric', () {
      final (_, model) = buildTable([
        ['X', 'Y'],
        [1, 2],
        [2, 4],
        [4, 8],
      ]);

      final data = resolveChart(specFor(model, 'A1:B4'), model);

      expect(data.domain.kind, DomainKind.numeric);
      expect(data.domain.values, [1, 2, 4]);
    });

    test(
      'when the numbers have a date format then the domain is a date domain',
      () {
        final (_, model) = buildTable(
          [
            ['Day', 'Y'],
            [45000, 2],
            [45001, 4],
          ],
          columnFormats: {'A': 'yyyy-mm-dd'},
        );

        final data = resolveChart(specFor(model, 'A1:B3'), model);

        expect(data.domain.kind, DomainKind.dateTime);
        expect(data.domain.numberFormat, 'yyyy-mm-dd');
        expect(data.domain.labels.first, '2023-03-15');
      },
    );

    test('when labels are treated as text then the domain is categorical', () {
      final (_, model) = buildTable([
        ['X', 'Y'],
        [1, 2],
        [2, 4],
      ]);
      final spec = specFor(model, 'A1:B3');

      final data = resolveChart(
        spec.copyWith(data: spec.data.copyWith(treatLabelsAsText: true)),
        model,
      );

      expect(data.domain.kind, DomainKind.categorical);
      expect(data.domain.labels, ['1', '2']);
    });
  });

  group('Given cells with errors and text', () {
    test('when resolving then they count as empty and errors warn', () {
      final (_, model) = buildTable([
        ['Name', 'Value'],
        ['a', 1],
        ['b', CellErrorKind.div0],
        ['c', 'n/a'],
        ['d', 4],
      ]);

      final data = resolveChart(specFor(model, 'A1:B5'), model);

      expect(data.series.single.values[1], isNaN);
      expect(data.series.single.values[2], isNaN);
      expect(
        data.warnings,
        contains(
          ChartWarning(
            ChartWarningCode.errorValuesIgnored,
            '',
            count: 1,
            seriesKey: columnKey(model, 'B'),
          ),
        ),
      );
    });
  });

  group('Given transactions with repeated labels', () {
    late WorkbookModel model;
    setUp(() {
      model = buildTable([
        ['Region', 'Amount'],
        ['West', 10],
        ['East', 5],
        ['West', 7],
        ['North', 1],
        ['East', 3],
      ]).$2;
    });

    for (final (fn, expected) in [
      (ChartAggregate.sum, [17.0, 8.0, 1.0]),
      (ChartAggregate.count, [2.0, 2.0, 1.0]),
      (ChartAggregate.average, [8.5, 4.0, 1.0]),
      (ChartAggregate.max, [10.0, 5.0, 1.0]),
      (ChartAggregate.min, [7.0, 3.0, 1.0]),
      (ChartAggregate.median, [8.5, 4.0, 1.0]),
    ]) {
      test(
        'when aggregating with ${fn.name} then groups keep first-appearance order',
        () {
          final data = resolveChart(
            specFor(model, 'A1:B6', aggregate: fn),
            model,
          );

          expect(data.domain.labels, ['West', 'East', 'North']);
          expect(data.series.single.values, expected);
        },
      );
    }
  });

  group('Given two ranges of different heights', () {
    test(
      'when resolving then the shorter one is padded and a warning is given',
      () {
        final (_, model) = buildTable([
          ['Name', 'A', 'B'],
          ['x', 1, 10],
          ['y', 2, 20],
          ['z', 3, null],
        ]);
        final spec = ChartSpec(
          data: ChartDataSpec(
            ranges: [rangeOf(model, 'A1:B4'), rangeOf(model, 'C1:C3')],
          ),
        );

        final data = resolveChart(spec, model);

        expect(data.series.map((s) => s.name), ['A', 'B']);
        expect(data.series[1].values[2], isNaN);
        expect(
          data.warnings.map((w) => w.code),
          contains(ChartWarningCode.rangeSizeMismatch),
        );
      },
    );
  });

  group('Given no usable range', () {
    test(
      'when the spec has no ranges then the data is empty with a warning',
      () {
        final (_, model) = buildTable([
          ['a'],
        ]);

        final data = resolveChart(const ChartSpec(), model);

        expect(data.isEmpty, isTrue);
        expect(data.warnings.single.code, ChartWarningCode.noData);
      },
    );

    test('when the range points at a deleted sheet then it is not found', () {
      final (_, model) = buildTable([
        ['a', 1],
      ]);
      const spec = ChartSpec(
        data: ChartDataSpec(ranges: [GridRange.sheet('no-such-sheet')]),
      );

      final data = resolveChart(spec, model);

      expect(data.isEmpty, isTrue);
      expect(
        data.warnings.map((w) => w.code),
        containsAll([ChartWarningCode.rangeNotFound, ChartWarningCode.noData]),
      );
    });
  });

  group('Given special chart types', () {
    test(
      'when resolving a pie with 60 slices then the smallest become "Other"',
      () {
        final (_, model) = buildTable([
          ['Item', 'Value'],
          for (var i = 1; i <= 60; i++) ['i$i', i],
        ]);

        final data = resolveChart(
          specFor(model, 'A1:B61', type: ChartType.pie),
          model,
        );

        expect(data.pointCount, 50);
        expect(data.domain.labels.last, 'Other');
        expect(data.series.first.values.last, 66); // 1 + … + 11
        expect(
          data.warnings.map((w) => w.code),
          contains(ChartWarningCode.pieOtherGrouped),
        );
      },
    );

    test(
      'when resolving a histogram then every numeric column is bucketed',
      () {
        final (_, model) = buildTable([
          ['Score'],
          for (final v in [1, 2, 2, 3, 3, 3, 9]) [v],
        ]);

        final data = resolveChart(
          specFor(
            model,
            'A1:A8',
            type: ChartType.histogram,
            typeOptions: {'bucketSize': 2},
          ),
          model,
        );

        expect(data.histogram!.bucketSize, 2);
        expect(data.histogram!.start, 0);
        expect(data.histogram!.counts.single, [1, 5, 0, 0, 1]);
      },
    );

    test(
      'when resolving a scorecard over one cell then it is the key value',
      () {
        final (_, model) = buildTable([
          [42],
        ]);

        final data = resolveChart(
          specFor(model, 'A1', type: ChartType.scorecard),
          model,
        );

        expect(data.scorecard!.keyValue, 42);
        expect(data.scorecard!.baseline, isNull);
      },
    );

    test(
      'when resolving a scorecard over two columns then the second is the baseline',
      () {
        final (_, model) = buildTable([
          ['Revenue', 'Last year'],
          [100, 80],
          [50, 40],
        ]);

        final data = resolveChart(
          specFor(model, 'A1:B3', type: ChartType.scorecard),
          model,
        );

        expect(data.scorecard!.keyValue, 150);
        expect(data.scorecard!.baseline, 120);
        expect(data.scorecard!.label, 'Revenue');
      },
    );

    test('when a scorecard has a key cell then it is read from that cell', () {
      final (_, model) = buildTable([
        ['Revenue', 'Last year'],
        [100, 80],
      ]);

      final data = resolveChart(
        specFor(
          model,
          'A1:B2',
          type: ChartType.scorecard,
          typeOptions: {'keyValueRef': rangeOf(model, 'B2').toJson()},
        ),
        model,
      );

      expect(data.scorecard!.keyValue, 80);
    });

    test('when resolving a table then every column is kept with its texts', () {
      final (_, model) = buildTable([
        ['Name', 'Note', 'Value'],
        ['a', 'first', 1],
        ['b', 'second', 2],
      ]);

      final data = resolveChart(
        specFor(model, 'A1:C3', type: ChartType.table),
        model,
      );

      expect(data.table!.headers, ['Name', 'Note', 'Value']);
      expect(data.table!.texts[1], ['first', 'second']);
      expect(data.table!.values[2], [1, 2]);
    });

    test(
      'when resolving a bubble chart then the text group column is a series',
      () {
        final (_, model) = buildTable([
          ['Name', 'X', 'Y', 'Group', 'Size'],
          ['a', 1, 2, 'g1', 10],
          ['b', 2, 3, 'g2', 20],
        ]);

        final data = resolveChart(
          specFor(model, 'A1:E3', type: ChartType.bubble),
          model,
        );

        expect(data.series.map((s) => s.name), ['X', 'Y', 'Group', 'Size']);
        expect(data.series[2].texts, ['g1', 'g2']);
      },
    );
  });
}
