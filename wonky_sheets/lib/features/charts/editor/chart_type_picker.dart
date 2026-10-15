import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_charts_flutter/wonky_charts_flutter.dart';

import '../../../l10n/sheets_l10n.dart';

/// A chart type with its preset variant (stacking, doughnut hole, smooth
/// lines) as offered by the type picker (08 §8.3).
@immutable
class ChartVariant {
  const ChartVariant(
    this.id,
    this.type, {
    this.stacking = ChartStacking.none,
    this.pieHole = 0,
    this.smooth = false,
    this.threeD = false,
  });

  final String id;
  final ChartType type;
  final ChartStacking stacking;
  final double pieHole;
  final bool smooth;

  /// Drawn in 3D (08 §23).
  final bool threeD;

  /// Whether [spec] shows this variant.
  bool matches(ChartSpec spec) =>
      spec.type == type &&
      spec.is3D == threeD &&
      (!type.supportsStacking || spec.stacking == stacking) &&
      (type != ChartType.pie ||
          (spec.pieOptions.pieHole > 0) == (pieHole > 0)) &&
      (type != ChartType.line || spec.style.smooth == smooth);

  /// `sheets.chart.setType` arguments.
  Map<String, Object?> args(String objectId) => {
    'objectId': objectId,
    'type': type.id,
    if (type.supportsStacking) 'stacking': stacking.name,
    if (type == ChartType.pie) 'pieHole': pieHole,
    if (type == ChartType.line) 'smooth': smooth,
    if (type.supports3D && !type.only3D) 'threeD': threeD,
  };

  String label(SheetsLocalizations l) => switch (id) {
    'line' => l.chartTypeLine,
    'smoothLine' => l.chartTypeSmoothLine,
    'combo' => l.chartTypeCombo,
    'area' => l.chartTypeArea,
    'stackedArea' => l.chartTypeStackedArea,
    'percentArea' => l.chartTypePercentArea,
    'column' => l.chartTypeColumn,
    'stackedColumn' => l.chartTypeStackedColumn,
    'percentColumn' => l.chartTypePercentColumn,
    'bar' => l.chartTypeBar,
    'stackedBar' => l.chartTypeStackedBar,
    'percentBar' => l.chartTypePercentBar,
    'pie' => l.chartTypePie,
    'doughnut' => l.chartTypeDoughnut,
    'scatter' => l.chartTypeScatter,
    'bubble' => l.chartTypeBubble,
    'histogram' => l.chartTypeHistogram,
    'candlestick' => l.chartTypeCandlestick,
    'waterfall' => l.chartTypeWaterfall,
    'scorecard' => l.chartTypeScorecard,
    'table' => l.chartTypeTable,
    'radar' => l.chartTypeRadar,
    'column3d' => l.chartType3DColumn,
    'stackedColumn3d' => l.chartType3DStackedColumn,
    'percentColumn3d' => l.chartType3DPercentColumn,
    'bar3d' => l.chartType3DBar,
    'stackedBar3d' => l.chartType3DStackedBar,
    'line3d' => l.chartType3DLine,
    'area3d' => l.chartType3DArea,
    'stackedArea3d' => l.chartType3DStackedArea,
    'pie3d' => l.chartType3DPie,
    'doughnut3d' => l.chartType3DDoughnut,
    'surface3d' => l.chartType3DSurface,
    _ => type.displayName,
  };
}

/// Every variant of the P0 and P1 types, by picker group.
const chartVariantGroups = <String, List<ChartVariant>>{
  'line': [
    ChartVariant('line', ChartType.line),
    ChartVariant('smoothLine', ChartType.line, smooth: true),
    ChartVariant('combo', ChartType.combo),
  ],
  'area': [
    ChartVariant('area', ChartType.area),
    ChartVariant('stackedArea', ChartType.area, stacking: ChartStacking.normal),
    ChartVariant(
      'percentArea',
      ChartType.area,
      stacking: ChartStacking.percent,
    ),
  ],
  'column': [
    ChartVariant('column', ChartType.column),
    ChartVariant(
      'stackedColumn',
      ChartType.column,
      stacking: ChartStacking.normal,
    ),
    ChartVariant(
      'percentColumn',
      ChartType.column,
      stacking: ChartStacking.percent,
    ),
  ],
  'bar': [
    ChartVariant('bar', ChartType.bar),
    ChartVariant('stackedBar', ChartType.bar, stacking: ChartStacking.normal),
    ChartVariant('percentBar', ChartType.bar, stacking: ChartStacking.percent),
  ],
  'pie': [
    ChartVariant('pie', ChartType.pie),
    ChartVariant('doughnut', ChartType.pie, pieHole: 0.5),
  ],
  'scatter': [
    ChartVariant('scatter', ChartType.scatter),
    ChartVariant('bubble', ChartType.bubble),
  ],
  '3d': [
    ChartVariant('column3d', ChartType.column, threeD: true),
    ChartVariant(
      'stackedColumn3d',
      ChartType.column,
      stacking: ChartStacking.normal,
      threeD: true,
    ),
    ChartVariant(
      'percentColumn3d',
      ChartType.column,
      stacking: ChartStacking.percent,
      threeD: true,
    ),
    ChartVariant('bar3d', ChartType.bar, threeD: true),
    ChartVariant(
      'stackedBar3d',
      ChartType.bar,
      stacking: ChartStacking.normal,
      threeD: true,
    ),
    ChartVariant('line3d', ChartType.line, threeD: true),
    ChartVariant('area3d', ChartType.area, threeD: true),
    ChartVariant(
      'stackedArea3d',
      ChartType.area,
      stacking: ChartStacking.normal,
      threeD: true,
    ),
    ChartVariant('pie3d', ChartType.pie, threeD: true),
    ChartVariant('doughnut3d', ChartType.pie, pieHole: 0.5, threeD: true),
    ChartVariant('surface3d', ChartType.surface, threeD: true),
  ],
  'other': [
    ChartVariant('histogram', ChartType.histogram),
    ChartVariant('candlestick', ChartType.candlestick),
    ChartVariant('waterfall', ChartType.waterfall),
    ChartVariant('scorecard', ChartType.scorecard),
    ChartVariant('table', ChartType.table),
    ChartVariant('radar', ChartType.radar),
  ],
};

