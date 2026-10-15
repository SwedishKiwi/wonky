import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_ui/wonky_ui.dart';

/// Reports a style edit as an RFC 7386 merge patch over the chart spec
/// (null values reset a key); [coalesceKey] groups a burst of edits of one
/// field into one undo step (sliders, typing).
typedef ChartStylePatch =
    void Function(Map<String, Object?> patch, {String? coalesceKey});

/// The texts of [ChartStyleEditor] (the app passes its localized strings;
/// [ChartStyleEditorStrings.english] is the default).
abstract class ChartStyleEditorStrings {
  const ChartStyleEditorStrings();

  /// English texts.
  const factory ChartStyleEditorStrings.english() = _English;

  String get sectionTitles;
  String get sectionLegend;
  String get sectionSeries;
  String get sectionAxes;
  String get sectionGridlines;
  String get sectionPie;
  String get section3D;
  String get sectionLayout;
  String get chartTitle;
  String get subtitle;
  String get horizontalAxisTitle;
  String get verticalAxisTitle;
  String get legendPosition;
  String get series;
  String get color;
  String get lineWidth;
  String get pointSize;
  String get dataLabels;
  String get horizontalAxisLine;
  String get verticalAxisLine;
  String get numberFormat;
  String get horizontalGridlines;
  String get verticalGridlines;
  String get maximize;
  String get donutHole;
  String get sliceLabels;
  String get startAngle;
  String get lighting;
  String get walls;
  String get depth;
  String get gapDepth;
  String get shape;
  String get explode;
  String get automatic;
  String get none;

  /// Tooltip of the per-field reset ("Reset to the spreadsheet's value").
  String get resetField;

  /// Semantics of the dot of a changed field.
  String get changedHere;
  String legend(LegendPosition p);
  String sliceLabel(SliceLabel s);
  String lightingOption(Chart3DLighting l);
  String shapeOption(Chart3DShape s);
}

/// The Customize part of the chart editor as a shared widget (Slides 08 §2.2,
/// §8.1): titles, legend, series, axes, gridlines, layout, pie and 3D options
/// of [spec], edited through [onPatch] merge patches — no command or app type
/// inside.
///
/// **Override mode** (Slides' linked charts): [allows] limits the editable
/// fields to an allowlist (others are not shown), [overrides] marks the
/// fields the deck changed with a dot and a per-field reset (a null patch).
/// Without [allows] every field is editable (full mode, native charts).
class ChartStyleEditor extends StatelessWidget {
  const ChartStyleEditor({
    super.key,
    required this.spec,
    required this.onPatch,
    this.data,
    this.overrides = const {},
    this.allows,
    this.enabled = true,
    this.strings = const ChartStyleEditorStrings.english(),
    this.keyPrefix = 'charts.style',
    this.initiallyOpen = const {'titles'},
  });

  /// The chart as rendered (effective spec: displayed values).
  final ChartSpec spec;

  /// The chart's data (series names and keys).
  final ChartData? data;

  /// The merge patch the deck applies over the source spec (override mode).
  final Map<String, Object?> overrides;

  /// Whether the field at a spec path may be edited (null = all).
  final bool Function(List<String> path)? allows;
  final bool enabled;
  final ChartStylePatch onPatch;
  final ChartStyleEditorStrings strings;

  /// Widget key prefix (`<prefix>.<field>`).
  final String keyPrefix;

  /// Groups expanded at first.
  final Set<String> initiallyOpen;

  /// The patch that sets [path] to [value] (null = reset).
  static Map<String, Object?> patchAt(List<String> path, Object? value) {
    Map<String, Object?> out = {path.last: value};
    for (final k in path.reversed.skip(1)) {
      out = {k: out};
    }
    return out;
  }

  /// Whether [overrides] set [path] (or something below it).
  static bool isOverridden(Map<String, Object?> overrides, List<String> path) {
    Object? cur = overrides;
    for (final k in path) {
      if (cur is! Map || !cur.containsKey(k)) return false;
      cur = cur[k];
    }
    return true;
  }

  bool _can(List<String> path) => allows?.call(path) ?? true;

