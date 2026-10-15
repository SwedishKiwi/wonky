import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';

import '../support/sample_data.dart';

/// Bit patterns of [v] (NaN payloads included).
List<int> bits(Float64List v) =>
    v.buffer.asUint8List(v.offsetInBytes, v.lengthInBytes);

ChartData richData() => ChartData(
  domain: ChartDomain(
    kind: DomainKind.dateTime,
    values: Float64List.fromList([45000, 45001.5, double.nan]),
    labels: const ['2023-03-15', '2023-03-16', ''],
    name: 'Day',
    key: 'c1',
    numberFormat: 'yyyy-mm-dd',
  ),
  series: [
    ChartSeries(
      key: 'c2',
      name: 'Revenue',
      values: Float64List.fromList([0.1 + 0.2, -0.0, double.nan]),
      numberFormat: '0%',
      isPercent: true,
      texts: const ['30%', '-0%', ''],
    ),
    ChartSeries(
      key: 'c3',
      name: 'Tiny',
      values: Float64List.fromList([5e-324, 1.7976931348623157e308, 1 / 3]),
    ),
  ],
  warnings: const [
    ChartWarning(
      ChartWarningCode.errorValuesIgnored,
      '2 error values ignored',
      count: 2,
      seriesKey: 'c2',
    ),
  ],
  sourceCellCount: 9,
  dataVersion: 0x7FFFFFFFFFFFFFF1,
  missingSeriesKeys: const ['c9'],
  histogram: HistogramData(
    start: -2.5,
    bucketSize: 0.5,
    counts: [
      Int32List.fromList([1, 0, 4]),
    ],
    seriesKeys: const ['c2'],
  ),
  scorecard: const ScorecardData(
    keyValue: double.nan,
    baseline: double.infinity,
    keyFormat: '#,##0',
    label: 'Total',
  ),
  table: ChartTableData(
    headers: const ['A', 'B'],
    texts: const [
      ['x', 'y'],
      ['1', '2'],
    ],
    values: [
      Float64List.fromList([double.nan, double.nan]),
      Float64List.fromList([1, 2]),
    ],
  ),
);

