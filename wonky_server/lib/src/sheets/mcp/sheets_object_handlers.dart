import 'dart:convert';
import 'dart:math' as math;

import 'package:serverpod/serverpod.dart' show Uuid;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/wonky_sheets_core.dart'
    hide ActorKind, CellInput;

import '../../platform/mcp/tool_support.dart';
import '../headless/headless_workbook.dart';
import 'sheets_mcp_support.dart';
import 'sheets_read_model.dart';
import 'sheets_rule_handlers.dart';
import 'sheets_writes.dart';

/// Charts and pivot tables (Sheets 12 §3.10).
abstract final class SheetsObjectHandlers {
  static ToolResult _result(
    SheetsWriteOutcome o,
    String summary, [
    Map<String, Object?> extra = const {},
  ]) {
    final id = o.changeId?.uuid;
    return ToolResult(
      {...extra, ...o.toJson(), 'summary': summary},
      text:
          '$summary'
          '${o.preview ? ' (suggested, not applied)' : ''}'
          '${id == null ? '' : ' · change_id $id'}'
          '${o.warnings.isEmpty ? '' : '\nWarnings: ${o.warnings.join(' ')}'}',
    );
  }

  static SheetsPlanStep _op(SheetsOperation Function() op) =>
      (model, pctx) => SheetsWrites.planner.plan(op(), model, pctx);

  // --------------------------------------------------------------- charts

  static const _typeAliases = {
    'doughnut': 'pie',
    'donut': 'pie',
    'stacked_column': 'column',
    'stacked_bar': 'bar',
    'column_3d': 'column',
    'bar_3d': 'bar',
    'line_3d': 'line',
    'area_3d': 'area',
    'pie_3d': 'pie',
  };

  /// Chart options of the tools → a JSON merge patch on the spec.
  static Map<String, Object?> optionsPatch(Map<String, dynamic> o) {
    final patch = <String, Object?>{};
    final data = <String, Object?>{};
    final axes = <String, Object?>{};
    for (final e in o.entries) {
      final v = e.value;
      switch (e.key) {
        case 'title':
          patch['title'] = v is Map ? v : {'text': '$v'};
        case 'subtitle':
          patch['subtitle'] = v is Map ? v : {'text': '$v'};
        case 'stacking':
          patch['stacking'] = v == 'stacked' ? 'normal' : v;
        case 'legend':
          patch['legend'] = v is Map ? v : {'position': v};
        case 'switch_rows_columns':
          data['switchRowsColumns'] = v;
        case 'headers':
          data['headerCount'] = v;
        case 'aggregate':
          data['aggregate'] = v;
        case 'x_axis_title':
          axes['h'] = {
            'title': {'text': '$v'},
          };
        case 'y_axis_title':
          axes['v'] = {
            'title': {'text': '$v'},
          };
        case 'series':
          patch['series'] = v;
        case 'three_d' || 'threeD':
          patch['threeD'] = v is bool ? {'enabled': v} : v;
        default:
          patch[e.key] = v;
      }
    }
    if (data.isNotEmpty) patch['data'] = data;
    if (axes.isNotEmpty) patch['axes'] = axes;
    return patch;
  }

  /// Merges two JSON merge patches (later wins).
  static Map<String, Object?> _merge(
    Map<String, Object?> a,
    Map<String, Object?> b,
  ) {
    final out = Map<String, Object?>.of(a);
    b.forEach((k, v) {
      final cur = out[k];
      out[k] = v is Map && cur is Map ? _merge(cur.cast(), v.cast()) : v;
    });
    return out;
  }

  static ChartSpec _patched(ChartSpec spec, Map<String, Object?> patch) {
    if (patch.isEmpty) return spec;
    try {
      return spec.patch(patch);
    } on ChartSpecValidationException catch (e) {
      throw McpToolException(
        McpErrorCode.invalidArgs,
        'Invalid chart options: $e',
      );
    }
  }

  static ChartSpec _withType(ChartSpec spec, String? type) {
    if (type == null) return spec;
    final id = _typeAliases[type] ?? type;
    final t = ChartType.tryParse(id);
    if (t == null) {
      throw McpToolException(
        McpErrorCode.unsupported,
        'Unknown chart type "$type".',
      );
    }
    if (!t.isImplemented) {
      throw McpToolException(
        McpErrorCode.unsupported,
        'The chart type "$type" is not available yet.',
      );
    }
    final patch = <String, Object?>{'type': t.name};
    if (type == 'doughnut' || type == 'donut') {
      patch['typeOptions'] = {'pieHole': 0.5};
    } else if (type == 'stacked_column' || type == 'stacked_bar') {
      patch['stacking'] = 'normal';
    }
    if (type.endsWith('_3d')) {
      patch['threeD'] = {'enabled': true};
    }
    return _patched(spec, patch);
  }

