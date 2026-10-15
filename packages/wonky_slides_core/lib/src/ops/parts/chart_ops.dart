part of '../operations.dart';

// Charts (02 §3.9, 08; planner SL-27).

/// A linked chart's snapshot (08 §3.4): written together (P4).
final class ChartSnapshot {
  const ChartSnapshot({
    required this.sourceSpecJson,
    required this.dataSnapshotJson,
    required this.sourceVersion,
    this.sheetId,
  });

  final String sourceSpecJson;
  final String dataSnapshotJson;
  final String sourceVersion;
  final String? sheetId;
}

/// Links chart element [elementId] to a Sheets chart (creates the
/// `ChartLink` row with `SlidesIds.chartLinkId`).
final class LinkChart extends SlidesOperation {
  const LinkChart(
    this.elementId, {
    required this.spreadsheetItemUuid,
    required this.chartObjectId,
    required this.snapshot,
    this.autoUpdate = false,
  });

  final String elementId;
  final String spreadsheetItemUuid;
  final String chartObjectId;
  final ChartSnapshot snapshot;
  final bool autoUpdate;

  @override
  String get name => 'LinkChart';
}

/// Stores a new snapshot of a linked chart (*Update*).
final class UpdateChartLink extends SlidesOperation {
  const UpdateChartLink(this.elementId, this.snapshot);

  final String elementId;
  final ChartSnapshot snapshot;

  @override
  String get name => 'UpdateChartLink';
}

/// *Update automatically* on/off.
final class SetChartAutoUpdate extends SlidesOperation {
  const SetChartAutoUpdate(this.elementId, this.autoUpdate);

  final String elementId;
  final bool autoUpdate;

  @override
  String get name => 'SetChartAutoUpdate';
}

/// Unlinks a chart (keeps a static snapshot in `dataJson`).
final class UnlinkChart extends SlidesOperation {
  const UnlinkChart(this.elementId);

  final String elementId;

  @override
  String get name => 'UnlinkChart';
}

/// Deck-side chart style overrides (`dataJson.style`/`camera`) as a merge
/// patch.
final class SetChartStyle extends SlidesOperation {
  const SetChartStyle(this.elementId, this.patch);

  final String elementId;
  final Map<String, Object?> patch;

  @override
  String get name => 'SetChartStyle';
}
