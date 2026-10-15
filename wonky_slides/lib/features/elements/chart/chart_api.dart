import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_client/wonky_client.dart' as api;
import 'package:wonky_slides_core/charts.dart';

/// Why a chart call failed (Slides 08 §4.3).
enum ChartApiError {
  offline,
  noAccess,
  spreadsheetTrashed,
  exportDisabled,
  chartNotFound,
  chartTooLarge,
  unsupportedSpec,
  quotaExceeded,
  rateLimited,
  failed,
}

/// A failed `slidesCharts` call.
class ChartApiException implements Exception {
  const ChartApiException(this.error, [this.message = '']);

  final ChartApiError error;
  final String message;

  @override
  String toString() => 'ChartApiException(${error.name}) $message';
}

/// One chart of a spreadsheet in the insert dialog (08 §4.2).
@immutable
class ChartSourceTile {
  const ChartSourceTile({
    required this.chartObjectId,
    required this.title,
    required this.type,
    required this.is3D,
    required this.sheetName,
    this.onChartSheet = false,
    this.unsupported = false,
    this.preview,
  });

  final String chartObjectId;
  final String title;

  /// Chart type id (`column`, `pie`, …).
  final String type;
  final bool is3D;
  final String sheetName;
  final bool onChartSheet;

  /// Made with a newer version of Wonky Sheets (disabled).
  final bool unsupported;

  /// The ≤ 200-point preview (null: no right to copy data).
  final ChartSourceSnapshot? preview;
}

/// The charts of a spreadsheet (`slidesCharts.listCharts`).
@immutable
class ChartSourceListing {
  const ChartSourceListing({
    required this.spreadsheetTitle,
    required this.charts,
    required this.exportAllowed,
  });

  final String spreadsheetTitle;
  final List<ChartSourceTile> charts;

  /// Whether the caller may copy charts (editor+, or `nonEditorsCanExport`).
  final bool exportAllowed;
}

/// The chart endpoints of the Slides client (08 §13): the
/// [ChartLinkService] contract (resolve, check) plus the insert dialog's
/// chart list. [of] returns the server implementation unless a test
/// installed a fake ([install]).
abstract class SlidesChartApi implements ChartLinkService {
  const SlidesChartApi();

  static final Expando<SlidesChartApi> _installed = Expando('slidesChartApi');

  /// The chart API of [services].
  static SlidesChartApi of(ShellServices services) =>
      _installed[services] ?? _ClientChartApi(services);

  /// Replaces the API of [services] (tests; null restores the server).
  @visibleForTesting
  static void install(ShellServices services, SlidesChartApi? api) =>
      _installed[services] = api;

  /// Whether calls can reach the server now.
  bool get online;

  /// The charts of spreadsheet [spreadsheetUuid] with previews.
  Future<ChartSourceListing> listCharts(String spreadsheetUuid);
}

class _ClientChartApi extends SlidesChartApi {
  _ClientChartApi(this.s);

  final ShellServices s;

  @override
  bool get online => s.client != null && s.connectivity.online;

  api.Client get _client {
    final c = s.client;
    if (c == null || !s.connectivity.online) {
      throw const ChartApiException(ChartApiError.offline);
    }
    return c;
  }

  static api.UuidValue _uuid(String v) => api.UuidValue.withValidation(v);

  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on ChartApiException {
      rethrow;
    } on api.WonkyException catch (e) {
      throw ChartApiException(_errorOf(e), e.message);
    } catch (e) {
      if (QuotaErrorPresenter.isQuotaExceeded(e)) {
        throw const ChartApiException(ChartApiError.quotaExceeded);
      }
      if (!s.connectivity.online || e is api.ServerpodClientException) {
        throw ChartApiException(ChartApiError.offline, '$e');
      }
      throw ChartApiException(ChartApiError.failed, '$e');
    }
  }

  static ChartApiError _errorOf(api.WonkyException e) {
    String? reason;
    try {
      final d = e.detailsJson == null ? null : jsonDecode(e.detailsJson!);
      if (d is Map && d['reason'] is String) reason = d['reason'] as String;
    } on FormatException {
      reason = null;
    }
    switch (reason) {
      case 'no_access':
        return ChartApiError.noAccess;
      case 'spreadsheet_trashed':
        return ChartApiError.spreadsheetTrashed;
      case 'chart_not_found':
        return ChartApiError.chartNotFound;
      case 'export_disabled':
        return ChartApiError.exportDisabled;
      case 'unsupported_spec':
        return ChartApiError.unsupportedSpec;
      case 'chart_too_large':
        return ChartApiError.chartTooLarge;
    }
    return switch (e.code) {
      api.WonkyErrorCode.notFound => ChartApiError.noAccess,
      api.WonkyErrorCode.forbidden => ChartApiError.exportDisabled,
      api.WonkyErrorCode.limitExceeded => ChartApiError.rateLimited,
      api.WonkyErrorCode.quotaExceeded => ChartApiError.quotaExceeded,
      _ => ChartApiError.failed,
    };
  }

  @override
  Future<ChartSourceListing> listCharts(String spreadsheetUuid) =>
      _call(() async {
        final r = await _client.slidesCharts.listCharts(_uuid(spreadsheetUuid));
        return ChartSourceListing(
          spreadsheetTitle: r.spreadsheetTitle,
          exportAllowed: r.exportAllowed,
          charts: [
            for (final c in r.charts)
              ChartSourceTile(
                chartObjectId: c.chartObjectId,
                title: c.title,
                type: c.type,
                is3D: c.is3D,
                sheetName: c.sheetName,
                onChartSheet: c.onChartSheet,
                unsupported: c.unsupported,
                preview: _preview(c.previewSnapshotJson),
              ),
          ],
        );
      });

  static ChartSourceSnapshot? _preview(String? json) {
    if (json == null) return null;
    try {
      return ChartSourceSnapshot.fromJson(jsonDecode(json));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<ResolvedChartSnapshot> resolve(
    String spreadsheetUuid,
    String chartObjectId,
  ) => _call(() async {
    final r = await _client.slidesCharts.resolveSnapshot(
      _uuid(spreadsheetUuid),
      chartObjectId,
    );
    return ResolvedChartSnapshot(
      spreadsheetUuid: r.spreadsheetUuid.uuid,
      chartObjectId: r.chartObjectId,
      sourceSpecJson: r.sourceSpecJson,
      dataSnapshotJson: r.dataSnapshotJson,
      sourceVersion: r.sourceVersion,
      sheetId: r.sheetId,
      warnings: r.warnings,
    );
  });

  @override
  Future<List<ChartLinkStatusData>> check(
    List<ChartLinkProbeData> probes,
  ) async {
    final out = <ChartLinkStatusData>[];
    // ≤ 50 probes per call (08 §5.2).
    for (var i = 0; i < probes.length; i += 50) {
      final part = probes.sublist(i, (i + 50).clamp(0, probes.length));
      final r = await _call(
        () => _client.slidesCharts.checkLinks([
          for (final p in part)
            api.ChartLinkProbe(
              elementId: p.elementId,
              spreadsheetUuid: _uuid(p.spreadsheetUuid),
              chartObjectId: p.chartObjectId,
              sourceVersion: p.sourceVersion,
            ),
        ]),
      );
      for (final x in r) {
        out.add(
          ChartLinkStatusData(
            elementId: x.elementId,
            status: ChartLinkStatusCode.values.byName(x.status.name),
            newVersion: x.newVersion,
            summary: x.summary,
          ),
        );
      }
    }
    return out;
  }
}
