import 'dart:convert';
import 'dart:typed_data';

import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/schema.dart';

import 'scene_fixture.dart';

/// Revenue by region: three months × two regions, as resolved by the server.
ChartData revenueData() => ChartData(
  domain: ChartDomain(
    kind: DomainKind.categorical,
    values: Float64List.fromList([double.nan, double.nan, double.nan]),
    labels: const ['Jan', 'Feb', 'Mar'],
    name: 'Month',
  ),
  series: [
    ChartSeries(
      key: 'north',
      name: 'North',
      values: Float64List.fromList([10, 13, 16]),
    ),
    ChartSeries(
      key: 'south',
      name: 'South',
      values: Float64List.fromList([30, 28.5, 26]),
    ),
  ],
  dataVersion: 42,
);

/// A source spec as Sheets stores it (explicit sheet colors and fonts).
Map<String, Object?> sheetSpec({String type = 'column', bool threeD = false}) =>
    {
      'v': 1,
      'type': type,
      'data': {
        'ranges': [
          {'s': 'sheet1', 'r1': 'r1', 'r2': 'r4', 'c1': 'c1', 'c2': 'c3'},
        ],
      },
      'title': {
        'text': 'Revenue by region',
        'font': {'family': 'Comic Neue', 'bold': true},
      },
      'style': {'fontFamily': 'Comic Neue', 'background': '#FFF8E1'},
      'series': {
        'north': {'color': '#FF0000'},
      },
      if (threeD) 'threeD': {'enabled': true},
    };

/// The snapshot pair of [sheetSpec] + [revenueData].
ChartSourceSnapshot revenueSnapshot({
  String type = 'column',
  bool threeD = false,
  String version = 'log:abc:42',
}) => ChartSourceSnapshot(
  spec: ChartSpec.fromJson(sheetSpec(type: type, threeD: threeD)),
  dataSnapshot: ChartDataSnapshot(
    data: revenueData(),
    sourceTheme: const ChartSourceTheme(
      accentArgbs: [
        0xFF4285F4,
        0xFFEA4335,
        0xFFFBBC04,
        0xFF34A853,
        0xFFFF6D01,
        0xFF46BDC6,
      ],
      textFont: 'Roboto',
    ),
    locale: 'en_US',
    source: const ChartSourceInfo(
      spreadsheetTitle: 'Finance 2026',
      sheetName: 'Q3',
      chartTitle: 'Revenue by region',
      rangesA1: ['Q3!A1:C4'],
    ),
    version: version,
  ),
);

/// A slide with a linked chart (and optionally a static one).
final class ChartFixture {
  ChartFixture({
    String type = 'column',
    bool threeD = false,
    Map<String, Object?> dataJson = const {
      'v': 1,
      'source': 'linked',
      'style': {'useDeckTheme': true},
    },
    bool compress = false,
    String? theme,
  }) : scene = SceneFixture(theme: theme) {
    chart = scene.element(
      ElementKind.chart,
      w: 1200,
      h: 742,
      columns: {ElementCols.dataJson: jsonEncode(dataJson)},
    );
    final (spec, data) = revenueSnapshot(
      type: type,
      threeD: threeD,
    ).toColumns();
    scene.b.chartLink(
      chart,
      sourceSpecJson: compress
          ? ChartSnapshotColumns.encode(spec, threshold: 0)
          : spec,
      dataSnapshotJson: compress
          ? ChartSnapshotColumns.encode(data, threshold: 0)
          : data,
      sourceVersion: 'log:abc:42',
    );
  }

  final SceneFixture scene;
  late final String chart;

  /// A static chart element with [snapshot] in its `dataJson`.
  String staticChart({ChartSourceSnapshot? snapshot}) => scene.element(
    ElementKind.chart,
    x: 1300,
    w: 500,
    h: 300,
    columns: {
      ElementCols.dataJson: jsonEncode({
        'v': 1,
        'source': 'static',
        'snapshot': (snapshot ?? revenueSnapshot()).toJson(),
      }),
    },
  );
}
