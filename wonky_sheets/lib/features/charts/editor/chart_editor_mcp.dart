import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_sheets_core/model.dart';

import '../../objects/objects_controller.dart';
import '../../sheet_editor/sheet_editor_controller.dart';
import '../chart_insert.dart';

/// Kinds of chart editor fields an agent can set.
enum ChartFieldKind { text, number, boolean, choice, color }

/// One field of the chart editor as an agent sees it.
class ChartEditorField {
  const ChartEditorField(
    this.id,
    this.label,
    this.kind, {
    this.options,
    this.section = 'setup',
    this.applies,
  });

  /// The spec path (`title.text`, `series.<key>.color` …) or a pseudo field
  /// (`type`, `dataRanges`).
  final String id;
  final String label;
  final ChartFieldKind kind;

  /// Allowed values of a choice.
  final List<String>? options;

  /// `setup`, or the Customize section (`style`, `titles`, `series` …).
  final String section;

  /// Whether the field applies to a spec (null = always).
  final bool Function(ChartSpec spec)? applies;
}

/// The chart editor as an MCP-describable panel (08 §8.4
/// `McpDescribablePanel`): [describe] lists the fields of the selected (or
/// given) chart with ids, labels, values and options; [setField] writes one
/// through the same `sheets.chart.*` commands as the panel (one undo step
/// each). Used by `ui.sheets.describe_panel` / `set_panel_field` when the
/// chart editor is open.
abstract final class ChartEditorMcp {
  static bool _cartesian(ChartSpec s) => s.type.isCartesian;
  static bool _lines(ChartSpec s) =>
      s.type == ChartType.line ||
      s.type == ChartType.area ||
      s.type == ChartType.combo;
  static bool _pie(ChartSpec s) => s.type == ChartType.pie;

  static List<String> _names(List<Enum> values) => [
    for (final v in values) v.name,
  ];

  /// Fields that don't depend on the series.
  static final List<ChartEditorField> chartFields = [
    ChartEditorField(
      'type',
      'Chart type',
      ChartFieldKind.choice,
      options: [
        for (final t in ChartType.values)
          if (t.isImplemented) t.id,
      ],
    ),
    ChartEditorField(
      'stacking',
      'Stacking',
      ChartFieldKind.choice,
      options: _names(ChartStacking.values),
      applies: (s) => s.type.supportsStacking,
    ),
    const ChartEditorField('dataRanges', 'Data range', ChartFieldKind.text),
    const ChartEditorField(
      'data.switchRowsColumns',
      'Switch rows / columns',
      ChartFieldKind.boolean,
    ),
    const ChartEditorField(
      'data.headerCount',
      'Header rows',
      ChartFieldKind.number,
    ),
    const ChartEditorField(
      'data.includeHidden',
      'Include hidden and filtered data',
      ChartFieldKind.boolean,
    ),
    ChartEditorField(
      'threeD.enabled',
      'Show in 3D',
      ChartFieldKind.boolean,
      section: 'threeD',
      applies: (s) => s.type.supports3D,
    ),
    const ChartEditorField(
      'style.background',
      'Background color',
      ChartFieldKind.color,
      section: 'style',
    ),
    const ChartEditorField(
      'style.border',
      'Chart border color',
      ChartFieldKind.color,
      section: 'style',
    ),
    const ChartEditorField(
      'style.maximize',
      'Maximize',
      ChartFieldKind.boolean,
      section: 'style',
    ),
    ChartEditorField(
      'style.smooth',
      'Smooth',
      ChartFieldKind.boolean,
      section: 'style',
      applies: _lines,
    ),
    const ChartEditorField(
      'title.text',
      'Chart title',
      ChartFieldKind.text,
      section: 'titles',
    ),
    const ChartEditorField(
      'subtitle.text',
      'Chart subtitle',
      ChartFieldKind.text,
      section: 'titles',
    ),
    ChartEditorField(
      'axes.h.title.text',
      'Horizontal axis title',
      ChartFieldKind.text,
      section: 'titles',
      applies: _cartesian,
    ),
    ChartEditorField(
      'axes.v.title.text',
      'Vertical axis title',
      ChartFieldKind.text,
      section: 'titles',
      applies: _cartesian,
    ),
    ChartEditorField(
      'legend.position',
      'Legend position',
      ChartFieldKind.choice,
      options: _names(LegendPosition.values),
      section: 'legend',
    ),
    ChartEditorField(
      'axes.v.min',
      'Vertical axis min',
      ChartFieldKind.number,
      section: 'vAxis',
      applies: _cartesian,
    ),
    ChartEditorField(
      'axes.v.max',
      'Vertical axis max',
      ChartFieldKind.number,
      section: 'vAxis',
      applies: _cartesian,
    ),
    ChartEditorField(
      'axes.v.logScale',
      'Log scale',
      ChartFieldKind.boolean,
      section: 'vAxis',
      applies: _cartesian,
    ),
    ChartEditorField(
      'typeOptions.pieHole',
      'Doughnut hole (0–0.9)',
      ChartFieldKind.number,
      section: 'pie',
      applies: _pie,
    ),
    ChartEditorField(
      'typeOptions.sliceLabel',
      'Slice label',
      ChartFieldKind.choice,
      options: _names(SliceLabel.values),
      section: 'pie',
      applies: _pie,
    ),
  ];

