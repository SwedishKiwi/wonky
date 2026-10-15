import 'dart:convert';
import 'dart:typed_data';

import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_slides/features/elements/chart/chart_api.dart';
import 'package:wonky_slides_core/charts.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/schema.dart' show ElementCols;
import 'package:wonky_slides_core/testing.dart';

const sheetUuid = '00000000-0000-4000-8000-000000000c01';
const chartId = '00000000-0000-4000-8000-000000000c02';
const chart3dId = '00000000-0000-4000-8000-000000000c03';

/// Revenue by region: three months × two regions (+ an extra series in v2).
ChartData revenueData({bool extra = false, double north = 10}) => ChartData(
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
      values: Float64List.fromList([north, 13, 16]),
    ),
    ChartSeries(
      key: 'south',
      name: 'South',
      values: Float64List.fromList([30, 28.5, 26]),
    ),
    if (extra)
      ChartSeries(
        key: 'west',
        name: 'West',
        values: Float64List.fromList([5, 6, 7]),
      ),
  ],
  dataVersion: extra ? 43 : 42,
);

Map<String, Object?> sheetSpec({String type = 'column', bool threeD = false}) =>
    {
      'v': 1,
      'type': type,
      'data': {
        'ranges': [
          {'s': 'sheet1', 'r1': 'r1', 'r2': 'r4', 'c1': 'c1', 'c2': 'c3'},
        ],
      },
      'title': {'text': 'Revenue by region'},
      if (threeD) 'threeD': {'enabled': true},
    };

/// The snapshot of the revenue chart as the server resolves it.
ResolvedChartSnapshot resolved({
  String chartObjectId = chartId,
  String version = 'log1.1:aaaa:42',
  bool threeD = false,
  bool extra = false,
  double north = 10,
}) {
  final data = ChartDataSnapshot(
    data: revenueData(extra: extra, north: north),
    sourceTheme: const ChartSourceTheme(
      accentArgbs: [0xFF4285F4, 0xFFEA4335, 0xFFFBBC04],
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
  );
  return ResolvedChartSnapshot(
    spreadsheetUuid: sheetUuid,
    chartObjectId: chartObjectId,
    sourceSpecJson: jsonEncode(sheetSpec(threeD: threeD)),
    dataSnapshotJson: data.encode(),
    sourceVersion: version,
    sheetId: 'sheet1',
  );
}

/// A fake `slidesCharts` (08 §13).
class FakeChartApi extends SlidesChartApi {
  FakeChartApi();

  @override
  bool online = true;

  /// What `resolve` returns per chart id (or throws).
  final Map<String, ResolvedChartSnapshot> snapshots = {
    chartId: resolved(),
    chart3dId: resolved(chartObjectId: chart3dId, threeD: true),
  };
  final Map<String, ChartApiError> errors = {};

  /// Statuses `check` returns per element id (default: up to date).
  final Map<String, ChartLinkStatusData> statuses = {};
  int resolves = 0;
  int checks = 0;

  @override
  Future<ChartSourceListing> listCharts(String spreadsheetUuid) async {
    if (!online) throw const ChartApiException(ChartApiError.offline);
    return ChartSourceListing(
      spreadsheetTitle: 'Finance 2026',
      exportAllowed: true,
      charts: [
        ChartSourceTile(
          chartObjectId: chartId,
          title: 'Revenue by region',
          type: 'column',
          is3D: false,
          sheetName: 'Q3',
          preview: ChartSourceSnapshot.fromColumns(
            snapshots[chartId]!.sourceSpecJson,
            snapshots[chartId]!.dataSnapshotJson,
          ),
        ),
        const ChartSourceTile(
          chartObjectId: chart3dId,
          title: 'Units 3D',
          type: 'column',
          is3D: true,
          sheetName: 'Q3',
        ),
        const ChartSourceTile(
          chartObjectId: 'newer',
          title: 'Future chart',
          type: 'column',
          is3D: false,
          sheetName: 'Pipeline',
          unsupported: true,
        ),
      ],
    );
  }

  @override
  Future<ResolvedChartSnapshot> resolve(
    String spreadsheetUuid,
    String chartObjectId,
  ) async {
    resolves++;
    if (!online) throw const ChartApiException(ChartApiError.offline);
    final e = errors[chartObjectId];
    if (e != null) throw ChartApiException(e);
    final s = snapshots[chartObjectId];
    if (s == null) throw const ChartApiException(ChartApiError.chartNotFound);
    return s;
  }

  @override
  Future<List<ChartLinkStatusData>> check(
    List<ChartLinkProbeData> probes,
  ) async {
    checks++;
    if (!online) throw const ChartApiException(ChartApiError.offline);
    return [
      for (final p in probes)
        statuses[p.elementId] ??
            ChartLinkStatusData(
              elementId: p.elementId,
              status: ChartLinkStatusCode.upToDate,
            ),
    ];
  }
}

/// A deck with a linked chart on slide 1 ([chartElementId]) and a static
/// one ([staticElementId]); [threeD] makes the linked chart 3D.
({DeckBuilder b, String slide, String linked, String static}) chartDeck({
  bool threeD = false,
  Map<String, Object?> dataJson = const {
    'v': 1,
    'source': 'linked',
    'style': {'useDeckTheme': true},
  },
  String version = 'log1.1:aaaa:42',
  bool autoUpdate = false,
}) {
  final b = DeckBuilder();
  final slide = b.slide(layoutKey: 'title', title: 'Charts');
  final linked = b.element(
    slide,
    ElementKind.chart,
    x: 200,
    y: 200,
    width: 1200,
    height: 742,
    columns: {ElementCols.dataJson: jsonEncode(dataJson)},
  );
  final r = resolved(threeD: threeD, version: version);
  b.chartLink(
    linked,
    sourceSpecJson: r.sourceSpecJson,
    dataSnapshotJson: r.dataSnapshotJson,
    sourceVersion: version,
    autoUpdate: autoUpdate,
  );
  final r2 = resolved();
  final snap = ChartSourceSnapshot.fromColumns(
    r2.sourceSpecJson,
    r2.dataSnapshotJson,
  );
  final stat = b.element(
    slide,
    ElementKind.chart,
    x: 100,
    y: 100,
    width: 600,
    height: 371,
    columns: {
      ElementCols.dataJson: ChartElementData(
        source: SlideChartSource.static,
        snapshot: snap,
      ).encode(),
    },
  );
  return (b: b, slide: slide, linked: linked, static: stat);
}
