import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';

const _sheet = '0193a3c2-0000-7000-8000-000000000001';
const _row1 = '0193a3c2-0000-7000-8000-000000000011';
const _row2 = '0193a3c2-0000-7000-8000-000000000012';
const _col1 = '0193a3c2-0000-7000-8000-000000000021';
const _col2 = '0193a3c2-0000-7000-8000-000000000022';

Map<String, Object?> _fullSpec() => {
  'v': 1,
  'type': 'combo',
  'stacking': 'normal',
  'data': {
    'ranges': [
      {'s': _sheet, 'r1': _row1, 'r2': _row2, 'c1': _col1, 'c2': _col2},
    ],
    'switchRowsColumns': true,
    'headerCount': 2,
    'useFirstColumnAsLabels': false,
    'treatLabelsAsText': true,
    'aggregate': 'median',
    'domain': {
      'ref': {'range': 0, 'offset': 0},
      'reverse': true,
    },
    'seriesRefs': [
      {
        'key': _col2,
        'ref': {'range': 0, 'offset': 1},
        'hidden': true,
      },
    ],
    'includeHidden': true,
    'emptyCells': 'connect',
    'maxPoints': 5000,
  },
  'style': {
    'background': '#101010',
    'fontFamily': 'Lato',
    'border': 'theme:accent2',
    'maximize': true,
    'smooth': true,
    'plotNullValues': true,
    'compareMode': 'category',
    'palette': ['#FF0000', '#00FF00'],
  },
  'title': {
    'text': 'Revenue by region',
    'font': {'size': 18, 'bold': true, 'color': '#333333'},
    'align': 'left',
  },
  'subtitle': {'text': 'FY 2026'},
  'axes': {
    'h': {
      'title': {'text': 'Region'},
      'labels': {'slant': 'custom', 'angle': -45},
      'reverse': true,
    },
    'v': {
      'min': 0,
      'max': 100,
      'logScale': true,
      'numberFormat': '0%',
      'showLine': false,
    },
    'v2': {
      'title': {'text': 'Units'},
    },
  },
  'legend': {
    'position': 'bottom',
    'alignment': 'end',
    'font': {'italic': true},
  },
  'gridlines': {
    'v': {
      'major': {'show': true, 'count': 5, 'color': '#CCCCCC'},
      'minor': {'show': true, 'count': 2},
      'ticks': {'major': 'outside', 'minor': 'inside'},
    },
  },
  'series': {
    _col2: {
      'type': 'line',
      'axis': 'right',
      'color': 'theme:accent3',
      'fillOpacity': 0.5,
      'lineWidth': 3,
      'lineDash': 'dashDot',
      'pointSize': 6,
      'pointShape': 'diamond',
      'dataLabels': {'show': true, 'position': 'above', 'type': 'percent'},
      'trendline': {
        'type': 'polynomial',
        'degree': 3,
        'label': 'equation',
        'showR2': true,
      },
      'points': {
        '3': {'color': '#E53935'},
      },
      'labelOverride': 'Units sold',
    },
  },
  'typeOptions': {'pieHole': 0.5, 'futureOption': 7},
};