  static const _lineTypes = {
    ChartType.line,
    ChartType.area,
    ChartType.combo,
    ChartType.scatter,
    ChartType.radar,
  };

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final type = spec.type;
    final groups = <Widget>[];
    void group(String id, String title, List<Widget?> fields) {
      final kids = [...fields.whereType<Widget>()];
      if (kids.isEmpty) return;
      groups.add(
        _Group(
          key: ValueKey<String>('$keyPrefix.group.$id'),
          title: title,
          initiallyOpen: initiallyOpen.contains(id),
          children: kids,
        ),
      );
    }

    final cartesian = type.isCartesian;
    group('titles', s.sectionTitles, [
      _text('title', s.chartTitle, ['title', 'text'], spec.title.text),
      _text('subtitle', s.subtitle, ['subtitle', 'text'], spec.subtitle.text),
      if (cartesian) ...[
        _text('axisH.title', s.horizontalAxisTitle, [
          'axes',
          'h',
          'title',
          'text',
        ], spec.axes.h.title.text),
        _text('axisV.title', s.verticalAxisTitle, [
          'axes',
          'v',
          'title',
          'text',
        ], spec.axes.v.title.text),
      ],
    ]);
    if (type != ChartType.scorecard && type != ChartType.table) {
      group('legend', s.sectionLegend, [
        _select<LegendPosition>(
          'legend.position',
          s.legendPosition,
          ['legend', 'position'],
          spec.legend.position,
          LegendPosition.values,
          s.legend,
          (v) => v.name,
        ),
      ]);
    }
    final series = data?.series ?? const <ChartSeries>[];
    if (series.isNotEmpty &&
        [
          'color',
          'lineWidth',
          'pointSize',
          'dataLabels',
        ].any((f) => _can(['series', series.first.key, f])) &&
        type != ChartType.pie &&
        type != ChartType.table &&
        type != ChartType.scorecard) {
      group('series', s.sectionSeries, [
        _SeriesFields(editor: this, series: series),
      ]);
    }
    if (cartesian) {
      group('axes', s.sectionAxes, [
        _switch('axisH.line', s.horizontalAxisLine, [
          'axes',
          'h',
          'showLine',
        ], spec.axes.h.showLine),
        _switch('axisV.line', s.verticalAxisLine, [
          'axes',
          'v',
          'showLine',
        ], spec.axes.v.showLine),
        _select<String>(
          'axisV.format',
          s.numberFormat,
          ['axes', 'v', 'numberFormat'],
          spec.axes.v.numberFormat ?? '',
          const ['', '0', '0.0', '#,##0', '#,##0.00', '0%', '0.0%', r'$#,##0'],
          (f) => f.isEmpty ? s.automatic : f,
          (f) => f.isEmpty ? null : f,
        ),
      ]);
      group('gridlines', s.sectionGridlines, [
        _switch('gridlines.v', s.verticalGridlines, [
          'gridlines',
          'v',
          'major',
          'show',
        ], spec.gridlines.v.major.show ?? true),
        _switch('gridlines.h', s.horizontalGridlines, [
          'gridlines',
          'h',
          'major',
          'show',
        ], spec.gridlines.h.major.show ?? false),
      ]);
    }
    if (type == ChartType.pie) {
      final pie = spec.pieOptions;
      group('pie', s.sectionPie, [
        _select<double>(
          'pie.hole',
          s.donutHole,
          ['typeOptions', 'pieHole'],
          _nearest(pie.pieHole, const [0, 0.25, 0.5, 0.75]),
          const [0, 0.25, 0.5, 0.75],
          (v) => v == 0 ? s.none : '${(v * 100).round()} %',
          (v) => v,
        ),
        _select<SliceLabel>(
          'pie.sliceLabel',
          s.sliceLabels,
          ['typeOptions', 'sliceLabel'],
          pie.sliceLabel,
          SliceLabel.values,
          s.sliceLabel,
          (v) => v.name,
        ),
        _select<double>(
          'pie.startAngle',
          s.startAngle,
          ['typeOptions', 'startAngle'],
          _nearest(pie.startAngle, const [0, 45, 90, 135, 180, 225, 270, 315]),
          const [0, 45, 90, 135, 180, 225, 270, 315],
          (v) => '${v.round()}°',
          (v) => v,
        ),
      ]);
    }
    if (spec.is3D) {
      final t = spec.threeD;
      final pie = type == ChartType.pie;
      group('threeD', s.section3D, [
        _select<Chart3DLighting>(
          '3d.lighting',
          s.lighting,
          ['threeD', 'lighting'],
          t.lighting,
          Chart3DLighting.values,
          s.lightingOption,
          (v) => v.name,
        ),
        if (!pie)
          _switch('3d.walls', s.walls, [
            'threeD',
            'wallsVisible',
          ], t.wallsVisible),
        _select<double>(
          '3d.depth',
          s.depth,
          ['threeD', 'depth'],
          _nearest(t.depth, const [20, 50, 100, 150, 200, 300, 500]),
          const [20, 50, 100, 150, 200, 300, 500],
          (v) => '${v.round()} %',
          (v) => v,
        ),
        if (!pie)
          _select<double>(
            '3d.gapDepth',
            s.gapDepth,
            ['threeD', 'gapDepth'],
            _nearest(t.gapDepth, const [0, 50, 100, 150, 250, 500]),
            const [0, 50, 100, 150, 250, 500],
            (v) => '${v.round()} %',
            (v) => v,
          ),
        if (type == ChartType.column || type == ChartType.bar)
          _select<Chart3DShape>(
            '3d.shape',
            s.shape,
            ['threeD', 'shape'],
            t.shape,
            Chart3DShape.values,
            s.shapeOption,
            (v) => v.name,
          ),
        if (pie)
          _select<double>(
            '3d.explode',
            s.explode,
            ['threeD', 'explode'],
            _nearest(t.explode, const [0, 0.1, 0.2, 0.3, 0.5]),
            const [0, 0.1, 0.2, 0.3, 0.5],
            (v) => v == 0 ? s.none : '${(v * 100).round()} %',
            (v) => v,
          ),
      ]);
    }
    group('layout', s.sectionLayout, [
      _switch('maximize', s.maximize, [
        'style',
        'maximize',
      ], spec.style.maximize),
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: groups,
    );
  }