  /// Fields of series [key].
  static List<ChartEditorField> seriesFields(String key, String name) => [
    ChartEditorField(
      'series.$key.color',
      '$name: fill color',
      ChartFieldKind.color,
      section: 'series',
    ),
    ChartEditorField(
      'series.$key.lineWidth',
      '$name: line thickness',
      ChartFieldKind.number,
      section: 'series',
      applies: _lines,
    ),
    ChartEditorField(
      'series.$key.pointSize',
      '$name: point size',
      ChartFieldKind.number,
      section: 'series',
      applies: (s) => _lines(s) || s.type == ChartType.scatter,
    ),
    ChartEditorField(
      'series.$key.axis',
      '$name: axis',
      ChartFieldKind.choice,
      options: _names(SeriesAxis.values),
      section: 'series',
      applies: _cartesian,
    ),
    ChartEditorField(
      'series.$key.dataLabels.show',
      '$name: data labels',
      ChartFieldKind.boolean,
      section: 'series',
    ),
    ChartEditorField(
      'series.$key.trendline.type',
      '$name: trendline (empty = none)',
      ChartFieldKind.choice,
      options: ['', ..._names(TrendlineType.values)],
      section: 'series',
      applies: (s) =>
          s.type.supportsTrendlines && s.stacking == ChartStacking.none,
    ),
    ChartEditorField(
      'series.$key.errorBars.type',
      '$name: error bars (empty = none)',
      ChartFieldKind.choice,
      options: ['', ..._names(ErrorBarType.values)],
      section: 'series',
      applies: _cartesian,
    ),
    ChartEditorField(
      'series.$key.errorBars.value',
      '$name: error bar value',
      ChartFieldKind.number,
      section: 'series',
      applies: _cartesian,
    ),
  ];

  static EmbeddedObjectRecord? _chart(
    SheetEditorController ed,
    String? objectId,
  ) {
    final objs = ObjectsController.of(ed);
    final o = objectId == null ? objs.selected : objs.record(objectId);
    return o?.kind == EmbeddedObjectKind.chart ? o : null;
  }

  static List<ChartEditorField> _fieldsOf(
    SheetEditorController ed,
    EmbeddedObjectRecord o,
    ChartSpec spec,
  ) {
    final data = ObjectsController.of(ed).chartOf(o).data;
    return [
      for (final f in chartFields)
        if (f.applies?.call(spec) ?? true) f,
      if (spec.type != ChartType.scorecard && spec.type != ChartType.table)
        for (final s in data.series)
          for (final f in seriesFields(s.key, s.name))
            if (f.applies?.call(spec) ?? true) f,
    ];
  }

  static Object? _at(Map<String, Object?> json, String path) {
    Object? cur = json;
    for (final part in path.split('.')) {
      if (cur is! Map) return null;
      cur = cur[part];
    }
    return cur;
  }

  static Object? _valueOf(
    SheetEditorController ed,
    ChartSpec spec,
    ChartEditorField f,
  ) {
    switch (f.id) {
      case 'type':
        return spec.typeId;
      case 'stacking':
        return spec.stacking.name;
      case 'dataRanges':
        return ChartInsert.a1Of(ed, spec.data.gridRanges).join(', ');
      case 'data.headerCount':
        return spec.data.headerCount;
      case 'threeD.enabled':
        return spec.threeD.enabled;
      case 'legend.position':
        return spec.legend.position.name;
    }
    final v = _at(spec.toJson(), f.id);
    if (v == null && f.kind == ChartFieldKind.boolean) return false;
    if (v == null && f.kind == ChartFieldKind.choice) {
      return f.id.endsWith('.axis') ? SeriesAxis.left.name : '';
    }
    return v;
  }

