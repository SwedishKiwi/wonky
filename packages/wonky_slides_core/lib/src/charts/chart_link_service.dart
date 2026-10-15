import 'package:wonky_charts/wonky_charts.dart';

import '../model/api/deck_reader.dart';
import '../model/api/kinds.dart';
import '../model/api/records.dart';
import '../ops/operations.dart';
import '../schema/slides_schema.dart';
import 'chart_element_data.dart';

/// The status of a linked chart's source (Slides 08 §5.2, §13 `checkLinks`); mirrors the
/// server's `ChartLinkState`.
enum ChartLinkStatusCode {
  upToDate,
  changed,
  noAccess,
  exportDisabled,
  chartDeleted,
  spreadsheetTrashed,
  spreadsheetDeleted,
  unsupportedSpec,
}

/// One link to check (08 §5.2).
final class ChartLinkProbeData {
  /// Creates a probe.
  const ChartLinkProbeData({
    required this.elementId,
    required this.spreadsheetUuid,
    required this.chartObjectId,
    required this.sourceVersion,
  });

  final String elementId;
  final String spreadsheetUuid;
  final String chartObjectId;
  final String sourceVersion;
}

/// The result of a check (08 §5.2).
final class ChartLinkStatusData {
  /// Creates a status.
  const ChartLinkStatusData({
    required this.elementId,
    required this.status,
    this.newVersion,
    this.summary,
  });

  final String elementId;
  final ChartLinkStatusCode status;

  /// The current token (upToDate with a newer change log, or changed).
  final String? newVersion;

  /// "Data changed", "Chart style changed", "Data and style changed".
  final String? summary;
}

/// A snapshot resolved by the server (08 §13 `resolveSnapshot`).
final class ResolvedChartSnapshot {
  /// Creates a snapshot.
  const ResolvedChartSnapshot({
    required this.spreadsheetUuid,
    required this.chartObjectId,
    required this.sourceSpecJson,
    required this.dataSnapshotJson,
    required this.sourceVersion,
    this.sheetId,
    this.warnings = const [],
  });

  final String spreadsheetUuid;
  final String chartObjectId;

  /// Plain JSON (not `gz:`); [ChartLinkOps.snapshotOf] compresses for storage.
  final String sourceSpecJson;
  final String dataSnapshotJson;
  final String sourceVersion;
  final String? sheetId;
  final List<String> warnings;
}

/// The chart link service of the Slides client (12 §5.6 `ChartLinkService`): resolves
/// snapshots and checks links through the server (`slidesCharts`). Implemented by the app
/// over the generated client (SL-32) and by fakes in tests; MCP (SL-40) calls the server
/// service directly.
abstract interface class ChartLinkService {
  /// `link(spreadsheetItemUuid, chartObjectId) → snapshot`.
  Future<ResolvedChartSnapshot> resolve(
    String spreadsheetUuid,
    String chartObjectId,
  );

  /// `status(links)`: one result per probe, in order.
  Future<List<ChartLinkStatusData>> check(List<ChartLinkProbeData> probes);
}

/// Operations and probes for linked charts (08 §5, §7, §14).
abstract final class ChartLinkOps {
  /// The column values of [r] for `LinkChart`/`UpdateChartLink` (`gz:` beyond 32 KB).
  static ChartSnapshot snapshotOf(ResolvedChartSnapshot r) => ChartSnapshot(
    sourceSpecJson: ChartSnapshotColumns.encode(r.sourceSpecJson),
    dataSnapshotJson: ChartSnapshotColumns.encode(r.dataSnapshotJson),
    sourceVersion: r.sourceVersion,
    sheetId: r.sheetId,
  );

  /// `slides.chart.update` of [elementId] to [r].
  static UpdateChartLink update(String elementId, ResolvedChartSnapshot r) =>
      UpdateChartLink(elementId, snapshotOf(r));

  /// Links [elementId] to [r] (insert, relink).
  static LinkChart link(
    String elementId,
    ResolvedChartSnapshot r, {
    bool autoUpdate = false,
  }) => LinkChart(
    elementId,
    spreadsheetItemUuid: r.spreadsheetUuid,
    chartObjectId: r.chartObjectId,
    snapshot: snapshotOf(r),
    autoUpdate: autoUpdate,
  );

  /// The maintenance write that stores a newer token for an unchanged chart (08 §5.2: no
  /// undo step; the caller writes it outside the undo history).
  static UpdateChartLink refreshToken(ChartLinkRec link, String newVersion) =>
      UpdateChartLink(
        link.elementId ?? '',
        ChartSnapshot(
          sourceSpecJson: link.sourceSpecJson,
          dataSnapshotJson: link.dataSnapshotJson,
          sourceVersion: newVersion,
          sheetId: link.sheetId,
        ),
      );

  /// A probe for every linked chart of [deck] (08 §5.3: checked when a deck opens).
  static List<ChartLinkProbeData> probesOf(DeckReader deck) {
    final out = <ChartLinkProbeData>[];
    for (final r in deck.records(SlidesTables.chartLink)) {
      if (r is! ChartLinkRec) continue;
      final id = r.elementId;
      final e = id == null ? null : deck.element(id);
      if (e == null || e.kind != ElementKind.chart) continue;
      if (ChartElementData.fromJson(e.dataJson).source !=
          SlideChartSource.linked) {
        continue;
      }
      out.add(
        ChartLinkProbeData(
          elementId: e.id,
          spreadsheetUuid: r.spreadsheetItemUuid,
          chartObjectId: r.chartObjectId,
          sourceVersion: r.sourceVersion,
        ),
      );
    }
    return out;
  }
}