  static double _nearest(double v, List<double> options) {
    var best = options.first;
    for (final o in options) {
      if ((o - v).abs() < (best - v).abs()) best = o;
    }
    return best;
  }

  Widget? _text(String id, String label, List<String> path, String value) {
    if (!_can(path)) return null;
    return _Field(
      editor: this,
      label: label,
      path: path,
      child: _TextInput(
        key: ValueKey<String>('$keyPrefix.$id'),
        value: value,
        enabled: enabled,
        placeholder: label,
        onCommit: (v) => onPatch(patchAt(path, v)),
      ),
    );
  }

  Widget? _switch(String id, String label, List<String> path, bool value) {
    if (!_can(path)) return null;
    return _Field(
      editor: this,
      label: label,
      path: path,
      child: ShadSwitch(
        key: ValueKey<String>('$keyPrefix.$id'),
        value: value,
        enabled: enabled,
        onChanged: (v) => onPatch(patchAt(path, v)),
      ),
    );
  }

  Widget? _select<T>(
    String id,
    String label,
    List<String> path,
    T value,
    List<T> options,
    String Function(T) labelOf,
    Object? Function(T) jsonOf,
  ) {
    if (!_can(path)) return null;
    return _Field(
      editor: this,
      label: label,
      path: path,
      child: ShadSelect<T>(
        key: ValueKey<String>('$keyPrefix.$id.$value'),
        initialValue: value,
        enabled: enabled,
        minWidth: 120,
        options: [
          for (final o in options)
            ShadOption<T>(value: o, child: Text(labelOf(o))),
        ],
        selectedOptionBuilder: (_, v) => Text(labelOf(v)),
        onChanged: (v) {
          if (v != null && v != value) onPatch(patchAt(path, jsonOf(v)));
        },
      ),
    );
  }
}

/// One labelled field with the "changed here" dot and reset (override mode).
class _Field extends StatelessWidget {
  const _Field({
    required this.editor,
    required this.label,
    required this.path,
    required this.child,
  });

  final ChartStyleEditor editor;
  final String label;
  final List<String> path;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final changed =
        editor.allows != null &&
        ChartStyleEditor.isOverridden(editor.overrides, path);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Row(
              children: [
                if (changed)
                  Semantics(
                    label: editor.strings.changedHere,
                    child: Container(
                      key: ValueKey<String>(
                        '${editor.keyPrefix}.changed.${path.join('.')}',
                      ),
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: child),
          ),
          if (changed)
            ShadTooltip(
              builder: (_) => Text(editor.strings.resetField),
              child: ShadIconButton.ghost(
                key: ValueKey<String>(
                  '${editor.keyPrefix}.reset.${path.join('.')}',
                ),
                width: 28,
                height: 28,
                enabled: editor.enabled,
                icon: const Icon(LucideIcons.undo2, size: 14),
                onPressed: () =>
                    editor.onPatch(ChartStyleEditor.patchAt(path, null)),
              ),
            ),
        ],
      ),
    );
  }
}