  static List<GridRange> _dataRanges(SheetsTarget t, List<String> a1s) => [
    for (final a1 in a1s)
      () {
        final r = SheetsMcp.range(t, a1);
        final s = t.model.sheet(r.sheetId)!;
        return s.gridRange(SheetsMcp.clipToUsed(s, r));
      }(),
  ];

  /// A default spec for [ranges]: the recommended chart.
  static ChartSpec recommended(HeadlessWorkbook wb, List<GridRange> ranges) {
    final profile = SelectionProfile.fromRanges(ranges, wb.model, wb.engine);
    final suggestions = ChartRecommender.recommend(profile);
    if (suggestions.isEmpty) {
      return ChartSpec(data: ChartDataSpec(ranges: ranges));
    }
    return suggestions.first.spec;
  }

  static ChartSpec _specFor(
    HeadlessWorkbook wb,
    List<GridRange> ranges,
    String? type,
  ) {
    if (type != null) {
      final id = ChartType.tryParse(_typeAliases[type] ?? type);
      final profile = SelectionProfile.fromRanges(ranges, wb.model, wb.engine);
      for (final s in ChartRecommender.recommend(profile)) {
        if (s.spec.type == id &&
            (type != 'doughnut' || s.spec.typeOptions['pieHole'] != null)) {
          return type.endsWith('_3d')
              ? _patched(s.spec, {
                  'threeD': {'enabled': true},
                })
              : s.spec;
        }
      }
    }
    return _withType(recommended(wb, ranges), type);
  }

