import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:xml/xml.dart';

import '../support/chart_test_support.dart';

const months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Whether every segment of [cmds] (move/line pairs) is horizontal.
bool allHorizontal(List<PathCmd> cmds) {
  for (var i = 0; i + 1 < cmds.length; i += 2) {
    final a = cmds[i] as PMoveTo, b = cmds[i + 1] as PLineTo;
    if (a.y != b.y) return false;
  }
  return true;
}

/// Whether every segment of [cmds] (move/line pairs) is vertical.
bool allVertical(List<PathCmd> cmds) {
  for (var i = 0; i + 1 < cmds.length; i += 2) {
    final a = cmds[i] as PMoveTo, b = cmds[i + 1] as PLineTo;
    if (a.x != b.x) return false;
  }
  return true;
}

void main() {
  late WorkbookModel revenue;
  setUp(() => revenue = monthlyRevenue());

  ChartScene revenueScene(ChartSpec Function(ChartSpec) edit) =>
      sceneOf(edit(specFor(revenue, 'A1:D13')), revenue);

  group('Given a column chart of 12 months × 3 regions', () {
    late ChartScene scene;
    setUp(() => scene = revenueScene((s) => s));

    test('when laid out then there is one column per series and month', () {
      final points = primitivesOf<SRect>(scene, SceneRole.point);

      expect(points, hasLength(36));
      expect(
        points.where((p) => p.tag!.seriesKey == columnKey(revenue, 'B')),
        hasLength(12),
      );
    });

    test('when laid out then every month labels the domain axis', () {
      expect(textsOf(scene, SceneRole.axisLabel, detail: 'h'), months);
    });

    test('when laid out then the value axis has nice ticks', () {
      expect(textsOf(scene, SceneRole.axisLabel, detail: 'v'), [
        '0',
        '10',
        '20',
        '30',
        '40',
        '50',
      ]);
    });

    test('when laid out then the legend lists the series', () {
      expect(textsOf(scene, SceneRole.legendEntry), ['North', 'South', 'East']);
    });

    test('when laid out then the value gridlines are horizontal', () {
      final grid = primitivesOf<SPath>(scene, SceneRole.gridline, detail: 'v');

      expect(grid, hasLength(1));
      expect(allHorizontal(grid.single.cmds), isTrue);
    });

    test(
      'when laid out then the columns of a month sit side by side in series order',
      () {
        final jan = [
          for (final p in primitivesOf<SRect>(scene, SceneRole.point))
            if (p.tag!.pointIndex == 0) p,
        ];

        expect(jan.map((p) => p.tag!.seriesKey), [
          columnKey(revenue, 'B'),
          columnKey(revenue, 'C'),
          columnKey(revenue, 'D'),
        ]);
        expect(jan[0].rect.right, lessThanOrEqualTo(jan[1].rect.left + 1e-9));
        expect(jan[1].rect.right, lessThanOrEqualTo(jan[2].rect.left + 1e-9));
      },
    );

    test(
      'when laid out then column heights are proportional to the values',
      () {
        final north = [
          for (final p in primitivesOf<SRect>(scene, SceneRole.point))
            if (p.tag!.seriesKey == columnKey(revenue, 'B')) p,
        ];

        // North: 10 in January, 43 in December.
        expect(
          north.last.rect.height / north.first.rect.height,
          closeTo(4.3, 1e-6),
        );
        expect(north.first.rect.bottom, closeTo(scene.plotArea!.bottom, 1e-6));
      },
    );

    test('when laying out twice then the scenes are identical', () {
      expect(revenueScene((s) => s).toJson(), scene.toJson());
    });

    test(
      'when hit-testing the center of a column then that point is found',
      () {
        final p = primitivesOf<SRect>(scene, SceneRole.point)[4];

        final hit = scene.hitTest(p.rect.centerX, p.rect.centerY);

        expect(hit!.tag.role, SceneRole.point);
        expect(hit.tag.seriesKey, p.tag!.seriesKey);
        expect(hit.tag.pointIndex, p.tag!.pointIndex);
      },
    );

    test('when matching the scene golden then nothing changed', () {
      expectGoldenJson('column_monthly', scene.toJson());
    });
  });

  group('Given data labels on grouped columns', () {
    test('when laid out then each label is centered over its own column', () {
      final keys = [
        for (final l in ['B', 'C', 'D']) columnKey(revenue, l),
      ];
      final scene = revenueScene(
        (s) => s.copyWith(
          series: {
            for (final k in keys)
              k: const SeriesStyle(dataLabels: DataLabelsSpec(show: true)),
          },
        ),
      );
      final points = primitivesOf<SRect>(scene, SceneRole.point);
      final labels = primitivesOf<SText>(scene, SceneRole.dataLabel);

      expect(labels, hasLength(36));
      for (final l in labels) {
        final col = points.firstWhere(
          (p) =>
              p.tag!.seriesKey == l.tag!.seriesKey &&
              p.tag!.pointIndex == l.tag!.pointIndex,
        );
        expect(l.at.x, closeTo(col.rect.centerX, 1e-6));
        expect(l.at.y, lessThan(col.rect.top));
      }
      expect(labels.first.text, '10');
    });
  });

  group('Given a bar chart', () {
    late ChartScene scene;
    setUp(() => scene = revenueScene((s) => s.withType(ChartType.bar)));

    test('when laid out then bars grow horizontally from the left edge', () {
      final bars = primitivesOf<SRect>(scene, SceneRole.point);

      expect(bars, hasLength(36));
      for (final b in bars) {
        expect(b.rect.height, closeTo(bars.first.rect.height, 1e-9));
      }
      for (final b in bars) {
        expect(b.rect.left, closeTo(scene.plotArea!.left, 1e-6));
      }
    });

    test(
      'when laid out then months label the vertical axis and values the horizontal one',
      () {
        expect(textsOf(scene, SceneRole.axisLabel, detail: 'v'), months);
        expect(textsOf(scene, SceneRole.axisLabel, detail: 'h').first, '0');
      },
    );

    test('when laid out then the value gridlines are vertical', () {
      final grid = primitivesOf<SPath>(scene, SceneRole.gridline, detail: 'h');

      expect(allVertical(grid.single.cmds), isTrue);
    });
  });

  group('Given stacked columns', () {
    test('when stacking normally then each column starts on the one below', () {
      final scene = revenueScene(
        (s) => s.copyWith(stacking: ChartStacking.normal),
      );
      final jan = [
        for (final p in primitivesOf<SRect>(scene, SceneRole.point))
          if (p.tag!.pointIndex == 0) p,
      ];

      expect(jan[1].rect.bottom, closeTo(jan[0].rect.top, 1e-6));
      expect(jan[2].rect.bottom, closeTo(jan[1].rect.top, 1e-6));
      expect(jan[0].rect.left, jan[1].rect.left);
    });

    test('when stacking to 100 % then the axis ends at 100 %', () {
      final scene = revenueScene(
        (s) => s.copyWith(stacking: ChartStacking.percent),
      );

      expect(textsOf(scene, SceneRole.axisLabel, detail: 'v').last, '100%');
      final jan = [
        for (final p in primitivesOf<SRect>(scene, SceneRole.point))
          if (p.tag!.pointIndex == 0) p,
      ];
      expect(jan.last.rect.top, closeTo(scene.plotArea!.top, 1e-6));
    });
  });

  group('Given a line chart', () {
    test(
      'when laid out then each series is one polyline through every month',
      () {
        final scene = revenueScene((s) => s.withType(ChartType.line));
        final lines = primitivesOf<SPolyline>(scene, SceneRole.series);

        expect(lines, hasLength(3));
        expect(lines.map((l) => l.length), [12, 12, 12]);
        expect(
          primitivesOf<SPolyline>(scene, SceneRole.legendEntry),
          hasLength(3),
        );
      },
    );

    test('when smoothing then the line is a curve', () {
      final scene = revenueScene(
        (s) => s
            .withType(ChartType.line)
            .copyWith(style: const ChartStyle(smooth: true)),
      );
      final curves = primitivesOf<SPath>(scene, SceneRole.series);

      expect(curves, hasLength(3));
      expect(curves.first.cmds.whereType<PCubicTo>(), hasLength(11));
    });

    group('and an empty cell in the middle', () {
      late WorkbookModel model;
      setUp(() {
        model = buildTable([
          ['Day', 'Value'],
          ['a', 1],
          ['b', 2],
          ['c', null],
          ['d', 4],
          ['e', 5],
        ]).$2;
      });

      ChartScene lineWith(EmptyCellMode mode) {
        final spec = specFor(model, 'A1:B6', type: ChartType.line);
        return sceneOf(
          spec.copyWith(data: spec.data.copyWith(emptyCells: mode)),
          model,
        );
      }

      test('when empty cells are gaps then the line breaks', () {
        final lines = primitivesOf<SPolyline>(
          lineWith(EmptyCellMode.gap),
          SceneRole.series,
        );

        expect(lines.map((l) => l.length), [2, 2]);
        expect(lines.last.pointIndexOf(0), 3);
      });

      test('when empty cells are connected then the line skips the point', () {
        final lines = primitivesOf<SPolyline>(
          lineWith(EmptyCellMode.connect),
          SceneRole.series,
        );

        expect(lines.single.length, 4);
      });

      test('when empty cells are zero then the line drops to zero', () {
        final scene = lineWith(EmptyCellMode.zero);
        final line = primitivesOf<SPolyline>(scene, SceneRole.series).single;

        expect(line.length, 5);
        expect(line.xy[5], closeTo(scene.plotArea!.bottom, 1e-6));
      });
    });

    test(
      'when there are 20,000 points then the line is downsampled with a warning',
      () {
        final model = buildTable([
          ['X', 'Y'],
          for (var i = 0; i < 20000; i++) [i, math.sin(i / 100)],
        ], extraRows: 0).$2;
        final spec = specFor(model, 'A1:B20001', type: ChartType.line);

        final layout = layoutChart(spec, resolveChart(spec, model));
        final line = primitivesOf<SPolyline>(
          layout.scene,
          SceneRole.series,
        ).single;

        expect(line.length, Lttb.targetFor(layout.scene.plotArea!.width));
        expect(
          layout.warnings.map((w) => w.code),
          contains(ChartWarningCode.downsampled),
        );
      },
    );
  });

  group('Given an area chart', () {
    test('when stacked then each area is filled down to the series below', () {
      final scene = revenueScene(
        (s) => s.withType(ChartType.area, stacking: ChartStacking.normal),
      );

      expect(primitivesOf<SPath>(scene, SceneRole.series), hasLength(3));
      expect(primitivesOf<SPolyline>(scene, SceneRole.series), hasLength(3));
    });
  });

  group('Given a combo chart', () {
    test(
      'when no types are set then the first series is columns and the rest lines',
      () {
        final scene = revenueScene((s) => s.withType(ChartType.combo));

        expect(primitivesOf<SRect>(scene, SceneRole.point), hasLength(12));
        expect(primitivesOf<SPolyline>(scene, SceneRole.series), hasLength(2));
      },
    );

    test(
      'when a series uses the right axis then a second value axis is drawn',
      () {
        final scene = revenueScene(
          (s) => s
              .withType(ChartType.combo)
              .withSeriesStyle(
                columnKey(revenue, 'D'),
                const SeriesStyle(axis: SeriesAxis.right),
              ),
        );

        expect(textsOf(scene, SceneRole.axisLabel, detail: 'v2'), isNotEmpty);
        final right = primitivesOf<SText>(
          scene,
          SceneRole.axisLabel,
          detail: 'v2',
        );
        expect(right.first.at.x, greaterThan(scene.plotArea!.right));
      },
    );
  });

  group('Given a pie chart of four fruits', () {
    late WorkbookModel model;
    setUp(() {
      model = buildTable([
        ['Fruit', 'Sales'],
        ['Apples', 40],
        ['Pears', 25],
        ['Plums', 20],
        ['Kiwis', 15],
      ]).$2;
    });

    test('when laid out then the slices cover the circle from 12 o\'clock', () {
      final scene = sceneOf(
        specFor(model, 'A1:B5', type: ChartType.pie),
        model,
      );
      final arcs = primitivesOf<SArc>(scene, SceneRole.point);

      expect(arcs, hasLength(4));
      expect(arcs.first.start, closeTo(-math.pi / 2, 1e-9));
      expect(arcs.first.sweep, closeTo(0.4 * 2 * math.pi, 1e-9));
      expect(
        arcs.fold<double>(0, (s, a) => s + a.sweep),
        closeTo(2 * math.pi, 1e-9),
      );
      expect(textsOf(scene, SceneRole.dataLabel), [
        '40.0%',
        '25.0%',
        '20.0%',
        '15.0%',
      ]);
      expect(textsOf(scene, SceneRole.legendEntry), [
        'Apples',
        'Pears',
        'Plums',
        'Kiwis',
      ]);
    });

    test('when the pie has a hole then it is a doughnut', () {
      final scene = sceneOf(
        specFor(
          model,
          'A1:B5',
          type: ChartType.pie,
          typeOptions: {'pieHole': 0.5},
        ),
        model,
      );
      final arc = primitivesOf<SArc>(scene, SceneRole.point).first;

      expect(arc.innerRadius, closeTo(arc.radius * 0.5, 1e-9));
    });

    test(
      'when a slice is pulled out then its center moves along its middle angle',
      () {
        final scene = sceneOf(
          specFor(
            model,
            'A1:B5',
            type: ChartType.pie,
            typeOptions: {
              'slices': {
                '0': {'offset': 0.2},
              },
            },
          ),
          model,
        );
        final arcs = primitivesOf<SArc>(scene, SceneRole.point);

        expect(arcs[0].center.x, greaterThan(arcs[1].center.x));
        expect(arcs[1].center, arcs[2].center);
      },
    );

    test('when a value is negative then it is left out with a warning', () {
      final m = buildTable([
        ['Fruit', 'Sales'],
        ['Apples', 40],
        ['Debt', -10],
      ]).$2;
      final spec = specFor(m, 'A1:B3', type: ChartType.pie);

      final layout = layoutChart(spec, resolveChart(spec, m));

      expect(primitivesOf<SArc>(layout.scene, SceneRole.point), hasLength(1));
      expect(
        layout.warnings.map((w) => w.code),
        contains(ChartWarningCode.pieNegativeIgnored),
      );
    });

    test('when matching the scene golden then nothing changed', () {
      expectGoldenJson(
        'pie_fruit',
        sceneOf(specFor(model, 'A1:B5', type: ChartType.pie), model).toJson(),
      );
    });
  });

  group('Given a scatter chart with an exact linear relation', () {
    late WorkbookModel model;
    late ChartSpec spec;
    setUp(() {
      model = buildTable([
        ['X', 'Y'],
        for (var x = 1; x <= 10; x++) [x, 2 * x + 1],
      ]).$2;
      spec = specFor(model, 'A1:B11', type: ChartType.scatter);
    });

    test('when laid out then each point is a marker on a numeric axis', () {
      final scene = sceneOf(spec, model);
      final markers = primitivesOf<SMarkers>(scene, SceneRole.point).single;

      expect(markers.length, 10);
      expect(markers.size, 7);
      expect(textsOf(scene, SceneRole.axisLabel, detail: 'h'), contains('10'));
      expect(
        primitivesOf<SPath>(scene, SceneRole.gridline, detail: 'h'),
        hasLength(1),
      );
    });

    test(
      'when a linear trendline with its equation is added then it is drawn and listed',
      () {
        final scene = sceneOf(
          spec.withSeriesStyle(
            columnKey(model, 'B'),
            const SeriesStyle(
              trendline: TrendlineSpec(
                label: TrendlineLabel.equation,
                showR2: true,
              ),
            ),
          ),
          model,
        );

        expect(
          primitivesOf<SPolyline>(scene, SceneRole.trendline),
          hasLength(1),
        );
        expect(textsOf(scene, SceneRole.legendEntry), [
          'Y',
          'y = 2x + 1  R² = 1',
        ]);
        expect(textsOf(scene, SceneRole.trendline), ['y = 2x + 1']);
      },
    );

    test('when a moving average is added then it starts at the period', () {
      final scene = sceneOf(
        spec.withSeriesStyle(
          columnKey(model, 'B'),
          const SeriesStyle(
            trendline: TrendlineSpec(
              type: TrendlineType.movingAverage,
              period: 3,
            ),
          ),
        ),
        model,
      );

      expect(
        primitivesOf<SPolyline>(scene, SceneRole.trendline).single.length,
        8,
      );
    });

    test(
      'when an exponential trendline meets non-positive values then it warns',
      () {
        final m = buildTable([
          ['X', 'Y'],
          [1, 2],
          [2, -1],
          [3, 8],
          [4, 16],
        ]).$2;
        final s = specFor(m, 'A1:B5', type: ChartType.scatter).withSeriesStyle(
          columnKey(m, 'B'),
          const SeriesStyle(
            trendline: TrendlineSpec(type: TrendlineType.exponential),
          ),
        );

        final layout = layoutChart(s, resolveChart(s, m));

        expect(
          layout.warnings,
          contains(
            ChartWarning(
              ChartWarningCode.trendlineInvalidPoints,
              '',
              count: 1,
              seriesKey: columnKey(m, 'B'),
            ),
          ),
        );
      },
    );

    test('when the value axis is logarithmic with a zero then it warns', () {
      final m = buildTable([
        ['X', 'Y'],
        [1, 0],
        [2, 10],
        [3, 1000],
      ]).$2;
      final s = specFor(
        m,
        'A1:B4',
        type: ChartType.scatter,
      ).copyWith(axes: const ChartAxes(v: ChartAxis(logScale: true)));

      final layout = layoutChart(s, resolveChart(s, m));

      expect(
        layout.warnings.map((w) => w.code),
        contains(ChartWarningCode.logNonPositiveSkipped),
      );
      expect(textsOf(layout.scene, SceneRole.axisLabel, detail: 'v'), [
        '10',
        '20',
        '50',
        '100',
        '200',
        '500',
        '1,000',
      ]);
    });

    test('when matching the scene golden then nothing changed', () {
      expectGoldenJson('scatter_linear', sceneOf(spec, model).toJson());
    });
  });

  group('Given a bubble chart with a color group', () {
    test(
      'when laid out then bubbles are sized by the last column and grouped in the legend',
      () {
        final model = buildTable([
          ['Name', 'X', 'Y', 'Group', 'Size'],
          ['a', 1, 2, 'g1', 10],
          ['b', 2, 5, 'g2', 40],
          ['c', 4, 3, 'g1', 90],
        ]).$2;

        final scene = sceneOf(
          specFor(model, 'A1:E4', type: ChartType.bubble),
          model,
        );
        final m = primitivesOf<SMarkers>(scene, SceneRole.point).single;

        expect(m.length, 3);
        // Largest first so small bubbles stay on top.
        expect(m.indices, [2, 1, 0]);
        expect(m.sizeOf(0), 36);
        expect(m.sizeOf(2), 6);
        expect(textsOf(scene, SceneRole.legendEntry), ['g1', 'g2']);
        expect(m.fillOf(0), m.fillOf(2));
        expect(m.fillOf(0), isNot(m.fillOf(1)));
      },
    );
  });

  group('Given a histogram', () {
    test(
      'when laid out then there is one bar per non-empty bucket and no legend',
      () {
        final model = buildTable([
          ['Score'],
          for (final v in [1, 2, 2, 3, 3, 3, 9]) [v],
        ]).$2;

        final scene = sceneOf(
          specFor(
            model,
            'A1:A8',
            type: ChartType.histogram,
            typeOptions: {'bucketSize': 2},
          ),
          model,
        );

        expect(primitivesOf<SRect>(scene, SceneRole.point), hasLength(3));
        expect(textsOf(scene, SceneRole.legendEntry), isEmpty);
        expect(textsOf(scene, SceneRole.axisLabel, detail: 'h').first, '0');
      },
    );
  });

  group('Given a candlestick chart', () {
    late WorkbookModel model;
    setUp(() {
      model = buildTable([
        ['Day', 'Low', 'Open', 'Close', 'High'],
        ['Mon', 10, 12, 15, 16],
        ['Tue', 11, 15, 13, 17],
      ]).$2;
    });

    test(
      'when laid out then rising candles are hollow and falling ones filled',
      () {
        final scene = sceneOf(
          specFor(model, 'A1:E3', type: ChartType.candlestick),
          model,
        );
        final bodies = primitivesOf<SRect>(scene, SceneRole.point);

        expect(bodies, hasLength(2));
        expect(bodies[0].fill, testTheme.background);
        expect(bodies[0].stroke!.color, testTheme.positive);
        expect(bodies[1].fill, testTheme.negative);
        expect(primitivesOf<SPath>(scene, SceneRole.series), hasLength(2));
      },
    );

    test(
      'when fewer than four value columns are given then a message is shown',
      () {
        final scene = sceneOf(
          specFor(model, 'A1:C3', type: ChartType.candlestick),
          model,
        );

        expect(
          textsOf(scene, SceneRole.emptyState).single,
          contains('low, open'),
        );
      },
    );
  });

  group('Given a waterfall chart with a start value and a subtotal', () {
    test('when laid out then bars float from the running total', () {
      final model = buildTable([
        ['Item', 'Delta'],
        ['Start', 100],
        ['Sales', 50],
        ['Costs', -30],
      ]).$2;

      final scene = sceneOf(
        specFor(
          model,
          'A1:B4',
          type: ChartType.waterfall,
          typeOptions: {
            'firstValueIsSubtotal': true,
            'subtotals': [
              {'afterIndex': 2, 'label': 'End'},
            ],
          },
        ),
        model,
      );
      final bars = primitivesOf<SRect>(scene, SceneRole.point);

      expect(bars, hasLength(4));
      expect(textsOf(scene, SceneRole.axisLabel, detail: 'h'), [
        'Start',
        'Sales',
        'Costs',
        'End',
      ]);
      expect(bars[1].rect.bottom, closeTo(bars[0].rect.top, 1e-6));
      expect(bars[3].tag!.detail, 'subtotal');
      expect(primitivesOf<SPath>(scene, SceneRole.connector), hasLength(1));
    });
  });

  group('Given a scorecard with a baseline', () {
    test('when laid out then the key value and the change are shown', () {
      final model = buildTable([
        ['Revenue', 'Last year'],
        [150, 120],
      ]).$2;

      final scene = sceneOf(
        specFor(
          model,
          'A1:B2',
          type: ChartType.scorecard,
          typeOptions: {'compareMode': 'percent'},
        ),
        model,
      );

      expect(textsOf(scene, SceneRole.keyValue), ['150']);
      expect(textsOf(scene, SceneRole.baseline), ['▲ 25.0%']);
      expect(
        primitivesOf<SText>(scene, SceneRole.baseline).single.style.color,
        testTheme.positive,
      );
    });
  });

  group('Given a table chart', () {
    late WorkbookModel model;
    setUp(() {
      model = buildTable([
        ['Name', 'Value'],
        for (var i = 1; i <= 5; i++) ['n$i', 10 - i],
      ]).$2;
    });

    test(
      'when laid out then headers and cells are drawn, numbers right-aligned',
      () {
        final scene = sceneOf(
          specFor(model, 'A1:B6', type: ChartType.table),
          model,
        );

        expect(textsOf(scene, SceneRole.tableHeader), ['Name', 'Value']);
        final cells = primitivesOf<SText>(scene, SceneRole.tableCell);
        expect(cells, hasLength(10));
        expect(
          cells.firstWhere((c) => c.text == '9').anchor,
          TextAnchor.middleRight,
        );
      },
    );

    test(
      'when sorted by value then rows ascend and the header shows the direction',
      () {
        final scene = sceneOf(
          specFor(
            model,
            'A1:B6',
            type: ChartType.table,
            typeOptions: {'sortColumn': 1},
          ),
          model,
        );

        expect(textsOf(scene, SceneRole.tableCell, detail: '1'), [
          '5',
          '6',
          '7',
          '8',
          '9',
        ]);
        expect(textsOf(scene, SceneRole.tableHeader), ['Name', 'Value ▲']);
      },
    );

    test('when paged then only one page is shown with a footer', () {
      final scene = sceneOf(
        specFor(
          model,
          'A1:B6',
          type: ChartType.table,
          typeOptions: {'pageSize': 2},
        ),
        model,
        options: const ChartLayoutOptions(tablePage: 1),
      );

      expect(textsOf(scene, SceneRole.tableCell, detail: '0'), ['n3', 'n4']);
      expect(textsOf(scene, SceneRole.legend, detail: 'paging'), [
        'Page 2 of 3',
      ]);
    });
  });

  group('Given a radar chart', () {
    test(
      'when laid out then each series is a closed polygon over the months',
      () {
        final scene = revenueScene((s) => s.withType(ChartType.radar));
        final polys = primitivesOf<SPath>(scene, SceneRole.series);

        expect(polys, hasLength(3));
        expect(polys.first.cmds.whereType<PClose>(), hasLength(1));
        expect(textsOf(scene, SceneRole.axisLabel, detail: 'h'), months);
      },
    );
  });

  group('Given chart chrome options', () {
    test(
      'when a title and subtitle are set then they are drawn at the top',
      () {
        final scene = revenueScene(
          (s) => s.copyWith(
            title: const ChartTitle(text: 'Revenue'),
            subtitle: const ChartTitle(text: '2024'),
          ),
        );

        final title = primitivesOf<SText>(scene, SceneRole.title).single;
        expect(title.text, 'Revenue');
        expect(title.style.bold, isTrue);
        expect(textsOf(scene, SceneRole.subtitle), ['2024']);
        expect(title.at.y, lessThan(scene.plotArea!.top));
      },
    );

    test('when the legend is off then no entries are drawn', () {
      final scene = revenueScene(
        (s) => s.copyWith(
          legend: const ChartLegend(position: LegendPosition.none),
        ),
      );

      expect(textsOf(scene, SceneRole.legendEntry), isEmpty);
    });

    test('when the legend is at the bottom then it is below the plot', () {
      final scene = revenueScene(
        (s) => s.copyWith(
          legend: const ChartLegend(position: LegendPosition.bottom),
        ),
      );

      final entry = primitivesOf<SText>(scene, SceneRole.legendEntry).first;
      expect(entry.at.y, greaterThan(scene.plotArea!.bottom));
    });

    test('when the legend is on the right then it is right of the plot', () {
      final scene = revenueScene(
        (s) => s.copyWith(
          legend: const ChartLegend(position: LegendPosition.right),
        ),
      );

      final entry = primitivesOf<SText>(scene, SceneRole.legendEntry).first;
      expect(entry.at.x, greaterThan(scene.plotArea!.right));
    });

    test('when a series is highlighted then the others are dimmed to 30 %', () {
      final scene = revenueScene((s) => s);
      final highlighted = sceneOf(
        specFor(revenue, 'A1:D13'),
        revenue,
        options: ChartLayoutOptions(
          highlightSeriesKey: columnKey(revenue, 'B'),
        ),
      );

      final groups = [for (final p in highlighted.flattenedGroups) p.opacity];
      expect(groups, everyElement(0.3));
      expect(groups, isNotEmpty);
      expect(
        primitivesOf<SRect>(highlighted, SceneRole.point),
        hasLength(primitivesOf<SRect>(scene, SceneRole.point).length),
      );
    });

    test(
      'when distinguishing series by pattern then lines get different dashes',
      () {
        final scene = sceneOf(
          specFor(revenue, 'A1:D13', type: ChartType.line),
          revenue,
          options: const ChartLayoutOptions(distinguishByPattern: true),
        );
        final dashes = [
          for (final l in primitivesOf<SPolyline>(scene, SceneRole.series))
            l.stroke.dash,
        ];

        expect(dashes[0], isNull);
        expect(dashes[1], isNotNull);
        expect(dashes[2], isNot(dashes[1]));
      },
    );

    test('when the theme is dark then the automatic background is dark', () {
      final dark = ChartTheme.from(SpreadsheetTheme.standard, dark: true);

      final scene = sceneOf(specFor(revenue, 'A1:D13'), revenue, theme: dark);

      expect(scene.background, dark.background);
      expect(
        primitivesOf<SText>(scene, SceneRole.legendEntry).first.style.color,
        dark.text,
      );
    });

    test('when an explicit background is set then it wins over the theme', () {
      final scene = revenueScene(
        (s) => s.copyWith(style: const ChartStyle(background: '#FFEEDD')),
      );

      expect(scene.background, 0xFFFFEEDD);
    });
  });

  group('Given axis and series options', () {
    test(
      'when a data point has its own color then only that column changes',
      () {
        final scene = revenueScene(
          (s) => s.withSeriesStyle(
            columnKey(revenue, 'B'),
            const SeriesStyle(points: {3: PointStyle(color: '#E53935')}),
          ),
        );
        final north = [
          for (final p in primitivesOf<SRect>(scene, SceneRole.point))
            if (p.tag!.seriesKey == columnKey(revenue, 'B')) p,
        ];

        expect(north[3].fill, 0xFFE53935);
        expect(north[2].fill, testTheme.seriesColor(0));
      },
    );

    test('when the value axis is reversed then columns hang from the top', () {
      final scene = revenueScene(
        (s) => s.copyWith(axes: const ChartAxes(v: ChartAxis(reverse: true))),
      );
      final first = primitivesOf<SRect>(scene, SceneRole.point).first;

      expect(first.rect.top, closeTo(scene.plotArea!.top, 1e-6));
    });

    test('when min and max are fixed then the axis uses them', () {
      final scene = revenueScene(
        (s) => s.copyWith(axes: const ChartAxes(v: ChartAxis(min: 0, max: 60))),
      );

      expect(textsOf(scene, SceneRole.axisLabel, detail: 'v').last, '60');
    });

    test('when major ticks are outside then tick marks are drawn', () {
      final scene = revenueScene(
        (s) => s.copyWith(
          gridlines: const ChartGridlines(
            v: AxisGridlines(ticks: TickSpec(major: TickMark.outside)),
          ),
        ),
      );
      final ticks = primitivesOf<SPath>(scene, SceneRole.tick, detail: 'v');

      expect(ticks.single.cmds.whereType<PMoveTo>(), hasLength(6));
    });

    test('when minor gridlines are on then they are drawn between majors', () {
      final scene = revenueScene(
        (s) => s.copyWith(
          gridlines: const ChartGridlines(
            v: AxisGridlines(minor: GridlineSpec(show: true, count: 1)),
          ),
        ),
      );

      final minor = primitivesOf<SPath>(
        scene,
        SceneRole.gridline,
        detail: 'v:minor',
      ).single;
      expect(minor.cmds.whereType<PMoveTo>(), hasLength(5));
    });

    test(
      'when the chart is maximized then the legend sits inside the plot',
      () {
        final scene = revenueScene(
          (s) => s.copyWith(style: const ChartStyle(maximize: true)),
        );
        final entry = primitivesOf<SText>(scene, SceneRole.legendEntry).first;

        expect(scene.plotArea!.contains(entry.at.x, entry.at.y), isTrue);
      },
    );

    test(
      'when a column chart has 3,000 categories then they become a density band',
      () {
        final model = buildTable([
          ['Item', 'Value'],
          for (var i = 0; i < 3000; i++) ['i$i', i % 50],
        ], extraRows: 0).$2;
        final spec = specFor(model, 'A1:B3001');

        final layout = layoutChart(spec, resolveChart(spec, model));

        expect(primitivesOf<SRect>(layout.scene, SceneRole.point), isEmpty);
        expect(
          primitivesOf<SPath>(layout.scene, SceneRole.series),
          hasLength(1),
        );
        expect(
          layout.warnings.map((w) => w.code),
          contains(ChartWarningCode.tooManyCategories),
        );
      },
    );
  });

  group('Given charts that cannot be drawn', () {
    test('when there is no data then "No data" is shown', () {
      final scene = sceneOf(
        const ChartSpec(title: ChartTitle(text: 'Empty')),
        revenue,
      );

      expect(textsOf(scene, SceneRole.emptyState), ['No data']);
      expect(textsOf(scene, SceneRole.title), ['Empty']);
    });

    test(
      'when the spec is from a newer version then a placeholder is shown',
      () {
        final spec = ChartSpec.fromJson({'v': 99, 'type': 'column'});

        final scene = sceneOf(spec, revenue);

        expect(
          textsOf(scene, SceneRole.emptyState).single,
          contains('newer version'),
        );
      },
    );

    test('when the type is not implemented yet then it says so', () {
      final scene = sceneOf(
        specFor(revenue, 'A1:D13', type: ChartType.gauge),
        revenue,
      );

      expect(textsOf(scene, SceneRole.emptyState), ['Unsupported chart type']);
    });
  });

  group('Given every P0 and P1 chart type with fitting data', () {
    for (final type in ChartType.values.where((t) => t.isImplemented)) {
      test(
        'when laying out and exporting ${type.id} then marks are drawn and the SVG is valid',
        () {
          final (model, a1) = switch (type) {
            ChartType.candlestick => (
              buildTable([
                ['Day', 'Low', 'Open', 'Close', 'High'],
                ['Mon', 10, 12, 15, 16],
                ['Tue', 11, 15, 13, 17],
              ]).$2,
              'A1:E3',
            ),
            ChartType.bubble => (
              buildTable([
                ['Name', 'X', 'Y', 'Size'],
                ['a', 1, 2, 10],
                ['b', 2, 5, 40],
              ]).$2,
              'A1:D3',
            ),
            ChartType.histogram || ChartType.scorecard => (revenue, 'B1:B13'),
            ChartType.pie || ChartType.waterfall => (revenue, 'A1:B13'),
            _ => (revenue, 'A1:D13'),
          };
          final scene = sceneOf(specFor(model, a1, type: type), model);

          expect(textsOf(scene, SceneRole.emptyState), isEmpty);
          final marks = scene.flattened.where(
            (p) => const {
              SceneRole.point,
              SceneRole.series,
              SceneRole.keyValue,
              SceneRole.tableCell,
            }.contains(p.tag?.role),
          );
          expect(marks, isNotEmpty);
          final svg = XmlDocument.parse(const SvgChartRenderer().render(scene));
          expect(svg.rootElement.name.local, 'svg');
        },
      );
    }
  });
}

extension on ChartScene {
  /// Every group with an opacity, depth-first.
  Iterable<SGroup> get flattenedGroups sync* {
    Iterable<SGroup> walk(List<ScenePrimitive> list) sync* {
      for (final p in list) {
        if (p is SGroup) {
          yield p;
          yield* walk(p.children);
        } else if (p is SClip) {
          yield* walk(p.children);
        }
      }
    }

    yield* walk(primitives);
  }
}