/// The per-series fields: a series picker, color, line width, point size,
/// data labels.
class _SeriesFields extends StatefulWidget {
  const _SeriesFields({required this.editor, required this.series});

  final ChartStyleEditor editor;
  final List<ChartSeries> series;

  @override
  State<_SeriesFields> createState() => _SeriesFieldsState();
}

class _SeriesFieldsState extends State<_SeriesFields> {
  String? _key;
  final _popover = ShadPopoverController();

  @override
  void dispose() {
    _popover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.editor;
    final s = e.strings;
    final theme = ShadTheme.of(context);
    final all = widget.series;
    final key = all.any((x) => x.key == _key) ? _key! : all.first.key;
    final style = e.spec.seriesStyle(key);
    List<String> p(String f) => ['series', key, f];
    final lines = ChartStyleEditor._lineTypes.contains(e.spec.type);
    final swatch = _parse(style.color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ShadSelect<String>(
            key: ValueKey<String>('${e.keyPrefix}.series.pick.$key'),
            initialValue: key,
            minWidth: 160,
            options: [
              for (final x in all)
                ShadOption<String>(value: x.key, child: Text(x.name)),
            ],
            selectedOptionBuilder: (_, v) => Text(
              all.firstWhere((x) => x.key == v, orElse: () => all.first).name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onChanged: (v) => setState(() => _key = v),
          ),
        ),
        if (e._can(p('color')))
          _Field(
            editor: e,
            label: s.color,
            path: p('color'),
            child: ShadPopover(
              controller: _popover,
              popover: (context) => WonkyColorPicker(
                value: style.color == null ? null : WonkyColor(style.color!),
                resetLabel: s.automatic,
                onChanged: (c) {
                  _popover.hide();
                  e.onPatch(ChartStyleEditor.patchAt(p('color'), c?.hex));
                },
              ),
              child: ShadButton.outline(
                key: ValueKey<String>('${e.keyPrefix}.series.color'),
                size: ShadButtonSize.sm,
                enabled: e.enabled,
                onPressed: _popover.toggle,
                leading: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: swatch,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: theme.colorScheme.border),
                  ),
                ),
                child: Flexible(
                  child: Text(
                    style.color?.toUpperCase() ?? s.automatic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        if (lines)
          ?e._select<double>(
            'series.lineWidth',
            s.lineWidth,
            p('lineWidth'),
            ChartStyleEditor._nearest(style.lineWidth ?? 2, const [
              0,
              1,
              2,
              3,
              4,
              6,
              8,
            ]),
            const [0, 1, 2, 3, 4, 6, 8],
            (v) => '${v.round()} px',
            (v) => v,
          ),
        if (lines)
          ?e._select<double>(
            'series.pointSize',
            s.pointSize,
            p('pointSize'),
            ChartStyleEditor._nearest(style.pointSize ?? 0, const [
              0,
              3,
              5,
              7,
              10,
              14,
            ]),
            const [0, 3, 5, 7, 10, 14],
            (v) => v == 0 ? s.none : '${v.round()} px',
            (v) => v,
          ),
        ?e._switch('series.dataLabels', s.dataLabels, [
          'series',
          key,
          'dataLabels',
          'show',
        ], style.dataLabels.show),
      ],
    );
  }

  static Color? _parse(String? hex) {
    if (hex == null) return null;
    final h = hex.replaceFirst('#', '');
    final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return v == null ? null : Color(v);
  }
}

/// A collapsible group of fields.
class _Group extends StatefulWidget {
  const _Group({
    super.key,
    required this.title,
    required this.children,
    this.initiallyOpen = false,
  });

  final String title;
  final List<Widget> children;
  final bool initiallyOpen;

  @override
  State<_Group> createState() => _GroupState();
}

class _GroupState extends State<_Group> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: _open,
          child: ShadButton.ghost(
            key: widget.key is ValueKey<String>
                ? ValueKey<String>(
                    '${(widget.key! as ValueKey<String>).value}.toggle',
                  )
                : null,
            size: ShadButtonSize.sm,
            mainAxisAlignment: MainAxisAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(
              _open ? LucideIcons.chevronDown : LucideIcons.chevronRight,
              size: 14,
            ),
            onPressed: () => setState(() => _open = !_open),
            child: Flexible(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          ),
      ],
    );
  }
}