void main() {
  group('Given a full v1 chart spec JSON', () {
    test('when parsing and encoding then the JSON round-trips unchanged', () {
      final json = _fullSpec();
      expect(ChartSpec.fromJson(json).toJson(), json);
    });

    test('when parsing then typed fields are read', () {
      final s = ChartSpec.fromJson(_fullSpec());
      expect(s.type, ChartType.combo);
      expect(s.stacking, ChartStacking.normal);
      expect(s.data.headerCount, 2);
      expect(s.data.aggregate, ChartAggregate.median);
      expect(s.data.seriesRefs.single.hidden, isTrue);
      expect(s.axes.v.logScale, isTrue);
      expect(s.axes.h.labels.angle, -45);
      expect(s.gridlines.v.ticks.major, TickMark.outside);
      final st = s.seriesStyle(_col2);
      expect(st.axis, SeriesAxis.right);
      expect(st.trendline!.type, TrendlineType.polynomial);
      expect(st.points[3]!.color, '#E53935');
      expect(s.pieOptions.pieHole, 0.5);
    });

    test(
      'when encoding as a string and parsing it then the specs are equal',
      () {
        final s = ChartSpec.fromJson(_fullSpec());
        expect(ChartSpec.fromJson(s.encode()), s);
        expect(ChartSpec.fromJson(s.encode()).hashCode, s.hashCode);
      },
    );
  });

  group('Given JSON with unknown keys at several levels', () {
    final json = {
      'v': 1,
      'type': 'line',
      'futureTop': {'a': 1},
      'data': {
        'ranges': <Object?>[],
        'futureData': true,
        'seriesRefs': [
          {
            'key': 'k1',
            'ref': {'range': 0, 'offset': 1, 'futureRef': 2},
            'futureSeriesRef': 'x',
          },
        ],
      },
      'style': {'futureStyle': 'y'},
      'title': {
        'text': 'T',
        'font': {'futureFont': 1},
      },
      'axes': {
        'h': {
          'futureAxis': [1, 2],
        },
        'futureAxes': 0,
      },
      'legend': {'futureLegend': null},
      'series': {
        'k1': {
          'futureSeries': {'deep': true},
          'dataLabels': {'futureDl': 1},
        },
      },
    };

    test('when round-tripping then every unknown key survives', () {
      final out = ChartSpec.fromJson(json).toJson();
      expect(out['futureTop'], {'a': 1});
      expect((out['data']! as Map)['futureData'], true);
      final ref = ((out['data']! as Map)['seriesRefs'] as List).single as Map;
      expect(ref['futureSeriesRef'], 'x');
      expect((ref['ref'] as Map)['futureRef'], 2);
      expect((out['style']! as Map)['futureStyle'], 'y');
      expect(((out['title']! as Map)['font'] as Map)['futureFont'], 1);
      expect(((out['axes']! as Map)['h'] as Map)['futureAxis'], [1, 2]);
      expect((out['axes']! as Map)['futureAxes'], 0);
      expect((out['legend']! as Map).containsKey('futureLegend'), isTrue);
      final series = (out['series']! as Map)['k1'] as Map;
      expect(series['futureSeries'], {'deep': true});
      expect((series['dataLabels'] as Map)['futureDl'], 1);
    });
  });

  group('Given a default spec', () {
    const s = ChartSpec();

    test('when encoding then defaults are omitted', () {
      expect(s.toJson(), {
        'v': 1,
        'type': 'column',
        'data': {'ranges': <Object?>[], 'seriesRefs': <Object?>[]},
      });
    });

    test('when copying with a title then only the title differs', () {
      final t = s.copyWith(title: const ChartTitle(text: 'Hi'));
      expect(t.title.text, 'Hi');
      expect(t.copyWith(title: ChartTitle.none), s);
    });

    test('when setting a series style then it is keyed by the series key', () {
      final t = s.withSeriesStyle('abc', const SeriesStyle(color: '#FF0000'));
      expect(t.seriesStyle('abc').color, '#FF0000');
      expect(t.seriesStyle('other'), SeriesStyle.standard);
    });
  });

  group('Given invalid or foreign JSON', () {
    test('when the input is not JSON then the default spec is returned', () {
      expect(ChartSpec.fromJson('not json'), const ChartSpec());
      expect(ChartSpec.fromJson(null), const ChartSpec());
    });

    test('when values have wrong types then they read as defaults', () {
      final s = ChartSpec.fromJson({
        'v': 1,
        'type': 'bar',
        'stacking': 42,
        'legend': {'position': 'diagonal'},
        'data': {'headerCount': 'one', 'ranges': 'nope'},
      });
      expect(s.type, ChartType.bar);
      expect(s.stacking, ChartStacking.none);
      expect(s.legend.position, LegendPosition.auto);
      expect(s.data.headerCount, isNull);
      expect(s.data.ranges, isEmpty);
    });

    test('when the type is unknown then the id is preserved', () {
      final s = ChartSpec.fromJson({
        'v': 1,
        'type': 'sankey',
        'data': {'ranges': <Object?>[]},
      });
      expect(s.hasKnownType, isFalse);
      expect(s.toJson()['type'], 'sankey');
    });

    test(
      'when the version is newer then the JSON is kept verbatim and patching fails',
      () {
        final json = {
          'v': 2,
          'type': 'column',
          'newField': {'x': 1},
          'data': {'ranges': <Object?>[]},
        };
        final s = ChartSpec.fromJson(json);
        expect(s.isFromNewerVersion, isTrue);
        expect(s.toJson(), json);
        expect(
          () => s.patch({
            'title': {'text': 'x'},
          }),
          throwsStateError,
        );
      },
    );
  });

  group('Given a version upgrade hook', () {
    tearDown(ChartSpec.upgrades.clear);

    test('when reading an older version then the hook runs', () {
      ChartSpec.upgrades[0] = (m) => {...m, 'type': 'line'};
      final s = ChartSpec.fromJson({'v': 0, 'type': 'column'});
      expect(s.type, ChartType.line);
      expect(s.toJson()['v'], 1);
    });
  });

  group('Given a spec and a merge patch', () {
    final spec = ChartSpec.fromJson(_fullSpec());

    test('when patching the title then other fields stay', () {
      final p = spec.patch({
        'title': {'text': 'New'},
      });
      expect(p.title.text, 'New');
      expect(p.title.font.bold, isTrue);
      expect(p.style, spec.style);
    });

    test('when patching a key to null then it resets to the default', () {
      final p = spec.patch({
        'style': {'maximize': null},
        'data': {'headerCount': null},
      });
      expect(p.style.maximize, isFalse);
      expect(p.data.headerCount, isNull);
    });

    test('when patching a series color then only that series changes', () {
      final p = spec.patch({
        'series': {
          _col2: {'color': '#123456'},
        },
      });
      expect(p.seriesStyle(_col2).color, '#123456');
      expect(p.seriesStyle(_col2).lineWidth, 3);
    });

    final invalid = <(String, Map<String, Object?>, String)>[
      ('an unknown type', {'type': 'sankey'}, 'type'),
      (
        'a negative header count',
        {
          'data': {'headerCount': -1},
        },
        'data.headerCount',
      ),
      (
        'a bad color',
        {
          'style': {'background': 'blueish'},
        },
        'style.background',
      ),
      (
        'a pie hole above 0.9',
        {
          'typeOptions': {'pieHole': 0.95},
        },
        'typeOptions.pieHole',
      ),
      (
        'a bad legend position',
        {
          'legend': {'position': 'diagonal'},
        },
        'legend.position',
      ),
      (
        'min ≥ max',
        {
          'axes': {
            'v': {'min': 10, 'max': 5, 'logScale': false},
          },
        },
        'axes.v.min',
      ),
      (
        'a series ref to a missing range',
        {
          'data': {
            'seriesRefs': [
              {
                'key': 'x',
                'ref': {'range': 3, 'offset': 0},
              },
            ],
          },
        },
        'data.seriesRefs[0].ref.range',
      ),
      (
        'a string line width',
        {
          'series': {
            'k': {'lineWidth': 'thick'},
          },
        },
        'series.k.lineWidth',
      ),
      ('removing the data section', {'data': null}, 'data'),
    ];
    for (final (name, patch, path) in invalid) {
      test('when the patch sets $name then validation fails at $path', () {
        expect(
          () => spec.patch(patch),
          throwsA(
            isA<ChartSpecValidationException>().having(
              (e) => e.issues.map((i) => i.path),
              'paths',
              contains(path),
            ),
          ),
        );
      });
    }
  });

  group('Given a pie chart with options', () {
    final pie = ChartSpec.fromJson({
      'v': 1,
      'type': 'pie',
      'data': {'ranges': <Object?>[]},
      'typeOptions': {'pieHole': 0.4, 'sliceLabel': 'value'},
    });

    test(
      'when switching to column and back then the pie options are restored',
      () {
        final col = pie.withType(ChartType.column);
        expect(col.typeOptions, isEmpty);
        expect(col.extras['typeOptionsByType'], {
          'pie': {'pieHole': 0.4, 'sliceLabel': 'value'},
        });
        final back = col.withType(ChartType.pie);
        expect(back.pieOptions.pieHole, 0.4);
        expect(back.extras.containsKey('typeOptionsByType'), isFalse);
      },
    );

    test(
      'when switching to a type without stacking then stacking is dropped',
      () {
        final s = pie.withType(
          ChartType.column,
          stacking: ChartStacking.percent,
        );
        expect(s.stacking, ChartStacking.percent);
        expect(s.withType(ChartType.line).stacking, ChartStacking.none);
      },
    );
  });

  group('Given type options', () {
    test('when reading waterfall options then subtotals are sorted', () {
      final o = WaterfallOptions.fromJson({
        'subtotals': [
          {'afterIndex': 5, 'label': 'H2'},
          {'afterIndex': 2},
        ],
        'connectorLines': {'show': false},
      });
      expect([for (final s in o.subtotals) s.afterIndex], [2, 5]);
      expect(o.connectorShow, isFalse);
      expect(WaterfallOptions.fromJson(o.toJson()), o);
    });

    final roundTrips =
        <(String, SpecNode Function(Object?), Map<String, Object?>)>[
          (
            'pie',
            PieOptions.fromJson,
            {
              'pieHole': 0.25,
              'slices': {
                '2': {'offset': 0.2},
              },
              'startAngle': 90,
            },
          ),
          (
            'histogram',
            HistogramOptions.fromJson,
            {'bucketSize': 5, 'outlierPercentile': 5},
          ),
          (
            'candlestick',
            CandlestickOptions.fromJson,
            {'risingColor': '#00FF00', 'risingFilled': true},
          ),
          (
            'table',
            TableOptions.fromJson,
            {'pageSize': 10, 'sortColumn': 1, 'sortAscending': false},
          ),
          (
            'radar',
            RadarOptions.fromJson,
            {'fillOpacity': 0.5, 'gridShape': 'circle'},
          ),
          (
            'bubble',
            BubbleOptions.fromJson,
            {
              'sizeRange': [4, 40],
              'colorBy': 'category',
            },
          ),
          (
            'scorecard',
            ScorecardOptions.fromJson,
            {'aggregate': 'average', 'compareMode': 'percent'},
          ),
        ];
    for (final (name, parse, json) in roundTrips) {
      test('when round-tripping $name options then the JSON is unchanged', () {
        expect(parse(json).toJson(), json);
      });
    }
  });

  group('Given the JSON schema', () {
    final schema = ChartSpecSchema.jsonSchema();

    test('when exporting then objects are strict and list every property', () {
      expect(schema['type'], 'object');
      expect(schema['additionalProperties'], false);
      final props = schema['properties']! as Map;
      expect((schema['required']! as List).toSet(), props.keys.toSet());
      final data = props['data'] as Map;
      expect(data['additionalProperties'], false);
      expect(jsonEncode(schema), isNotEmpty);
    });

    test('when validating the full example then there are no issues', () {
      expect(ChartSpecSchema.validate(_fullSpec()), isEmpty);
    });

    test(
      'when a strict client sends maps as pairs and nulls then they are normalized',
      () {
        final strict = <String, Object?>{
          'v': 1,
          'type': 'line',
          'stacking': null,
          'data': {
            'ranges': [
              {'s': _sheet, 'r1': _row1, 'r2': _row2, 'c1': _col1, 'c2': _col2},
            ],
            'headerCount': null,
            'seriesRefs': [
              {
                'key': _col2,
                'ref': {'range': 0, 'offset': 1},
                'hidden': null,
              },
            ],
          },
          'series': [
            {
              'key': _col2,
              'value': {
                'color': '#FF0000',
                'points': [
                  {
                    'key': '2',
                    'value': {'color': '#00FF00'},
                  },
                ],
                'trendline': null,
              },
            },
          ],
        };

        final normalized = ChartSpecSchema.fromStrictJson(strict);
        final spec = ChartSpec.parseStrict(normalized);

        expect(normalized['stacking'], isNull);
        expect(normalized.containsKey('stacking'), isFalse);
        expect(spec.type, ChartType.line);
        expect(spec.seriesStyle(_col2).color, '#FF0000');
        expect(spec.seriesStyle(_col2).points[2]!.color, '#00FF00');
        expect(spec.data.seriesRefs.single.hidden, isFalse);
      },
    );
  });
}