  /// `{panel, objectId, chartType, fields: [{id, label, type, section,
  /// value, options?}]}`; null when no chart is selected.
  static Map<String, Object?>? describe(
    SheetEditorController ed, {
    String? objectId,
  }) {
    final o = _chart(ed, objectId);
    if (o == null) return null;
    final spec = ChartSpec.fromJson(o.specJson);
    return {
      'panel': chartEditorPanelId,
      'objectId': o.id,
      'chartType': spec.typeId,
      'readOnly': !ed.canEdit || spec.isFromNewerVersion,
      'fields': [
        for (final f in _fieldsOf(ed, o, spec))
          {
            'id': f.id,
            'label': f.label,
            'type': f.kind.name,
            'section': f.section,
            'value': _valueOf(ed, spec, f),
            'options': ?f.options,
          },
      ],
    };
  }

  /// The merge patch setting [path] to [value] (null removes it).
  static Map<String, Object?> patchFor(String path, Object? value) {
    final parts = path.split('.');
    Object? cur = value;
    for (var i = parts.length - 1; i >= 0; i--) {
      cur = {parts[i]: cur};
    }
    return (cur! as Map).cast<String, Object?>();
  }

  /// Sets field [id] of the selected (or given) chart to [value]. Returns
  /// an error message, or null.
  static Future<String?> setField(
    SheetEditorController ed,
    String id,
    Object? value, {
    String? objectId,
    InvocationSource source = InvocationSource.mcp,
  }) async {
    final o = _chart(ed, objectId);
    if (o == null) return 'No chart is selected.';
    final spec = ChartSpec.fromJson(o.specJson);
    final fields = _fieldsOf(ed, o, spec);
    final f = fields.where((x) => x.id == id).firstOrNull;
    if (f == null) {
      return 'Unknown field "$id". Fields: '
          '${[for (final x in fields) x.id].join(', ')}';
    }
    Object? v = value;
    switch (f.kind) {
      case ChartFieldKind.boolean:
        if (v is! bool) return 'The field "$id" takes true or false.';
      case ChartFieldKind.number:
        if (v is String) v = num.tryParse(v.trim());
        if (v != null && v is! num) return 'The field "$id" takes a number.';
      case ChartFieldKind.choice:
        final s = v == null ? '' : '$v';
        if (!(f.options ?? const []).contains(s)) {
          return 'The field "$id" takes one of: ${f.options!.join(', ')}.';
        }
        v = s.isEmpty ? null : s;
      case ChartFieldKind.color:
        final s = v == null ? '' : '$v'.trim();
        if (s.isNotEmpty && !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(s)) {
          return 'The field "$id" takes a #RRGGBB color (empty = automatic).';
        }
        v = s.isEmpty ? null : s.toUpperCase();
      case ChartFieldKind.text:
        v = v == null ? '' : '$v';
    }
    final Map<String, Object?> args;
    final String command;
    switch (id) {
      case 'type':
        command = 'sheets.chart.setType';
        args = {'objectId': o.id, 'type': v};
      case 'dataRanges':
        command = 'sheets.chart.setDataRanges';
        args = {
          'objectId': o.id,
          'ranges': [
            for (final part in (v! as String).split(','))
              if (part.trim().isNotEmpty) part.trim(),
          ],
        };
      default:
        command = 'sheets.chart.update';
        Object? stored = v;
        if (id.endsWith('.errorBars.type')) {
          stored = v == null ? null : {'type': v};
          args = {
            'objectId': o.id,
            'patch': patchFor(
              id.substring(0, id.length - '.type'.length),
              stored,
            ),
          };
        } else if (id.endsWith('.trendline.type')) {
          args = {
            'objectId': o.id,
            'patch': patchFor(
              id.substring(0, id.length - '.type'.length),
              v == null ? null : {'type': v},
            ),
          };
        } else {
          if (f.kind == ChartFieldKind.text && stored == '') stored = null;
          args = {'objectId': o.id, 'patch': patchFor(id, stored)};
        }
    }
    try {
      final r = await ed.services.dispatcher.invoke(
        command,
        args: args,
        source: source,
      );
      return r.isOk ? null : (r.message ?? 'Could not set "$id".');
    } catch (e) {
      return '$e';
    }
  }
}