/// A text input that commits on Enter and when it loses focus.
class _TextInput extends StatefulWidget {
  const _TextInput({
    super.key,
    required this.value,
    required this.onCommit,
    this.enabled = true,
    this.placeholder,
  });

  final String value;
  final ValueChanged<String> onCommit;
  final bool enabled;
  final String? placeholder;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final _c = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_TextInput old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_focus.hasFocus) {
      _c.text = widget.value;
    }
  }

  void _commit() {
    if (_c.text != widget.value) widget.onCommit(_c.text);
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShadInput(
    controller: _c,
    focusNode: _focus,
    enabled: widget.enabled,
    placeholder: widget.placeholder == null ? null : Text(widget.placeholder!),
    onSubmitted: (_) => _commit(),
  );
}

class _English extends ChartStyleEditorStrings {
  const _English();

  @override
  String get sectionTitles => 'Chart & axis titles';
  @override
  String get sectionLegend => 'Legend';
  @override
  String get sectionSeries => 'Series';
  @override
  String get sectionAxes => 'Axes';
  @override
  String get sectionGridlines => 'Gridlines';
  @override
  String get sectionPie => 'Pie chart';
  @override
  String get section3D => '3D';
  @override
  String get sectionLayout => 'Layout';
  @override
  String get chartTitle => 'Chart title';
  @override
  String get subtitle => 'Subtitle';
  @override
  String get horizontalAxisTitle => 'Horizontal axis title';
  @override
  String get verticalAxisTitle => 'Vertical axis title';
  @override
  String get legendPosition => 'Position';
  @override
  String get series => 'Series';
  @override
  String get color => 'Color';
  @override
  String get lineWidth => 'Line width';
  @override
  String get pointSize => 'Point size';
  @override
  String get dataLabels => 'Data labels';
  @override
  String get horizontalAxisLine => 'Horizontal axis line';
  @override
  String get verticalAxisLine => 'Vertical axis line';
  @override
  String get numberFormat => 'Number format';
  @override
  String get horizontalGridlines => 'Horizontal axis gridlines';
  @override
  String get verticalGridlines => 'Vertical axis gridlines';
  @override
  String get maximize => 'Maximize';
  @override
  String get donutHole => 'Donut hole';
  @override
  String get sliceLabels => 'Slice labels';
  @override
  String get startAngle => 'Start angle';
  @override
  String get lighting => 'Lighting';
  @override
  String get walls => 'Walls and floor';
  @override
  String get depth => 'Depth';
  @override
  String get gapDepth => 'Gap depth';
  @override
  String get shape => 'Shape';
  @override
  String get explode => 'Explode';
  @override
  String get automatic => 'Automatic';
  @override
  String get none => 'None';
  @override
  String get resetField => "Reset to the spreadsheet's value";
  @override
  String get changedHere => 'Changed in this presentation';
  @override
  String legend(LegendPosition p) => switch (p) {
    LegendPosition.auto => 'Automatic',
    LegendPosition.top => 'Top',
    LegendPosition.bottom => 'Bottom',
    LegendPosition.left => 'Left',
    LegendPosition.right => 'Right',
    LegendPosition.inside => 'Inside',
    LegendPosition.none => 'None',
  };
  @override
  String sliceLabel(SliceLabel s) => switch (s) {
    SliceLabel.none => 'None',
    SliceLabel.label => 'Label',
    SliceLabel.value => 'Value',
    SliceLabel.percentage => 'Percentage',
    SliceLabel.valueAndPercentage => 'Value and percentage',
  };
  @override
  String lightingOption(Chart3DLighting l) => switch (l) {
    Chart3DLighting.soft => 'Soft',
    Chart3DLighting.bright => 'Bright',
    Chart3DLighting.flat => 'Flat',
  };
  @override
  String shapeOption(Chart3DShape s) => switch (s) {
    Chart3DShape.box => 'Box',
    Chart3DShape.cylinder => 'Cylinder',
    Chart3DShape.cone => 'Cone',
    Chart3DShape.pyramid => 'Pyramid',
  };
}