/// All variants.
List<ChartVariant> get allChartVariants => [
  for (final g in chartVariantGroups.values) ...g,
];

/// The variant shown by [spec] (falls back to its plain type).
ChartVariant variantOf(ChartSpec spec) {
  for (final v in allChartVariants) {
    if (v.matches(spec)) return v;
  }
  return allChartVariants.firstWhere(
    (v) => v.type == spec.type,
    orElse: () => allChartVariants.first,
  );
}

/// The variant of a recommended spec.
ChartVariant variantOfSuggestion(ChartSuggestion s) => variantOf(s.spec);

String _groupLabel(SheetsLocalizations l, String g) => switch (g) {
  'line' => l.chartGroupLine,
  'area' => l.chartGroupArea,
  'column' => l.chartGroupColumn,
  'bar' => l.chartGroupBar,
  'pie' => l.chartGroupPie,
  'scatter' => l.chartGroupScatter,
  '3d' => l.chartGroup3D,
  _ => l.chartGroupOther,
};

/// The chart type select of the editor (08 §8.3): a button with the
/// current type that opens a popover with search, the suggested types and
/// all types by group, each drawn as a [ChartTypeIcon].
class ChartTypePicker extends StatefulWidget {
  const ChartTypePicker({
    super.key,
    required this.value,
    required this.suggestions,
    required this.onSelected,
    this.enabled = true,
  });

  final ChartVariant value;
  final List<ChartVariant> suggestions;
  final ValueChanged<ChartVariant> onSelected;
  final bool enabled;

  @override
  State<ChartTypePicker> createState() => _ChartTypePickerState();
}

class _ChartTypePickerState extends State<ChartTypePicker> {
  final _popover = ShadPopoverController();
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _popover.dispose();
    _search.dispose();
    super.dispose();
  }

  void _pick(ChartVariant v) {
    _popover.hide();
    widget.onSelected(v);
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    return ShadPopover(
      controller: _popover,
      popover: (context) => SizedBox(
        width: 296,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShadInput(
                  key: const ValueKey<String>('chartEditor.type.search'),
                  controller: _search,
                  autofocus: true,
                  placeholder: Text(l.chartTypeSearch),
                  leading: const Icon(LucideIcons.search, size: 14),
                  onChanged: (v) => setState(() => _query = v.toLowerCase()),
                ),
                ..._groups(context, l, theme),
              ],
            ),
          ),
        ),
      ),
      child: ShadButton.outline(
        key: const ValueKey<String>('chartEditor.type'),
        enabled: widget.enabled,
        width: double.infinity,
        mainAxisAlignment: MainAxisAlignment.start,
        onPressed: () {
          _search.clear();
          setState(() => _query = '');
          _popover.toggle();
        },
        leading: SizedBox(
          width: 24,
          height: 18,
          child: chartVariantIcon(widget.value),
        ),
        trailing: const Icon(LucideIcons.chevronDown, size: 14),
        child: Expanded(
          child: Text(
            widget.value.label(l),
            textAlign: TextAlign.start,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  List<Widget> _groups(
    BuildContext context,
    SheetsLocalizations l,
    ShadThemeData theme,
  ) {
    bool match(ChartVariant v) =>
        _query.isEmpty || v.label(l).toLowerCase().contains(_query);
    final out = <Widget>[];
    void group(String title, List<ChartVariant> list, String key) {
      final shown = list.where(match).toList();
      if (shown.isEmpty) return;
      out.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
          child: Text(
            title,
            style: theme.textTheme.muted.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      out.add(
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final v in shown)
              _Tile(
                key: ValueKey<String>('chartEditor.type.$key.${v.id}'),
                variant: v,
                label: v.label(l),
                selected: v.id == widget.value.id,
                onTap: () => _pick(v),
              ),
          ],
        ),
      );
    }

    if (widget.suggestions.isNotEmpty) {
      group(l.chartGroupSuggested, widget.suggestions, 'suggested');
    }
    for (final e in chartVariantGroups.entries) {
      group(_groupLabel(l, e.key), e.value, e.key);
    }
    if (out.isEmpty) {
      out.add(
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(l.chartTypeNoMatch, style: theme.textTheme.muted),
        ),
      );
    }
    return out;
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.variant,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ChartVariant variant;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadTooltip(
      builder: (_) => Text(label),
      child: Semantics(
        label: label,
        selected: selected,
        button: true,
        child: ShadButton.ghost(
          width: 60,
          height: 50,
          padding: const EdgeInsets.all(6),
          backgroundColor: selected ? theme.colorScheme.accent : null,
          decoration: ShadDecoration(
            border: ShadBorder.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.border,
              radius: BorderRadius.circular(6),
            ),
          ),
          onPressed: onTap,
          child: SizedBox(
            width: 48,
            height: 36,
            child: chartVariantIcon(variant),
          ),
        ),
      ),
    );
  }
}

/// The shared icon of [v] (`ChartTypeIcon` of `wonky_charts_flutter`).
ChartTypeIcon chartVariantIcon(ChartVariant v) => ChartTypeIcon(
  id: v.id,
  type: v.type,
  stacking: v.stacking,
  pieHole: v.pieHole,
  smooth: v.smooth,
  threeD: v.threeD,
);