void main() {
  group('Given ChartData with every payload', () {
    test('when round-tripping through JSON text then every bit survives', () {
      final data = richData();
      final back = ChartData.fromJson(jsonDecode(jsonEncode(data.toJson())));
      expect(back.domain.kind, DomainKind.dateTime);
      expect(bits(back.domain.values), bits(data.domain.values));
      expect(back.domain.labels, data.domain.labels);
      expect(back.domain.key, 'c1');
      expect(back.domain.numberFormat, 'yyyy-mm-dd');
      for (var i = 0; i < data.series.length; i++) {
        expect(bits(back.series[i].values), bits(data.series[i].values));
        expect(back.series[i].key, data.series[i].key);
        expect(back.series[i].name, data.series[i].name);
        expect(back.series[i].numberFormat, data.series[i].numberFormat);
        expect(back.series[i].isPercent, data.series[i].isPercent);
        expect(back.series[i].texts, data.series[i].texts);
      }
      expect(back.warnings, data.warnings);
      expect(back.warnings.single.message, '2 error values ignored');
      expect(back.sourceCellCount, 9);
      expect(back.dataVersion, 0x7FFFFFFFFFFFFFF1);
      expect(back.missingSeriesKeys, ['c9']);
      expect(back.histogram!.start, -2.5);
      expect(back.histogram!.counts.single, [1, 0, 4]);
      expect(back.scorecard!.keyValue.isNaN, isTrue);
      expect(back.scorecard!.baseline, double.infinity);
      expect(back.scorecard!.label, 'Total');
      expect(back.table!.texts, data.table!.texts);
      expect(bits(back.table!.values[1]), bits(data.table!.values[1]));
    });

    test('when encoding then the JSON is stable', () {
      expect(
        jsonEncode(richData().toJson()),
        jsonEncode(ChartData.fromJson(richData().toJson()).toJson()),
      );
    });

    test(
      'when the domain carries its length then the timeline can read it',
      () {
        final json = sampleData().toJson();
        expect((json['domain']! as Map)['length'], 3);
        expect(((json['series']! as List).first as Map)['key'], 'north');
      },
    );
  });

  group('Given malformed snapshot data', () {
    test('when decoding then it falls back to empty values', () {
      final d = ChartData.fromJson({
        'domain': {'labels': 'nope', 'values': '***'},
        'series': [
          {'values': 'AAAA'},
          7,
        ],
        'warnings': [
          {'code': 'fromTheFuture'},
        ],
      });
      expect(d.domain.length, 0);
      expect(d.series.single.key, 's0');
      expect(d.series.single.values, isEmpty);
      expect(d.warnings, isEmpty);
      expect(ChartData.fromJson('not json').isEmpty, isTrue);
    });

    test('when values come as a JSON list then they are read', () {
      expect(ChartDataCodec.parseDoubles([1, null, 'NaN']).length, 3);
      expect(ChartDataCodec.parseDoubles([1, null])[1].isNaN, isTrue);
    });
  });

  group('Given a data snapshot', () {
    final snap = ChartDataSnapshot(
      data: sampleData(),
      sourceTheme: ChartSourceTheme.of(
        const ChartThemeColors(accentArgbs: [0xFF112233, 0xFF445566]),
        colors: {'text': '#000000', 'bad': 'nope', 'accent1': 0xFF112233},
      ),
      locale: 'de_DE',
      source: const ChartSourceInfo(
        spreadsheetTitle: 'Finance 2026',
        sheetName: 'Q3',
        chartTitle: 'Revenue by region',
        rangesA1: ['Q3!A1:D13'],
      ),
      version: 'a:b:c',
    );

    test('when round-tripping then theme, locale and source survive', () {
      final back = ChartDataSnapshot.fromJson(snap.encode());
      expect(back.formatVersion, 1);
      expect(back.locale, 'de_DE');
      expect(back.version, 'a:b:c');
      expect(back.source.rangesA1, ['Q3!A1:D13']);
      expect(back.source.chartTitle, 'Revenue by region');
      expect(back.sourceTheme!.accentArgbs, [0xFF112233, 0xFF445566]);
      expect(back.sourceTheme!.resolveArgb('theme:text'), 0xFF000000);
      expect(back.sourceTheme!.resolveArgb('theme:accent2'), 0xFF445566);
      expect(back.sourceTheme!.colors.containsKey('bad'), isFalse);
      expect(back.data.series.length, 2);
      expect(back.isPlaceholder, isFalse);
    });

    test('when reading a placeholder then it says so', () {
      final p = ChartDataSnapshot.fromJson('{"v":1}');
      expect(p.isPlaceholder, isTrue);
      expect(p.formatVersion, 1);
      expect(ChartDataSnapshot.fromJson('{"v":9}').isFromNewerVersion, isTrue);
    });
  });

  group('Given snapshot columns', () {
    test('when the JSON is small then it is stored as is', () {
      expect(ChartSnapshotColumns.encode('{"v":1}'), '{"v":1}');
      expect(ChartSnapshotColumns.decode('{"v":1}'), '{"v":1}');
    });

    test(
      'when the JSON exceeds 32 KB then it is gz-compressed and decodes',
      () {
        final big = jsonEncode({'v': 1, 'x': List.filled(5000, 'abcdefgh')});
        final stored = ChartSnapshotColumns.encode(big);
        expect(stored, startsWith('gz:'));
        expect(stored.length, lessThan(big.length));
        expect(ChartSnapshotColumns.isCompressed(stored), isTrue);
        expect(ChartSnapshotColumns.decode(stored), big);
        expect(
          ChartSnapshotColumns.compressedSize(big),
          lessThan(ChartSnapshotColumns.maxCompressedBytes),
        );
      },
    );

    test('when a gz value is corrupt then it decodes as an empty object', () {
      expect(ChartSnapshotColumns.decode('gz:!!!'), '{}');
    });

    test('when reading a source snapshot from gz columns then it renders', () {
      const spec = ChartSpec(type: ChartType.line);
      final pair = ChartSourceSnapshot(
        spec: spec,
        dataSnapshot: ChartDataSnapshot(data: sampleData(), version: 'v'),
      );
      final (specCol, dataCol) = pair.toColumns();
      final back = ChartSourceSnapshot.fromColumns(
        ChartSnapshotColumns.encode(specCol, threshold: 0),
        ChartSnapshotColumns.encode(dataCol, threshold: 0),
      );
      expect(back.spec.type, ChartType.line);
      expect(back.data.series.first.key, 'north');
      final static = ChartSourceSnapshot.fromJson(pair.toJson())!;
      expect(static.dataSnapshot.version, 'v');
      expect(ChartSourceSnapshot.fromJson({'x': 1}), isNull);
    });
  });

  group('Given a source version token', () {
    test('when parsing then the three parts are read', () {
      final v = ChartSourceVersion.tryParse('log.3:abcd:42')!;
      expect(v.changeLog, 'log.3');
      expect(v.specHash, 'abcd');
      expect(v.dataVersion, '42');
      expect(v.toString(), 'log.3:abcd:42');
      expect(
        v.sameChartAs(ChartSourceVersion.tryParse('other:abcd:42')!),
        isTrue,
      );
      expect(ChartSourceVersion.tryParse('a:b'), isNull);
      expect(ChartSourceVersion.tryParse(''), isNull);
    });
  });

  group('Given data beyond the snapshot limits', () {
    ChartData lineData(int n) => ChartData(
      domain: ChartDomain(
        kind: DomainKind.numeric,
        values: Float64List.fromList([for (var i = 0; i < n; i++) i * 1.0]),
        labels: [for (var i = 0; i < n; i++) '$i'],
      ),
      series: [
        for (final k in ['a', 'b'])
          ChartSeries(
            key: k,
            name: k,
            values: Float64List.fromList([
              for (var i = 0; i < n; i++) (i * 7919 % 101).toDouble(),
            ]),
          ),
      ],
    );

    test('when a line chart has 5,000 points then ≤ 2,000 remain', () {
      final out = const ChartSnapshotLimits().apply(
        const ChartSpec(type: ChartType.line),
        lineData(5000),
      );
      expect(out.domain.length, lessThanOrEqualTo(2000));
      expect(out.domain.labels.first, '0');
      expect(out.domain.labels.last, '4999');
      expect(out.series.first.values.length, out.domain.length);
      expect(out.warnings.single.code, ChartWarningCode.downsampled);
    });

    test('when a column chart has 800 categories then ≤ 500 remain', () {
      final out = const ChartSnapshotLimits().apply(
        const ChartSpec(type: ChartType.column),
        lineData(800),
      );
      expect(out.domain.length, lessThanOrEqualTo(500));
    });

    test('when within the limits then the data is unchanged', () {
      final data = lineData(100);
      expect(
        const ChartSnapshotLimits().apply(
          const ChartSpec(type: ChartType.line),
          data,
        ),
        same(data),
      );
    });

    test('when a pie has 80 slices then small ones are grouped', () {
      final data = ChartData(
        domain: ChartDomain(
          kind: DomainKind.categorical,
          values: Float64List(80),
          labels: [for (var i = 0; i < 80; i++) 'S$i'],
        ),
        series: [
          ChartSeries(
            key: 'v',
            name: 'v',
            values: Float64List.fromList([
              for (var i = 0; i < 80; i++) i + 1.0,
            ]),
          ),
        ],
      );
      final out = const ChartSnapshotLimits().apply(
        const ChartSpec(type: ChartType.pie),
        data,
      );
      expect(out.domain.length, 50);
      expect(out.domain.labels.last, 'Other');
      expect(out.warnings.single.code, ChartWarningCode.pieOtherGrouped);
    });

    test('when a table has 300 rows then the first 200 are kept', () {
      final data = ChartData(
        domain: ChartDomain.synthetic(0),
        series: const [],
        table: ChartTableData(
          headers: const ['A'],
          texts: [
            [for (var i = 0; i < 300; i++) '$i'],
          ],
          values: [Float64List(300)],
        ),
      );
      final out = const ChartSnapshotLimits().apply(
        const ChartSpec(type: ChartType.table),
        data,
      );
      expect(out.table!.rowCount, 200);
      expect(out.table!.values.single.length, 200);
    });
  });
}
