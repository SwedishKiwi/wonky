import 'dart:convert';

import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_slides_core/charts.dart';
import 'package:wonky_slides_core/schema.dart' show ChartLinkCols, ElementCols;

import '../../editor_screen/deck_editor_controller.dart';
import 'chart_api.dart';

/// Sheets chart pastes with data (Slides 08 §4.4, SL-18 + SL-32): the
/// pasted chart's snapshot is resolved from the server before the paste is
/// applied, so a linked paste writes its `ChartLink` with data and *Paste
/// chart unlinked* a static chart with its frozen snapshot (not only the
/// spec). Offline or on errors the payload is left as mapped: a linked
/// chart gets its first snapshot from the next link check.
abstract final class ChartPaste {
  /// [payload] (one mapped Sheets chart of clipboard [item]) with its
  /// snapshot; [resolved] is false when it could not be fetched.
  static Future<({Map<String, Object?> payload, bool resolved})> withSnapshot(
    DeckEditorController ed,
    Map<String, Object?> item,
    Map<String, Object?> payload, {
    required bool unlinked,
  }) async {
    final els = payload['elements'];
    if (els is! List || els.isEmpty || els.first is! Map) {
      return (payload: payload, resolved: false);
    }
    final links = payload['chartLinks'];
    final link = links is List && links.isNotEmpty && links.first is Map
        ? (links.first as Map).cast<String, Object?>()
        : null;
    final uuid =
        link?[ChartLinkCols.spreadsheetItemUuid] as String? ??
        item['spreadsheetItemUuid'] as String?;
    final objectId =
        link?[ChartLinkCols.chartObjectId] as String? ??
        item['objectId'] as String?;
    final api = SlidesChartApi.of(ed.services);
    if (uuid == null || objectId == null || !api.online) {
      return (payload: payload, resolved: false);
    }
    final ResolvedChartSnapshot r;
    try {
      r = await api.resolve(uuid.toLowerCase(), objectId.toLowerCase());
    } on ChartApiException {
      return (payload: payload, resolved: false);
    }
    final el = Map<String, Object?>.from(els.first as Map);
    final snap = ChartSourceSnapshot.fromColumns(
      r.sourceSpecJson,
      r.dataSnapshotJson,
    );
    final alt = el[ElementCols.altText];
    if (alt is! String || alt.isEmpty) {
      el[ElementCols.altText] = ChartDescriber.describe(snap.spec, snap.data);
    }
    final out = Map<String, Object?>.from(payload);
    if (link != null && !unlinked) {
      final cols = ChartLinkOps.snapshotOf(r);
      out['chartLinks'] = [
        {
          ...link,
          ChartLinkCols.sourceSpecJson: cols.sourceSpecJson,
          ChartLinkCols.dataSnapshotJson: cols.dataSnapshotJson,
          ChartLinkCols.sourceVersion: cols.sourceVersion,
          ChartLinkCols.sheetId: cols.sheetId ?? link[ChartLinkCols.sheetId],
        },
        ...(links as List).skip(1),
      ];
    } else {
      final data = ChartElementData.fromJson(el[ElementCols.dataJson]);
      el[ElementCols.dataJson] = jsonEncode(
        ChartElementData(
          source: SlideChartSource.static,
          style: data.style,
          camera: data.camera,
          overrides: data.overrides,
          snapshot: snap,
          background: data.background,
          interactive: data.interactive,
          extras: data.extras,
        ).toJson(),
      );
    }
    out['elements'] = [el, ...els.skip(1)];
    return (payload: out, resolved: true);
  }
}