  static Future<ToolResult> createChart(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final a1s = a.list('data_ranges')!.cast<String>();
    final ranges = _dataRanges(t, a1s);
    final first = SheetsMcp.range(t, a1s.first);
    var spec = _specFor(t.wb, ranges, a.string('type'));
    final options = a.object('options') ?? const {};
    spec = _patched(spec, optionsPatch(options));
    final title = spec.title.text.isEmpty ? null : spec.title.text;
    final ownSheet = a.boolean('own_sheet') ?? false;
    final width =
        a.number('width')?.toDouble() ?? ObjectAnchor.defaultChartWidth;
    final height =
        a.number('height')?.toDouble() ?? ObjectAnchor.defaultChartHeight;
    final id = const Uuid().v7();
    final steps = <SheetsPlanStep>[];
    String sheetId;
    String? anchorA1;
    if (ownSheet) {
      sheetId = const Uuid().v7();
      final sid = sheetId;
      steps.add(
        _op(
          () => AddSheet(
            name: title,
            kind: SheetKind.chart,
            rows: 1,
            columns: 1,
            sheetId: sid,
          ),
        ),
      );
      steps.add(
        _op(
          () => AddObject(
            sid,
            EmbeddedObjectKind.chart,
            anchorJson: const ObjectAnchor.ownSheetAnchor().encode(),
            specJson: spec.encode(),
            title: title,
            id: id,
          ),
        ),
      );
    } else {
      final s = a.has('sheet')
          ? SheetsMcp.sheet(t, a.string('sheet')!)
          : t.model.sheet(first.sheetId)!;
      sheetId = s.id;
      int row, col;
      if (a.has('anchor_cell')) {
        final c = SheetsMcp.range(
          t,
          a.string('anchor_cell')!,
          contextSheetId: s.id,
        );
        if (c.sheetId != s.id) {
          throw SheetsMcp.invalidRange(
            'anchor_cell must be on the chart\'s sheet.',
          );
        }
        row = c.rect.top;
        col = c.rect.left;
      } else if (first.sheetId == s.id) {
        final data = SheetsMcp.clipToUsed(s, first);
        row = data.top;
        col = math.min(data.right + 2, s.columns.length - 1);
      } else {
        row = 0;
        col = 0;
      }
      anchorA1 = CellPos(row, col).a1;
      final anchor = ObjectAnchor.atCell(
        row,
        col,
        width: width,
        height: height,
        rows: s.rows,
        columns: s.columns,
      ).encode();
      steps.add(
        _op(
          () => AddObject(
            s.id,
            EmbeddedObjectKind.chart,
            anchorJson: anchor,
            specJson: spec.encode(),
            title: title,
            id: id,
          ),
        ),
      );
    }
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.create_chart',
      label: SheetsMcp.label(
        ctx,
        'sheets.create_chart',
        title == null ? spec.typeId : '"$title"',
      ),
      structural:
          'Create a ${spec.type.displayName.toLowerCase()} chart'
          '${title == null ? '' : ' "$title"'}',
      intents: (model) => [if (!ownSheet) ObjectWrite(sheetId)],
      steps: steps,
    );
    return _result(
      o,
      'Created ${spec.type.displayName.toLowerCase()} chart'
      '${title == null ? '' : ' "$title"'}',
      {
        'chart_id': id,
        'type': spec.typeId,
        'anchor': anchorA1,
        'sheet': SheetsWrites.modelAfter(ctx, t).sheet(sheetId)?.name,
      },
    );
  }

  static (SheetModel, EmbeddedObjectRecord) _chart(SheetsTarget t, String id) {
    for (final s in t.model.sheets) {
      final o = s.objects[id];
      if (o != null && o.kind == EmbeddedObjectKind.chart) return (s, o);
    }
    throw McpToolException(McpErrorCode.notFound, 'No chart $id.');
  }

  /// The chart spec in A1 form (data ranges as A1 strings).
  static Map<String, Object?> a1Spec(HeadlessWorkbook wb, ChartSpec spec) {
    final json = spec.toJson();
    final data = (json['data'] as Map?)?.cast<String, Object?>();
    if (data != null) {
      data['ranges'] = [
        for (final g in spec.data.ranges)
          if (wb.model.resolve(g) case final ResolvedRange rr)
            wb.model.a1Of(rr),
      ];
      json['data'] = data;
    }
    return json;
  }

  static Future<ToolResult> updateChart(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final id = a.requireString('chart_id');
    final (s, rec) = _chart(t, id);
    var spec = ChartSpec.fromJson(rec.specJson);
    var patch = <String, Object?>{
      ...?a.object('patch')?.cast<String, Object?>(),
    };
    // A1 data ranges in the patch → stored ranges.
    final pData = patch['data'];
    if (pData is Map && pData['ranges'] is List) {
      final ranges = _dataRanges(t, (pData['ranges'] as List).cast<String>());
      patch['data'] = {
        ...pData.cast<String, Object?>(),
        'ranges': [for (final g in ranges) g.toJson()],
      };
    }
    if (a.has('data_ranges')) {
      final ranges = _dataRanges(t, a.list('data_ranges')!.cast<String>());
      final fresh = recommended(t.wb, ranges);
      patch = _merge(patch, {'data': fresh.data.toJson()});
    }
    if (a.has('options')) {
      patch = _merge(patch, optionsPatch(a.object('options')!));
    }
    final type = patch.remove('type');
    spec = _patched(spec, patch);
    if (type is String) spec = _withType(spec, type);
    String? anchorJson;
    final anchor = ObjectAnchor.tryParse(rec.anchorJson);
    if (anchor != null &&
        !anchor.ownSheet &&
        (a.has('anchor_cell') || a.has('width') || a.has('height'))) {
      var row = anchor.rowId == null
          ? 0
          : math.max(0, s.rows.indexOf(anchor.rowId!));
      var col = anchor.colId == null
          ? 0
          : math.max(0, s.columns.indexOf(anchor.colId!));
      if (a.has('anchor_cell')) {
        final c = SheetsMcp.range(
          t,
          a.string('anchor_cell')!,
          contextSheetId: s.id,
        );
        row = c.rect.top;
        col = c.rect.left;
      }
      anchorJson = ObjectAnchor.atCell(
        row,
        col,
        width: a.number('width')?.toDouble() ?? anchor.width,
        height: a.number('height')?.toDouble() ?? anchor.height,
        rows: s.rows,
        columns: s.columns,
      ).encode();
    }
    final title = spec.title.text.isEmpty ? null : spec.title.text;
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.update_chart',
      label: SheetsMcp.label(
        ctx,
        'sheets.update_chart',
        title == null ? id : '"$title"',
      ),
      structural: 'Change chart${title == null ? '' : ' "$title"'}',
      intents: (model) => [ObjectWrite(s.id)],
      steps: [
        _op(
          () => UpdateObject(
            id,
            specJson: spec.encode(),
            anchorJson: anchorJson,
            title: title,
          ),
        ),
      ],
    );
    return _result(o, 'Updated the chart', {'chart_id': id});
  }

  static Future<ToolResult> deleteChart(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final id = a.requireString('chart_id');
    final (s, rec) = _chart(t, id);
    final ownSheet = ObjectAnchor.tryParse(rec.anchorJson)?.ownSheet ?? false;
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.delete_chart',
      label: SheetsMcp.label(ctx, 'sheets.delete_chart', id),
      structural: 'Delete a chart',
      intents: (model) => [ObjectWrite(s.id)],
      steps: [
        _op(() => DeleteObject(id)),
        if (ownSheet && t.model.sheets.length > 1) _op(() => DeleteSheet(s.id)),
      ],
    );
    return _result(o, 'Deleted the chart');
  }

  static ChartData _resolve(HeadlessWorkbook wb, ChartSpec spec) =>
      ChartDataResolver.resolve(spec, wb.model, wb.engine, locale: wb.locale);

  static Future<ToolResult> getChart(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a);
    final id = a.requireString('chart_id');
    final (s, rec) = _chart(t, id);
    final spec = ChartSpec.fromJson(rec.specJson);
    final data = _resolve(t.wb, spec);
    final anchor = ObjectAnchor.tryParse(rec.anchorJson);
    final description = ChartDescriber.describe(spec, data);
    return ToolResult({
      'chart_id': id,
      'sheet': s.name,
      'title': rec.title,
      'alt_text': rec.altText,
      'anchor': SheetsReadModel.anchorA1(s, rec.anchorJson),
      'own_sheet': anchor?.ownSheet ?? false,
      'width': anchor?.width,
      'height': anchor?.height,
      'spec': a1Spec(t.wb, spec),
      'data_summary': {
        'points': data.pointCount,
        'domain': data.domain.name,
        'series': [
          for (final se in data.series)
            {'name': se.name, 'points': se.values.length},
        ],
        if (data.warnings.isNotEmpty)
          'warnings': [for (final w in data.warnings) '$w'],
      },
      'description': description,
    }, text: description);
  }

  static Future<ToolResult> exportChartPng(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a);
    final id = a.requireString('chart_id');
    final (_, rec) = _chart(t, id);
    final png = renderPng(
      t.wb,
      ChartSpec.fromJson(rec.specJson),
      ObjectAnchor.tryParse(rec.anchorJson),
      width: a.number('width')?.toDouble(),
      height: a.number('height')?.toDouble(),
      scale: (a.integer('scale') ?? 1).toDouble(),
      dark: a.boolean('dark') ?? false,
    );
    return ToolResult(
      {'chart_id': id, 'width': png.$2, 'height': png.$3},
      text: 'Chart $id (${png.$2.round()}×${png.$3.round()} px)',
      images: [ToolImage(base64Encode(png.$1))],
    );
  }

  /// Renders a chart as PNG bytes with the pure-Dart raster renderer.
  static (List<int>, double, double) renderPng(
    HeadlessWorkbook wb,
    ChartSpec spec,
    ObjectAnchor? anchor, {
    double? width,
    double? height,
    double scale = 1,
    bool dark = false,
  }) {
    final w =
        width ??
        (anchor != null && anchor.width > 0
            ? anchor.width
            : ObjectAnchor.defaultChartWidth);
    final h =
        height ??
        (anchor != null && anchor.height > 0
            ? anchor.height
            : ObjectAnchor.defaultChartHeight);
    final data = _resolve(wb, spec);
    final scene = ChartLayoutEngine.layout(
      spec,
      data,
      ChartSize(w, h),
      ChartTheme.from(wb.model.theme, dark: dark, export: true),
      const RasterTextMeasurer(),
      fmt: DefaultChartValueFormatter(locale: wb.locale),
    );
    return (const RasterChartRenderer().render(scene, scale: scale), w, h);
  }

  // --------------------------------------------------------------- pivots

  /// The column id of a pivot field: a header name or a column letter
  /// within [source].
  static String fieldId(
    HeadlessWorkbook wb,
    SheetModel s,
    GridRect source,
    String field,
  ) {
    final f = field.trim();
    for (var c = source.left; c <= source.right; c++) {
      if (wb.displayAt(s.id, source.top, c).trim().toLowerCase() ==
          f.toLowerCase()) {
        return s.columns.idAt(c);
      }
    }
    if (RegExp(r'^[A-Za-z]{1,3}$').hasMatch(f)) {
      final c = ColumnLetters.toIndex(f.toUpperCase());
      if (c >= source.left && c <= source.right) return s.columns.idAt(c);
    }
    final headers = [
      for (var c = source.left; c <= source.right; c++)
        wb.displayAt(s.id, source.top, c),
    ];
    throw McpToolException(
      McpErrorCode.invalidArgs,
      'No column "$field" in the source. Headers: '
      '${headers.map((h) => '"$h"').join(', ')}.',
    );
  }

  static String _pivotSpec(
    SheetsTarget t,
    SheetModel s,
    GridRect source,
    ToolArgs a, {
    PivotSpec? base,
  }) {
    PivotGroupSpec group(Map<String, dynamic> g) => PivotGroupSpec(
      fieldId(t.wb, s, source, '${g['source_column']}'),
      showTotals: g['show_totals'] != false,
      ascending: g['sort'] != 'desc',
      repeatLabels:
          (a.object('options')?['repeat_row_labels'] as bool?) ?? false,
    );
    PivotValueSpec value(Map<String, dynamic> v) => PivotValueSpec(
      source: fieldId(t.wb, s, source, '${v['source_column']}'),
      summarizeBy: PivotSummarize.byId(v['summarize_by'] ?? 'sum'),
      name: v['name'] as String?,
      showAs: switch (v['show_as']) {
        'percent_of_row' => PivotShowAs.percentOfRowTotal,
        'percent_of_column' => PivotShowAs.percentOfColumnTotal,
        'percent_of_grand_total' => PivotShowAs.percentOfGrandTotal,
        _ => PivotShowAs.defaultValue,
      },
    );
    PivotFilterSpec filter(Map<String, dynamic> f) {
      final colId = fieldId(t.wb, s, source, '${f['source_column']}');
      final criteria = <String, Object?>{};
      final visible = f['visible_values'];
      if (visible is List) {
        final keep = {for (final v in visible) '$v'};
        final col = s.columns.indexOf(colId);
        final hidden = <String>{};
        for (var r = source.top + 1; r <= source.bottom; r++) {
          final d = t.wb.displayAt(s.id, r, col);
          if (!keep.contains(d)) hidden.add(d);
        }
        criteria['hiddenValues'] = hidden.toList();
      }
      final cond = f['condition'];
      if (cond is Map) {
        criteria['condition'] = SheetsRuleHandlers.conditionJson(
          t,
          cond.cast<String, dynamic>(),
          sheetId: s.id,
          row: source.top + 1,
          col: s.columns.indexOf(colId),
          use: ConditionUse.filter,
        );
      }
      return PivotFilterSpec.fromJson({'source': colId, 'criteria': criteria});
    }

    List<T>? list<T>(String key, T Function(Map<String, dynamic>) f) =>
        a.has(key)
        ? [for (final e in a.list(key)!) f((e as Map).cast<String, dynamic>())]
        : null;
    final b = base ?? const PivotSpec();
    final spec = PivotSpec(
      rows: list('rows', group) ?? b.rows,
      columns: list('columns', group) ?? b.columns,
      values: list('values', value) ?? b.values,
      filters: list('filters', filter) ?? b.filters,
      valueLayout: (a.object('options')?['values_in_rows'] as bool?) == true
          ? PivotValueLayout.rows
          : b.valueLayout,
      showEmptyGroups: b.showEmptyGroups,
    );
    return spec.encode();
  }

  /// The output rectangle of a pivot table (from the pivot engine).
  static GridRect? pivotOutput(
    HeadlessWorkbook wb,
    ResolvedRange source,
    String specJson,
    int row,
    int col,
  ) {
    try {
      final table = SourceTable.fromModel(
        wb.model,
        wb.engine,
        source,
        wb.display,
      );
      final result = const PivotEngine().compute(
        PivotSpec.parse(specJson),
        table,
        PivotContext(locale: wb.locale),
      );
      final grid = PivotLayout.build(result);
      if (grid.rowCount == 0 || grid.columnCount == 0) return null;
      return GridRect(
        row,
        col,
        row + grid.rowCount - 1,
        col + grid.columnCount - 1,
      );
    } on Object {
      return null;
    }
  }

  static Future<ToolResult> createPivotTable(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final src = SheetsMcp.range(t, a.requireString('source'));
    final srcSheet = t.model.sheet(src.sheetId)!;
    final rect = SheetsMcp.clipToUsed(srcSheet, src);
    if (rect.rowCount < 2) {
      throw McpToolException(
        McpErrorCode.invalidArgs,
        'The source needs a header row and at least one data row.',
      );
    }
    final source = ResolvedRange(srcSheet.id, rect);
    final spec = _pivotSpec(t, srcSheet, rect, a);
    final target = a.object('target') ?? const {};
    final id = const Uuid().v7();
    final steps = <SheetsPlanStep>[];
    String sheetId;
    var row = 0, col = 0;
    String? newSheetName;
    if (target['sheet'] == null) {
      sheetId = const Uuid().v7();
      var n = 1;
      while (t.model.sheetByName('Pivot Table $n') != null) {
        n++;
      }
      newSheetName = 'Pivot Table $n';
      final sid = sheetId;
      steps.add(_op(() => AddSheet(name: newSheetName, sheetId: sid)));
    } else {
      final s = SheetsMcp.sheet(t, target['sheet'] as String);
      sheetId = s.id;
    }
    if (target['cell'] != null) {
      final c = SheetsMcp.range(
        t,
        target['cell'] as String,
        contextSheetId: newSheetName == null ? sheetId : srcSheet.id,
      );
      row = c.rect.top;
      col = c.rect.left;
    }
    final sid = sheetId;
    steps.add(_op(() => AddPivotTable(sid, row, col, source, spec, id: id)));
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.create_pivot_table',
      label: SheetsMcp.label(
        ctx,
        'sheets.create_pivot_table',
        t.model.a1Of(source),
      ),
      structural:
          'Create a pivot table of ${t.model.a1Of(source)}'
          '${newSheetName == null ? '' : ' on a new sheet "$newSheetName"'}',
      intents: (model) => [if (newSheetName == null) ObjectWrite(sid)],
      steps: steps,
    );
    final model = SheetsWrites.modelAfter(ctx, t);
    final out = pivotOutput(t.wb, source, spec, row, col);
    final sheetName = model.sheet(sid)?.name ?? newSheetName;
    return _result(o, 'Created a pivot table on "$sheetName"', {
      'pivot_id': id,
      'sheet': sheetName,
      'anchor': CellPos(row, col).a1,
      'output_range': out == null || model.sheet(sid) == null
          ? null
          : SheetsMcp.a1(model, sid, out),
    });
  }

  static (SheetModel, PivotTableRecord) _pivot(SheetsTarget t, String id) {
    for (final s in t.model.sheets) {
      final p = s.pivots[id];
      if (p != null) return (s, p);
    }
    throw McpToolException(McpErrorCode.notFound, 'No pivot table $id.');
  }

  static Future<ToolResult> updatePivotTable(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final id = a.requireString('pivot_id');
    final (s, rec) = _pivot(t, id);
    ResolvedRange? source;
    if (a.has('source')) {
      final r = SheetsMcp.range(t, a.string('source')!);
      final rs = t.model.sheet(r.sheetId)!;
      source = ResolvedRange(rs.id, SheetsMcp.clipToUsed(rs, r));
    }
    final g = GridRange.tryParse(rec.sourceRangeJson);
    final current = source ?? (g == null ? null : t.model.resolve(g));
    if (current == null) {
      throw McpToolException(
        McpErrorCode.invalidArgs,
        'The pivot source no longer exists; pass source.',
      );
    }
    final srcSheet = t.model.sheet(current.sheetId)!;
    final spec = _pivotSpec(
      t,
      srcSheet,
      current.rect,
      a,
      base: PivotSpec.parse(rec.specJson),
    );
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.update_pivot_table',
      label: SheetsMcp.label(ctx, 'sheets.update_pivot_table', id),
      structural: 'Change a pivot table',
      intents: (model) => [ObjectWrite(s.id)],
      steps: [_op(() => UpdatePivotTable(id, specJson: spec, source: source))],
    );
    return _result(o, 'Updated the pivot table', {'pivot_id': id});
  }

  static Future<ToolResult> deletePivotTable(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final id = a.requireString('pivot_id');
    final (s, _) = _pivot(t, id);
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.delete_pivot_table',
      label: SheetsMcp.label(ctx, 'sheets.delete_pivot_table', id),
      structural: 'Delete a pivot table',
      intents: (model) => [ObjectWrite(s.id)],
      steps: [_op(() => DeletePivotTable(id))],
    );
    return _result(o, 'Deleted the pivot table');
  }
}
