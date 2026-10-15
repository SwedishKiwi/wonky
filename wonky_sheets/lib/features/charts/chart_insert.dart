import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../sheet_editor/sheet_editor_controller.dart';

/// Panel id of the chart editor (04 §10).
const chartEditorPanelId = 'sheets.panel.chartEditor';

/// Chart creation helpers (08 §5): data ranges from A1 text or the
/// selection, recommendations, and A1 ↔ `GridRange` conversion.
abstract final class ChartInsert {
  /// `GridRange`s of A1 texts (comma-separated parts allowed). Throws
  /// `InvalidRangeException`.
  static List<GridRange> rangesFromA1(
    SheetEditorController ed,
    Iterable<String> texts,
  ) => [
    for (final t in texts)
      for (final part in t.split(','))
        if (part.trim().isNotEmpty) _grid(ed, part.trim()),
  ];

  static GridRange _grid(SheetEditorController ed, String a1) {
    final rr = ed.model.parseA1(a1, contextSheetId: ed.activeSheetId);
    final sheet = ed.model.sheet(rr.sheetId)!;
    return sheet.gridRange(
      rr.rect,
      wholeRows: rr.wholeRows,
      wholeColumns: rr.wholeColumns,
    );
  }

  /// The chart data ranges of the selection: the selected ranges, or the
  /// contiguous region around the active cell when a single cell is
  /// selected (08 §5.2).
  static List<GridRange> rangesFromSelection(SheetEditorController ed) {
    final sheet = ed.activeSheet!;
    final sel = ed.selection.resolved;
    final ranges = sel.toResolvedRanges();
    if (ranges.length == 1 && ranges.single.rect.isSingleCell) {
      final region = ChartRecommender.contiguousRegion(
        sheet.id,
        sel.activeRow,
        sel.activeCol,
        ed.engine,
        rowCount: sheet.rows.length,
        columnCount: sheet.columns.length,
      );
      return [sheet.gridRange(region)];
    }
    return [
      for (final r in ranges)
        ed.model
            .sheet(r.sheetId)!
            .gridRange(
              _clip(ed, r),
              wholeRows: r.wholeRows,
              wholeColumns: r.wholeColumns,
            ),
    ];
  }

  /// Whole rows/columns are clipped to the used range (08 §4.1).
  static GridRect _clip(SheetEditorController ed, ResolvedRange r) {
    if (!r.wholeRows && !r.wholeColumns) return r.rect;
    final used = ed.model.sheet(r.sheetId)?.usedRect();
    if (used == null) return r.rect;
    return r.rect.intersection(used) ?? r.rect;
  }

  /// A1 texts of [ranges] (sheet-qualified when not on the active sheet).
  static List<String> a1Of(SheetEditorController ed, List<GridRange> ranges) =>
      [
        for (final g in ranges)
          if (ed.model.sheet(g.sheetId)?.resolve(g) case final rr?)
            ed.model.a1Of(rr, includeSheet: g.sheetId != ed.activeSheetId),
      ];

  /// The recommended charts for [ranges] (08 §5).
  static List<ChartSuggestion> suggestions(
    SheetEditorController ed,
    List<GridRange> ranges,
  ) {
    if (ranges.isEmpty) return const [];
    final profile = SelectionProfile.fromRanges(ranges, ed.model, ed.engine);
    return ChartRecommender.recommend(profile);
  }

  /// A spec for [ranges]: the recommended default (or the suggestion of
  /// [type], else the default switched to [type]).
  static ChartSpec specFor(
    SheetEditorController ed,
    List<GridRange> ranges, {
    ChartType? type,
  }) {
    final list = suggestions(ed, ranges);
    if (list.isEmpty) {
      return ChartSpec(
        type: type ?? ChartType.column,
        data: ChartDataSpec(ranges: ranges.toRefs()),
      );
    }
    if (type != null) {
      for (final s in list) {
        if (s.type == type) return s.spec;
      }
      return list.first.spec.withType(type);
    }
    return list.first.spec;
  }

  /// The data region (bounds of the first range) used for placing a new
  /// chart.
  static GridRect? regionOf(SheetEditorController ed, List<GridRange> ranges) {
    for (final g in ranges) {
      if (g.sheetId != ed.activeSheetId) continue;
      final rr = ed.model.sheet(g.sheetId)?.resolve(g);
      if (rr != null) return rr.rect;
    }
    return null;
  }

  /// Converts A1 strings in a spec/patch's `data.ranges` (MCP form, 08 §17)
  /// into stored `GridRange` JSON; other entries pass through.
  static Map<String, Object?> rangesToStored(
    SheetEditorController ed,
    Map<String, Object?> json,
  ) {
    final data = json['data'];
    if (data is! Map) return json;
    final ranges = data['ranges'];
    if (ranges is! List || !ranges.any((r) => r is String)) return json;
    return {
      ...json,
      'data': {
        ...data.cast<String, Object?>(),
        'ranges': [
          for (final r in ranges) r is String ? _grid(ed, r).toJson() : r,
        ],
      },
    };
  }
}
